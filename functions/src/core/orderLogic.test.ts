import { test } from 'node:test';
import assert from 'node:assert/strict';
import { computeOrder } from './orderLogic';

const book = { ownerId: 'seller', status: 'available', listingType: 'sale', price: 250, currency: 'inr' };

test('price comes from the book (never the client) and is converted to minor units', () => {
  const r = computeOrder('buyer', book, 'inr');
  assert.deepEqual(r, { ok: true, amountMinor: 25000, currency: 'inr' });
});

test('handles decimals correctly', () => {
  const r = computeOrder('buyer', { ...book, price: 199.99 }, 'inr');
  assert.equal(r.ok && r.amountMinor, 19999);
});

test('unauthorized (no uid) is refused', () => {
  assert.equal(computeOrder('', book, 'inr').ok, false);
});

test('missing book, own book, unavailable, swap-only are refused', () => {
  assert.equal(computeOrder('buyer', null, 'inr').ok, false);
  assert.equal(computeOrder('seller', book, 'inr').ok, false);
  assert.equal(computeOrder('buyer', { ...book, status: 'sold' }, 'inr').ok, false);
  assert.equal(computeOrder('buyer', { ...book, listingType: 'swap' }, 'inr').ok, false);
});

test('invalid amounts are refused', () => {
  for (const price of [0, -5, NaN, Infinity, 100001, 1.005, undefined as unknown as number]) {
    assert.equal(computeOrder('buyer', { ...book, price }, 'inr').ok, false, String(price));
  }
});

test('currency mismatch is refused', () => {
  assert.equal(computeOrder('buyer', { ...book, currency: 'usd' }, 'inr').ok, false);
});

test('a live checkout hold by someone else blocks a second buyer; expired holds do not', () => {
  const now = 1_000_000;
  const held = { ...book, pendingOrderId: 'o1', pendingOrderExpiresAtMs: now + 60_000, pendingBuyerId: 'other_buyer' };
  assert.equal(computeOrder('buyer', held, 'inr', now).ok, false);
  const sameBuyerHeld = { ...book, pendingOrderId: 'o1', pendingOrderExpiresAtMs: now + 60_000, pendingBuyerId: 'buyer' };
  assert.equal(computeOrder('buyer', sameBuyerHeld, 'inr', now).ok, true);
  const expired = { ...book, pendingOrderId: 'o1', pendingOrderExpiresAtMs: now - 1 };
  assert.equal(computeOrder('buyer', expired, 'inr', now).ok, true);
});
