// Storage rules tests (need the Storage emulator). Run: cd rules-tests && npm test
const { test, before, after } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { ref, uploadBytes, deleteObject } = require('firebase/storage');

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-bookswaphub',
    storage: { rules: fs.readFileSync(path.join(__dirname, '..', 'storage.rules'), 'utf8') },
  });
});
after(async () => env && (await env.cleanup()));

const png = new Uint8Array([137, 80, 78, 71]);
test('owner can upload an image to their own folder; others and non-images are blocked', async () => {
  const a = env.authenticatedContext('alice', { email_verified: true }).storage();
  const b = env.authenticatedContext('bob', { email_verified: true }).storage();
  await assertSucceeds(uploadBytes(ref(a, 'books/alice/cover.png'), png, { contentType: 'image/png' }));
  await assertFails(uploadBytes(ref(b, 'books/alice/evil.png'), png, { contentType: 'image/png' }));
  await assertFails(uploadBytes(ref(a, 'books/alice/script.html'), png, { contentType: 'text/html' }));
  await assertFails(uploadBytes(ref(a, 'other/alice/x.png'), png, { contentType: 'image/png' }));
  await assertFails(deleteObject(ref(b, 'books/alice/cover.png')));
});

test('too-large images are blocked', async () => {
  const a = env.authenticatedContext('alice', { email_verified: true }).storage();
  const big = new Uint8Array(6 * 1024 * 1024);
  await assertFails(uploadBytes(ref(a, 'books/alice/big.png'), big, { contentType: 'image/png' }));
});
