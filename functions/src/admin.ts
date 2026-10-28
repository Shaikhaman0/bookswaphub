import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getAuth } from 'firebase-admin/auth';
import { db, FieldValue, requireAdmin, str } from './shared';

async function audit(adminUid: string, action: string, target: string, details: Record<string, unknown> = {}) {
  await db.collection('auditLogs').add({ adminUid, action, target, details, createdAt: FieldValue.serverTimestamp() });
}

async function countOf(q: FirebaseFirestore.Query): Promise<number> {
  return (await q.count().get()).data().count;
}

export const adminStats = onCall(async (request) => {
  await requireAdmin(request);
  const [users, availableBooks, swapsPending, swapsActive, swapsCompleted, openReports, paidOrders] = await Promise.all([
    countOf(db.collection('users')),
    countOf(db.collection('books').where('status', '==', 'available')),
    countOf(db.collection('swapRequests').where('status', '==', 'pending')),
    countOf(db.collection('swapRequests').where('status', 'in', ['accepted', 'inProgress'])),
    countOf(db.collection('swapRequests').where('status', '==', 'completed')),
    countOf(db.collection('reports').where('status', '==', 'open')),
    countOf(db.collection('orders').where('status', '==', 'paid')),
  ]);
  return { users, availableBooks, swapsPending, swapsActive, swapsCompleted, openReports, paidOrders };
});

export const adminUpdateReport = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const reportId = str(request.data?.reportId, 'reportId', 128);
  const status = str(request.data?.status, 'status', 20);
  if (!['reviewed', 'dismissed', 'actioned'].includes(status)) throw new HttpsError('invalid-argument', 'Invalid status.');
  const note = str(request.data?.note, 'note', 500, false);
  const ref = db.doc(`reports/${reportId}`);
  if (!(await ref.get()).exists) throw new HttpsError('not-found', 'Report not found.');
  await ref.update({ status, adminNote: note, reviewedBy: adminUid, reviewedAt: FieldValue.serverTimestamp() });
  await audit(adminUid, 'report.update', reportId, { status });
  return { ok: true };
});

export const adminModerateBook = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const bookId = str(request.data?.bookId, 'bookId', 128);
  const action = str(request.data?.action, 'action', 20);
  if (!['remove', 'restore'].includes(action)) throw new HttpsError('invalid-argument', 'Invalid action.');
  const ref = db.doc(`books/${bookId}`);
  if (!(await ref.get()).exists) throw new HttpsError('not-found', 'Book not found.');
  await ref.update({ status: action === 'remove' ? 'removed' : 'available', updatedAt: FieldValue.serverTimestamp() });
  await audit(adminUid, `book.${action}`, bookId);
  return { ok: true };
});

export const adminSetUserDisabled = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const targetUid = str(request.data?.uid, 'uid', 128);
  const disabled = request.data?.disabled === true;
  if (targetUid === adminUid) throw new HttpsError('failed-precondition', 'You cannot disable your own account.');
  await getAuth().updateUser(targetUid, { disabled });
  if (disabled) await getAuth().revokeRefreshTokens(targetUid);
  await db.doc(`users/${targetUid}`).set({ disabled }, { merge: true });
  await audit(adminUid, disabled ? 'user.disable' : 'user.enable', targetUid);
  return { ok: true };
});

export const adminBroadcast = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const title = str(request.data?.title, 'title', 120);
  const body = str(request.data?.body, 'body', 1000);

  const usersSnap = await db.collection('users').get();
  const docs = usersSnap.docs;

  for (let i = 0; i < docs.length; i += 400) {
    const chunk = docs.slice(i, i + 400);
    const batch = db.batch();
    for (const doc of chunk) {
      const notifRef = db.collection('notifications').doc();
      batch.set(notifRef, {
        userId: doc.id,
        title,
        body,
        type: 'system',
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  await audit(adminUid, 'system.broadcast', 'all_users', { title, count: docs.length });
  return { ok: true, count: docs.length };
});

export const adminManageSwap = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const swapId = str(request.data?.swapId, 'swapId', 128);
  const action = str(request.data?.action, 'action', 32);

  const swapRef = db.doc(`swapRequests/${swapId}`);
  const snap = await swapRef.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Swap request not found.');
  const swap = snap.data()!;

  if (action === 'delete') {
    await swapRef.delete();
    await audit(adminUid, 'swap.delete', swapId);
    return { ok: true, action: 'deleted' };
  }

  if (action === 'complete' || action === 'forceComplete') {
    await swapRef.update({
      status: 'completed',
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (swap.bookId) {
      await db.doc(`books/${swap.bookId}`).update({ status: 'swapped', reservedBySwapId: FieldValue.delete() }).catch(() => {});
    }
    if (swap.offeredBookId) {
      await db.doc(`books/${swap.offeredBookId}`).update({ status: 'swapped', reservedBySwapId: FieldValue.delete() }).catch(() => {});
    }
    for (const id of [swap.requesterId, swap.ownerId]) {
      if (id) await db.doc(`users/${id}`).set({ totalSwaps: FieldValue.increment(1) }, { merge: true }).catch(() => {});
    }
    await audit(adminUid, 'swap.forceComplete', swapId);
    return { ok: true, action: 'completed' };
  }

  if (action === 'cancel' || action === 'forceCancel') {
    await swapRef.update({
      status: 'cancelled',
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (swap.bookId) {
      await db.doc(`books/${swap.bookId}`).update({ status: 'available', reservedBySwapId: FieldValue.delete() }).catch(() => {});
    }
    if (swap.offeredBookId) {
      await db.doc(`books/${swap.offeredBookId}`).update({ status: 'available', reservedBySwapId: FieldValue.delete() }).catch(() => {});
    }
    await audit(adminUid, 'swap.forceCancel', swapId);
    return { ok: true, action: 'cancelled' };
  }

  throw new HttpsError('invalid-argument', `Unknown admin action: ${action}`);
});

export const adminDeleteUser = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const targetUid = str(request.data?.uid, 'uid', 128);
  if (targetUid === adminUid) throw new HttpsError('failed-precondition', 'You cannot delete your own admin account.');

  // 1. Delete Auth user
  try {
    await getAuth().deleteUser(targetUid);
  } catch (_) {}

  // 2. Delete Firestore profile
  await db.doc(`users/${targetUid}`).delete();

  // 3. Mark user's books as removed
  const booksSnap = await db.collection('books').where('ownerId', '==', targetUid).get();
  if (!booksSnap.empty) {
    const batch = db.batch();
    booksSnap.docs.forEach((doc) => {
      batch.update(doc.ref, { status: 'removed', updatedAt: FieldValue.serverTimestamp() });
    });
    await batch.commit();
  }

  await audit(adminUid, 'user.delete', targetUid);
  return { ok: true, uid: targetUid };
});
