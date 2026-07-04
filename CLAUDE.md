# Claude notes for this repo

- Solo-dev repo: work directly on `main` and push there. No pull requests,
  no feature branches unless explicitly asked.

## TODO: finish the Dexicon rename

The app was renamed Planedex → Dexicon (display names, code identifiers,
copy, README, Dart package). The remaining naming work below is approved —
orphaning the old installed version is explicitly OK. Blocked on one input:

**NEEDED FROM PARKER: the publisher name he releases apps under** (he does
not want `parkerallen` in identifiers). Once known, use reverse-domain form
`com.<publisher>.dexicon` everywhere below.

- [ ] Rename the GitHub repo `planes` → `dexicon` (manual: repo Settings →
      General → Repository name; old URLs auto-redirect)
- [ ] Android app identity: `applicationId` and `namespace` in
      `android/app/build.gradle.kts` → `com.<publisher>.dexicon`; move
      `MainActivity.kt` from `kotlin/com/parkerallen/plane_tracker/` to the
      matching new package path and update its `package` line. This makes it
      a brand-new app on the Play Store (intended).
- [ ] iOS/macOS bundle identifiers: `PRODUCT_BUNDLE_IDENTIFIER`
      (`com.parkerallen.planeTracker`) in `ios/Runner.xcodeproj/project.pbxproj`
      (app + RunnerTests), `macos/Runner/Configs/AppInfo.xcconfig`, and
      macOS RunnerTests entries → `com.<publisher>.dexicon`
- [ ] Linux: `APPLICATION_ID` and `BINARY_NAME` in `linux/CMakeLists.txt`
      (`com.parkerallen.plane_tracker` / `plane_tracker` → new id / `dexicon`)
- [ ] Windows: `project()`/`BINARY_NAME` in `windows/CMakeLists.txt` and the
      `plane_tracker` strings in `windows/runner/Runner.rc` (FileDescription,
      InternalName, OriginalFilename, ProductName) → `dexicon`/`Dexicon`
- [ ] macOS Xcode leftovers: `plane_tracker.app` references in
      `macos/Runner.xcodeproj/` (pbxproj + xcscheme) → `dexicon.app`
- [ ] Launcher icons: current icons are still the old Planedex artwork.
      Replace `assets/icon_foreground.png`, `assets/icon_foreground_padded.png`,
      `assets/icon_legacy.png` with new Dexicon art, update
      `flutter_launcher_icons.yaml`, run `dart run flutter_launcher_icons`
- [ ] Play Store: create the new listing under the publisher account/name
- [ ] Pre-launch cleanup while at it: remove the hardcoded F-35 test-plane
      injection in `lib/main.dart`

Optional/skip: internal `Plane` model, `plane_*.dart` filenames, and the
`planes` Hive box are invisible to users; renaming the Hive box/types needs
a data migration, so leave them unless doing that migration deliberately.
