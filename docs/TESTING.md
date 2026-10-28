# Testing

| Suite | Command | Result in this build |
|---|---|---|
| Backend pure logic (swap rules, Stripe mode guard, order pricing, signature, webhook idempotency, AI validation, rate limit, notifications) | `cd functions && npm install && npm test` | **70 / 70 pass** (`docs/backend_test_output.txt`) |
| Dart static sanity (brackets, imports, no mock imports, no hard-coded keys) | `python3 scripts/static_check.py` | **OK, 77 files** (`docs/static_check_output.txt`). This is NOT `flutter analyze`. |
| Flutter unit tests (`test/`: search keywords, AppConfig test-key guard, validators, Book model) | `flutter test` | **Written, not run** (no Flutter SDK here) |
| Firestore/Storage rules tests | `cd rules-tests && npm install && npm test` | **Written, not run** (needs emulator) |
| Cloud Functions compile | `cd functions && npm run build` | **Not verified** (firebase packages could not be installed here) |
| Flutter build | `flutter analyze && flutter build apk --debug --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxx` | **Blocked** |

## Manual test checklist (after setup)
Register → verify email → login → add book with photo → search/filter/scroll → wishlist → request swap from a 2nd account → accept → both confirm → leave review → chat both ways → notification appears → report a book → admin removes it → AI question → Buy with test card, check order becomes `paid` → repeat webhook (no double effect) → try editing another user's book in the emulator UI (must be denied).
