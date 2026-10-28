// Verifies Stripe webhook signatures (the documented HMAC-SHA256 scheme).
// Header looks like:  t=1700000000,v1=<hex>,v1=<hex>

import { createHmac, timingSafeEqual } from 'node:crypto';

export class WebhookSignatureError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'WebhookSignatureError';
  }
}

export interface VerifyOptions {
  toleranceSeconds?: number;
  nowSeconds?: number;
}

export function computeSignature(secret: string, timestamp: string, rawBody: string | Buffer): string {
  const payload = Buffer.concat([Buffer.from(`${timestamp}.`, 'utf8'), Buffer.from(rawBody)]);
  return createHmac('sha256', secret).update(payload).digest('hex');
}

export function verifyStripeSignature(
  rawBody: string | Buffer,
  header: string | undefined,
  secret: string,
  opts: VerifyOptions = {},
): void {
  if (!header) throw new WebhookSignatureError('Missing Stripe-Signature header.');
  if (!secret) throw new WebhookSignatureError('Webhook secret is not configured.');

  let timestamp = '';
  const signatures: string[] = [];
  for (const part of header.split(',')) {
    const idx = part.indexOf('=');
    if (idx === -1) continue;
    const key = part.slice(0, idx).trim();
    const value = part.slice(idx + 1).trim();
    if (key === 't') timestamp = value;
    if (key === 'v1') signatures.push(value);
  }
  if (!timestamp || signatures.length === 0) {
    throw new WebhookSignatureError('Malformed Stripe-Signature header.');
  }
  const tolerance = opts.toleranceSeconds ?? 300;
  const now = opts.nowSeconds ?? Math.floor(Date.now() / 1000);
  const ts = Number(timestamp);
  if (!Number.isFinite(ts) || Math.abs(now - ts) > tolerance) {
    throw new WebhookSignatureError('Timestamp outside the allowed tolerance.');
  }

  const expected = Buffer.from(computeSignature(secret, timestamp, rawBody), 'hex');
  const match = signatures.some((sig) => {
    if (!/^[0-9a-fA-F]+$/.test(sig)) return false;
    const got = Buffer.from(sig, 'hex');
    return got.length === expected.length && timingSafeEqual(got, expected);
  });
  if (!match) throw new WebhookSignatureError('Signature does not match.');
}
