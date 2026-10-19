// Stripe TEST-MODE-ONLY guard.
// Called before ANY payment work. If anything looks like live mode, we throw and
// the payment function stops. There is no "fallback to live".

export class StripeConfigError extends Error {
  readonly code: string;
  constructor(code: string, message: string) {
    super(message);
    this.name = 'StripeConfigError';
    this.code = code;
  }
}

export interface StripeEnv {
  STRIPE_MODE?: string;
  STRIPE_SECRET_KEY?: string;
  STRIPE_WEBHOOK_SECRET?: string;
  STRIPE_CURRENCY?: string;
}

export interface StripeTestConfig {
  readonly mode: 'test';
  readonly secretKey: string;
  readonly webhookSecret: string;
  readonly currency: string;
}

const LIVE_MARKER = /_live_/i;

/** Throws StripeConfigError unless everything is clearly TEST mode. */
export function assertStripeTestMode(env: StripeEnv, opts: { needWebhookSecret?: boolean } = {}): StripeTestConfig {
  if (env.STRIPE_MODE !== 'test') {
    throw new StripeConfigError(
      'stripe-mode-not-test',
      'STRIPE_MODE must be exactly "test". Payments are disabled until it is.',
    );
  }
  const secret = (env.STRIPE_SECRET_KEY ?? '').trim();
  if (!secret) {
    throw new StripeConfigError('stripe-secret-missing', 'STRIPE_SECRET_KEY is not configured.');
  }
  if (LIVE_MARKER.test(secret)) {
    throw new StripeConfigError('stripe-live-key-rejected', 'A LIVE Stripe key was detected. Live keys are rejected.');
  }
  if (!(secret.startsWith('sk_test_') || secret.startsWith('rk_test_'))) {
    throw new StripeConfigError('stripe-key-invalid', 'STRIPE_SECRET_KEY must start with sk_test_.');
  }
  const wh = (env.STRIPE_WEBHOOK_SECRET ?? '').trim();
  if (opts.needWebhookSecret) {
    if (!wh) {
      throw new StripeConfigError('stripe-webhook-secret-missing', 'STRIPE_WEBHOOK_SECRET is not configured.');
    }
    if (!wh.startsWith('whsec_')) {
      throw new StripeConfigError('stripe-webhook-secret-invalid', 'STRIPE_WEBHOOK_SECRET must start with whsec_.');
    }
  }
  const currency = (env.STRIPE_CURRENCY ?? 'inr').trim().toLowerCase();
  if (!/^[a-z]{3}$/.test(currency)) {
    throw new StripeConfigError('stripe-currency-invalid', 'STRIPE_CURRENCY must be a 3-letter code.');
  }
  return Object.freeze({ mode: 'test' as const, secretKey: secret, webhookSecret: wh, currency });
}

/** Checks a publishable key (used by the Flutter app and in docs/tests). */
export function isTestPublishableKey(key: string | undefined | null): boolean {
  const k = (key ?? '').trim();
  return k.startsWith('pk_test_') && !LIVE_MARKER.test(k);
}
