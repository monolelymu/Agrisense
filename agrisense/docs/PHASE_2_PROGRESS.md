# Phase 2 progress

## Approved scope and decisions

- A: persistent alerts and Standard/Sensitive/Custom phone presets.
- B: opt-in automatic Tomato diagnosis, linked results, manual stage retries.
- C: explicitly enabled Android connected-device foreground service, one shared
  Flutter engine/controller/Hive owner, ongoing Open/Stop notification.
- D: regression/static checks, APK, emulator lifecycle verification; physical
  camera/phone acceptance remains pending until hardware is available.
- Sensitive: fresh baseline +/-1 C and +/-5 percentage points humidity/calibrated
  soil, fixed limits, duration 10 s, repeat cooldown 30 s. Poll every 10 s.
- Existing settings become Custom. Auto-analysis and background operation default
  Off. Notifications do not gate capture/inference. No firmware/model changes.
- Keep 500 alerts and 20 original warning photos / 30 MB. Old data stays readable.
- No new dependencies planned. Local checkpoint commits only; do not push.

## Status

- Starting from dd89a3d (Phase 1), 68 tests previously passed.
- A: complete, including preset controls and backward-compatible storage.
- B: complete; 29 targeted tests passed (automatic diagnosis + notifications +
  alert/preset storage), followed by full regression and emulator checks below.
- C: native build passes offline; five fake-service tests pass. Actual emulator
  service starts on API 36 as connectedDevice, with Open/Stop notification actions.
  Loopback readings continued from count 4 to 8 while minimized/screen-locked;
  reopening retained the same app process (one data owner). Notification Stop,
  force-stop/reopen and actual automatic-model checks now pass (see below).
- D: all 86 Flutter regression tests pass; final static analysis reports no
  issues. Updated APK installs and launches on the API 36 read-only emulator.
  Synthetic loopback boards pair successfully. Sensitive preset UI verified.
  Sensitive preview correctly showed 34..36 C and 85..95% from baseline 35/90;
  uncalibrated soil remained disabled. Editing revealed a focus-loss bug when the
  baseline label disappeared. Fixed it; new preset_editing_test passes.
- Latest focused checks: 13 tests passed, including original-photo retention,
  linked diagnosis retention, stable IDs, and complete numeric preset editing.
- Battery checkpoint: emulator and loopback fixture server stopped explicitly.
  Source changes are saved. No dependencies installed or remote push performed.
- Unrelated untracked deliverables and C++ firmware test must remain untouched.

## Implementation shape

Use a persistent alert store with stable event/result IDs and saved stage states.
Keep notification photos backward compatible, adding an optional event ID and
capture time. Use the existing classifier with injected fake inference for tests.
Activity and Android service share one cached Flutter engine and app data owner;
notification delivery must not require an Activity. No automatic boot/restart.

## Checks and next action

Checkpoint A: 21 tests passed (monitoring_alert_test + sensor_notifications_test).
Migration, baseline clamping/freshness, repeat cooldown and 500-record retention
are covered. No dependencies installed.

Implementation checkpoints: 5bbe820 (A domain/storage), 6877cca (B/C implementation
and focused verification). Final checks: `flutter analyze --no-pub` clean;
`flutter test --no-pub --reporter expanded` reports 86 passed. An initial lint for
missing braces was corrected and analysis rerun successfully. The test emulator
and loopback fixture are stopped. User guide: PHASE_2.md.
Final `gradlew --offline --no-daemon :app:assembleDebug --quiet` completed with
exit 0. APK: `build/app/outputs/apk/debug/app-debug.apk`. Existing Java native
access warnings did not prevent the build. No dependencies downloaded.

## Resumed emulator acceptance (2026-10-21)

- Used the saved APK on API 36, a temporary read-only emulator, and loopback-only
  fake boards. No production board, firmware or dependency changes.
- Configured the real app through Devices and Monitoring & Auto Scan. Sensitive
  fixed limits were 34..36 C and 85..95% from baseline 35 C / 90% RH; soil disabled.
- Enabled capture, analysis and background operation. Changed fixture readings
  to 37 C / 96% RH and minimized/locked the emulator. The real installed Tomato
  TFLite model processed the captured synthetic JPEG and saved an Auto Scan.
  Synthetic solid-color input scored 16.3%, correctly shown as Uncertain. This
  verifies the pipeline, not disease accuracy.
- A second sustained alert after repeat cooldown produced a second linked result.
  History > Alerts showed both measurements combined into each Diagnosis saved
  event. Scans displayed the automatic result. Returned fixture to baseline.
- Expanded the actual ongoing notification and pressed Stop. The notification
  disappeared, the native monitoring service ended and Devices showed Monitoring
  off. Simulator readings stopped at 12, captures at 2.
- Started a new monitoring session, force-stopped the app, then reopened it.
  Devices retained assignments and showed Monitoring off; no MonitoringService
  was running. History still showed exactly two saved automatic diagnoses after
  reopening, confirming persistence without duplicate results.
- Full suite/build were not rerun: this continuation changed documentation and
  ignored test fixtures only. The existing 86 passing tests, clean analysis and
  offline APK build remain applicable. Test processes stopped after checks.

Next: perform physical phone/board screen-lock, Wi-Fi/camera and sustained
operation checks using PHASE_2_ACCEPTANCE.md. Also verify notification Open and
reboot behavior on the physical phone. Physical acceptance is pending, not claimed
complete. No new dependencies or firmware changes. Test helpers/logs are ignored in
`.tools/phase2_*` and `.tools/phase2-*`; do not commit them or deliverables.
