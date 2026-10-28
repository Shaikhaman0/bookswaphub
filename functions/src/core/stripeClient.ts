// Tiny Stripe REST client (no SDK) so every call is visible and testable.
// Only creates PaymentIntents, and refuses to continue if Stripe says livemode=true.

import { StripeConfigError, type StripeTestConfig } from './stripeMode';

export type FetchLike = (
  url: string,
  init: { method: string; headers: Record<string, string>; body?: string; signal?: AbortSignal },
) => Promise<{ ok: boolean; status: number; json(): Promise<unknown> }>;

export interface CreatePaymentIntentInput {
  amountMinor: number;
  currency: string;
  metadata: Record<string, string>;
  idempotencyKey: string;
}

export interface PaymentIntentResult {
  id: string;
  clientSecret: string;
  status: string;
}

export class StripeApiError extends Error {
  readonly status: number;
  constructor(status: number, message: string) {
    super(message);
    this.name = 'StripeApiError';
    this.status = status;
  }
}

export function encodeForm(params: Record<string, string>): string {
  return Object.entries(params)
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
    .join('&');
}

export async function createPaymentIntent(
  cfg: StripeTestConfig,
  input: CreatePaymentIntentInput,
  fetchFn: FetchLike,
  timeoutMs = 15000,
): Promise<PaymentIntentResult> {
  if (cfg.mode !== 'test') {
    throw new StripeConfigError('stripe-mode-not-test', 'Refusing to call Stripe outside test mode.');
  }
  if (!Number.isInteger(input.amountMinor) || input.amountMinor <= 0) {
    throw new StripeApiError(400, 'Invalid amount.');
  }
  const form: Record<string, string> = {
    amount: String(input.amountMinor),
    currency: input.currency,
    'automatic_payment_methods[enabled]': 'true',
  };
  for (const [k, v] of Object.entries(input.metadata)) {
    form[`metadata[${k}]`] = v;
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetchFn('https://api.stripe.com/v1/payment_intents', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${cfg.secretKey}`,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Idempotency-Key': input.idempotencyKey,
      },
      body: encodeForm(form),
      signal: controller.signal,
    });
    const body = (await res.json()) as Record<string, unknown>;
    if (!res.ok) {
      const err = (body?.error ?? {}) as { message?: string };
      throw new StripeApiError(res.status, err.message ?? 'Stripe request failed.');
    }
    if (body.livemode === true) {
      throw new StripeConfigError('stripe-live-response', 'Stripe returned a LIVE object. Aborting.');
    }
    if (typeof body.id !== 'string' || typeof body.client_secret !== 'string') {
      throw new StripeApiError(502, 'Unexpected Stripe response.');
    }
    return { id: body.id, clientSecret: body.client_secret, status: String(body.status ?? '') };
  } finally {
    clearTimeout(timer);
  }
}
