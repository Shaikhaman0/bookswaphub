# Book Swap Hub

Swap or buy second-hand books. Flutter app + Firebase (Auth, Firestore, Storage, Cloud Functions, FCM). Payments run in **Stripe TEST mode only**; no real money is ever used.

## Quick start
1. Follow `docs/FIREBASE_SETUP.md` (Firebase project, `flutterfire configure`, deploy rules/functions).
2. `flutter pub get`
3. `flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxx` (omit the key to run without payments)
4. Emulators instead of cloud: `firebase emulators:start` and add `--dart-define=USE_EMULATORS=true`.

## Docs
`docs/FEATURE_STATUS.md` (what works / what is unverified), `ARCHITECTURE`, `FIREBASE_SETUP`, `FIRESTORE_SCHEMA`, `API_SETUP`, `STRIPE_TEST_MODE`, `TESTING`, `STEP_BY_STEP_IMPLEMENTATION`, `INITIAL_PROJECT_AUDIT`.

## Security rules of thumb
Never commit `.env`, `google-services.json`, service-account keys or secret keys. Secrets live in Firebase Secret Manager. Admins are created only with `functions/scripts/set-admin.js`.

## Honest status
Backend pure logic: 70 tests pass. The Flutter app, security rules and live Firebase/Stripe flows were written but **not compiled or run** in the environment that produced them. Run `flutter analyze` and `flutter test` first and fix any small compile errors.


git initgit init
flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_51R6GLPFSZDmdoQ1j80qMGtkcUC8f9jOYQ3gUE2tVa6kZu1t7wVqT3W1NkanUgiawSQO5FRzbyGyDXnMBc6cWye5d00BwjmkI0e