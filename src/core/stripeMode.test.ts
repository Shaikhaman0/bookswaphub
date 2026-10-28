import { test } from 'node:test';
import assert from 'node:assert/strict';
import { assertStripeTestMode, isTestPublishableKey, StripeConfigError } from './stripeMode';

const good = { STRIPE_MODE: 'test', STRIPE_SECRET_KEY: 'sk_test_abc123', STRIPE_WEBHOOK_SECRET: 'whsec_abc' };

test('accepts a proper test configuration', () => {
  const cfg = assertStripeTestMode(good, { needWebhookSecret: true });
  assert.equal(cfg.mode, 'test');
  assert.equal(cfg.currency, 'inr');
});

test('REJECTS live secret keys (sk_live_ and rk_live_)', () => {
  for (const key of ['sk_live_abc', 'rk_live_abc']) {
    assert.throws(
      () => assertStripeTestMode({ ...good, STRIPE_SECRET_KEY: key }),
      (e: unknown) => e instanceof StripeConfigError && e.code === 'stripe-live-key-rejected',
    );
  }
});

test('REJECTS a live key even when STRIPE_MODE says test', () => {
  assert.throws(() => assertStripeTestMode({ STRIPE_MODE: 'test', STRIPE_SECRET_KEY: 'sk_live_zzz' }));
});

test('REJECTS STRIPE_MODE=live, missing, or wrong case', () => {
  for (const mode of ['live', undefined, '', 'TEST', 'production']) {
    assert.throws(
      () => assertStripeTestMode({ ...good, STRIPE_MODE: mode }),
      (e: unknown) => e instanceof StripeConfigError && e.code === 'stripe-mode-not-test',
    );
  }
});

test('rejects missing/garbled keys', () => {
  assert.throws(() => assertStripeTestMode({ STRIPE_MODE: 'test' }));
  assert.throws(() => assertStripeTestMode({ STRIPE_MODE: 'test', STRIPE_SECRET_KEY: 'pk_test_123' }));
  assert.throws(() => assertStripeTestMode({ STRIPE_MODE: 'test', STRIPE_SECRET_KEY: 'whatever' }));
});

test('webhook secret is validated only when needed', () => {
  assert.doesNotThrow(() => assertStripeTestMode({ STRIPE_MODE: 'test', STRIPE_SECRET_KEY: 'sk_test_1' }));
  assert.throws(() => assertStripeTestMode({ STRIPE_MODE: 'test', STRIPE_SECRET_KEY: 'sk_test_1' }, { needWebhookSecret: true }));
  assert.throws(() =>
    assertStripeTestMode({ STRIPE_MODE: 'test', STRIPE_SECRET_KEY: 'sk_test_1', STRIPE_WEBHOOK_SECRET: 'bad' }, { needWebhookSecret: true }),
  );
});

test('publishable key helper accepts only pk_test_', () => {
  assert.equal(isTestPublishableKey('pk_test_123'), true);
  assert.equal(isTestPublishableKey('pk_live_123'), false);
  assert.equal(isTestPublishableKey(''), false);
  assert.equal(isTestPublishableKey(undefined), false);
});
