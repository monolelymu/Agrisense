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
- A domain/storage: complete; preset controls will be connected alongside B UI.
- B: implemented; 29 targeted tests pass (automatic diagnosis + notifications +
  alert/preset storage). Full regression and UI checks remain in D.
- C: native build passes offline; five fake-service tests pass. Actual emulator
  service starts on API 36 as connectedDevice, with Open/Stop notification actions.
  Loopback readings continued from count 4 to 8 while minimized/screen-locked;
  reopening retained the same app process (one data owner). Stop/force-stop checks
  and actual automatic-model result still pending.
- D: all 85 Flutter regression tests pass; analysis clean before final docs/guard
  changes. Updated APK installs and launches on the API 36 read-only emulator.
  Synthetic loopback boards pair successfully. Sensitive preset UI under test.
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

Next: run final analysis/full suite and offline APK build, then save validation
results in a local commit. Remaining acceptance: notification Stop action,
force-stop/reopen behavior, actual automatic TFLite result through the full
emulator workflow, and physical phone/board screen-lock, Wi-Fi/camera and sustained
operation. These checks are pending, not claimed complete. No new dependencies or
firmware changes. Test helpers/logs are ignored in
`.tools/phase2_*` and `.tools/phase2-*`; do not commit them or deliverables.
