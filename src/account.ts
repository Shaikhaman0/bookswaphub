import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getAuth } from 'firebase-admin/auth';
import { getStorage } from 'firebase-admin/storage';
import { db, requireAuth } from './shared';

/**
 * Deletes the caller's account.
 * Removed: profile, own books (+ images), wishlist, notifications, device tokens, login.
 * Kept (so other people's history stays intact): swap records, chat messages, reviews you wrote.
 * Those show "Deleted user" because the profile no longer exists.
 * Blocked while a swap is accepted/in progress (finish or cancel it first).
 */
export const deleteMyAccount = onCall(async (request) => {
  const uid = requireAuth(request);

  const active = await db.collection('swapRequests').where('participantIds', 'array-contains', uid)
    .where('status', 'in', ['accepted', 'inProgress']).limit(1).get();
  if (!active.empty) throw new HttpsError('failed-precondition', 'Finish or cancel your active swaps before deleting your account.');

  // Cancel pending swaps involving this user.
  const pending = await db.collection('swapRequests').where('participantIds', 'array-contains', uid).where('status', '==', 'pending').get();
  const batch = db.batch();
  pending.docs.forEach((d) => batch.update(d.ref, { status: 'cancelled' }));

  const deleteAll = async (q: FirebaseFirestore.Query) => (await q.get()).docs.forEach((d) => batch.delete(d.ref));
  await deleteAll(db.collection('books').where('ownerId', '==', uid));
  await deleteAll(db.collection('wishlists').where('userId', '==', uid));
  await deleteAll(db.collection('notifications').where('userId', '==', uid));
  await deleteAll(db.collection(`users/${uid}/devices`));
  batch.delete(db.doc(`users/${uid}`));
  await batch.commit();

  const bucket = getStorage().bucket();
  await Promise.all([bucket.deleteFiles({ prefix: `books/${uid}/` }), bucket.deleteFiles({ prefix: `avatars/${uid}/` })]).catch(() => undefined);
  await getAuth().deleteUser(uid);
  return { ok: true };
});
