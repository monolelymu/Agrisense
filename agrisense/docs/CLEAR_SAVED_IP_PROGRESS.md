# Clear saved IP — 23 October 2026

## Behavior
Devices → edit Sensor node or Camera node → **Clear saved IP**. The action
removes only that crop/device's saved endpoint on this phone. It performs no
board requests, needs no pairing-code validation, and works with local HTTP off
or an unreachable old IP. Leaving the address blank and applying uses the same
local clearing path. Cancel does not clear it.

The saved sensor identity, pairing code, readings, photos, alerts, scans and other
crop/device addresses remain. Clearing does not stop independent automatic
capture on a board. This limitation is shown in the dialog and success message.
Clearing is not a factory reset or a board command.

Persistence is written before the in-memory mapping changes. A failed storage
write retains the old mapping. Successful clearing removes the stored address
key and reloads as Not assigned. Sensor alert-duration tracking is reset and
the previous connection error is cleared. Pairing the same sensor at a new IP
can reuse the saved code after identity verification; a replacement needs its
own supplied code. An explicitly cleared endpoint is never contacted as an
empty address during later camera or replacement assignments.

## Changed/created files
Modified:
- lib/core/hardware_controller.dart
- lib/features/monitoring/hardware_dashboard.dart
- test/sensor_assignment_test.dart

Created: docs/CLEAR_SAVED_IP_PROGRESS.md. No files deleted or dependencies changed.
Earlier Chili and IP-recovery changes remain in this checkout. Camera firmware
source changes are separate and are not flashed or distributed by an app APK.
Training notebooks, model assets and storage schemas are unchanged.

## Verification
- Existing Dart SDK formatting on changed Dart files.
- Focused sensor assignment/automatic capture tests. A UI finder initially
  matched an additional existing warning; corrected it. Disk persistence is
  tested with the real controller; UI dispatch uses the existing controller
  stub pattern rather than waiting for filesystem IO in Flutter's fake clock.
- First full suite: 160 tests pass. Added the explicit-clear/replacement edge
  case afterward; final full regression and analysis results recorded below.
- New coverage: offline clear of both addresses, pairing/history preservation,
  persistence on reload, camera assignment while no sensor IP is saved, re-adding
  the same sensor, replacement code requirement, storage failure, and clear UI
  bypassing invalid IP/code fields at a 360-pixel phone width.

## Delivery checkpoint
- Final `flutter --suppress-analytics --no-version-check test --no-pub
  --reporter expanded`: all 161 tests pass (58 seconds). Log:
  `.dart_tool/clear-ip-regression-final.log`.
- Final `flutter --suppress-analytics --no-version-check analyze --no-pub`:
  no issues (12.6 seconds). Log: `.dart_tool/clear-ip-analyze-final.log`.
- `git diff --check` passes (Git line-ending notices only).
- Offline review APK build succeeded using the existing Android Studio JBR:
  `gradlew.bat --offline --no-daemon :app:assembleDebug --console=plain`.
  Log: `.dart_tool/clear-ip-build.log`. Build completed in 1m 23s; existing
  Gradle/Kotlin deprecation warnings retained.
- APK: `build/review/agrisense-clear-ip-debug-b2edf9a7d7c1.apk`.
  SHA-256: `b2edf9a7d7c1af694c69e8b0799a5c6a6616c45dfafa3343adee638effe31441`.
  Size: 216,705,333 bytes. Previous versioned review APKs preserved.
- Verified the packaged kernel contains the clear action and controller method;
  all four model/label assets match source hashes, and the review copy hash
  matches the build output. No Android installation performed.

No installation, app-data clearing, physical board commands, remote push or
dependency installation performed by this task. Physical phone acceptance
is still required. Test doubles were used for all board operations.
