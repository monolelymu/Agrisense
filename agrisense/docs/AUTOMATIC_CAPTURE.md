# Automatic photos from sensor alerts

## Set up once

1. Upload the updated **sensor_node_full** folder to the sensor board and the
   updated **CameraWebServer** folder to the AI Thinker ESP32-CAM. Keep all headers
   with each sketch. Use your existing board/library settings and Wi-Fi credentials.
   The shared camera sketch uses placeholder Wi-Fi credentials; enter yours there.
   For sensors copy secrets.h.example to secrets.h and enter Wi-Fi details.
2. Insert the camera's FAT32 microSD card while powered off, then power on both
   boards on the same trusted Wi-Fi. No internet is needed.
3. Open camera Serial Monitor at 115200 baud, press reset, and copy its **Camera
   pairing code** privately. This is different from the sensor pairing code.
4. Install the updated app over the existing app to preserve local scans.
5. In **Devices**, choose your crop, enable local hardware HTTP, and assign the
   sensor and camera. Continue using the sensor pairing code for sensor assignment.
6. Open **Automatic capture settings**. Enable the switch, enter the camera pairing
   code, select measurements, and enter your limits. The camera is the one assigned
   to this crop in Devices. Automatic capture currently uses camera HTTP port 80.
7. Set sustained duration and cooldown, then **Save to sensor**. Wait for confirmation.
   Enter the camera code again when saving changes to enabled rules. The app does
   not store this camera key; the sensor stores it for board-to-board requests.

There are no recommended disease thresholds baked in. Starting limits are the
sensor's allowed numeric bounds. Choose suitable growing-condition limits for
your setup. Temperature accepts -40..80 Celsius; humidity/soil 0..100 percent.
Soil triggers require measured DRY/WET calibration and SOIL_CALIBRATED=true in
sensor firmware. Raw gas readings do not trigger photos.

## What happens

- Every approximately 10 seconds the sensor evaluates fresh measurements.
- ANY enabled measurement continuously outside its minimum/maximum for the saved
  duration (10..3600 seconds) can trigger. Equal-to-limit readings are in range.
- Missing, implausible, or interrupted readings reset that measurement's timer.
- Each attempt observes a cooldown (60..86400 seconds), including failed attempts.
  Restarting or saving settings restarts the cooldown. A persistent alarm may take
  another photo once the cooldown ends; it is not one photo per incident.
- The sensor sends an authenticated request directly to the camera's saved private
  IPv4 address. The camera checks its ID and pairing code and saves a JPEG to SD.
  The camera also enforces a 60-second minimum between automatic attempts.
- Both boards must stay powered and on the same Wi-Fi. The phone/app may be closed.
- Photos are stored under /captures/<session>/<sequence>.jpg, alongside manual
  captures. Serial Monitor prints crop/event and file information. These files do
  not yet import into app history or run model inference. Sensor alerts indicate
  growing conditions, not a disease diagnosis.

## Stop, move, or troubleshoot

Turn Automatic capture off and **Save to sensor** while connected to stop rules.
The app's local HTTP switch only blocks app requests; it does not remotely stop
automation saved on a board. Powering off the sensor also stops triggering.

Reload settings/status to see the sensor's last attempt (status resets at boot or
configuration change). Missing/full/failing camera SD storage reports failure;
manual Wi-Fi captures remain available. Back up/free the card with power off and
restart. No files are automatically deleted or cards formatted. A lost reply can
mean a photo was saved even though the sensor reports a timeout.

Moving/removing a paired sensor or camera first stops affected automatic rules;
an unreachable sensor can block reassignment until reconnected. Changing a sensor's
crop disables its rules in firmware. Configure rules again for the new crop.
The app does not keep separate historical rules for every past crop on one board.
If a router changes an IP, update the app assignment and re-save automatic settings.
IP addresses are not discovered automatically. Reserve addresses on your router
if it supports this. Camera pairing and sensor settings survive ordinary restarts;
erasing flash requires pairing/configuration again.

## Teammate's physical acceptance test

Compile both complete sketches in Arduino IDE, retaining working wiring/calibration
and Wi-Fi settings. Check Serial Monitor for camera SD readiness and pairing code.
Start with a test threshold just outside the current safe measured condition (do
not heat, dry out, or damage plants to force a test). Use duration 10 seconds and
cooldown 60 seconds; wait at least a minute after saving. Confirm a JPEG is saved,
normal sensor readings still work, and manual app captures still work.

Close the app: confirm another photo after cooldown during the sustained test
condition. Restore the threshold so the reading is in range: no further photo
should occur. Save Off and verify capture stops. Restart both boards and verify
saved settings, crop identity, and startup cooldown. Test unavailable camera,
missing/full SD card, wrong pairing code, and Wi-Fi interruption. Restore intended
limits after testing; leave Off until those limits are agreed.

## Validation and limits

App tests use in-memory fake boards; timing tests exercise the actual portable C++
trigger logic on the host. These do not replace Arduino compilation or board tests.
No Arduino tools or new dependencies were downloaded. Firmware uses existing
Espressif HTTPClient, WebServer, Preferences, and SD_MMC facilities. Network calls
and SD writes add latency, so check timing and stable power on your physical setup.
No cloud requests or background phone service are used. Pairing keys travel over
the explicitly enabled local HTTP connection; use trusted Wi-Fi and keep codes private.

API references: https://github.com/espressif/arduino-esp32/blob/master/libraries/HTTPClient/src/HTTPClient.h
and https://docs.espressif.com/projects/arduino-esp32/en/latest/api/sdmmc.html
