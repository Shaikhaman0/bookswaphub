# Architecture

```
Flutter app (lib/)  ──reads/limited writes──▶  Firestore + Storage  (protected by firestore.rules / storage.rules)
      │                                              ▲
      └──── callable functions (auth required) ──▶ Cloud Functions (functions/)  ── Stripe (TEST) / AI provider
                                                     ▲
                                  Stripe webhook (signature verified) ┘
```

## Layers in the app
- `lib/screens`, `lib/widgets`: the original UI (kept).
- `lib/data/repositories`: the only code that talks to Firebase. Screens never call Firestore directly.
- `lib/data/providers/providers.dart`: Riverpod providers (streams for live data, futures for one-off reads).
- `lib/data/models`: plain Dart classes with `fromMap`, tolerant of missing fields.
- `lib/core`: config (`--dart-define`), routing (auth redirect), utils (errors, search keywords), bootstrap.

## Trust rule
> The app may only write data the user fully owns. Anything involving two people, money, ratings or roles is done by a Cloud Function.

| Done directly by the app (rules-checked) | Done only by Cloud Functions |
|---|---|
| Own profile (name, bio, location, avatar) | Swap requests and every status change |
| Own books (allow-listed fields) | Orders, payments, Stripe webhook |
| Wishlist (`uid_bookId`) | Reviews and rating updates |
| Chat messages (participants only) | Notifications and push |
| Reports (status always `open`) | Admin actions, AI calls, account deletion |

## Roles
Admin = Firebase Auth **custom claim** `admin: true`, set only with `functions/scripts/set-admin.js` using your own credentials. No document field can make someone admin; rules and functions both check the claim.

## Swap state machine
`pending → accepted → inProgress → completed` (also `rejected`, `cancelled`). Accept reserves the book, cancel/reject release it. Completion needs both people to confirm. Logic is in `functions/src/core/swapStateMachine.ts` and unit-tested.

## Payments (TEST only)
App sends only the book id. Server reads the price from the book, creates a PaymentIntent (idempotency key), stores an order. The webhook verifies the Stripe signature, ignores duplicates (`stripeEvents/{id}`), rejects live events, checks the amount, then marks the order paid and the book sold. The app shows "paid" only when the order document says so.

## Search
Each book stores `searchKeywords` (lowercase prefixes). One keyword is queried with `array-contains`; extra words are filtered in the app. Pagination uses `startAfterDocument`.
