# AgriSense camera control contract — app v1.0.10

This describes the app's implemented interface for the NEXT firmware update.
No firmware is changed in this delivery. Old sensor firmware remains read/capture
compatible and receives no movement or status POSTs because it lacks these capabilities.

## Identity and discovery

Keep existing DHCP, mDNS kit identity and `/identity` version 1 schema unchanged.
Camera capability `stream` enables live view. Sensor capability `pan_tilt_v1`
enables the five movement buttons. Sensor capability `app_status_v1` enables
app status heartbeats. Advertise only features the board has actually initialized.
The app verifies kit, role, readiness and pinned device ID before movement and
before each live-stream connection. No credentials belong in identity/mDNS.

## Camera live feed

For camera HTTP base `http://<private-ip>:<port>`, the stream is
`http://<same-ip>:<port+1>/stream` (normally port 81). Existing CameraWebServer
already has this endpoint. Reply HTTP 200, `multipart/x-mixed-replace`.
Each part must have `Content-Type: image/jpeg`, numeric `Content-Length`, a blank
line, then the complete JPEG. No redirects. App limits frames to 2 MiB and headers
to 8 KiB; validates displayed images and redraws up to four times per second.

Live view runs only on the visible foreground camera route with local access on.
Leaving Camera, locking/backgrounding, opting out or toggling Live off closes its
socket and retry timer. It retries failures after 2/5/10/30 seconds. A frozen frame
is labeled reconnecting, not Live. Failure does not declare still capture offline.
Manual, scheduled and warning captures close/pause the stream before `/capture`,
then resume only if the camera view is still active. Actual camera mutex fairness,
power and stream/capture behavior must be verified on the OV3660 kit.

## Sensor movement

POST `/pan-tilt`, fixed-length `application/x-www-form-urlencoded` body:

```
version=1&device_id=<sensor-id>&request_id=<session>-<sequence>&action=up
```

Allowed actions: `up`, `down`, `left`, `right`, `center`. One deliberate tap is one
small bounded step; no hold-to-run, automatic movement retries or queued sweeps.
Firmware owns the actual step, pan/tilt direction signs, center and mechanical
limits. Initial proposed signal pins: sensor ESP32 GPIO25 pan, GPIO26 tilt.
The app sends directions, never arbitrary angles or GPIO numbers.

Success response:

```json
{"version":1,"device_id":"aabbccddeeff","request_id":"session-1","ready":true,"pan":90,"tilt":90}
```

The app requires matching IDs/version/readiness and integer angle values in
0..180. This validation range is NOT permission to drive an SG90 or assembled
mount through 180 degrees. Firmware must enforce its physically tested limits.
Repeated request IDs must return the same acknowledgement without moving again.
An action at a limit can acknowledge unchanged angles. Timeout means unconfirmed;
the app never automatically repeats it. Stop/limit commands must not block Wi-Fi,
sensor sampling or HTTP servicing. Preserve existing authentication on old
configuration/automation endpoints. These new limited demo controls assume trusted
local Wi-Fi; device-ID matching is not cryptographic authentication or Internet security.

## Sensor status heartbeat and proposed LEDs

During monitoring the app sends best-effort POST `/app-status` after a fresh
sensor cycle, only when the verified sensor advertises `app_status_v1`:

```
version=1&device_id=<sensor-id>&session_id=<app-session>&camera_ready=1&camera_device_id=<camera-id>
```

`camera_ready` is `1` only with a recent verified camera identity, recent successful
still photo, or fresh live frame; otherwise `0`. Camera ID can be empty before
verification. Return `{"version":1,"device_id":"aabbccddeeff"}` on acceptance.
Expire phone communication and relayed camera status after 60 seconds without a
valid heartbeat. Missed heartbeats do not stop scans or trigger movement retries.
No heartbeat is promised when monitoring is off; the LED means communicating,
not simply that a phone has joined Wi-Fi.

All six LED outputs are proposed on the sensor WROOM board, each through 330 ohms:
camera status GPIO17, sensor running GPIO4, phone communicating GPIO13, DHT22 valid
GPIO14, soil sampling GPIO27, MQ135 sampling GPIO33. Keep sensor pins32/34/35,
RTC21/22 and SD5/18/23/19 reserved. Soil/MQ LEDs indicate sampling, not calibration
or conclusive electrical sensor-health detection. Outputs remain firmware work.

## Physical acceptance checks

Install the app over the existing APK. Connect on Huawei Wi-Fi, open Camera and
verify Live starts, then test still capture during Live. Switch tabs, lock/unlock,
interrupt/restore Wi-Fi, and confirm the feed releases/reconnects and later captures
still work. Check sensor readings and scheduled/warning photos continue normally.
After sensor firmware is updated, test one small step in each direction and Center,
mechanical stops, command timeout without duplicate movement, and both servos under
load. This app build alone cannot validate the mount, power or physical operation.
