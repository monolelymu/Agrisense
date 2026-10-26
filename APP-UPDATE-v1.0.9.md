# AgriSense v1.0.9 — app-only update

Branch: `v2-ui-simple`. Pre-update checkpoint: `1235db1`.
Install `AgriSense-v1.0.9.apk` over the existing app. Do not uninstall or clear data.

## Changes

- Bell on the left of Home, Camera and Records opens a shared, newest-first Alerts page.
- Sensor warnings, scheduled photos and watering reminders have distinct titles/times.
  New notification taps carry a saved record target, including when starting the app.
  Notifications created by older APKs cannot acquire a target retroactively.
- Home has one daily watering reminder with Edit, Off and Clear. No time is enabled
  silently. It does not require Wi-Fi, boards or the monitoring foreground service.
- Native Android alarms store the schedule and delivery receipts, restore future
  reminders after reboot/time-zone changes, and prevent duplicate daily events.
  Precise delivery needs Android Alarms & reminders access on applicable versions;
  the card explains possible delays and offers a direct permission action.
- New/unconfigured sensor warnings initialize from fresh readings automatically:
  temperature +/-1 C, humidity +/-5 percentage points, soil +/-150 raw units internally;
  a change must persist 10 seconds. Cooldown is 60 seconds. Saved custom/off settings
  and older percentage-based soil rules keep their meaning. Missing readings wait.
  Raw soil sensitivity is editable using simple named choices, without fake percentages.
- Settings and the main Camera page use the same last valid original image and
  capture timestamp. Refresh/connection tests update that shared preview. Failed
  capture, camera unavailable, timeout and an unreachable board have separate messages.
  This does not establish that the physical OV2640 image-quality issue is resolved.

## Phone checks still required

1. Install the APK and open Alerts using the bell from all three tabs.
2. On Home, set Watering reminder a few minutes ahead. Allow notifications and
   use Allow precise reminders if shown. Turn monitoring off; no board is needed.
3. Lock the phone. Confirm one notification at the chosen time. Tap it and check
   it opens the matching reminder; Back returns through Alerts into the main app.
4. Repeat with the app removed from Recents. Do not use Android Force stop.
   Check editing/clearing cancels the previous time. A past selected time means tomorrow.
5. Reopen the app and confirm the time persists and no duplicate reminder appears.
   Verify a reboot restores a future reminder, without replaying missed reminders.
6. With the kit, compare Settings Test camera connection and main Camera preview:
   same image/time, then Refresh photo. Test temporary connection loss and recovery.
7. Confirm sensor warnings initialize on connection, react to sustained changes,
   and open the matching sensor alert; verify one scheduled photo event/result.

Android notification permissions, precise-alarm permission, manufacturer battery
restrictions, and Force stop affect delivery. These require physical phone checks;
automated tests and an APK build alone do not confirm locked-screen operation.

## Engineering verification and files

Focused `flutter test --no-pub` suite: 89 passing tests across app_alerts,
sensor_notifications, monitoring_alert, simple_ui, preset_editing, daily_monitoring,
background_monitoring, kit_discovery, automatic_diagnosis and dashboard_records.
Static check: `flutter analyze --no-pub`.
Build: `flutter build apk --release --no-pub --build-name=1.0.9 --build-number=10`.
No emulator, new dependency, firmware change or model-training change.

New source: Android `AppAlerts.kt`; Dart `app_alerts_bridge.dart`,
`app_alert_event.dart`, `app_alerts_screen.dart`, `watering_reminder_card.dart`,
`camera_photo_preview.dart`; tests `app_alerts_test.dart`.
Updated source: Android manifest, Application and MainActivity; Dart startup,
hardware controller, sensor warnings, alert descriptions, camera/dashboard/alert
settings screens and camera issue messages. Focused existing tests were updated
for the new defaults/messages; their temporary data stays inside the workspace.
No source files deleted. Existing records and model assets are preserved.
