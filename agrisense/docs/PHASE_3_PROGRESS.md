# Phase 3 progress

## Scope and defaults

Tomato only: growing-condition references and offline explanations for all 17
installed labels. Keep image scores/ranking, Phase 2 monitoring and native service
unchanged. Mixed/undecided growing setup; established plants. Day reference is
06:00–18:00 phone local time (assumed), 21–29 C; night 18–21 C. RH 65–75% is a
protected-growing reference only. No universal soil percentage or gas assessment.
No dependencies, firmware changes, emulator or simulator. Local commits; no push.

## Checkpoints

- A reference data: complete; 17 sourced entries and research table saved.
- B assessment and persistence: complete; focused assessment + auto-diagnosis
  tests report 19 passed.
- C Dashboard/shared result UI: complete; 7 focused widget tests passed.
- D complete: all 106 Flutter tests passed; static analysis clean; final offline
  debug APK build passed (exit 0).

## Decisions

- Reuse existing readings; no new poller or retention changes.
- Preserve source conditions/limitations, not invented probabilities. Rules that
  need leaf wetness cannot establish exposure from air humidity.
- Bundle typed Dart reference data, with offline text and copyable HTTPS sources;
  no new asset loader or URL-launch dependency.
- Old scans remain readable; new assessments are optional versioned snapshots.
- Automatic context is the trigger sample. Manual camera context uses the latest
  preceding same-crop/current-device reading within 30 seconds. Uploads have none.
- Exposure requires same crop/device, unique IDs, and no gap over 30 seconds.
- Late blight uses a time-weighted average temperature over the 10-hour window,
  with RH continuously above 90%; it does not require every temperature in-band.
- Source actions copy the HTTPS link; text stays available offline, with no new
  URL-launch dependency or automatic external requests.

## Validation policy and recovery

Run only focused tests at checkpoints A/B/C. Run full Flutter tests once, final
analysis and one offline debug APK build at D. Repeat only for failures or changes
that affect a check. Update this file before the build and after each checkpoint.
Physical acceptance stays pending with Phase 2. Do not stage unrelated untracked
C++ tests or deliverables. Checkpoint A: focused knowledge test reports 2 passed
(`flutter test --no-pub test/tomato_knowledge_test.dart --reporter expanded`).
No dependencies installed or network sources contacted during implementation.

Checkpoint B command: `flutter test --no-pub test/tomato_assessment_test.dart
test/automatic_diagnosis_test.dart --reporter expanded` (19 passed).

Checkpoint C: `flutter test --no-pub test/tomato_context_widgets_test.dart
--reporter expanded` (7 passed). Initial grouped UI/scan test run stalled on the
new Dashboard test's temporary Hive setup inside fake time. Stopped that run,
moved the setup/cleanup into `tester.runAsync`, and reran focused widgets; passed.
Layout at 320 px with enlarged text, source copying, saved context, expiry and
Tomato-only behavior are verified without an emulator.

Implementation checkpoints: 1abd7e4 (A), 9b6468c (B), 8b94371 (C).
Final analysis initially flagged one redundant test import; removed it and reran
analysis successfully. The full suite then ran once: `flutter test --no-pub
--reporter expanded` reports 106 passed (about 13 s test time). No emulator used.
Tomato model SHA256 remains
`EF87A0106A2950B4926BF7BB0DE4E1EDDF1600FD6AAC972C8B12358A91B11665`.
`git diff --check` passes. No dependencies, model or firmware changes.

Final build: `gradlew --offline --no-daemon :app:assembleDebug --quiet` passed,
exit 0. APK: `build/app/outputs/apk/debug/app-debug.apk`. Existing Java native-access
warnings did not prevent the build. One APK build; no emulator/simulator started.
No dependencies installed, native service changes, remote push or new services.

Exact next action: install the APK on the physical phone and follow PHASE_3.md
alongside PHASE_2_ACCEPTANCE.md. Verify representative sensor placement, calibration,
local growing references, Dashboard expiry and saved automatic/manual context.
Physical phone/board and local horticultural acceptance remain pending. Later
Chili/Eggplant work needs model integration, class-specific references and crop
validation; their current monitoring features are unchanged.
