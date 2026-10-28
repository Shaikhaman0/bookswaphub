import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { db, FieldValue, requireAuth, str, addNotification, pushToUser, userSummary } from './shared';
import { applySwapAction, validateCreateSwap, type SwapState, type SwapStatus } from './core/swapStateMachine';
import { swapNotification } from './core/notificationBuilder';

const ACTIVE: SwapStatus[] = ['pending', 'accepted', 'inProgress'];

export const createSwapRequest = onCall(async (request) => {
  const uid = requireAuth(request);
  const bookId = str(request.data?.bookId, 'bookId', 128);
  const offeredBookId = str(request.data?.offeredBookId, 'offeredBookId', 128, false) || null;
  const message = str(request.data?.message, 'message', 500, false);
  const me = await userSummary(uid);

  const result = await db.runTransaction(async (tx) => {
    const bookSnap = await tx.get(db.doc(`books/${bookId}`));
    const book = bookSnap.exists ? bookSnap.data()! : null;
    const offeredSnap = offeredBookId ? await tx.get(db.doc(`books/${offeredBookId}`)) : null;
    const offered = offeredSnap && offeredSnap.exists ? offeredSnap.data()! : null;
    const dup = await tx.get(
      db.collection('swapRequests').where('requesterId', '==', uid).where('bookId', '==', bookId).where('status', 'in', ACTIVE),
    );

    const check = validateCreateSwap({
      requesterId: uid,
      book: book ? { ownerId: book.ownerId, status: book.status, listingType: book.listingType } : null,
      offeredBookId,
      offeredBook: offered ? { ownerId: offered.ownerId, status: offered.status, listingType: offered.listingType } : null,
      hasActiveRequestForSameBook: !dup.empty,
    });
    if (!check.ok) throw new HttpsError(check.code, check.message);

    const ownerId = String(book!.ownerId);
    const owner = await userSummary(ownerId);
    const ref = db.collection('swapRequests').doc();
    tx.set(ref, {
      requesterId: uid,
      requesterName: me.name,
      requesterAvatar: me.avatar,
      ownerId,
      ownerName: owner.name,
      ownerAvatar: owner.avatar,
      participantIds: [uid, ownerId],
      bookId,
      bookTitle: String(book!.title ?? ''),
      bookCover: String((book!.imageUrls ?? [])[0] ?? ''),
      offeredBookId,
      offeredBookTitle: offered ? String(offered.title ?? '') : null,
      offeredBookCover: offered ? String((offered.imageUrls ?? [])[0] ?? '') : null,
      status: 'pending',
      confirmedBy: [],
      message,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    addNotification(tx, ownerId, swapNotification('requested', String(book!.title ?? ''), me.name));
    return { swapId: ref.id, ownerId, title: String(book!.title ?? '') };
  });

  await pushToUser(result.ownerId, { title: 'New swap request', body: `${me.name} wants "${result.title}".`, route: '/swaps' });
  return { swapId: result.swapId };
});

export const updateSwapStatus = onCall(async (request) => {
  const uid = requireAuth(request);
  const swapId = str(request.data?.swapId, 'swapId', 128);
  const action = str(request.data?.action, 'action', 32);
  const me = await userSummary(uid);

  const out = await db.runTransaction(async (tx) => {
    const swapRef = db.doc(`swapRequests/${swapId}`);
    const swapSnap = await tx.get(swapRef);
    if (!swapSnap.exists) throw new HttpsError('not-found', 'Swap not found.');
    const swap = swapSnap.data()!;

    const state: SwapState = {
      status: swap.status as SwapStatus,
      requesterId: String(swap.requesterId),
      ownerId: String(swap.ownerId),
      confirmedBy: Array.isArray(swap.confirmedBy) ? swap.confirmedBy.map(String) : [],
    };
    const result = applySwapAction(state, action, uid);
    if (!result.ok) throw new HttpsError(result.code, result.message);

    const bookRef = db.doc(`books/${swap.bookId}`);
    const bookSnap = await tx.get(bookRef);
    const offeredRef = swap.offeredBookId ? db.doc(`books/${swap.offeredBookId}`) : null;
    const offeredSnap = offeredRef ? await tx.get(offeredRef) : null;

    let otherPending: FirebaseFirestore.QuerySnapshot | null = null;
    if (result.reserveBooks || result.markBooksSwapped) {
      if (!bookSnap.exists || bookSnap.data()!.status !== 'available') {
        throw new HttpsError('failed-precondition', 'That book is no longer available.');
      }
      if (offeredSnap && (!offeredSnap.exists || offeredSnap.data()!.status !== 'available')) {
        throw new HttpsError('failed-precondition', 'The offered book is no longer available.');
      }
      otherPending = await tx.get(
        db.collection('swapRequests').where('bookId', '==', swap.bookId).where('status', '==', 'pending'),
      );
    }

    // ---- all reads done; writes below ----
    tx.update(swapRef, {
      status: result.next.status,
      confirmedBy: result.next.confirmedBy,
      updatedAt: FieldValue.serverTimestamp(),
    });

    const setBook = (ref: FirebaseFirestore.DocumentReference | null, snap: FirebaseFirestore.DocumentSnapshot | null, patch: Record<string, unknown>) => {
      if (ref && snap && snap.exists) tx.update(ref, { ...patch, updatedAt: FieldValue.serverTimestamp() });
    };
    if (result.reserveBooks) {
      const patch = { status: 'reserved', reservedBySwapId: swapId };
      setBook(bookRef, bookSnap, patch);
      setBook(offeredRef, offeredSnap, patch);
      otherPending?.docs.forEach((d) => {
        if (d.id === swapId) return;
        tx.update(d.ref, { status: 'rejected', updatedAt: FieldValue.serverTimestamp() });
        addNotification(tx, String(d.data().requesterId), swapNotification('rejected', String(swap.bookTitle ?? ''), 'The owner'));
      });
    }
    if (result.releaseBooks) {
      const patch = { status: 'available', reservedBySwapId: FieldValue.delete() };
      if (bookSnap.exists && bookSnap.data()!.reservedBySwapId === swapId) setBook(bookRef, bookSnap, patch);
      if (offeredSnap?.exists && offeredSnap.data()!.reservedBySwapId === swapId) setBook(offeredRef, offeredSnap, patch);
    }
    if (result.markBooksSwapped) {
      const patch = { status: 'swapped', reservedBySwapId: FieldValue.delete() };
      setBook(bookRef, bookSnap, patch);
      setBook(offeredRef, offeredSnap, patch);
      for (const id of [state.requesterId, state.ownerId]) {
        tx.set(db.doc(`users/${id}`), { totalSwaps: FieldValue.increment(1) }, { merge: true });
      }
      otherPending?.docs.forEach((d) => {
        if (d.id === swapId) return;
        tx.update(d.ref, { status: 'rejected', updatedAt: FieldValue.serverTimestamp() });
        addNotification(tx, String(d.data().requesterId), swapNotification('rejected', String(swap.bookTitle ?? ''), 'The owner'));
      });
    }

    // Notify the other participant (and both when completed).
    const other = uid === state.ownerId ? state.requesterId : state.ownerId;
    const title = String(swap.bookTitle ?? '');
    const eventMap: Record<string, Parameters<typeof swapNotification>[0]> = {
      accept: 'accepted', reject: 'rejected', cancel: 'cancelled', start: 'started',
    };
    let notify: { to: string; payload: ReturnType<typeof swapNotification> }[] = [];
    if (action === 'confirmComplete') {
      notify = result.next.status === 'completed'
        ? [state.requesterId, state.ownerId].map((to) => ({ to, payload: swapNotification('completed', title, me.name) }))
        : [{ to: other, payload: swapNotification('awaitingConfirm', title, me.name) }];
    } else {
      notify = [{ to: other, payload: swapNotification(eventMap[action], title, me.name) }];
    }
    notify.forEach((n) => addNotification(tx, n.to, n.payload));
    return { status: result.next.status, notify };
  });

  await Promise.all(out.notify.map((n) => pushToUser(n.to, { title: n.payload.title, body: n.payload.body, route: n.payload.actionRoute })));
  return { status: out.status };
});
