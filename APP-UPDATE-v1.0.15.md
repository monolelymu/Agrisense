# AgriSense v1.0.15 (build 16)

## Changes in this update cycle

1. **Disease descriptions:** confident disease results now have a collapsed **What to look for** section. It shows typical signs, checks for similar symptoms, and explains that these are reference descriptions, not features verified by the model. Tomato, eggplant and chili references are available offline. Expanded descriptions include tomato early/late blight, leaf mold and leaf miner; eggplant Alternaria, mosaic and wilt; chili bacterial/Cercospora spots and powdery mildew. Existing source links remain available. Uncertain results retain retake guidance.
2. **Sensor responsiveness:** app monitoring checks every second instead of ten seconds. It skips overlapping monitor cycles and yields to camera controls. Existing capture operations continue using the operation lock. Background notification/settings wording matches the new interval.
3. **Live data versus history:** fresh samples appear immediately. Trend persistence remains approximately ten seconds, with the existing 5,000-record-per-crop bound. Duplicate IDs do not become new readings, renew freshness or repeatedly trigger alerts. Scans can use the most recent valid live reading even before its next trend save. Sensor-reported sample age is preserved; optional DHT age makes stale temperature/humidity unavailable.
4. **Firmware sampling:** soil/gas ADC sampling every second; DHT22 temperature/humidity every two seconds with independent freshness. Failed DHT readings remain null. Serial/SD logging remains every ten seconds. These are scheduling targets; blocking hardware/network calls can delay them.
5. **Servo movement:** ten degrees per accepted command; two-degree clamped increments every 20 ms; existing 75..105-degree limits and 90-degree center. PWM and wiring stay the same. Duplicate/stale command protection remains. No physical speed or clearance claim is made.
6. **Three warning LEDs:** GPIO14 combines temperature/humidity warnings, GPIO27 is soil, GPIO33 is gas. GPIO17/4/13 are no longer configured as LED outputs. Warnings light on the next valid out-of-range sample, and clear in range. Disabled/unconfigured/invalid readings and readings older than five seconds cannot light a warning LED. A dark LED is not proof of sensor health.
7. **Gas setting:** optional enabled/min/max range in existing sensor-alert settings, default disabled, 0..4095 raw units. It controls the kit LED only; no ppm, air-safety interpretation, phone notification, automatic photo or model scoring change.
8. **Saved limits:** capability-advertised authenticated GET/POST /warnings with validated identity, crop, units, ranges and readback. Limits persist on the sensor board, work without the phone and restore on restart. Physical crop reassignment clears the previous warning configuration. The app retries pending changes, reads back periodically, avoids redundant flash writes and shows Saved to kit / Waiting to sync. Older firmware remains usable and gets an update-required message for LED syncing.

The everyday flow remains Connect -> Readings -> Scan -> Result. No remote access, Firebase, new Wi-Fi onboarding, faster live video, model files or score calculations were added. FloraScan was not modified.

## Files

App files modified: pubspec.yaml; hardware_controller.dart; sensor_notifications.dart; hardware_client.dart; simple_result_card.dart; tomato_knowledge.dart; eggplant_knowledge.dart; chili_knowledge.dart; notification_settings_screen.dart; monitoring_settings_screen.dart; automatic_capture_screen.dart; Android MonitoringService.kt; hardware_transport_test.dart.

App files created: lib/data/kit_warning.dart; test/immediate_update_test.dart; this release note. Firmware modified: sensor_node_full.ino, demo_controls.h, README.md and host test shim/test. Firmware created: warning_rules.h, warning_config.h, checks/warning_config_test.cpp. No source files were deleted. Firmware is locally ignored by Git; its complete source is delivered in the versioned ZIP.

## Software checks

- Direct Dart analysis of lib and the new update tests: clean.
- Final acceptance run after the last edits: all 40 tests passed (immediate_update, sensor_notifications, hardware_transport, scan_guidance).
- Focused Flutter regression run: 71 passed; two legacy UI failures reproduced unchanged from the v1.0.14 source: the Chili knowledge heading and the old growing-conditions panel on Home.
- Three failures in the older hardware_test.dart also reproduce on v1.0.14 (old History/Trends labels and a crop-address exclusivity assumption). They were not hidden or changed.
- Host g++ checks exercise movement bounds/overshoot, duplicates/stale commands, three LEDs, invalid/stale readings, offline warning behavior, configuration authentication, raw bounds/units, idempotent writes, restart restore, crop clearing and storage failure. These are test shims, not an ESP32 compilation.
- Release APK built using existing Flutter/Gradle tooling and JDK 21; manifest version, signing certificate and included reference images are checked before delivery.
- No new dependencies, setup scripts, global settings or services were installed. No ESP32 Arduino compiler was available on PATH; actual ESP32 verification/upload, electrical wiring, sensor response, power stability and servo clearance remain for the user.

Commands used (from agrisense unless noted):

```text
dart --suppress-analytics analyze lib test/immediate_update_test.dart test/hardware_transport_test.dart
flutter test --no-pub test/immediate_update_test.dart test/sensor_notifications_test.dart test/hardware_transport_test.dart test/scan_guidance_test.dart --reporter expanded
flutter test --no-pub test/immediate_update_test.dart test/hardware_transport_test.dart test/daily_monitoring_test.dart test/sensor_notifications_test.dart test/background_monitoring_test.dart test/scan_guidance_test.dart test/tomato_knowledge_test.dart test/eggplant_knowledge_test.dart test/tomato_context_widgets_test.dart test/chili_context_test.dart --reporter expanded
flutter build apk --release --no-pub --build-name=1.0.15 --build-number=16
android/gradlew.bat assembleRelease --offline --no-daemon --console=plain (run from android with JDK 21)
g++ -std=c++17 -Wall -Wextra -I firmware/demo-pan-tilt/checks firmware/demo-pan-tilt/checks/demo_controls_test.cpp -o output/immediate-update/demo_controls_test.exe (repository root)
g++ -std=c++17 -Wall -Wextra -I firmware/demo-pan-tilt/checks firmware/demo-pan-tilt/checks/warning_config_test.cpp -o output/immediate-update/warning_config_test.exe (repository root)
git diff --check
```

The initial Flutter build selected the system JBR and stalled; it was stopped and the release build completed using the existing JDK 21 offline Gradle path. Baseline test runs use the archived v1.0.14 source, not the edited working tree. Complete logs are in output/immediate-update.

## Delivery and rollback

Verified APK manifest: com.example.agrisense, versionName 1.0.15, versionCode 16. Signing certificate matches v1.0.14; all 16 offline reference JPEGs remain packaged.

SHA-256:

```text
AgriSense-v1.0.15.apk
94B96E163B0353A8CADEC51855C39F7DB2A349205F9392F00310A9FAD0BFC1C5
AgriSense-Firmware-v1.0.15.zip
190DF15043392FE0DBB014A7F934D95E4812D130CA21EB1B8CFBC2A8D9F8AB5F
```

The firmware package contains 27 source/documentation entries, no completed secrets.h or executables, and all 13 camera files match the pre-update copy.

- Updated APK: AgriSense-v1.0.15.apk. Install over the existing app to preserve its data.
- Firmware: AgriSense-Firmware-v1.0.15.zip. Follow its root README. Only the sensor sketch needs updating if the existing camera already works. Keep all neighboring headers together. Completed secrets.h files are excluded; enter Wi-Fi privately and retain Erase All Flash disabled.
- Before editing, the exact tracked v1.0.14 source was saved to output/immediate-update/AgriSense-v1.0.14-source-rollback.zip from commit e910507. Firmware was saved separately to output/immediate-update/AgriSense-firmware-before-v1.0.15.zip, excluding completed credentials. Existing v1.0.14 APK remains untouched.
- For an app rollback without uninstalling, rebuild that archived source with the same signing identity and a higher version code (17 or greater after installing build 16). Installing the older build 15 directly may be rejected as a downgrade. Do not uninstall if history must be retained.
- Restore and compile the archived sensor source to roll back firmware. Keep Erase All Flash disabled. The old firmware ignores the added warning-storage key. Preserve private Wi-Fi settings locally; they are deliberately absent from the archives.

## Hardware acceptance checks

Confirm fresh readings, saved-limit sync, each LED inside/outside limits, humidity-only DHT warning, phone disconnect, sensor restart, camera capture/live-view recovery, and unloaded servo direction/travel/power. Gas warnings need a deliberately selected raw range, not an invented safety threshold. The LEDs react immediately while existing photo alerts retain their duration/cooldown.
