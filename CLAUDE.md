# Claude notes for this repo

**Last updated: 7-4-2026.** This file is the living context doc for the app.
When you make changes that alter anything described here (or finish a TODO
item), update this file — including this date — in the same commit.

## Workflow rules

- Solo-dev repo: work directly on `main` and push there. No pull requests,
  no feature branches unless explicitly asked.
- Publisher name for app identifiers/store listings: **Driftwood**
  (reverse-domain id: `com.driftwood.dexicon`). Never use `parkerallen`
  in app identifiers.

## What the app is

**Dexicon** — a Flutter app to scan, identify, and collect anything with AI.
The user photographs something (a plane, bird, car, flower, or any category
they create), Gemini identifies it, writes a description, tags it, and adds
it to their collection. The whole UI is styled as a retro 90s handheld
scanner toy: chunky plastic frame, animated LEDs, CRT scanlines, boot
sequence, sound effects. Think "Pokédex for the real world."

History that explains the code: the app began as a plane-spotting app called
**Planedex**, later generalized to arbitrary categories and renamed
**Dexicon**. All user-facing copy, display names, and app ids are done; the
*internal* names were deliberately left alone (see "Naming quirk" below).

Current version: `1.0.1+5`. All Flutter platform folders exist, but the real
targets are Android and iOS.

## Tech stack

- Flutter, Dart SDK `^3.9.2`, Material.
- **Riverpod 3** (`flutter_riverpod`, Notifier API) for state.
- **Hive** for the collection database (box named `planes`).
- **Gemini**, model `gemini-3.5-flash` (constant `GeminiService.modelName`),
  reached through one of two backends (`services/genai_backend.dart`):
  **Firebase AI Logic** (`firebase_ai`, App Check-attested, no key in the
  binary) when Firebase is configured — the production path — else direct
  `google_generative_ai` with the `.env.local` key as local-dev fallback.
- API key (fallback path only): `GEMINI_API_KEY` in `.env.local` at the
  repo root, loaded with `flutter_dotenv` and bundled as a Flutter asset.
  `flutter build` fails if the file doesn't exist — create it first in
  fresh clones (it's gitignored; may be empty once Firebase is configured).
  NOTE: the bundled key is extractable from the APK/IPA — do NOT ship a
  store build on the fallback path; configure Firebase first.
- `shared_preferences` for settings and categories; `google_fonts` for retro
  fonts; `audioplayers` for synthesized retro sounds; `image_picker` for
  camera/gallery; `geolocator` + `exif` for capture location;
  `share_plus` for exporting backups.
- **Firebase** (optional, off until configured): `firebase_core`,
  `firebase_auth` (anonymous), `cloud_firestore`, `firebase_storage`,
  `firebase_app_check`, `firebase_ai`. `lib/firebase_options.dart` is a
  placeholder that throws until `flutterfire configure` replaces it —
  `FirebaseBootstrap.init()` catches that and the app runs local-only.
  Setup steps live in `FIREBASE_SETUP.md`. Firebase forces Android
  minSdk 23 and iOS 15 (set in gradle/Podfile/pbxproj).
- **No codegen wired up**: `build_runner`/`hive_generator` were removed due
  to a version conflict with Riverpod. `lib/models/plane.g.dart` is checked
  in and hand-maintained — if you add/change Hive fields, edit the adapter
  by hand (or temporarily re-add the generators).

## Code map (`lib/`)

- `main.dart` — entry point. Loads `.env.local`, inits `StorageService`,
  injects a hardcoded F-35 test plane (pre-launch TODO: remove), and runs
  `DexiconApp` with routes `/home`, `/add`, `/settings`. Picks retro vs
  classic theme and optionally shows the boot screen first.
- `models/plane.dart` (+ `plane.g.dart`) — `Plane` is the core record for
  **any** scanned item, not just aircraft (name is legacy). Fields: image
  path, timestamp, lat/long, identification, description, activity, tags,
  chat history, `status` (identifying/finalized), `guesses` (alternative
  identifications with confidence), `identificationTips`, `categoryId`.
  Also `ChatMessage` and `PlaneGuess`. Hive typeIds 0–3 — don't reuse them.
  Sync fields: `updatedAt` (last-write-wins merging; stamped by
  StorageService on every local write) and `imageUrl` (Firebase Storage
  download URL). Hive fields 0–15 used.
- `models/scan_category.dart` — `ScanCategory` (id, name, emoji,
  `geminiContext` prompt phrase, `validTags`). Five defaults: Planes, Cars,
  Flowers, Trees, Birds.
- `providers/category_provider.dart` — category list + active category,
  persisted to SharedPreferences (`scan_categories_v1`). Users can add
  custom categories; tags the AI invents during identification get appended
  to the category's tag list.
- `providers/theme_provider.dart` — `AppSettings`: classic vs retro mode,
  retro font choice (Press Start 2P, VT323, Orbitron, Audiowide), and
  toggles for screen frame, animated LEDs, CRT scanlines, entry animation,
  sound effects, boot animation. Persisted to SharedPreferences.
- `screens/home_screen.dart` — the collection: grid of scanned items, the
  skeuomorphic category dial (CategoryScrollWheel), filtering. Biggest file.
- `screens/add_plane_screen.dart` — capture/pick a photo and run the
  identification flow.
- `screens/plane_detail_screen.dart` — item detail: guesses, tags, and a
  Gemini chat about the item (history stored on the `Plane`).
- `screens/settings_screen.dart` — theme/retro toggles, category management,
  backup import/export.
- `screens/boot_screen.dart` — retro boot animation shown on launch.
- `services/gemini_service.dart` — all AI calls: `identifyPlane` (photo →
  identification/description/tags/guesses, category-aware via
  `geminiContext` and `validTags`), `regenerateTags`, `chat`, and
  `generateCategoryProfile` (new category name → emoji/context/starter
  tags). Responses are JSON parsed out of markdown code fences. Talks to
  Gemini through a `GenAiBackend`, picked in `geminiServiceProvider`.
- `services/genai_backend.dart` — `GenAiBackend` interface +
  `FirebaseAiBackend` (firebase_ai / AI Logic) and `GoogleAiBackend`
  (google_generative_ai + API key) implementations.
- `services/storage_service.dart` — Hive CRUD, tag aggregation, JSON
  export/import for backups. Deleting an item also deletes its stored photo.
  The single choke point for writes: `savePlane`/`updatePlane`/`deletePlane`
  stamp `updatedAt` and push to SyncService; `applyRemotePlane`/
  `removeLocalPlane` are the remote→local path (no stamp, no push-back).
  Exposes the box `listenable` so the home grid refreshes on synced-in
  changes.
- `services/sync_service.dart` — Firestore mirror at `users/{uid}/items/{id}`
  (doc body = `Plane.toJson()` + `deleted` flag). Realtime snapshot listener,
  last-write-wins on `updatedAt`, soft-delete tombstones, and a first-snapshot
  seeding pass that uploads local items the cloud has never seen. Firestore
  offline persistence queues pushes while offline. Only active when
  `cloudEnabledProvider` is true. Photos: uploaded to Firebase Storage at
  `users/{uid}/scans/<basename>` (download URL stamped on `Plane.imageUrl`);
  other devices download missing photos into their local scans/ dir, and
  deleting an item deletes the cloud object too. Interrupted uploads retry
  on the next launch's seeding pass.
- `services/image_store.dart` — permanent photo storage. Picked photos are
  copied out of the image_picker cache into `<documents>/scans/<uuid>.<ext>`
  and persisted on `Plane.imagePath` as the *relative* token
  (`scans/<uuid>.jpg`), which survives iOS container moves and is portable
  across devices. Anywhere a `File` is built from `plane.imagePath`, wrap it
  in `ImageStore.resolve()` (handles tokens, `assets/` paths, and legacy
  absolute paths).
- `services/firebase_bootstrap.dart` — Firebase init + App Check (debug
  providers in debug builds, Play Integrity/App Attest in release) +
  anonymous sign-in. Exposes `cloudEnabledProvider` (overridden in `main`).
- `services/location_service.dart`, `services/sound_service.dart`.
- `theme/app_themes.dart` — classic and retro `ThemeData`.
- `widgets/dexicon_logo.dart`.

## Naming quirk (intentional — don't "fix")

Everything user-facing says Dexicon and is category-aware, but the internal
`Plane` model, `plane_*.dart` filenames, and the `planes` Hive box are
legacy from the plane-spotting origin. They are invisible to users, and
renaming the Hive box/types requires a data migration — leave them unless
doing that migration deliberately.

## TODO: finish the Dexicon rename

App was renamed Planedex → Dexicon. All code identifiers, copy, display
names, Dart package name, and app/bundle identifiers (now
`com.driftwood.dexicon` on every platform) are done. Orphaning the old
installed version was approved and has happened (new applicationId).

Still remaining:

- [ ] Rename the GitHub repo `planes` → `dexicon` (manual: repo Settings →
      General → Repository name; old URLs auto-redirect)
- [ ] Launcher icons: current icons are still the old Planedex artwork.
      Replace `assets/icon_foreground.png`, `assets/icon_foreground_padded.png`,
      `assets/icon_legacy.png` with new Dexicon art, update
      `flutter_launcher_icons.yaml`, run `dart run flutter_launcher_icons`
- [ ] Play Store: create the new listing under the Driftwood publisher
      account (new app — the old Planedex listing is orphaned by design)
- [ ] Pre-launch cleanup: remove the hardcoded F-35 test-plane injection
      in `lib/main.dart`
