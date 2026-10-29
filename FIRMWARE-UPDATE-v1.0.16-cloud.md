# AgriSense Firmware v1.0.16b-cloud — Remote Cloud Telemetry & Control (Payload & Status Fix Release)

Delivery package: `AgriSense-Firmware-v1.0.16b-cloud.zip`.
Base: `AgriSense-Firmware-v1.0.15d-power.zip`.

## Fixes in v1.0.16b-cloud

1. **Fixed Sensor Telemetry JSON Payload Structure (`firebase_sync.h` & `sensor_node_full.ino`):**
   - Extracted `buildOpenReadingsJson()`, `closeReadingsJson()`, and `buildSensorCloudPayload()` in `sensor_node_full/firebase_sync.h` so both local `/readings` and cloud `/kits/demo/sensor.json` use shared, host-tested builders.
   - `closeReadingsJson()` properly appends `dht_age_ms` and `age_ms` and closes the `readings` JSON object (`}`) before `buildSensorCloudPayload()` appends `"uploaded_at_ms":{".sv":"timestamp"}` at the sensor root and closes the outer document (`}`).
2. **Checked Cloud HTTP Response Status Codes (`firebase_sync.h` & `firebase_camera_sync.h`):**
   - Checked `PUT` and `GET` HTTP status codes for sensor telemetry, command receipts, camera identity, and camera snapshots.
   - Non-200 responses are logged via `Serial.printf`, `401`/`403` responses invalidate the cached auth token (`cloudToken = ""` / `cameraCloudToken = ""`) to force re-authentication on the next tick, and camera snapshot requests are only marked executed when the snapshot `PUT` returns HTTP 200.
3. **Host Test Exercising Actual Firmware Payload Builders (`checks/cloud_sync_test.cpp`):**
   - Added structural JSON validation and brace-depth assertions exercising `buildOpenReadingsJson()`, `closeReadingsJson()`, and `buildSensorCloudPayload()` directly for both calibrated/valid-DHT and uncalibrated/NAN-DHT readings.
   - Verified `"identity"`, `"readings"`, and `"uploaded_at_ms"` are at depth 1 (sensor root) while `"sample_id"`, `"dht_age_ms"`, and `"age_ms"` are at depth 2 inside `"readings"`.

## Fixes Retained from v1.0.16a-cloud

1. **Camera Sketch Compilation Order:** `#include "firebase_camera_sync.h"` placed after `DemoNetwork network("camera");` in `CameraWebServer/camera_main.h`.
2. **Built-in Firebase Defaults:** Default `AGRISENSE_FIREBASE_URL` and `AGRISENSE_FIREBASE_API_KEY` built into `demo_network.h` (byte-identical across both sketches). `secrets.h` requires only `AGRISENSE_WIFI_SSID` and `AGRISENSE_WIFI_PASSWORD`.
3. **Boot-Time Command/Request Seeding & Target Device ID Validation:** `CloudDeduplicator` seeds pre-existing Firebase commands on first successful poll without executing them, keeps `bootSeeded = false` on failed initial polls, validates `targetDeviceId == myDeviceId`, and rejects duplicates.
4. **Persistent TLS Reuse & Non-Overlapping Scheduling:** Reuses a single `WiFiClientSecure` + `HTTPClient` (`setReuse(true)`, 1500 ms timeouts) and executes at most one cloud HTTP request per `loop()` pass.

## Pending Actions & Limitations

- **Hardware & Live Firebase Acceptance:** ESP32 compilation via Arduino IDE/CLI, flashing to physical boards, and live end-to-end verification of remote readings, pan/tilt commands, and snapshots against the physical kit and Firebase remain pending. Host tests verify C++ helpers, payload construction, and scheduling logic only.
- **Rollback Baseline:** Checkpoint commit `071c218` and earlier archives (`AgriSense-Firmware-v1.0.15d-power.zip`, `AgriSense-Firmware-v1.0.16-cloud.zip`, `AgriSense-Firmware-v1.0.16a-cloud.zip`) remain intact.
