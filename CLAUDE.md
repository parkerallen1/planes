# Claude notes for this repo

- Solo-dev repo: work directly on `main` and push there. No pull requests,
  no feature branches unless explicitly asked.
- Publisher name for app identifiers/store listings: **Driftwood**
  (reverse-domain id: `com.driftwood.dexicon`). Never use `parkerallen`
  in app identifiers.

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

Optional/skip: internal `Plane` model, `plane_*.dart` filenames, and the
`planes` Hive box are invisible to users; renaming the Hive box/types needs
a data migration, so leave them unless doing that migration deliberately.
