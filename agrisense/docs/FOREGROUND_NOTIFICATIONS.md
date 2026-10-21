# Sensor notifications while the app is open

This feature requires an app update only. It uses ordinary /readings responses;
no new sensor or camera firmware, cloud service, or background phone service is
required. Threshold settings are saved locally per crop and are separate from
automatic camera capture rules saved on the sensor.

## Enable

1. Install the updated APK over your existing app to retain saved scans.
2. Open Devices, select a crop, then Notifications and limits.
3. Enable sensor notifications, select measurements, and enter minimum/maximum
   limits appropriate to your setup. Initial values are sensor bounds, not growing
   recommendations. Soil alerts require calibrated percentage readings.
4. Set how long the measurement must stay outside the range (10–3600 seconds)
   and minimum time between alerts (60–86400 seconds), then Save.
5. Allow Android notifications if prompted. The Send test notification button
   works without hardware after saving enabled settings.
6. Return to Devices, enable local hardware HTTP, assign your sensor, and turn on
   Read sensors every 10 seconds. Keep the app open. Polling stops when leaving
   the app or opening settings/diagnosis, and resumes automatically when you return.
   The ON switch stays on during these pauses. Switching crops switches monitoring
   to the new crop; it waits if that crop has no assigned sensor. Only turning the
   switch off, disabling local HTTP, or closing/restarting the app clears monitoring.

An enabled measurement alerts after fresh readings stay below the minimum or
above the maximum for the duration. Values equal to a boundary are in range.
Repeated cached readings do not advance the check. Missing/invalid measurements,
failed reads, gaps longer than 30 seconds, and stopped polling reset duration.
One notification is sent per measurement's continuous excursion. Recovery
re-arms that measurement, subject to the crop's notification cooldown.

Notification content includes crop, measurement and configured range, and does
not claim a disease diagnosis. Notifications can remain in the notification shade
after the app closes, but no new readings are monitored in the background.
Android settings, channel settings, and Do Not Disturb control banners and sound.
If a notification is blocked, readings are still saved and delivery status is
shown in Devices. Re-enable notifications in Android settings if necessary.

## Optional photo on warning

Assign a camera to the selected crop in Devices. In Notifications and limits,
enable Take a photo on warning and save. A successfully posted sensor warning
then requests one photo from that crop's existing camera `/capture` endpoint.
Test notifications and blocked notifications do not request a photo. Monitoring
must be active with local hardware HTTP enabled; this does not run in background.

Open History and select the crop to view Warning photos. These are snapshots,
without an automatic disease prediction. The app retains the latest 20 photos,
up to 30 MB total, resizing large photos to a maximum side of 1600 pixels.
Camera failures are reported without stopping polling or repeating the warning.
This switch does not change any independent capture rules saved on a board.

## Test without hardware

Save enabled notification rules for a crop and tap Send test notification while
the app is open. Confirm the clearly labeled test notification appears and tapping
it opens AgriSense. Denying permission should keep newly enabled settings unsaved;
ordinary app use and stored results remain available.

## Test with hardware later

Use a harmless test threshold just outside the current measured condition (do not
damage plants to force readings). Start polling and wait the configured duration.
Check that one alert appears, persistent readings do not repeatedly alert, normal
readings re-arm detection, and changing crops does not reuse the old duration.
Minimize the app or stop polling before the duration completes: no alert should
be generated for that interval. Restore intended thresholds after testing.

Implementation uses the Android notification APIs through a Flutter method
channel, with no added dependencies. Automated tests use fake sensors and a fake
notification service; physical permission, banner, sound and tap behavior still
require a phone/emulator test.
