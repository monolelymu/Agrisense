# AgriSense v1.0.15b — local soil percentage

APK: `AgriSense-v1.0.15b.apk`. Android version name `1.0.15b`, version code 18;
Flutter package version `1.0.15-b+18`. Signing certificate matches v1.0.15a.

APK size: 155,144,730 bytes. SHA-256:
`06f28447fa95d7c04a442f887d66c3d1119675b606b4d00e0cbcd36ea0efe419`.

## Use it

1. Connect the kit with the existing firmware. Before saving references, Home
   shows the soil sensor's raw reading without an uncalibrated label.
2. Note a steady reading with the probe in dry soil, then a steady reading in
   thoroughly wet soil. Keep the probe electronics dry.
3. Open Settings → Device setup → Soil percentage, enter those two raw numbers,
   and choose Save percentage. Return the probe to the soil being monitored.

Dry is 0%, wet is 100%. Either ADC direction is supported. Values outside those
references display as 0% or 100%. This is relative moisture, not volumetric water
content. Do not use invented reference numbers. On each phone, save its references
once; reset them if the probe is replaced. Use raw readings instead clears the
phone's references and allows measuring new endpoints from Home.

## Changes and boundaries

- Same Home soil card and spacing, showing the converted percentage once saved.
  Temperature and humidity remain numerical. Without references, soil stays raw.
- Simple two-field setup inside Device setup, with validation for distinct whole
  numbers in the existing 0–4095 ADC range and readable save failures.
- References persist on this phone per sensor identity. Legacy sensors without
  identity use their saved local address; reset references if that address is
  reused for different hardware. A known mismatched identity is not converted.
- Native board-calibrated percentages take precedence over phone conversion.
- New camera scans freeze the local reference values with their sensor context,
  so saved percentages do not change when references are edited or cleared.
- Display conversion only: sensor alert thresholds, board warning configuration,
  trends' original stored units, model inputs, scores and sensor assessment logic
  are unchanged. The percentage does not claim to confirm disease.

No firmware, Firebase, remote-control, model or dependency changes. the contributing project
was untouched. No source files were deleted.

## Files

Created: `agrisense/lib/data/soil_calibration.dart`,
`agrisense/lib/features/monitoring/soil_calibration_screen.dart`,
`agrisense/test/soil_calibration_test.dart`, this note and the APK.

Modified: `agrisense/lib/core/hardware_controller.dart`,
`agrisense/lib/features/monitoring/hardware_dashboard.dart`,
`agrisense/lib/features/diagnosis/scan_guidance.dart`, `agrisense/pubspec.yaml`,
and the immediate-update, scan-guidance and simple-UI tests.

## Verification and commands

- 23 targeted tests passed: endpoints, reversed ADC direction, clamping, invalid
  values, persistence, different-kit isolation, native board percentage priority,
  frozen scan percentages, original sensor-rule preservation, setup validation
  at 320px/enlarged text, Home percentage/numerical readings and refresh layout.
- `flutter test --no-pub test/soil_calibration_test.dart test/immediate_update_test.dart test/scan_guidance_test.dart`
- Two selected `simple_ui_test.dart` tests: background sensor refresh and Home
  numerical readings switching from raw to percent.
- Changed-file `dart analyze`, `dart format`, and `git diff --check`.
- Updated ignored Android `local.properties` version metadata; built with Java 21
  using `gradlew.bat assembleRelease --offline --no-daemon --console=plain`.
- `aapt dump badging` confirms version; `apksigner verify --print-certs` confirms
  the APK signature and certificate match with v1.0.15a.

The team must supply and check actual sensor references. No physical calibration
accuracy or hardware behaviour has been validated here.

## Rollback

Previous APK retained: `AgriSense-v1.0.15a.apk`. Previous source preserved in local
commit `4a100d2` before these edits; that checkpoint was not pushed in this cycle.
Android may refuse a lower version-code APK as an update. Preserve local records
by rebuilding the checkpoint with the same signing key and a higher version code;
uninstalling instead removes local app data.
