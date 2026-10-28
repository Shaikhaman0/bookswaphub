# API setup

## AI assistant (backend only)
- The app calls the `aiAssistant` Cloud Function; the provider key never ships in Flutter.
- Set the secret: `firebase functions:secrets:set ANTHROPIC_API_KEY`. Model: `AI_MODEL` (default `claude-sonnet-5-5`).
- The function: needs sign-in, allows max 10 turns of 2000 characters, rate-limits per user (`AI_RATE_LIMIT_PER_HOUR`, default 30), looks up real listings by keyword and tells the model to recommend only those. If the secret is missing, the app shows a friendly error.

## Google Books
**Not implemented.** It was optional in the brief. Add later through a function or a restricted key.

## Push notifications (FCM)
Enabled by step 3 of `FIREBASE_SETUP.md`. Web push also needs a VAPID key and a service worker (not set up). iOS needs an APNs key uploaded in Firebase.

## Stripe
See `STRIPE_TEST_MODE.md`.
