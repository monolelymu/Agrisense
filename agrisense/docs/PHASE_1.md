# Phase 1: app usability

The Android app opens the real hardware dashboard. Tomato has on-device photo
analysis; Chili and Eggplant support sensor monitoring but have no bundled models.
This update changes presentation and recovery guidance, not firmware or inference.

## Where things are

- Dashboard: crop selection, latest saved/recent sensor reading, and latest scan.
- Devices: local hardware access, board assignments, connection tests, and the
  **Monitoring & Auto Scan** entry point.
- Monitoring & Auto Scan: phone monitoring switch, notification limits and warning
  photos. Under Advanced, independent board SD capture has its own confirmed
  settings. Phone rules and board rules are deliberately not synchronized.
- History: **Scans**, **Alerts** (warning photos), and **Readings**, filtered by
  crop. All lists show newest first. Alerts without photos are not persisted yet.
- Help icon: offline setup, troubleshooting/error codes, and Replay tutorial.
  The first-launch guide can be skipped and stores its completion on this phone.

## Errors and forms

Error cards show a stable code, plain-language explanation, recovery steps, and
available actions. Raw exceptions and pairing keys are not displayed. The catalog
in `lib/core/app_issue.dart` is also the source for offline troubleshooting.
Device addresses and numerical limit fields validate before submission. Saving
board changes still requires a readback; on an uncertain outcome, reload first.

## Compatibility

Existing scan, reading, assignment, notification and warning-photo storage keys
are retained. This update adds only `tutorial-complete-v1`. Disabled measurement
limits are preserved when saving other settings. Demo resets remain separate.
No packages, permissions, cloud endpoints or background services are added.

Phone monitoring pauses outside the app and during settings or analysis, then
resumes on return if enabled. Warning photos remain snapshots without automatic
diagnosis. Independent SD capture can continue with the app closed; stop it by
connecting and saving Off to the sensor. SD photos are not imported into the app.

## Verification

From the Flutter package: `flutter analyze --no-pub` and `flutter test --no-pub`.
On October 21, 2026, static analysis reported no issues and all 68 Flutter tests
passed. Dashboard and monitoring layouts were also rendered locally for review.
The Android debug APK was assembled with existing dependencies in Gradle offline
mode. Existing Android/Kotlin toolchain deprecation warnings remain.
The tests cover error mapping/privacy, tutorial completion/replay, separated
history, invalid form submissions, responsive controls, and existing monitoring,
pairing, transport and persistence behavior. They use fake boards.

On Android, install over the existing app without clearing data. Verify existing
scans/settings remain, skip/replay the guide, browse all history filters, enter
invalid limits, test an unreachable board, and review Help. Confirm notification
permission/banners, camera capture, monitoring pause/resume, and board settings
readback using the existing physical setup. Hardware checks remain necessary.
