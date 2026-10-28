# Stripe: TEST MODE ONLY

**Never use live keys, real cards or real bank details.** Test card: `4242 4242 4242 4242`, any future date, any CVC.

## How test-only is enforced
- App: `AppConfig.paymentsDisabledReason` disables the Buy button unless the key starts with `pk_test_`; Stripe is not even initialised otherwise.
- Server: `assertStripeTestMode` requires `STRIPE_MODE=test`, an `sk_test_`/`rk_test_` key and rejects anything containing `_live_`. There is no fallback to live.
- Server aborts if Stripe ever returns `livemode: true`; the webhook rejects live events.
- Price is computed on the server from the book; the client only sends the book id.
- "Paid" is shown only after the webhook writes `status: paid` to the order.

## Setup
1. Stripe dashboard → switch to **Test mode** → copy `pk_test_…` and `sk_test_…`.
2. `firebase functions:secrets:set STRIPE_SECRET_KEY` (paste sk_test).
3. Deploy functions, then copy the `stripeWebhook` URL.
4. Dashboard (test mode) → Developers → Webhooks → add endpoint with that URL, events: `payment_intent.succeeded`, `payment_intent.payment_failed`, `payment_intent.canceled`. Copy the `whsec_…` signing secret → `firebase functions:secrets:set STRIPE_WEBHOOK_SECRET`, redeploy functions.
5. Run: `flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxx` (Android/iOS; Payment Sheet is not enabled on web).
6. Local webhook testing: `stripe listen --forward-to <emulator functions url>/stripeWebhook` (use the secret it prints).

## Webhook behaviour
Invalid signature → 400. Duplicate event id → ignored (idempotent). Amount mismatch → order not marked paid. Order not ready yet → 409 so Stripe retries.

## Status honesty
Logic is unit-tested (see TESTING.md). The full flow with real Stripe test servers has **not** been run here.
