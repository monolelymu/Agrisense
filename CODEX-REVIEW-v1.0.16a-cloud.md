# Codex Review Report: AgriSense v1.0.16a-cloud (App) / v1.0.16b-cloud (Firmware) Fix Verification

**Date:** 2026-10-30  
**Target:** Reconciled Fix Release (`AgriSense-v1.0.16a-cloud.apk` + `AgriSense-Firmware-v1.0.16b-cloud.zip`)  
**Rollback Baseline:** Commit `071c218` on branch `v2-ui-simple`

---

## 1. Executive Summary & Verification Evidence

All 7 initial findings from Codex's review plus the follow-up telemetry JSON blocker in `sensor_node_full/firebase_sync.h` have been verified, fixed, and host-tested in `v1.0.16b-cloud` without expanding scope or adding unapproved dependencies.

### Verified Test Results

1. **Firmware Host Tests** (`firmware/demo-pan-tilt/checks/run_host_checks.py`):
   - Command: `python firmware/demo-pan-tilt/checks/run_host_checks.py`
   - Exit code: `0`
   - Test suites: **All 6 passed**
     - `PASS: demo_controls_test`
     - `PASS: warning_config_test`
     - `PASS: network_test`
     - `PASS: network_empty_test`
     - `PASS: power_timing_test`
     - `PASS: cloud_sync_test` *(exercises actual `buildOpenReadingsJson`, `closeReadingsJson`, `buildSensorCloudPayload`, `jsonStringField`, and `CloudDeduplicator`)*

2. **Flutter Unit & Regression Tests**:
   - Command: `flutter test test/firebase_cloud_client_test.dart test/kit_discovery_test.dart test/camera_controls_test.dart test/hardware_transport_test.dart test/sensor_trend_card_test.dart test/dashboard_records_test.dart`
   - Exit code: `0`
   - Output: **`All tests passed!` (49/49 tests passed)**

3. **Dart Static Analysis**:
   - Command: `dart analyze lib/data/firebase_cloud_client.dart lib/core/hardware_controller.dart lib/data/hardware_client.dart test/firebase_cloud_client_test.dart`
   - Exit code: `0`
   - Output: **`No issues found!`**

4. **Deliverables & Integrity**:
   - **Android App:** `AgriSense-v1.0.16a-cloud.apk` (and `AgriSense-latest.apk`)
     - Version: `1.0.16-a+23` (`versionName: 1.0.16a-cloud`, `versionCode: 23`)
     - Size: `154,724,986 bytes`
     - SHA-256: `5681afdef9bcf9eb3e516b582a5576a8cbf13d365a6d5644ee211d1c53b0cf87`
   - **Firmware Archive:** `AgriSense-Firmware-v1.0.16b-cloud.zip` *(earlier `v1.0.16-cloud` and `v1.0.16a-cloud` archives preserved)*
     - Base: `AgriSense-Firmware-v1.0.15d-power.zip`
     - Size: `93,388 bytes`
     - SHA-256: `9cb57df49a1c525870af46dcf70802d120613ba4e935cea56a486011c145d4f7`

---

## 2. Verification of Follow-Up Telemetry Payload Blocker (`v1.0.16b-cloud`)

- **Finding:** In `sensor_node_full/firebase_sync.h`, `latestJson` leaves the `readings` JSON object open so `serveReadings()` can append `dht_age_ms` and `age_ms`. Appending `,"uploaded_at_ms":{".sv":"timestamp"}}` left `readings` unclosed, placed `uploaded_at_ms` inside `readings` instead of at the `/kits/demo/sensor` root, and omitted the outer closing brace. Additionally, `PUT` responses were ignored.
- **Resolution:**
  1. **Extracted Shared Payload Builders (`sensor_node_full/firebase_sync.h` & `sensor_node_full.ino`):**
     - `buildOpenReadingsJson(...)` builds the open-brace `latestJson` prefix in `sensor_node_full.ino`.
     - `closeReadingsJson(openReadingsJson, dhtAgeMs, sampleAgeMs)` appends `dht_age_ms` and `age_ms` and closes the `readings` object (`}`).
     - `buildSensorCloudPayload(identityJson, openReadingsJson, dhtAgeMs, sampleAgeMs)` wraps `identity` and `closeReadingsJson(...)`, appends `,"uploaded_at_ms":{".sv":"timestamp"}` at the `/kits/demo/sensor` root, and closes the outer document (`}`).
  2. **Checked Cloud HTTP Status Codes (`firebase_sync.h` & `firebase_camera_sync.h`):**
     - Verified HTTP return codes on all `PUT` and `GET` calls. Non-200 responses are logged via `Serial.printf`, `401`/`403` responses clear the cached token (`cloudToken = ""` / `cameraCloudToken = ""`) so the next tick re-authenticates, and camera snapshot requests are only marked executed when the snapshot `PUT` returns `200`.
  3. **Host Test on Actual Payload Builders (`checks/cloud_sync_test.cpp`):**
     - Calls `buildOpenReadingsJson()`, `closeReadingsJson()`, and `buildSensorCloudPayload()` directly.
     - Verifies balanced braces/brackets/quotes, exact string match, and key brace depths (`"identity":`, `"readings":`, and `"uploaded_at_ms":` at depth 1; `"sample_id"`, `"dht_age_ms"`, and `"age_ms"` at depth 2 inside `"readings"`), including `null` handling for uncalibrated soil and `NAN` DHT readings.

---

## 2. Verification of Codex Findings & Exact Resolutions

### Finding 1: Camera Compile Blocker
- **Finding:** `camera_main.h` included `firebase_camera_sync.h` on line 6 before declaring `DemoNetwork network("camera");` on line 10.
- **Verification:** Confirmed compilation blocker because `firebase_camera_sync.h` accesses `network.online()`, `network.connecting()`, etc.
- **Resolution:** Moved `#include "firebase_camera_sync.h"` to line 15 (after `DemoNetwork network("camera");` and all camera function declarations).

### Finding 2: Replay Deduplication, Target Device ID & Expiry
- **Finding:** Cloud commands lacked expiry, target device validation, and replay deduplication across restarts.
- **Resolution:**
  - Implemented `CloudDeduplicator` in `sensor_node_full/firebase_sync.h` and `CameraWebServer/firebase_camera_sync.h`.
  - **Boot-Time Seeding:** On the first successful poll after boot (`!bootSeeded`), the board reads whatever command/request is currently in Firebase and seeds `lastRequestId` without executing it (`dedup.seed(reqId);`). This prevents replaying stale commands on board reboots.
  - **Initial Poll Failure Safety:** If the initial HTTP GET fails (timeout / HTTP != 200), `bootSeeded` remains `false`.
  - **Device ID Check:** Commands and requests are validated with `dedup.shouldExecute(targetDevice, reqId)`, rejecting any command where `targetDevice != myDeviceId`.
  - **Duplicate Rejection:** Any repeated poll with the same `request_id` is rejected.
  - Tested comprehensively on host C++ in `checks/cloud_sync_test.cpp`.

### Finding 3: Board Security & Demo Constraints
- **Finding:** `setInsecure()` and anonymous auth without restricted board certificates.
- **Consensus Resolution:**
  - `setInsecure()` is preserved intentionally for the 1-day demo because ESP32-CAM lacks an RTC chip and neither board blocks boot on NTP sync (certificate date verification fails if the clock is 1970).
  - Open authenticated demo-kit access (`auth != null` under `/kits/demo`) is preserved for the one-day demo defense.
  - Server-timestamp verification (`"uploaded_at_ms": {".sv": "timestamp"}`) was added to telemetry payloads to ensure freshness.

### Finding 4: Persistent Auth Storage & Form-Encoded Token Refresh
- **Finding:** Default `FirebaseCloudClient` was not connected to persistent auth storage. Token refresh used JSON instead of Firebase's documented form encoding.
- **Resolution:**
  - In `HardwareController`, `client = client ?? HardwareClient(cloud: FirebaseCloudClient(box: box, clock: clock ?? DateTime.now))` passes the persistent Hive box.
  - Anonymous auth tokens and refresh tokens are cached in `box` under `firebase-anon-auth-v1` and reused across app launches without repeat sign-up calls.
  - In `FirebaseCloudClient._refreshIdToken()`, requests to `https://securetoken.googleapis.com/v1/token?key=$apiKey` use `application/x-www-form-urlencoded` (`grant_type=refresh_token&refresh_token=...`) per OAuth2 specification. Tested in `firebase_cloud_client_test.dart`.

### Finding 5: Synchronous Request Blocking in Firmware
- **Finding:** Synchronous HTTPS requests could block DHT/sensor sampling and local web controls.
- **Resolution:**
  - **TLS Connection Reuse:** Both boards reuse static `WiFiClientSecure` and `HTTPClient` with `setReuse(true)` and bounded `1500 ms` connect and read timeouts.
  - **Non-Overlapping Task Scheduling:** Alternating turns (`cloudTaskTurn` / `cameraCloudTaskTurn`) ensure at most **one** cloud HTTP request runs per `loop()` pass, preventing cumulative delays and keeping DHT sampling and local web requests responsive.

### Finding 6: Firmware Host Tests & Mocks
- **Finding:** Host checks did not compile cloud headers, and cloud tests covered mocked success paths.
- **Resolution:**
  - In `checks/esp32-hal-ledc.h`, added `indexOf(const char*, size_t)` and `indexOf(char, size_t)` to the host `String` shim.
  - Extracted `jsonStringField` and `CloudDeduplicator` outside `#if defined(ARDUINO)`.
  - Created `firmware/demo-pan-tilt/checks/cloud_sync_test.cpp` and added it to `run_host_checks.py`. Tests cover string parsing, unseeded rejection, failed poll handling, boot seeding replay protection, duplicate rejection, and device ID validation.
  - In Flutter: Expanded `firebase_cloud_client_test.dart` to test form-encoded token refresh, Hive auth caching, stale telemetry rejection (> 45s `uploaded_at_ms`), and live polling staleness (> 30s unchanged `sample_id`).

### Finding 7: Documentation & Status Statements
- **Finding:** Contradictory statements regarding cloud history sync.
- **Resolution:**
  - Updated `ARGON-FIRMWARE-15-POWER-HANDOFF.md`, `APP-UPDATE-v1.0.16-cloud.md`, and `FIRMWARE-UPDATE-v1.0.16-cloud.md`.
  - Clarified that scan history stays local on each phone in Hive (`TomatoScanStore`) intentionally to guarantee scan privacy, fast offline performance, and zero cloud photo storage costs for the demo.
  - Clearly documented that ESP32 sketch compilation and flashing remain pending user action on real hardware.

---

## 3. Additional User Experience Improvement

### Built-in Firebase Defaults in Firmware
- In `sensor_node_full/demo_network.h` and `CameraWebServer/demo_network.h`:
  - `AGRISENSE_FIREBASE_URL` defaults to `"https://agrisense-3eba5-default-rtdb.asia-southeast1.firebasedatabase.app"`
  - `AGRISENSE_FIREBASE_API_KEY` defaults to `"AIzaSyCdXw00WR8x2TYnse4NJAs2O2_pQ0QYA0c"`
  - `AGRISENSE_KIT_ID` defaults to `"agrisense-demo-kit"`
- Both `demo_network.h` files are byte-identical.
- **Impact:** The user's `secrets.h` now **only requires Wi-Fi credentials**:
  ```c
  #define AGRISENSE_WIFI_SSID "YOUR_WIFI_NAME"
  #define AGRISENSE_WIFI_PASSWORD "YOUR_WIFI_PASSWORD"
  ```

---

## 4. File Modification Ledger

### Created / Packaged Files
- `AgriSense-v1.0.16a-cloud.apk` (Release APK)
- `AgriSense-latest.apk` (Convenience copy)
- `AgriSense-Firmware-v1.0.16a-cloud.zip` (Source firmware package)
- `firmware/demo-pan-tilt/checks/cloud_sync_test.cpp` (Host C++ test)
- `CODEX-REVIEW-v1.0.16a-cloud.md` (This document)

### Modified Firmware Files
- `firmware/demo-pan-tilt/CameraWebServer/camera_main.h`
- `firmware/demo-pan-tilt/CameraWebServer/demo_network.h`
- `firmware/demo-pan-tilt/CameraWebServer/secrets.example.h`
- `firmware/demo-pan-tilt/CameraWebServer/firebase_camera_sync.h`
- `firmware/demo-pan-tilt/sensor_node_full/demo_network.h`
- `firmware/demo-pan-tilt/sensor_node_full/secrets.example.h`
- `firmware/demo-pan-tilt/sensor_node_full/firebase_sync.h`
- `firmware/demo-pan-tilt/checks/esp32-hal-ledc.h`
- `firmware/demo-pan-tilt/checks/run_host_checks.py`

### Modified App Files
- `agrisense/lib/core/hardware_controller.dart`
- `agrisense/lib/data/hardware_client.dart`
- `agrisense/lib/data/firebase_cloud_client.dart`
- `agrisense/test/firebase_cloud_client_test.dart`
- `agrisense/pubspec.yaml`
- `agrisense/android/local.properties`

### Updated Documentation Files
- `APP-UPDATE-v1.0.16-cloud.md`
- `FIRMWARE-UPDATE-v1.0.16-cloud.md`
- `ARGON-FIRMWARE-15-POWER-HANDOFF.md`

---

## 5. Remaining Limitations & Next Action

- **Hardware Acceptance:** ESP32 compilation via Arduino IDE/CLI and physical on-bench flashing remain pending user upload. All host shims and protocol tests pass.
- **Rollback Safety:** Commit `071c218` on branch `v2-ui-simple` remains untouched.
