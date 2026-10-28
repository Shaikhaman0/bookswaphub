# Initial project audit (before any change)

Source: `bookswaphub-source.zip` (original kept in `/home/claude/work/original_backup/`). This audit was done by reading the real files.

## What the project was
A Flutter app (Dart ^3.7.2, Riverpod, go_router) with a **complete UI but no backend**. Every screen read from `lib/data/mock/*` (hard-coded users, books, swaps, messages, reviews).

## Findings
| Area | State found |
|---|---|
| Firebase | Not installed, no config, no rules |
| Auth | Login/Register screens only navigated; no validation; logout did nothing (`context.go('/login')`) |
| Books | Mock list; "Add book" never saved; no image upload |
| Search / filter | Local filter over mock list; distance sort had no data |
| Wishlist | In-memory only |
| Swaps | Fake "Swap Requested!" snackbar; no state rules |
| Chat | Mock messages; send was local only |
| Notifications | Mock list; header badge was the fixed number 3 |
| Profile / settings | Hard-coded "John Doe"; switches did nothing |
| AI assistant | `if text.contains('programming')` canned replies (not an AI) |
| Admin | None |
| Payments | None |
| Tests | Default counter test that no longer matched the app |
| Android | `com.example` id, debug signing for release, no internet permission in the main manifest |
| Security | No rules, so nothing to protect data; roles did not exist |

## Risks identified
Admin would have been trivially forgeable if stored in a user document, payments could have been trusted from the client, and API keys had no safe home. These drove the design in `ARCHITECTURE.md`.

## Decisions
UI kept (same screens, layout, theme). Behaviour was moved onto Firebase. See `STEP_BY_STEP_IMPLEMENTATION.md`.
