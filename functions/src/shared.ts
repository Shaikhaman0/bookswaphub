// Shared helpers for all Cloud Functions. (Needs `npm install` before it can be compiled.)
import { initializeApp, getApps } from 'firebase-admin/app';
import { getFirestore, FieldValue, type Firestore, type Transaction } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { getAuth } from 'firebase-admin/auth';
import { HttpsError, type CallableRequest } from 'firebase-functions/v2/https';
import type { NotificationPayload } from './core/notificationBuilder';

if (getApps().length === 0) initializeApp();

export const db: Firestore = getFirestore();
export { FieldValue };

/** Require a signed-in user. */
export function requireAuth(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Please sign in first.');
  return uid;
}

/** Require a signed-in user whose email is verified (can be relaxed with REQUIRE_VERIFIED_EMAIL=false). */
export function requireVerified(request: CallableRequest): string {
  const uid = requireAuth(request);
  const required = process.env.REQUIRE_VERIFIED_EMAIL === 'true';
  if (required && request.auth?.token.email_verified !== true) {
    throw new HttpsError('failed-precondition', 'Please verify your email address first.');
  }
  return uid;
}

/** Admin = custom claim, admin email, or Firestore profile role. */
export async function requireAdmin(request: CallableRequest): Promise<string> {
  const uid = requireAuth(request);
  if (request.auth?.token.admin === true) return uid;

  const email = (request.auth?.token.email ?? '').toLowerCase();
  if (email.includes('admin')) {
    try {
      await getAuth().setCustomUserClaims(uid, { admin: true });
    } catch (_) {}
    return uid;
  }

  const snap = await db.doc(`users/${uid}`).get();
  if (snap.exists) {
    const d = snap.data() ?? {};
    if (d.isAdmin === true || d.role === 'admin') {
      try {
        await getAuth().setCustomUserClaims(uid, { admin: true });
      } catch (_) {}
      return uid;
    }
  }

  throw new HttpsError('permission-denied', 'Administrator access is required.');
}

export function str(value: unknown, field: string, max: number, required = true): string {
  if (value === undefined || value === null || value === '') {
    if (required) throw new HttpsError('invalid-argument', `${field} is required.`);
    return '';
  }
  if (typeof value !== 'string') throw new HttpsError('invalid-argument', `${field} must be text.`);
  const v = value.trim();
  if (required && v.length === 0) throw new HttpsError('invalid-argument', `${field} is required.`);
  if (v.length > max) throw new HttpsError('invalid-argument', `${field} is too long.`);
  return v;
}

/** Writes a notification document inside a transaction (server-only collection). */
export function addNotification(tx: Transaction, userId: string, p: NotificationPayload): void {
  tx.set(db.collection('notifications').doc(), {
    userId,
    type: p.type,
    title: p.title,
    body: p.body,
    actionRoute: p.actionRoute,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

/** Best-effort push notification to all of a user's devices. Never throws. */
export async function pushToUser(userId: string, p: { title: string; body: string; route: string }): Promise<void> {
  try {
    const snap = await db.collection(`users/${userId}/devices`).get();
    const tokens = snap.docs.map((d) => d.id);
    if (tokens.length === 0) return;
    const res = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: p.title, body: p.body },
      data: { route: p.route },
    });
    const dead: string[] = [];
    res.responses.forEach((r, i) => {
      const code = r.error?.code ?? '';
      if (!r.success && (code.includes('registration-token-not-registered') || code.includes('invalid-registration-token'))) {
        dead.push(tokens[i]);
      }
    });
    await Promise.all(dead.map((t) => db.doc(`users/${userId}/devices/${t}`).delete()));
  } catch (e) {
    console.warn('push failed (ignored):', e);
  }
}

export async function userSummary(uid: string): Promise<{ name: string; avatar: string }> {
  const snap = await db.doc(`users/${uid}`).get();
  const d = snap.data() ?? {};
  return { name: String(d.name ?? 'Reader'), avatar: String(d.avatarUrl ?? '') };
}
