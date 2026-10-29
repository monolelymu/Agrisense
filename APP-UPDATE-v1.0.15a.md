# AgriSense v1.0.15a

User-facing APK: `AgriSense-v1.0.15a.apk`. Android version name `1.0.15a`,
internal version code 17 (higher than the previous build, allowing installation
as an update). Flutter package version: `1.0.15-a+17`.

## Changes in this update cycle

- Added 16 offline reference photos: all 32 current crop/condition labels now
  have a matching example. Existing comparison spacing and fixed Back button
  remain. Added collapsed photo source credits and short captions where needed.
- Show collapsed What to look for for all 32 labels, including uncertain and
  healthy results. Uncertain results still recommend retaking the photo. Healthy
  guidance uses Healthy appearance. Scores and models are unchanged.
- Home shows uncalibrated soil as its actual raw number, rather than Monitoring.
  Calibrated soil remains a percentage; temperature and humidity retain numbers.
- Scan results show the temperature, humidity and soil measurements saved at
  photo time, with units. Missing, invalid, stale, future, wrong-crop and uploaded
  photo context is not presented as usable measurements.
- Quiet background kit discovery keeps the existing connection message while
  searching, avoiding a temporary layout shift. Real connection outcomes still
  update. Sensor polling itself remains once per second without a loading panel.

Connect → Readings → Scan → Result remains unchanged. No dependencies, model
files, firmware or Firebase configuration were changed. FloraScan was untouched.
Older firmware still controls its sampling rate; this app update cannot increase
the board's sampling rate or validate physical sensor/servo/LED behaviour.

## Files

Modified: `pubspec.yaml`, `hardware_controller.dart`, `hardware_dashboard.dart`,
`simple_result_card.dart`, `scan_guidance.dart`, `disease_example.dart`,
`assets/pathology_reference/PROVENANCE.md`, and the scan-guidance, discovery and
simple-UI tests. Created: 16 JPEG assets, `SOURCES.json`,
`reference_photo_credits.dart`, this update note and the release APK.
No source files were deleted.

## Sources and limitations

See `agrisense/assets/pathology_reference/SOURCES.json` for exact photo URLs,
authors, licence statements and file hashes; credits are also visible in-app.
Dataset labels are illustrative, not laboratory confirmation. Eggplant downy
mildew retains its explicit unverified-disease caveat. Spotted wilt uses a clearly
captioned tomato fruit example. Original rights for the existing FloraScan
photos and the standalone Tomato-Village nitrogen image are not established;
this update does not claim permission for broader/commercial redistribution.

## Verification

Result: 28 distinct targeted tests passed (plus the updated long-credit sheet
test passed again); changed-file Dart analysis and `git diff --check` passed.
Release build succeeded with Java 21. APK metadata confirms `1.0.15a` / 17,
and its signing certificate matches `AgriSense-v1.0.15.apk`. All 32 photo bytes
inside the APK match `SOURCES.json`; `google-services.json` is not bundled.

APK size: 155,079,194 bytes. SHA-256:
`b1e88e40b5f0813b8a4ae7a77687ed5a9aecd9f2f25c65d1a62c95b42eaf50e5`.

- `flutter test --no-pub test/scan_guidance_test.dart test/immediate_update_test.dart test/kit_discovery_test.dart`
- Selected `simple_ui_test.dart` tests: background refresh layout/navigation and
  numerical Home readings at enlarged text.
- Dart analysis of changed application files and tests; `git diff --check`.
- Verified all 32 JPEGs decode and match their provenance SHA-256 values.
- Release build uses `flutter build apk --release --no-pub --build-name=1.0.15a
  --build-number=17` to prepare metadata, then Java 21 Gradle
  `assembleRelease --offline --no-daemon --console=plain` if Flutter's selected
  Java runtime stalls. Validate APK version and signing certificate after build.

Hardware checks remain with the team. Screen stability has automated coverage;
physical-phone behaviour has not been claimed as tested.

## Rollback

Keep `AgriSense-v1.0.15.apk` and the existing firmware. The pushed Git checkpoint
`pre-firebase-v1.0.15` (`1e82d00016ed1e348e49bd5d7b60a0ea103ce19f`) preserves the
previous source. Do not reset or overwrite unrelated local work.
Android may reject installation of the older APK over version code 17. Back up
records before any uninstall; uninstalling removes local app history. To preserve
app data, build the checkpoint with the same signing key and a higher version
code instead of uninstalling.
