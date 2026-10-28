# Firebase setup (steps only you can do: they need your Google account)

1. Create a Firebase project at https://console.firebase.google.com (use a **dev** project).
2. Upgrade to the **Blaze** plan (Cloud Functions and Secret Manager need it; test usage costs ~nothing).
3. Enable: **Authentication → Email/Password**, **Firestore** (production mode), **Storage**, **Cloud Messaging**.
4. Install tools: Flutter SDK, Node 22, `npm i -g firebase-tools`, firebase deploy --only firestore:rules,firestore:indexes,storagethen `dart pub global activate flutterfire_cli`.
5. In the project folder: `firebase login`, then `cp .firebaserc.example .firebaserc` and put your project id in it.
6. `flutterfire configure` → this **replaces `lib/firebase_options.dart`** (the placeholder throws on purpose) and creates `android/app/google-services.json`. Do not commit these.
7. Deploy backend pieces:
   ```
   cd functions && npm install && cd ..
   firebase deploy --only firestore:rules,firestore:indexes,storage
   firebase functions:secrets:set STRIPE_SECRET_KEY      # sk_test_... only
   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET  # see STRIPE_TEST_MODE.md
   firebase functions:secrets:set ANTHROPIC_API_KEY
   firebase deploy --only functions
   ```
   Put non-secret settings from `.env.example` in `functions/.env.<project-id>`.
8. Make yourself admin (once): download a service-account key to a path **outside the repo**, then  
   `cd functions && GOOGLE_APPLICATION_CREDENTIALS=/path/key.json GCLOUD_PROJECT=<id> node scripts/set-admin.js you@email.com`  
   Sign out and in again to refresh your token.
9. App Check (recommended): register the app in Console → App Check, then enforce it for Firestore/Storage/Functions once it works.
10. Android: change `applicationId` from `com.example.bookswaphub` to your own before publishing, register it in Firebase, and create a real release keystore (the template signs release with the debug key).

## Local emulators (no cloud needed)
`firebase emulators:start` then `flutter run --dart-define=USE_EMULATORS=true`.  
If you open the app before step 6, you will see a "Setup required" screen, not a crash.
