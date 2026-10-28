#!/usr/bin/env node
/**
 * Gives ONE existing user the administrator custom claim.
 * Run it yourself, locally, with credentials only you have. Nothing in the app can do this.
 *
 *   cd functions && npm install
 *   # Option A (real project): gcloud auth application-default login   (or set GOOGLE_APPLICATION_CREDENTIALS)
 *   # Option B (emulator):     export FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
 *   GCLOUD_PROJECT=<your-project-id> node scripts/set-admin.js you@example.com
 *
 * Revoke: node scripts/set-admin.js you@example.com --revoke
 * The user must sign out and in again (or refresh the ID token) to pick up the change.
 */
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

const email = process.argv[2];
const revoke = process.argv.includes('--revoke');
if (!email || !email.includes('@')) {
  console.error('Usage: node scripts/set-admin.js <email> [--revoke]');
  process.exit(1);
}
if (!process.env.GCLOUD_PROJECT && !process.env.GOOGLE_CLOUD_PROJECT) {
  console.error('Set GCLOUD_PROJECT to your Firebase project id first.');
  process.exit(1);
}
initializeApp();
(async () => {
  const auth = getAuth();
  const user = await auth.getUserByEmail(email);
  await auth.setCustomUserClaims(user.uid, revoke ? { admin: false } : { admin: true });
  console.log(`${revoke ? 'Removed' : 'Granted'} admin for ${email} (uid ${user.uid}). Sign out/in to refresh.`);
})().catch((e) => { console.error(e.message); process.exit(1); });
