# Hardware integration

The normal app now opens the real dashboard. It never seeds demo readings.
Existing photo results keep their storage keys and appear in History and the
latest-diagnosis card. Old mock history remains stored but is not displayed.

## Safety and connection setup

1. Use a trusted Wi-Fi network shared by the Android phone and both ESP32 boards.
2. In Devices turn on **Allow local hardware HTTP** (off by default).
3. Choose the crop and edit each board's private IPv4 address
   (for example `192.168.1.50`). An optional HTTP port is supported.
   Do not enter `/capture`, `/readings`, or the camera's streaming port 81.
   For the sensor, enter its pairing code on first setup and tap **Apply assignment**.
   The app checks the sensor, tells it the selected crop, then reads it back.
   With HTTP off you can remove assignments or change the local camera assignment,
   but cannot configure or contact the sensor.
4. Tap **Test sensor and save reading** and **Test camera connection**.
   Use **Scan leaf → Capture and analyze**
   for the camera, or continue uploading photos without hardware.

HTTP is unencrypted and the supplied camera firmware has no authentication.
Do not port-forward either board or use untrusted Wi-Fi. The app restricts its
hardware client to numeric RFC1918 IPv4 addresses, disallows redirects and
proxies, limits response sizes, and times out requests. Android permits HTTP
at application level to support user-selected addresses; the saved opt-in gate
and address restrictions are enforced by the app's hardware controller/client.
There is no certificate bypass, cloud service, Wi-Fi discovery, or background
service. Turning the switch off stops polling. Foreground polling is explicit,
selected-crop-only, every 10 seconds, and stops when the app is backgrounded,
the selected crop changes, or diagnosis opens. It does not resume automatically.
An in-progress request must finish before changing assignments or the HTTP switch.

Sensor crop writes require a board-generated 128-bit pairing code. It is printed
only on Serial Monitor, never returned by HTTP. The app stores it locally in its
private app data (not encrypted separately); Android backup is disabled in the
manifest. HTTP remains unencrypted, so this does not protect against a hostile
device sniffing the same network. Never share screenshots of the pairing code.
Readings and camera capture remain read-only endpoints without authentication.

## Changing crops after first setup

1. Physically move the nodes to the intended plant.
2. Choose the new crop in **Devices**, then edit **Sensor node**.
3. Under **Or use an existing board**, tap its previous crop. Leave the code
   blank to reuse the saved pairing code, then **Apply assignment**.
4. Repeat for **Camera node**. Camera assignment is stored in the app only.
5. Test readings and camera preview. New readings/scans go to the new crop;
   existing history stays with its original crop.

The sensor saves its crop in ESP32 Preferences and remembers it after power loss.
No reflashing is needed for crop changes after this firmware is installed.
The app transfers its local assignment only after both the command response and
a separate configuration read confirm the requested crop and board identity.
If the reply or local save fails, the board may already have changed; retry the
same assignment. Wrong-crop readings are rejected in the meantime. A changed
device ID at a known IP is rejected; remove the old assignment before explicitly
pairing a replacement board. Removing an assignment does not reset the board.

## Camera firmware

The existing CameraWebServer provides `GET /capture` with `image/jpeg` on its
main HTTP port (normally 80). No camera firmware changes are needed. Enter the
IP shown in its Serial Monitor. Capture returns a photo which is classified
locally and saved with source `camera`, model version, crop and top predictions.
Only tomato classification is currently available. Other crops never fall
back to the tomato model. The camera does not identify its crop: its physical
placement must match your assignment. Each board address can belong to one crop.

## Sensor firmware handoff

Updated local sketch:
`firmware/sensor_node_full-20261016T013958Z-1-001/sensor_node_full/sensor_node_full.ino`
(relative to the repository root). The firmware directory is ignored by Git;
share these changed firmware files with the hardware teammate separately.

1. Copy `secrets.h.example` to `secrets.h` beside the sketch and enter Wi-Fi
   credentials locally. With no secrets file, Serial/SD logging still works
   and Wi-Fi is disabled. Never commit or send real credentials with source.
2. There is no crop constant to edit. Tomato is the first-boot default; assign
   the crop from the app after pairing.
3. Measure dry/wet soil ADC values, update `DRY_VALUE` / `WET_VALUE`, then set
   `SOIL_CALIBRATED = true`. Before that the app shows raw ADC and no percentage.
4. Compile and flash the ESP32 WROOM-32 sketch using the existing Adafruit DHT,
   Unified Sensor and RTClib libraries. WiFi/WebServer are from the ESP32 core.
5. Open Serial Monitor at 115200 baud. Copy the sensor IP and pairing code into
   Devices. Reopening Serial Monitor/resetting the board prints the same saved
   pairing code. Erasing the ESP32's flash resets that code and saved crop.

No new external firmware library is required: Preferences, WiFi and WebServer
are part of the ESP32 Arduino core. SD logging continues in `sensor_log_v2.csv`,
which now includes the crop and leaves uncalibrated percentages blank. The old
CSV remains untouched. Wi-Fi reconnect is attempted every 30 seconds when offline.

`GET /readings` returns JSON version 1:

```json
{"version":1,"device_id":"aabbccddeeff","crop":"tomato","sample_id":"board-boot-1","age_ms":500,
 "temp_c":25.1,"humidity_pct":60.0,"soil_raw":2300,"soil_pct":null,
 "soil_calibrated":false,"gas_raw":400}
```

`GET /config` returns `crop_protocol: 1`, `device_id`, and `crop`.
`POST /crop` accepts URL-encoded `crop` and `device_id` with an
`X-AgriSense-Key` header. Unknown crops, wrong identities, missing/incorrect keys
and failed flash writes are rejected. Repeating the same assignment is safe and
does not repeatedly write flash. On a successful change, cached telemetry is
discarded and a new reading gets a new sample ID.

Implementation reference: [Espressif Preferences source](https://github.com/espressif/arduino-esp32/blob/master/libraries/Preferences/src/Preferences.cpp).

Failed DHT values are null. A sample older than 30 seconds is rejected. Sample
IDs change across reboot and sampling, preventing duplicate history entries.
Received timestamps use the phone clock; the RTC remains used for SD logs.
MQ135 values are raw ADC, not ppm. No unvalidated stress score or automatic
disease diagnosis is generated from these readings. Up to 5,000 recent samples
per crop are retained. History shows the latest 100; Trends uses all retained
samples. Unavailable metrics are omitted from charts.

## Physical acceptance test (requires boards)

- With HTTP off, reading/capture must be blocked and no board contacted.
- Enable it, read a sample, verify values against Serial Monitor; repeat inside
  ten seconds and verify there is no duplicate sample in History.
- Select a different crop: the wrong sensor crop must be rejected.
- Reassign the sensor from Tomato to Eggplant in the app. Verify its old reading
  remains under Tomato, and its new reading appears only under Eggplant. Power
  cycle it and verify Eggplant persists. Switch back without reflashing.
- Enter a wrong pairing code: assignment must not change. Interrupt Wi-Fi after
  sending an assignment, restore Wi-Fi and retry the same crop successfully.
- Capture a tomato photo and verify the same saved result appears on Dashboard
  and History; reopen after restarting the app.
- Turn off a board: request fails within 12 seconds; saved values are labeled
  saved/not live. Check invalid DHT values remain unavailable, never zero.
- Enable polling, background the app, return: polling should be off.
- Compile/flash and perform sensor/camera tests on hardware before declaring
  the integration verified. An emulator must have a network route to the boards;
  a physical Android phone on the same Wi-Fi is preferable for acceptance.

Firmware compilation was deliberately left to the hardware teammate; no Arduino
compiler, board package or library downloads were installed for this update.
One-time Wi-Fi configuration, physical sensor calibration, wiring/power checks,
and these acceptance tests remain necessary. Model improvement is not a
substitute for validating real hardware.
