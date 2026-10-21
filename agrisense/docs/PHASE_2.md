# Phase 2 app guide

## Start monitoring

Pair the sensor and camera in Devices and enable local hardware access. Open
Monitoring & Auto Scan for the selected crop, then Sensor limits & warning photos.
Enable alerts and choose whether to show notifications, save warning photos and
analyze photos automatically. Automatic analysis defaults to Off and currently
supports Tomato. Chili and Eggplant can record alerts and warning photos.

Choose Standard for your configured limits with a 30-second duration and
300-second cooldown; each measurement must recover before another alert.
Sensitive reads a fresh baseline and proposes fixed limits of +/-1 degree C and
+/-5 percentage points humidity and calibrated soil moisture. Review the limits
before saving. It uses a 10-second duration and 30-second repeat cooldown.
Unavailable measurements stay disabled; soil requires calibration. Gas does not
trigger alerts. Editing limits or timing switches the preset to Custom.

Start monitoring from the Dashboard. Readings are checked every 10 seconds.
Cached or invalid readings cannot satisfy the duration. Simultaneous triggers
share one alert and photo. Failed captures also consume the cooldown.

## Review and recover

History > Alerts includes every accepted alert, including failures and alerts
without photos. Open an alert to review its readings, limits and outcome. A
successful automatic Tomato analysis appears under Scans and links back to its
alert. Notification permission does not control capture or analysis.

Failed stages offer Retry capture, Retry analysis or Retry saving. Interrupted
operations require manual recovery. Stable IDs prevent duplicate diagnoses.
The app retains 500 recent alerts and up to 20 warning-photo originals / 30 MB.
Expired originals are identified; saved diagnoses keep their usual history.

## Continue with the screen locked

Enable Continue in background, then start monitoring while the app is visible.
Android shows an ongoing monitoring notification with Open and Stop actions.
The same monitoring owner continues when the UI is detached. Stop ends phone
monitoring. Reboot, force-stop or process termination also ends it; start again
manually. Device power management can delay checks.

Advanced independent SD capture remains a separate existing board feature. Its
photos stay on the camera SD card and do not receive app diagnosis automatically.

## Acceptance status

No firmware, models or dependencies were changed. See PHASE_2_PROGRESS.md for
automated checks and emulator evidence. Automatic TFLite diagnosis, notification
Stop and force-stop/reopen checks passed on the API 36 emulator. Sustained physical
phone/board acceptance remains pending; follow PHASE_2_ACCEPTANCE.md on hardware.
