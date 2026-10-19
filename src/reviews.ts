import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { db, FieldValue, requireVerified, str, userSummary } from './shared';

/** One review per participant per COMPLETED swap. */
export const submitReview = onCall(async (request) => {
  const uid = requireVerified(request);
  const swapId = str(request.data?.swapId, 'swapId', 128);
  const comment = str(request.data?.comment, 'comment', 1000, false);
  const rating = Number(request.data?.rating);
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    throw new HttpsError('invalid-argument', 'Rating must be a whole number from 1 to 5.');
  }
  const me = await userSummary(uid);

  await db.runTransaction(async (tx) => {
    const swapSnap = await tx.get(db.doc(`swapRequests/${swapId}`));
    if (!swapSnap.exists) throw new HttpsError('not-found', 'Swap not found.');
    const swap = swapSnap.data()!;
    if (swap.status !== 'completed') throw new HttpsError('failed-precondition', 'You can only review completed swaps.');
    if (uid !== swap.requesterId && uid !== swap.ownerId) throw new HttpsError('permission-denied', 'You were not part of this swap.');
    const revieweeId = uid === swap.ownerId ? swap.requesterId : swap.ownerId;

    const reviewRef = db.doc(`reviews/${swapId}_${uid}`);
    if ((await tx.get(reviewRef)).exists) throw new HttpsError('already-exists', 'You already reviewed this swap.');
    const userRef = db.doc(`users/${revieweeId}`);
    const userSnap = await tx.get(userRef);
    const prevCount = Number(userSnap.data()?.ratingCount ?? 0);
    const prevRating = Number(userSnap.data()?.rating ?? 0);
    const newCount = prevCount + 1;
    const newRating = Math.round(((prevRating * prevCount + rating) / newCount) * 100) / 100;

    tx.set(reviewRef, {
      swapId, reviewerId: uid, reviewerName: me.name, reviewerAvatar: me.avatar,
      revieweeId, rating, comment, createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(userRef, { rating: newRating, ratingCount: newCount }, { merge: true });
  });
  return { ok: true };
});
