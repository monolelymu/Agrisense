# Phase 2 acceptance checks

Run these on a real Android phone with the sensor and camera paired to the same
trusted Wi-Fi. Use the existing firmware and installed Tomato model. Record the
phone/Android version, duration, outcome and any issue code. Emulator evidence is
listed in PHASE_2_PROGRESS.md; it does not establish physical reliability.

API 36 emulator checks passed for automatic capture with the real Tomato model,
linked repeat alerts, notification Stop, force-stop/reopen with monitoring Off,
and two saved diagnoses surviving reopening. Earlier checks verified minimized
and screen-locked polling and reuse of the same process when reopening.

## Phone and board checks (pending)

1. Confirm existing settings and history survive installing the updated APK.
   Automatic analysis and background operation must remain Off unless enabled.
2. Read a fresh sample, apply Sensitive and review its proposed limits. Confirm
   soil is disabled when uncalibrated. Save; subsequent readings must not move
   those limits. A small change inside the band must not trigger an alert.
3. Enable warning photos and automatic analysis for Tomato. Keep one reading
   outside the band for at least 10 seconds. Check History > Alerts for the
   captured original and linked diagnosis; check Scans and Dashboard for the
   same result. Repeat after the 30-second cooldown and check for duplicates.
4. Enable Continue in background and start monitoring while visible. Minimize,
   then lock the phone for at least 30 minutes. Trigger a real sensor change.
   Confirm readings, captures and analysis continue, and note delayed checks,
   battery use, thermal changes or Wi-Fi disconnections. Exact timing depends
   on Android/device restrictions.
5. Open the ongoing notification, then use Stop. Confirm readings and camera
   captures stop, the ongoing notification disappears and reopening keeps
   monitoring Off. Starting again should create one monitoring session.
6. Force-stop the app, reopen and confirm monitoring stays Off. Reboot the phone
   and confirm there is no automatic monitoring restart. Start it manually.
7. Deny notification permission while keeping monitoring/capture/analysis on.
   Trigger an alert and confirm the photo and diagnosis are still saved.
8. Disconnect the camera and trigger an alert. Confirm Capture failed is saved.
   Restore the camera, choose Retry capture and confirm one linked result.
   Disconnect Wi-Fi and verify bounded requests and actionable connection errors.
9. Switch to Chili/Eggplant and confirm monitoring and warning photos work,
   automatic disease analysis is unavailable and crop histories stay separate.
10. Return to Standard and confirm a sustained excursion creates one alert until
    that measurement recovers. Confirm editing timing/limits selects Custom.

For interrupted inference/storage, deterministic tests exercise reconciliation,
manual recovery and stable IDs. Do not deliberately exhaust phone storage or
modify private app data on a user's device to reproduce storage failures.

## Acceptance record

Physical checks above: **pending**. Record failures with the step number, observed
behavior, issue code and whether an alert, photo and diagnosis were saved.
