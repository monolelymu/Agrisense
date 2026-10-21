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
- B/C/D: pending.
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

Next: connect alert persistence and classifier to the controller; add linked
records, manual recovery, notification-independent capture and preset/settings UI.
