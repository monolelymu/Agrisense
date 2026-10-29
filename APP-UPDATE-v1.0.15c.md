# AgriSense v1.0.15c

Android version name `1.0.15c`, version code 19. Flutter package version
`1.0.15-c+19`. APK: `AgriSense-v1.0.15c.apk`.

- Removed Photo source from the comparison sheet and removed the contributing
  project's name and credit from the app and bundled reference metadata.
- Photos are unchanged. All 32 examples, useful captions, existing padding and
  Back to result remain. Required third-party attribution is accessible under
  Help & troubleshooting → Image licenses, outside the scan flow.
- No firmware, Firebase, remote-control, model, sensor, calibration or dependency
  changes in this update.

Modified files: `pubspec.yaml`, `disease_example.dart`,
`reference_photo_credits.dart`, `help_screen.dart`, `scan_guidance_test.dart`,
reference `SOURCES.json` and `PROVENANCE.md`, and the preceding two release notes
to remove the project name. Created this note and release APK. No files deleted.

Checks: scan-guidance tests, changed-file Dart analysis, formatting and
`git diff --check`; source and packaged-asset searches for the removed project
name; APK version/signature verification; all 32 photo hashes checked against
the previous release. Build uses Java 21 and the existing Gradle wrapper:
`assembleRelease --offline --no-daemon --console=plain`.

All 10 scan-guidance tests passed; changed-file analysis and whitespace checks
are clean. All 32 local JPEGs were verified byte-for-byte against v1.0.15b.
Release build succeeded. APK metadata confirms `1.0.15c` / 19 and its signing
certificate matches the previous release. Packaged assets and app code contain
no removed project-name references; all 32 bundled photos match v1.0.15b.
APK size: 155,144,534 bytes. SHA-256:
`1d960cfd7036dad203268a1ab5f25b78fdfec7882ebe87bf44431fabe13dfc55`.

Rollback: previous `AgriSense-v1.0.15b.apk` retained; source checkpoint saved
locally as `7091a48` before edits. That checkpoint was not pushed in this cycle.
Android may reject installing an older version code over the update. Preserve
records by rebuilding the checkpoint with the same signing key and a higher
version code; uninstalling instead removes local app records.

No physical hardware testing is claimed. Previous image-label and source-rights
limitations remain; this is a UI/credit cleanup, not image verification.
