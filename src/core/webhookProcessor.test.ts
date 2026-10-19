import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  processStripeEvent,
  type OrderDoc,
  type StripeEvent,
  type Store,
  type Tx,
} from './webhookProcessor';

// In-memory store that behaves like a Firestore transaction (reads first, writes applied at commit).
function makeStore(orders: OrderDoc[], bookStatus = 'available', pendingOrderId: string | null = 'o1') {
  const state = {
    orders: new Map(orders.map((o) => [o.id, { ...o } as Record<string, unknown> & OrderDoc])),
    events: new Map<string, string>(),
    payments: new Map<string, Record<string, unknown>>(),
    soldBooks: [] as string[],
    holdsCleared: [] as string[],
    notifications: [] as { uid: string; title: string }[],
    bookStatus,
  };
  const store: Store = {
    async runTransaction(fn) {
      const writes: Array<() => void> = [];
      const tx: Tx = {
        async eventAlreadyProcessed(id) { return state.events.has(id); },
        async getOrder(id) { const o = state.orders.get(id); return o ? ({ ...o } as OrderDoc) : null; },
        async getBook() { return { status: state.bookStatus, pendingOrderId }; },
        recordEvent(id, _t, outcome) { writes.push(() => state.events.set(id, outcome)); },
        updateOrder(id, patch) { writes.push(() => Object.assign(state.orders.get(id)!, patch)); },
        markBookSold(bookId) { writes.push(() => state.soldBooks.push(bookId)); },
        clearBookHold(bookId) { writes.push(() => state.holdsCleared.push(bookId)); },
        recordPayment(pi, data) { writes.push(() => state.payments.set(pi, data)); },
        notify(uid, p) { writes.push(() => state.notifications.push({ uid, title: p.title })); },
      };
      const result = await fn(tx);
      writes.forEach((w) => w());
      return result;
    },
  };
  return { store, state };
}

const order = (over: Partial<OrderDoc> = {}): OrderDoc => ({
  id: 'o1', buyerId: 'buyer', sellerId: 'seller', bookId: 'b1',
  amountMinor: 25000, currency: 'inr', status: 'pending', paymentIntentId: 'pi_1', ...over,
});

const evt = (type: string, over: Record<string, unknown> = {}, id = 'evt_1', livemode = false): StripeEvent => ({
  id, type, livemode,
  data: { object: { id: 'pi_1', amount: 25000, currency: 'inr', metadata: { orderId: 'o1' }, ...over } },
});

test('successful payment marks order paid, book sold, records payment, notifies both', async () => {
  const { store, state } = makeStore([order()]);
  assert.equal(await processStripeEvent(evt('payment_intent.succeeded'), store), 'paid');
  assert.equal(state.orders.get('o1')!.status, 'paid');
  assert.deepEqual(state.soldBooks, ['b1']);
  assert.equal(state.payments.get('pi_1')!.testMode, true);
  assert.equal(state.notifications.length, 2);
});

test('DUPLICATE webhook delivery is processed only once (idempotent)', async () => {
  const { store, state } = makeStore([order()]);
  assert.equal(await processStripeEvent(evt('payment_intent.succeeded'), store), 'paid');
  assert.equal(await processStripeEvent(evt('payment_intent.succeeded'), store), 'duplicate');
  assert.equal(state.soldBooks.length, 1);
  assert.equal(state.notifications.length, 2);
});

test('a second DIFFERENT event for an already-paid order does not fulfil twice', async () => {
  const { store, state } = makeStore([order()]);
  await processStripeEvent(evt('payment_intent.succeeded', {}, 'evt_1'), store);
  assert.equal(await processStripeEvent(evt('payment_intent.succeeded', {}, 'evt_2'), store), 'ignored');
  assert.equal(state.soldBooks.length, 1);
});

test('wrong amount is NOT marked paid (invalid order amount)', async () => {
  const { store, state } = makeStore([order()]);
  assert.equal(await processStripeEvent(evt('payment_intent.succeeded', { amount: 100 }), store), 'amount_mismatch');
  assert.equal(state.orders.get('o1')!.status, 'amount_mismatch');
  assert.equal(state.soldBooks.length, 0);
});

test('wrong currency is NOT marked paid', async () => {
  const { store, state } = makeStore([order()]);
  assert.equal(await processStripeEvent(evt('payment_intent.succeeded', { currency: 'usd' }), store), 'amount_mismatch');
  assert.equal(state.soldBooks.length, 0);
});

test('forged metadata (PaymentIntent id differs from stored one) is ignored', async () => {
  const { store, state } = makeStore([order()]);
  assert.equal(await processStripeEvent(evt('payment_intent.succeeded', { id: 'pi_OTHER' }), store), 'ignored');
  assert.equal(state.orders.get('o1')!.status, 'pending');
});

test('unknown order and missing orderId are ignored', async () => {
  const { store } = makeStore([order()]);
  assert.equal(await processStripeEvent(evt('payment_intent.succeeded', { metadata: { orderId: 'nope' } }), store), 'ignored');
  assert.equal(await processStripeEvent(evt('payment_intent.succeeded', { metadata: {} }, 'evt_9'), store), 'ignored');
});

test('declined payment marks order failed and releases the hold', async () => {
  const { store, state } = makeStore([order()]);
  const out = await processStripeEvent(
    evt('payment_intent.payment_failed', { last_payment_error: { message: 'Your card was declined.' } }),
    store,
  );
  assert.equal(out, 'failed');
  assert.equal(state.orders.get('o1')!.status, 'failed');
  assert.deepEqual(state.holdsCleared, ['b1']);
  assert.equal(state.soldBooks.length, 0);
});

test('a failed attempt can later succeed on the same PaymentIntent (Stripe allows retry)', async () => {
  const { store, state } = makeStore([order()]);
  await processStripeEvent(evt('payment_intent.payment_failed', {}, 'evt_f'), store);
  assert.equal(await processStripeEvent(evt('payment_intent.succeeded', {}, 'evt_s'), store), 'paid');
  assert.equal(state.orders.get('o1')!.status, 'paid');
});

test('cancelled payment marks order cancelled; cancel after paid is ignored', async () => {
  const a = makeStore([order()]);
  assert.equal(await processStripeEvent(evt('payment_intent.canceled'), a.store), 'cancelled');
  assert.equal(a.state.orders.get('o1')!.status, 'cancelled');

  const b = makeStore([order({ status: 'paid' })]);
  assert.equal(await processStripeEvent(evt('payment_intent.canceled'), b.store), 'ignored');
  assert.equal(b.state.orders.get('o1')!.status, 'paid');
});

test('LIVE-mode events are rejected outright', async () => {
  const { store, state } = makeStore([order()]);
  assert.equal(await processStripeEvent(evt('payment_intent.succeeded', {}, 'evt_live', true), store), 'live_event_rejected');
  assert.equal(state.orders.get('o1')!.status, 'pending');
});

test('unrelated event types are acknowledged and ignored', async () => {
  const { store } = makeStore([order()]);
  assert.equal(await processStripeEvent(evt('charge.refunded'), store), 'ignored');
});

test('paying when the book is no longer available still records the payment but flags it for review', async () => {
  const { store, state } = makeStore([order()], 'removed');
  assert.equal(await processStripeEvent(evt('payment_intent.succeeded'), store), 'paid');
  assert.equal(state.orders.get('o1')!.reviewNote, 'book_not_available_at_payment');
});

test('RACE: event arriving before the PaymentIntent id is saved is NOT consumed (Stripe will retry)', async () => {
  const { store, state } = makeStore([order({ paymentIntentId: '' })]);
  assert.equal(await processStripeEvent(evt('payment_intent.succeeded'), store), 'retry_later');
  assert.equal(state.events.size, 0);
  assert.equal(state.orders.get('o1')!.status, 'pending');
});

test('a failed payment does not clear a hold that belongs to a different order', async () => {
  const { store, state } = makeStore([order()], 'available', 'o_other');
  await processStripeEvent(evt('payment_intent.payment_failed'), store);
  assert.deepEqual(state.holdsCleared, []);
});
