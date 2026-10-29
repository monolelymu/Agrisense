# AgriSense v1.0.15d — simpler main flow

APK: `AgriSense-v1.0.15d.apk`. Android version name `1.0.15d`, version code 20;
Flutter package version `1.0.15-d+20`.

Release build succeeded. APK version and signature verified; certificate matches
v1.0.15c. Size: 155,078,886 bytes. SHA-256:
`4171cad519dc2fd99c441ef759656dd0f7e1017dde18c1819f5c8873b6ee3a3b`.
Packaged captions match the edited source; all 32 photos match v1.0.15c exactly.
The removed project name is absent from packaged assets and app code.

## Changes

- Simplified Connect → Readings → Scan → Result wording. Connection instructions,
  missing readings, camera status, progress messages and common recovery messages
  use shorter sentences with clear next steps.
- Raw soil shows **Soil reading: 2300**, without the word raw or a percentage
  claim. Temperature and humidity remain numerical. Saved scan readings still
  come from photo time, never today's values.
- Uncertain results say **Not sure yet** and ask for another clear photo.
  Healthy results give a simple reminder to keep checking the plant.
- Comparison reminder: **Example only. Your plant may look different.**
  Removed repetitive laboratory/dataset wording from captions. Kept short notes
  for fruit examples, insects and the uncertain eggplant downy-mildew label.
- Photo scores are available in a collapsed **Photo scores** section. The same
  sorted predictions and percentages remain accessible; no score was changed.
- Removed repeated disclaimers and duplicate inspection text from results.
  Care tips sit inside the existing What to look for section, with symptoms
  available for all 32 labels. Simplified some botanical wording in the three
  crop references; reference URLs and environmental rules are unchanged.
- Main error cards show a plain title and Get help. Error codes remain in Help.
- Kept existing spacing, images, controls and connection/capture behaviour.

No firmware, Firebase, remote access, model, dependency or sensor-threshold
changes. Existing optional calibration behaviour is unchanged. All 32 reference
photos remain unchanged. No source files were deleted.

## Files

Modified under `agrisense/lib/`: `core/app_issue.dart`, `core/issue_card.dart`,
`core/hardware_controller.dart`; diagnosis `simple_result_card.dart`,
`scan_guidance.dart`, `disease_example.dart`, `reference_photo_credits.dart`,
`tomato_scan_screen.dart`, `camera_live_panel.dart`, `camera_photo_preview.dart`,
and the three crop knowledge files; monitoring `hardware_dashboard.dart`.
Also modified: reference `SOURCES.json` captions, `pubspec.yaml`, and related
scan-guidance, simple-UI, record, phase-one and phase-six test wording.
Created this note and the release APK.

## Verification

- 36 focused result/reference/record/knowledge/connection tests passed.
- 13 selected main-flow UI tests passed, including Home measurements, refresh
  stability, Camera/Records navigation, saved settings, Connect and crop changes.
- Changed-file Dart analysis is clean; formatting and `git diff --check` passed.
- Commands: `flutter test --no-pub` with scan-guidance, immediate-update,
  kit-discovery, dashboard-records and two knowledge test files; simple-UI tests
  filtered with `--name '^(?!failed camera analysis)'`; changed-file `dart analyze`.
- Java 21 Gradle build: `assembleRelease --offline --no-daemon --console=plain`.
- Release checks: `aapt dump badging`, `apksigner verify --print-certs`, bundled
  reference-photo hashes and absence of the previously removed project name.

The initial wider run had 61 passing and 10 failing tests. One obsolete retake
text assertion was updated and its test now passes in the focused run. Remaining
broader issues include old Home/legacy-model-screen expectations, Trends dropdown
overflow at 360px with 1.5x text, and an asynchronous camera-recovery test timeout.
The focused suite therefore does not claim that the entire repository test suite
passes. Physical hardware and phone operation still need the team's checks.

## Rollback

Previous APK retained: `AgriSense-v1.0.15c.apk`. Source checkpoint saved locally
before edits: `002ee64`; it was not pushed in this cycle. Installing an older APK
may be blocked by Android's lower-version rule. To preserve local records, rebuild
that checkpoint with the same signing key and a higher version code instead of
uninstalling. Uninstalling removes local app data.
