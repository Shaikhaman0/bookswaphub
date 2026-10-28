# Feature status

Legend: PASS = verified by a test or inspection that was actually run. BLOCKED = code written but cannot be verified here (missing Flutter SDK, Firebase project, emulator or Stripe access). Nothing below is marked PASS unless something ran.

| # | Feature | Status | Evidence / note |
|---|---|---|---|
| 1 | Existing UI preserved | IN PROGRESS | Same screens/layout/theme kept; not visually verified (no Flutter SDK) |
| 2 | Firebase initialisation | BLOCKED | Needs `flutterfire configure` (FIREBASE_SETUP.md). App shows a setup screen until then |
| 3 | Auth (register, verify email, login, reset, logout) | BLOCKED | Code written, not run |
| 4 | Roles: admin by custom claim only | BLOCKED | Rules + functions check claim; `set-admin.js` written; rules tests not run |
| 5 | Book CRUD + image upload | BLOCKED | Code written, not run |
| 6 | Search / filter / pagination | BLOCKED | Keyword generator unit tests written (`flutter test` not run) |
| 7 | Google Books integration | NOT STARTED | Optional, skipped |
| 8 | Wishlist | BLOCKED | Written, not run |
| 9 | Swaps with validated transitions | PASS (logic) / BLOCKED (functions) | State machine unit tests pass; callable wiring not compiled |
| 10 | Real-time chat | BLOCKED | Written, not run |
| 11 | Notifications + FCM | BLOCKED | Written, not run; web push not configured |
| 12 | Profile, reviews | BLOCKED | Written, not run |
| 13 | Reports + admin panel | BLOCKED | Written, not run. Category management by admin: NOT STARTED |
| 14 | AI assistant via backend | PASS (validation/prompt/rate limit logic) / BLOCKED (live call) | No live AI call made |
| 15 | Firestore + Storage rules | BLOCKED | Default-deny rules + ~20 emulator tests written, not run |
| 16 | Stripe test checkout | PASS (logic) / BLOCKED (live flow) | Mode guard, pricing, hold, client unit tests pass; never contacted Stripe |
| 17 | Stripe webhook | PASS (logic) / BLOCKED (endpoint) | Signature, idempotency, amount check, live-event rejection tested |
| 18 | Live payments disabled | PASS | `_live_` / non-test keys rejected in app and server; unit tests |
| 19 | Automated tests | PASS (70 backend) / BLOCKED (Flutter, rules) | `docs/backend_test_output.txt` |
| 20 | Build (APK/web) | BLOCKED | No Flutter SDK |
| 21 | Documentation | PASS | This docs folder |

## Known limitations
- Crashlytics/Analytics not added. Remember-me works on web only. Per-type notification toggles, profile-visibility and language are shown as "coming soon" (disabled) rather than fake switches. FAQ / Terms / Privacy links are still placeholders.
- Old listings keep the owner name they were created with if the owner renames their profile.
- Distance sorting was removed (no geolocation data); "Nearby" matches the city text.
- Chat attachments disabled. Stripe Payment Sheet: Android/iOS only.
- `applicationId` is still `com.example.bookswaphub`; release signing still uses debug keys.
