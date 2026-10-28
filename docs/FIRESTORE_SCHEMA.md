# Firestore schema

| Collection | Doc id | Key fields | Client write? |
|---|---|---|---|
| `users` | uid | name, bio, location, avatarUrl, rating, ratingCount, totalSwaps, disabled, createdAt | own doc, allow-listed fields only (no rating, no role) |
| `users/{uid}/devices` | FCM token | platform, createdAt | own |
| `books` | auto | title, author, description, category, categoryId, condition, language, location, ownerId, ownerName, status, listingType (swap/sale/both), price, currency, imageUrls, searchKeywords, titleLower, rating, pendingOrderId, createdAt | owner create/update/delete with allow-list; status limited to available/unavailable |
| `wishlists` | `uid_bookId` | userId, bookId, createdAt | own |
| `swapRequests` | auto | requesterId, ownerId, participantIds, bookId, offeredBookId, status, message, confirmedBy, createdAt | **no** (functions) |
| `conversations` | `uidA_uidB` (sorted) | participantIds, lastMessage, unread map | participants (limited) |
| `conversations/{id}/messages` | auto | senderId, text, createdAt | participants, senderId must equal auth uid |
| `notifications` | auto | userId, type, title, body, route, read | mark read / delete only |
| `reviews` | `swapId_uid` | reviewerId, revieweeId, rating, comment | **no** (functions) |
| `reports` | auto | reporterId, targetType, targetId, reason, status | create with status `open` |
| `orders` | auto | buyerId, sellerId, bookId, amountMinor, currency, status, paymentIntentId | **no** |
| `payments`, `stripeEvents`, `rateLimits`, `auditLogs` | various | server bookkeeping | **no** (auditLogs readable by admin) |

Indexes: `firestore.indexes.json` (deploy with `firebase deploy --only firestore:indexes`).
Storage: `books/{uid}/…` (5 MB) and `avatars/{uid}/…` (2 MB), jpeg/png/webp only, writable only by the owner.
