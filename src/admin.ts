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
  requireAdmin(request);
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
  const adminUid = requireAdmin(request);
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
  const adminUid = requireAdmin(request);
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
  const adminUid = requireAdmin(request);
  const targetUid = str(request.data?.uid, 'uid', 128);
  const disabled = request.data?.disabled === true;
  if (targetUid === adminUid) throw new HttpsError('failed-precondition', 'You cannot disable your own account.');
  await getAuth().updateUser(targetUid, { disabled });
  if (disabled) await getAuth().revokeRefreshTokens(targetUid);
  await db.doc(`users/${targetUid}`).set({ disabled }, { merge: true });
  await audit(adminUid, disabled ? 'user.disable' : 'user.enable', targetUid);
  return { ok: true };
});
