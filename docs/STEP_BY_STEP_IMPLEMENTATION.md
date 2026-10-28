# Step by step (beginner explanation)

1. **Read the real code.** Found a finished UI that used fake data (INITIAL_PROJECT_AUDIT.md). A backup of the original zip was kept.
2. **Decide who is allowed to do what.** Wrote the rules first (`firestore.rules`, `storage.rules`): everything is denied unless a rule allows it. Why: the app runs on the user's device, so anything the app can do, a hacker can try to do.
3. **Backend for trusted things.** Cloud Functions handle swaps, payments, reviews, notifications, admin and AI because users must not be able to edit those directly. The tricky logic (swap states, Stripe checks, webhook signature) is plain TypeScript with 70 tests so it can be checked without any cloud.
4. **Auth.** Email + password with email verification. The router sends signed-out users to Login and unverified users to the verify screen. Admin is a special flag on the login token that only your script can set.
5. **Repositories + providers.** One class per area talks to Firebase; Riverpod providers feed screens live data. Screens only show loading / error / empty / data.
6. **Screens, one by one.** Home, Discover (search, filters, infinite scroll), Add/Edit book, My books, Wishlist, Swaps, Chat, Notifications, Book details, Profile, Settings, AI assistant, Admin. The look stays the same; the data is now real.
7. **Search.** Firestore cannot search "contains", so each book stores lowercase word beginnings and we search those.
8. **Stripe (test).** App sends the book id → server sets the price → Stripe PaymentSheet → Stripe tells our webhook → order becomes paid. The app never decides "paid" itself.
9. **Cleanup.** Mock data moved to `/home/claude/work/removed_mock` (recoverable), default test replaced, Android set up for Stripe, `.gitignore` protects secrets.
10. **Checks.** 70 backend tests run and pass. Everything needing Flutter/Firebase is honestly marked BLOCKED in FEATURE_STATUS.md.
