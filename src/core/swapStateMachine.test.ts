import { test } from 'node:test';
import assert from 'node:assert/strict';
import { applySwapAction, validateCreateSwap, type SwapState } from './swapStateMachine';

const base = (over: Partial<SwapState> = {}): SwapState => ({
  status: 'pending',
  requesterId: 'alice',
  ownerId: 'bob',
  confirmedBy: [],
  ...over,
});

test('owner can accept a pending request and books get reserved', () => {
  const r = applySwapAction(base(), 'accept', 'bob');
  assert.equal(r.ok, true);
  if (r.ok) {
    assert.equal(r.next.status, 'accepted');
    assert.equal(r.reserveBooks, true);
  }
});

test('requester cannot accept their own request', () => {
  const r = applySwapAction(base(), 'accept', 'alice');
  assert.equal(r.ok, false);
  if (!r.ok) assert.equal(r.code, 'permission-denied');
});

test('a stranger cannot do anything', () => {
  for (const a of ['accept', 'reject', 'cancel', 'start', 'confirmComplete']) {
    const r = applySwapAction(base(), a, 'mallory');
    assert.equal(r.ok, false);
    if (!r.ok) assert.equal(r.code, 'permission-denied');
  }
});

test('owner can reject pending; requester cannot', () => {
  assert.equal(applySwapAction(base(), 'reject', 'bob').ok, true);
  assert.equal(applySwapAction(base(), 'reject', 'alice').ok, false);
});

test('requester can cancel pending; owner cannot cancel pending', () => {
  const ok = applySwapAction(base(), 'cancel', 'alice');
  assert.equal(ok.ok, true);
  const no = applySwapAction(base(), 'cancel', 'bob');
  assert.equal(no.ok, false);
});

test('either participant can cancel an accepted swap and books are released', () => {
  for (const who of ['alice', 'bob']) {
    const r = applySwapAction(base({ status: 'accepted' }), 'cancel', who);
    assert.equal(r.ok, true);
    if (r.ok) {
      assert.equal(r.next.status, 'cancelled');
      assert.equal(r.releaseBooks, true);
    }
  }
});

test('accepted -> inProgress by either participant, not from pending', () => {
  assert.equal(applySwapAction(base({ status: 'accepted' }), 'start', 'alice').ok, true);
  assert.equal(applySwapAction(base({ status: 'pending' }), 'start', 'alice').ok, false);
});

test('completion needs BOTH people to confirm (cannot be fabricated by one side)', () => {
  const s1 = applySwapAction(base({ status: 'inProgress' }), 'confirmComplete', 'alice');
  assert.equal(s1.ok, true);
  if (!s1.ok) return;
  assert.equal(s1.next.status, 'inProgress');
  assert.deepEqual(s1.next.confirmedBy, ['alice']);
  assert.equal(s1.markBooksSwapped, false);

  const again = applySwapAction(s1.next, 'confirmComplete', 'alice');
  assert.equal(again.ok, false);

  const s2 = applySwapAction(s1.next, 'confirmComplete', 'bob');
  assert.equal(s2.ok, true);
  if (s2.ok) {
    assert.equal(s2.next.status, 'completed');
    assert.equal(s2.markBooksSwapped, true);
  }
});

test('cannot confirm completion before the swap is in progress', () => {
  assert.equal(applySwapAction(base({ status: 'accepted' }), 'confirmComplete', 'alice').ok, false);
  assert.equal(applySwapAction(base({ status: 'pending' }), 'confirmComplete', 'bob').ok, false);
});

test('terminal states cannot change', () => {
  for (const status of ['rejected', 'cancelled', 'completed'] as const) {
    for (const a of ['accept', 'reject', 'cancel', 'start', 'confirmComplete']) {
      for (const who of ['alice', 'bob']) {
        assert.equal(applySwapAction(base({ status }), a, who).ok, false, `${status}/${a}/${who}`);
      }
    }
  }
});

test('unknown action is rejected', () => {
  const r = applySwapAction(base(), 'hack', 'bob');
  assert.equal(r.ok, false);
  if (!r.ok) assert.equal(r.code, 'invalid-argument');
});

test('swap between the same person is refused', () => {
  const r = applySwapAction(base({ requesterId: 'bob', ownerId: 'bob' }), 'accept', 'bob');
  assert.equal(r.ok, false);
});

const book = { ownerId: 'bob', status: 'available', listingType: 'swap' };

test('validateCreateSwap: happy path', () => {
  assert.equal(
    validateCreateSwap({ requesterId: 'alice', book, hasActiveRequestForSameBook: false }).ok,
    true,
  );
});

test('validateCreateSwap: own book, unavailable, sale-only, duplicate', () => {
  const run = (over: object, extra: object = {}) =>
    validateCreateSwap({ requesterId: 'alice', book: { ...book, ...over }, hasActiveRequestForSameBook: false, ...extra });
  assert.equal(run({ ownerId: 'alice' }).ok, false);
  assert.equal(run({ status: 'reserved' }).ok, false);
  assert.equal(run({ listingType: 'sale' }).ok, false);
  assert.equal(run({}, { hasActiveRequestForSameBook: true }).ok, false);
  assert.equal(validateCreateSwap({ requesterId: 'alice', book: null, hasActiveRequestForSameBook: false }).ok, false);
  assert.equal(validateCreateSwap({ requesterId: '', book, hasActiveRequestForSameBook: false }).ok, false);
});

test('validateCreateSwap: offered book must be yours and available', () => {
  const mk = (offeredBook: object | null) =>
    validateCreateSwap({
      requesterId: 'alice',
      book,
      offeredBookId: 'x',
      offeredBook: offeredBook as never,
      hasActiveRequestForSameBook: false,
    });
  assert.equal(mk({ ownerId: 'alice', status: 'available', listingType: 'swap' }).ok, true);
  assert.equal(mk({ ownerId: 'carol', status: 'available', listingType: 'swap' }).ok, false);
  assert.equal(mk({ ownerId: 'alice', status: 'sold', listingType: 'swap' }).ok, false);
  assert.equal(mk(null).ok, false);
});
