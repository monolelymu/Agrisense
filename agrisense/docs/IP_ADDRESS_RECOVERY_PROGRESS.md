# Saved IP address recovery — 23 October 2026

## Report and cause
User reports NET-001 when changing either sensor or camera IP in the 22 October
16:30 review build. NET-001 means a device request failed; the physical network
has not been independently tested. A reproducible controller defect explains
this symptom: address changes contact the saved sensor endpoint to stop board
automation before persisting a mapping. After a DHCP move, that endpoint is
unreachable. Blank sensor codes were also looked up only by endpoint.

## Fix and use
- For the same sensor at a new IP, read configuration at the new address first.
  Reuse the selected crop's saved code only after the saved device ID matches;
  never send that code to a different identity.
- Verify automation is off using the matched sensor's new endpoint, then apply
  and read back its crop before saving. Failed requests/readback preserve the
  old local mapping. Different replacement boards retain the old-board stop gate.
- Update the sensor address for its existing crop first, then update the camera.
  The assignment dialog explains both steps. No app-data clearing is needed.
- This does not make an offline new endpoint reachable, bypass pairing, or allow
  changing cameras while the associated sensor cannot confirm automation is off.

## Files changed for this fix
- lib/core/hardware_controller.dart
- lib/features/monitoring/hardware_dashboard.dart
- test/sensor_assignment_test.dart
- docs/IP_ADDRESS_RECOVERY_PROGRESS.md (new)

Earlier Chili changes remain in the working tree and will be included in the
review APK. No files deleted, dependencies installed, models changed, training
notebooks edited, migrations, installation or remote push performed.

## Verification checkpoint
- `dart format` on the three affected Dart files.
- Focused `flutter --suppress-analytics --no-version-check test --no-pub
  test/sensor_assignment_test.dart test/automatic_capture_test.dart
  --reporter expanded`: 20 tests pass.
- Four new tests: offline old-IP recovery plus camera move and persistence;
  different identity receives no saved code; wrong automation identity or failed
  stop is rejected; replacement/camera moves retain old-board checks.
- Full regression and static analysis running; results/build recorded below
  after completion. Existing SDK used with approved external-tool access.
- `git diff --check` passes; only Git line-ending notices.

## Remaining acceptance
Physical phone/boards and actual DHCP/network recovery remain to be tested.
Chili inference stays unavailable; no model training or inference change here.
