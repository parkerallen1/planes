# Firebase setup for Dexicon

The app is fully wired for Firebase but ships **dormant**: until the steps
below are done, `lib/firebase_options.dart` is a placeholder, Firebase init
fails quietly, and the app runs exactly as before — local Hive storage and
the `.env.local` Gemini key.

Doing this setup turns on, with no further code changes:

- **Cloud backup & sync** of the collection (Firestore) and photos
  (Cloud Storage), per anonymous user, offline-tolerant.
- **Gemini via Firebase AI Logic** — removes the API key from the app
  binary (the `.env.local` key is extractable from any APK/IPA, so do not
  ship a store build before this).

## 1. Create the Firebase project

1. Go to <https://console.firebase.google.com> → **Add project**, name it
   e.g. `dexicon` (under the Driftwood account).
2. Skip Google Analytics unless you want it.
3. Upgrade the project to the **Blaze** (pay-as-you-go) plan — required for
   Cloud Storage buckets on new projects. The free-tier allowances still
   apply; a solo user stays at $0.

## 2. Register the apps with FlutterFire

```bash
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli

# from the repo root:
flutterfire configure
```

Pick the project, select **android** and **ios**, and accept
`com.driftwood.dexicon` as the id for both. This overwrites
`lib/firebase_options.dart` (the placeholder) with real values — commit
that file. No `google-services.json`/`GoogleService-Info.plist` gymnastics
are needed; the app passes options explicitly at init.

## 3. Enable Anonymous Authentication

Console → **Build → Authentication → Get started → Sign-in method →
Anonymous → Enable**.

Each install gets a stable anonymous uid with zero login UI. Caveat:
uninstalling the app abandons that uid (cloud data stays but nothing can
reach it). If that ever matters, layer Google/Apple sign-in on top with
`linkWithCredential` — no data migration needed.

## 4. Create the Firestore database

Console → **Build → Firestore Database → Create database** → production
mode → pick a region close to you (e.g. `us-central1`). Then set **Rules**:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

Data layout the app uses: `users/{uid}/items/{itemId}` — one doc per
scanned item (the `Plane.toJson()` body plus a `deleted` tombstone flag).

## 5. Enable Cloud Storage

Console → **Build → Storage → Get started** (same region). **Rules**:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{uid}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

Photos are stored at `users/{uid}/scans/<filename>.jpg`.

## 6. Enable Firebase AI Logic (Gemini)

Console → **Build → AI Logic → Get started** and choose the **Gemini
Developer API** backend (the free-tier one; no Vertex/billing needed for
`gemini-3.5-flash`-class models). The app already requests the model named
in `GeminiService.modelName`.

## 7. App Check

Console → **Build → App Check**:

1. Register the Android app with **Play Integrity** and the iOS app with
   **App Attest**.
2. For dev builds the app activates the **debug provider** automatically
   (`kDebugMode`): run once, copy the debug token from logcat/Xcode
   console, and add it under App Check → Apps → ⋮ → Manage debug tokens.
3. Once both real providers verify traffic, turn **Enforcement** on for
   Firestore, Storage, and AI Logic. Don't enforce before then or dev
   builds lock out.

## 8. Verify

- `flutter run` → console should NOT print "Firebase not configured".
- Scan something → Console → Firestore → `users/{uid}/items` shows the doc;
  Storage shows the photo under `users/{uid}/scans/`.
- Delete `.env.local`'s key (leave the file, it can be empty) →
  identification still works (AI Logic path).
- Install on a second device → collection and photos appear after launch.

## Costs

Free-tier allowances (per day: 50k Firestore reads / 20k writes; 5 GB
Storage total, 1 GiB Firestore) dwarf single-user usage. The only real
cost lever is photo storage — if collections get big, add
`maxWidth`/`imageQuality` to the `ImagePicker.pickImage` call in
`add_plane_screen.dart` to shrink uploads.
