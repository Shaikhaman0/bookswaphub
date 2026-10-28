// Security-rules tests. They need the Firebase Emulator Suite, so run them on YOUR machine:
//   cd rules-tests && npm install && npm test
// (Written but NOT executed in the authoring environment: the emulator could not be downloaded there.)
const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp, collection, query, where, getDocs } = require('firebase/firestore');

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-bookswaphub',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8') },
  });
});
after(async () => env && (await env.cleanup()));
beforeEach(async () => env.clearFirestore());

const alice = () => env.authenticatedContext('alice', { email_verified: true }).firestore();
const aliceUnverified = () => env.authenticatedContext('alice', { email_verified: false }).firestore();
const bob = () => env.authenticatedContext('bob', { email_verified: true }).firestore();
const carol = () => env.authenticatedContext('carol', { email_verified: true }).firestore();
const adminCtx = () => env.authenticatedContext('root', { email_verified: true, admin: true }).firestore();
const anon = () => env.unauthenticatedContext().firestore();

const newBook = (over = {}) => ({
  title: 'Clean Code', titleLower: 'clean code', author: 'Martin', authorLower: 'martin', description: 'd',
  category: 'Programming', categoryId: 'programming', condition: 'Good', language: 'English', location: 'Ahmedabad',
  listingType: 'swap', imageUrls: [], searchKeywords: ['clean', 'code'], ownerId: 'alice', ownerName: 'Alice',
  status: 'available', rating: 0, ratingCount: 0, createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...over,
});
const seed = (fn) => env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));

// ---------- users ----------
test('user can create own profile but cannot add role/admin fields or fake rating', async () => {
  const base = { name: 'Alice', location: 'X', createdAt: serverTimestamp() };
  await assertSucceeds(setDoc(doc(aliceUnverified(), 'users/alice'), base));
  await assertFails(setDoc(doc(alice(), 'users/alice'), { ...base, role: 'admin' }));
  await assertFails(setDoc(doc(alice(), 'users/alice'), { ...base, isAdmin: true }));
  await assertFails(setDoc(doc(alice(), 'users/alice'), { ...base, rating: 5 }));
  await assertFails(setDoc(doc(bob(), 'users/alice'), base)); // someone else's profile
});

test('user cannot promote self to admin or change rating by update', async () => {
  await seed((d) => setDoc(doc(d, 'users/alice'), { name: 'Alice', location: 'X', rating: 0, ratingCount: 0, totalSwaps: 0 }));
  await assertSucceeds(updateDoc(doc(alice(), 'users/alice'), { bio: 'hi', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(alice(), 'users/alice'), { role: 'admin' }));
  await assertFails(updateDoc(doc(alice(), 'users/alice'), { isAdmin: true }));
  await assertFails(updateDoc(doc(alice(), 'users/alice'), { rating: 5 }));
  await assertFails(updateDoc(doc(bob(), 'users/alice'), { bio: 'hacked', updatedAt: serverTimestamp() }));
});

// ---------- books ----------
test('verified user can create a book they own; unverified, anonymous and impersonation fail', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'books/b1'), newBook()));
  await assertFails(setDoc(doc(aliceUnverified(), 'books/b2'), newBook()));
  await assertFails(setDoc(doc(anon(), 'books/b3'), newBook()));
  await assertFails(setDoc(doc(bob(), 'books/b4'), newBook({ ownerId: 'alice' })));
});

test('book validation: bad price, sale without price, fake rating, wrong status', async () => {
  await assertFails(setDoc(doc(alice(), 'books/x1'), newBook({ listingType: 'sale' })));
  await assertFails(setDoc(doc(alice(), 'books/x2'), newBook({ listingType: 'sale', price: -1, currency: 'inr' })));
  await assertSucceeds(setDoc(doc(alice(), 'books/x3'), newBook({ listingType: 'sale', price: 200, currency: 'inr' })));
  await assertFails(setDoc(doc(alice(), 'books/x4'), newBook({ rating: 5 })));
  await assertFails(setDoc(doc(alice(), 'books/x5'), newBook({ status: 'sold' })));
  await assertFails(setDoc(doc(alice(), 'books/x6'), newBook({ condition: 'Mint' })));
});

test('anyone can read books; only the owner can edit/delete', async () => {
  await seed((d) => setDoc(doc(d, 'books/b1'), { ...newBook(), createdAt: new Date(), updatedAt: new Date() }));
  await assertSucceeds(getDoc(doc(anon(), 'books/b1')));
  await assertFails(updateDoc(doc(bob(), 'books/b1'), { title: 'Hacked', titleLower: 'hacked', updatedAt: serverTimestamp() }));
  await assertFails(deleteDoc(doc(bob(), 'books/b1')));
  await assertSucceeds(updateDoc(doc(alice(), 'books/b1'), { description: 'new', updatedAt: serverTimestamp() }));
});

test('owner cannot change ownerId, rating, or set server-only statuses', async () => {
  await seed((d) => setDoc(doc(d, 'books/b1'), { ...newBook(), createdAt: new Date(), updatedAt: new Date() }));
  await assertFails(updateDoc(doc(alice(), 'books/b1'), { ownerId: 'bob', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(alice(), 'books/b1'), { rating: 5, updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(alice(), 'books/b1'), { status: 'sold', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(alice(), 'books/b1'), { pendingOrderId: 'o1', updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(doc(alice(), 'books/b1'), { status: 'unavailable', updatedAt: serverTimestamp() }));
});

test('a reserved book cannot be deleted or made available by the owner', async () => {
  await seed((d) => setDoc(doc(d, 'books/b1'), { ...newBook({ status: 'reserved' }), createdAt: new Date(), updatedAt: new Date() }));
  await assertFails(deleteDoc(doc(alice(), 'books/b1')));
  await assertFails(updateDoc(doc(alice(), 'books/b1'), { status: 'available', updatedAt: serverTimestamp() }));
});

// ---------- wishlist ----------
test('wishlist: only owner can read/write own entries; id must match', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'wishlists/alice_b1'), { userId: 'alice', bookId: 'b1', createdAt: serverTimestamp() }));
  await assertFails(setDoc(doc(alice(), 'wishlists/alice_b2'), { userId: 'bob', bookId: 'b2', createdAt: serverTimestamp() }));
  await assertFails(setDoc(doc(alice(), 'wishlists/wrongid'), { userId: 'alice', bookId: 'b3', createdAt: serverTimestamp() }));
  await assertSucceeds(getDoc(doc(alice(), 'wishlists/alice_b1')));
  await assertFails(getDoc(doc(bob(), 'wishlists/alice_b1')));
  await assertFails(deleteDoc(doc(bob(), 'wishlists/alice_b1')));
  await assertSucceeds(deleteDoc(doc(alice(), 'wishlists/alice_b1')));
});

// ---------- swaps ----------
test('swap requests are readable by participants only and NEVER writable by clients', async () => {
  await seed((d) => setDoc(doc(d, 'swapRequests/s1'), { participantIds: ['alice', 'bob'], requesterId: 'alice', ownerId: 'bob', status: 'pending' }));
  await assertSucceeds(getDoc(doc(alice(), 'swapRequests/s1')));
  await assertSucceeds(getDoc(doc(bob(), 'swapRequests/s1')));
  await assertFails(getDoc(doc(carol(), 'swapRequests/s1')));
  await assertFails(updateDoc(doc(alice(), 'swapRequests/s1'), { status: 'completed' }));
  await assertFails(updateDoc(doc(bob(), 'swapRequests/s1'), { status: 'accepted' }));
  await assertFails(setDoc(doc(alice(), 'swapRequests/s2'), { participantIds: ['alice', 'bob'], status: 'completed' }));
});

// ---------- chat ----------
const seedConv = () => seed(async (d) => {
  await setDoc(doc(d, 'conversations/alice_bob'), { participantIds: ['alice', 'bob'], unread: { bob: 2 } });
  await setDoc(doc(d, 'conversations/alice_bob/messages/m1'), { senderId: 'alice', text: 'hi', createdAt: new Date() });
});

test('chat: members can read; outsiders cannot read conversation or messages', async () => {
  await seedConv();
  await assertSucceeds(getDoc(doc(bob(), 'conversations/alice_bob')));
  await assertSucceeds(getDoc(doc(bob(), 'conversations/alice_bob/messages/m1')));
  await assertFails(getDoc(doc(carol(), 'conversations/alice_bob')));
  await assertFails(getDoc(doc(carol(), 'conversations/alice_bob/messages/m1')));
  await assertFails(getDocs(query(collection(carol(), 'conversations'), where('participantIds', 'array-contains', 'alice'))));
});

test('chat: sender must be the signed-in user; outsiders cannot send; no edit/delete', async () => {
  await seedConv();
  const ok = { senderId: 'bob', text: 'hello', createdAt: serverTimestamp() };
  await assertSucceeds(setDoc(doc(bob(), 'conversations/alice_bob/messages/m2'), ok));
  await assertFails(setDoc(doc(bob(), 'conversations/alice_bob/messages/m3'), { ...ok, senderId: 'alice' })); // impersonation
  await assertFails(setDoc(doc(carol(), 'conversations/alice_bob/messages/m4'), { ...ok, senderId: 'carol' }));
  await assertFails(setDoc(doc(bob(), 'conversations/alice_bob/messages/m5'), { ...ok, text: '' }));
  await assertFails(updateDoc(doc(bob(), 'conversations/alice_bob/messages/m1'), { text: 'edit' }));
  await assertFails(deleteDoc(doc(alice(), 'conversations/alice_bob/messages/m1')));
});

test('chat: create conversation needs both ids sorted, matching doc id, and caller as member', async () => {
  const ok = { participantIds: ['alice', 'bob'], unread: {}, createdAt: serverTimestamp() };
  await assertSucceeds(setDoc(doc(alice(), 'conversations/alice_bob'), ok));
  await assertFails(setDoc(doc(carol(), 'conversations/alice_bob2'), ok));              // carol not a member
  await assertFails(setDoc(doc(alice(), 'conversations/bob_alice'), { ...ok, participantIds: ['bob', 'alice'] })); // unsorted
  await assertFails(setDoc(doc(alice(), 'conversations/alice_carol'), ok));              // id mismatch
});

test('chat: participant can reset only their own unread counter', async () => {
  await seedConv();
  await assertSucceeds(updateDoc(doc(bob(), 'conversations/alice_bob'), { 'unread.bob': 0 }));
  await assertFails(updateDoc(doc(bob(), 'conversations/alice_bob'), { 'unread.alice': 0 }));
  await assertFails(updateDoc(doc(bob(), 'conversations/alice_bob'), { participantIds: ['bob', 'carol'] }));
});

// ---------- notifications ----------
test('notifications: owner can read/mark read/delete; cannot create or edit content; others blocked', async () => {
  await seed((d) => setDoc(doc(d, 'notifications/n1'), { userId: 'alice', title: 't', isRead: false }));
  await assertSucceeds(getDoc(doc(alice(), 'notifications/n1')));
  await assertFails(getDoc(doc(bob(), 'notifications/n1')));
  await assertSucceeds(updateDoc(doc(alice(), 'notifications/n1'), { isRead: true }));
  await assertFails(updateDoc(doc(alice(), 'notifications/n1'), { title: 'hacked' }));
  await assertFails(updateDoc(doc(bob(), 'notifications/n1'), { isRead: true }));
  await assertFails(setDoc(doc(alice(), 'notifications/n2'), { userId: 'alice', title: 'fake', isRead: false }));
});

// ---------- reports ----------
test('reports: users can file but not change; only reporter/admin can read', async () => {
  const r = { reporterId: 'alice', targetType: 'book', targetId: 'b1', reason: 'spam', details: 'x', status: 'open', createdAt: serverTimestamp() };
  await assertSucceeds(setDoc(doc(alice(), 'reports/r1'), r));
  await assertFails(setDoc(doc(alice(), 'reports/r2'), { ...r, status: 'actioned' }));
  await assertFails(setDoc(doc(alice(), 'reports/r3'), { ...r, reporterId: 'bob' }));
  await assertFails(updateDoc(doc(alice(), 'reports/r1'), { status: 'dismissed' }));
  await assertSucceeds(getDoc(doc(alice(), 'reports/r1')));
  await assertFails(getDoc(doc(bob(), 'reports/r1')));
  await assertSucceeds(getDoc(doc(adminCtx(), 'reports/r1')));
});

// ---------- orders & payments ----------
test('orders/payments: participants can read, nobody on the client can write (cannot mark paid)', async () => {
  await seed(async (d) => {
    await setDoc(doc(d, 'orders/o1'), { buyerId: 'alice', sellerId: 'bob', status: 'pending', amountMinor: 25000 });
    await setDoc(doc(d, 'payments/pi_1'), { buyerId: 'alice', sellerId: 'bob', status: 'succeeded' });
  });
  await assertSucceeds(getDoc(doc(alice(), 'orders/o1')));
  await assertSucceeds(getDoc(doc(bob(), 'orders/o1')));
  await assertFails(getDoc(doc(carol(), 'orders/o1')));
  await assertFails(updateDoc(doc(alice(), 'orders/o1'), { status: 'paid' }));
  await assertFails(setDoc(doc(alice(), 'orders/o2'), { buyerId: 'alice', sellerId: 'bob', status: 'paid' }));
  await assertFails(setDoc(doc(alice(), 'payments/pi_fake'), { buyerId: 'alice', sellerId: 'bob', status: 'succeeded' }));
  await assertFails(updateDoc(doc(alice(), 'payments/pi_1'), { status: 'refunded' }));
  await assertFails(getDoc(doc(alice(), 'stripeEvents/evt_1')));
});

// ---------- admin-only ----------
test('auditLogs readable only by admin claim; a user doc field "role" does not make anyone admin', async () => {
  await seed(async (d) => {
    await setDoc(doc(d, 'auditLogs/a1'), { action: 'x' });
    await setDoc(doc(d, 'users/alice'), { name: 'Alice', location: 'X', role: 'admin', isAdmin: true });
  });
  await assertFails(getDoc(doc(alice(), 'auditLogs/a1')));
  await assertSucceeds(getDoc(doc(adminCtx(), 'auditLogs/a1')));
  await assertFails(setDoc(doc(adminCtx(), 'auditLogs/a2'), { action: 'y' }));
});

test('unknown collections are denied', async () => {
  await assertFails(setDoc(doc(alice(), 'randomStuff/x'), { a: 1 }));
  await assertFails(getDoc(doc(alice(), 'randomStuff/x')));
});
