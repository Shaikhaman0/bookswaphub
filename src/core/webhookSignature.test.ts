import { test } from 'node:test';
import assert from 'node:assert/strict';
import { computeSignature, verifyStripeSignature, WebhookSignatureError } from './webhookSignature';

const secret = 'whsec_testsecret';
const body = JSON.stringify({ id: 'evt_1', type: 'payment_intent.succeeded' });
const now = 1_700_000_000;
const header = (t: number, sig: string) => `t=${t},v1=${sig}`;

test('accepts a correctly signed payload', () => {
  const sig = computeSignature(secret, String(now), body);
  assert.doesNotThrow(() => verifyStripeSignature(body, header(now, sig), secret, { nowSeconds: now }));
});

test('accepts when one of several v1 signatures matches', () => {
  const sig = computeSignature(secret, String(now), body);
  assert.doesNotThrow(() =>
    verifyStripeSignature(body, `t=${now},v1=deadbeef,v1=${sig}`, secret, { nowSeconds: now }),
  );
});

test('rejects a wrong secret', () => {
  const sig = computeSignature('whsec_other', String(now), body);
  assert.throws(() => verifyStripeSignature(body, header(now, sig), secret, { nowSeconds: now }), WebhookSignatureError);
});

test('rejects a tampered body', () => {
  const sig = computeSignature(secret, String(now), body);
  assert.throws(() => verifyStripeSignature(body + ' ', header(now, sig), secret, { nowSeconds: now }), WebhookSignatureError);
});

test('rejects missing, malformed, or non-hex headers', () => {
  assert.throws(() => verifyStripeSignature(body, undefined, secret, { nowSeconds: now }));
  assert.throws(() => verifyStripeSignature(body, 'garbage', secret, { nowSeconds: now }));
  assert.throws(() => verifyStripeSignature(body, `t=${now},v1=zzzz`, secret, { nowSeconds: now }));
});

test('rejects old timestamps (replay) and accepts within tolerance', () => {
  const old = now - 301;
  const sigOld = computeSignature(secret, String(old), body);
  assert.throws(() => verifyStripeSignature(body, header(old, sigOld), secret, { nowSeconds: now }));
  const ok = now - 299;
  const sigOk = computeSignature(secret, String(ok), body);
  assert.doesNotThrow(() => verifyStripeSignature(body, header(ok, sigOk), secret, { nowSeconds: now }));
});

test('rejects when the secret is empty', () => {
  assert.throws(() => verifyStripeSignature(body, header(now, 'ab'), '', { nowSeconds: now }));
});

test('matches the documented Stripe scheme (HMAC-SHA256 of "t.body")', () => {
  // Independent recomputation using node:crypto directly.
  const { createHmac } = require('node:crypto') as typeof import('node:crypto');
  const expected = createHmac('sha256', secret).update(`${now}.${body}`).digest('hex');
  assert.equal(computeSignature(secret, String(now), body), expected);
});
