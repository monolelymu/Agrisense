# AgriSense firmware v1.0.15d-power

Firmware-only revision of v1.0.15 for the current v1.0.15d app (build 20). RTC, both SD storage paths, timestamps, saved warnings, pairing, scanning and camera controls remain. No app, model or dependency changes.

## Changes

- Wi-Fi waits at least two seconds before association. It allows 20 seconds for connection/address acquisition, then requires successful radio shutdown before a 2/5/10/30-second capped retry rest. Missing credentials never start an attempt. Startup logs identify the revision/reset reason; disconnect logs show reason codes without keys.
- Sensor initializes RTC/SD first, then commands pan and tilt 750 ms apart, allowing another 750 ms before controls become available. Normal moves change one axis at a time; Center completes pan, waits 250 ms, then moves tilt. Existing limits, step size, PWM, holding torque and duplicate-command protection remain.
- New movement waits during association or motor settling. Sensor association starts only while servos are idle. Sensor SD writes and sensor-triggered automatic camera requests defer during movement/settling without consuming capture cooldown or stopping fresh sample/warning evaluation.
- Camera retries initialization between Wi-Fi attempts. Camera/SD startup precedes the first association. Existing manual capture, streaming and storage behavior remain.

These changes reduce simultaneous commanded demand. They cannot guarantee stable voltage. Separate-board manual streaming/capture and motor holding current can still overlap. Keep the separate camera supply that resolved the observed symptom, suitable servo power and common ground. Brownout protection is unchanged.

## Install / rollback

Source package: `AgriSense-Firmware-v1.0.15d-power.zip`. Compile and upload BOTH standalone sketches, preserving each board's working board/core/camera settings and private Wi-Fi settings. Keep every neighboring header. Use the existing ESP32 Arduino 3.x core and DHT/Unified Sensor/RTClib libraries; no new library is needed. Keep Erase All Flash disabled. Continue using the current app; no APK rebuild is required.

The package contains examples only, no completed secrets.h. Enter credentials privately. Original firmware archive `AgriSense-Firmware-v1.0.15.zip` remains untouched; compile/upload its two original sketches with your private settings to roll back without erasing NVS.

## Verification

The original source matched all 27 files in the v15 archive before editing. Its SHA-256 is `190DF15043392FE0DBB014A7F934D95E4812D130CA21EB1B8CFBC2A8D9F8AB5F`.

Executed `python firmware/demo-pan-tilt/checks/run_host_checks.py`: five suites passed, compiled with g++ using `-std=c++17 -Wall -Wextra`. The suites cover staged startup/failure, one-axis Center and settling, movement bounds/deduplication/stale rejection, LEDs and offline warnings, authenticated persisted warning settings, nonoverlapping retry lifecycle, radio stop/start failure, DHCP timeout, capped backoff, missing credentials, discovery recovery, millis rollover and capture deferral/cooldown/freshness. Host shims do not exercise real ESP32 drivers. Logs: `output/firmware-v15d-power/host-checks.log`.

No arduino-cli was available on PATH. ESP32 compilation, flashing, sensor/servo clearance, current and voltage measurements remain unperformed. Validate cold startup, weak/missing Wi-Fi and router recovery, both-axis Center, rapid/duplicate commands, saved warnings after restart, live view/manual scanning, sensor CSV timestamps and standalone automatic SD photos. Measure the board input and 3.3 V rail during the heaviest combined load before claiming a power improvement.

## Files / commands / dependencies

Firmware changed: both `demo_network.h` files; sensor `demo_controls.h`, `sensor_node_full.ino`, `auto_capture.h`, `auto_capture_timing.h`; camera `camera_main.h`; root firmware README. Existing host control test/shim updated. Added network test/shims, power timing test and host runner under `firmware/demo-pan-tilt/checks/`. No source deleted. Firmware is ignored by Git; the source ZIP and generated baseline diff are the reviewable delivery.

Commands: read-only rg/Get-Content/Get-FileHash/git status/git check-ignore; Python baseline byte comparison; g++ host builds and execution via the runner above; package/hash/byte-comparison validation. No dependencies installed, system changes, Git commits, pushes, setup scripts or hardware access. Unrelated dirty app files remain untouched.

Package metadata, changed-file listing and unified diff: `output/firmware-v15d-power/package-manifest.json` and `output/firmware-v15d-power/firmware.diff`.
