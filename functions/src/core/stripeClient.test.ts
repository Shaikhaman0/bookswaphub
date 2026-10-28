import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createPaymentIntent, encodeForm, StripeApiError, type FetchLike } from './stripeClient';
import { assertStripeTestMode, StripeConfigError } from './stripeMode';

const cfg = assertStripeTestMode({ STRIPE_MODE: 'test', STRIPE_SECRET_KEY: 'sk_test_abc' });
const input = { amountMinor: 25000, currency: 'inr', metadata: { orderId: 'o1', buyerId: 'u1' }, idempotencyKey: 'order-o1' };

function fake(status: number, body: unknown, capture?: { url?: string; init?: Parameters<FetchLike>[1] }): FetchLike {
  return async (url, init) => {
    if (capture) { capture.url = url; capture.init = init; }
    return { ok: status >= 200 && status < 300, status, json: async () => body };
  };
}

test('sends a correct, form-encoded test request with an idempotency key', async () => {
  const cap: { url?: string; init?: Parameters<FetchLike>[1] } = {};
  const r = await createPaymentIntent(cfg, input, fake(200, { id: 'pi_1', client_secret: 'pi_1_secret_x', status: 'requires_payment_method', livemode: false }, cap));
  assert.deepEqual(r, { id: 'pi_1', clientSecret: 'pi_1_secret_x', status: 'requires_payment_method' });
  assert.equal(cap.url, 'https://api.stripe.com/v1/payment_intents');
  assert.equal(cap.init!.headers['Idempotency-Key'], 'order-o1');
  assert.equal(cap.init!.headers.Authorization, 'Bearer sk_test_abc');
  assert.match(cap.init!.body!, /amount=25000/);
  assert.match(cap.init!.body!, /currency=inr/);
  assert.match(cap.init!.body!, /metadata%5BorderId%5D=o1/);
});

test('aborts if Stripe ever answers with a live object', async () => {
  await assert.rejects(
    createPaymentIntent(cfg, input, fake(200, { id: 'pi_1', client_secret: 's', livemode: true })),
    (e: unknown) => e instanceof StripeConfigError && e.code === 'stripe-live-response',
  );
});

test('maps Stripe errors and rejects bad amounts before any network call', async () => {
  await assert.rejects(createPaymentIntent(cfg, input, fake(402, { error: { message: 'bad' } })), StripeApiError);
  let called = false;
  const spy: FetchLike = async () => { called = true; return { ok: true, status: 200, json: async () => ({}) }; };
  await assert.rejects(createPaymentIntent(cfg, { ...input, amountMinor: 0 }, spy), StripeApiError);
  await assert.rejects(createPaymentIntent(cfg, { ...input, amountMinor: 10.5 }, spy), StripeApiError);
  assert.equal(called, false);
});

test('unexpected response shape is an error', async () => {
  await assert.rejects(createPaymentIntent(cfg, input, fake(200, { id: 'pi_1' })), StripeApiError);
});

test('encodeForm escapes values', () => {
  assert.equal(encodeForm({ 'a[b]': 'x y&z' }), 'a%5Bb%5D=x%20y%26z');
});
