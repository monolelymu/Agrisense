# Camera workload profile — 23 October 2026

Target: user-confirmed AI-Thinker ESP32-CAM carrier with an OV5640 camera module.
An autofocus-capable lens assembly must also be present. This is prepared source,
not a flashed or thermally validated firmware release.

## Behavior
- JPEG captures remain 320x240 (QVGA). The previous sketch also selected QVGA
  after initialization; this change removes the initial UXGA-sized allocation
  and the PSRAM branch's two-buffer continuous DMA mode. One buffer and
  CAMERA_GRAB_WHEN_EMPTY are used for the configured JPEG mode, with or without
  PSRAM. JPEG quality is 12 instead of the PSRAM branch's previous 10.
- Wi-Fi modem sleep is disabled, matching the upstream CameraWebServer example.
  This restores the original connectivity setting while investigating standalone
  power failures. Deep sleep and CPU/sensor-clock changes are not introduced.
- Live preview returns 503 by default. AgriSense's /capture endpoint remains
  available. If cameraPreviewEnabled is deliberately changed to true, preview is
  bounded to about 5 FPS maximum and 30 seconds per connection, without flash;
  per-still AF is skipped to avoid racing the separate preview task.
- Flash starts off and is capped at duty 32/255 for still requests. No preview
  flash. Camera control rejects frame sizes above QVGA and JPEG quality below 12;
  custom output windows must also fit the allocated 320x240 buffer.
- When the installed driver exposes esp_camera_af.h and is built with
  CONFIG_CAMERA_AF_SUPPORT=1, the detected OV5640 uses manual AF mode and a
  single focus cycle before JPEG/BMP/automatic captures, bounded to 2 seconds
  for the wait operation. No continuous focus loop is introduced.
- If initialized AF cannot confirm focus, the request returns 503 instead of
  delivering an unconfirmed-focus image. If the driver/sensor cannot initialize
  AF, a Serial message explicitly reports fallback to existing lens focus.
- Before a still, one queued frame is discarded so the next frame is fresh.
  Automatic capture authentication, event deduplication, 60-second minimum
  retry interval and SD saving remain in place.

## Files
Under `firmware/CameraWebServer-20261016T013319Z-1-001/CameraWebServer/`:
- Modified `CameraWebServer.ino`: capture allocation, Wi-Fi sleep, focus startup.
- New `camera_focus.h`: optional driver AF integration and fresh-frame preparation.
- Modified `app_httpd.cpp`: bounded/disabled preview, flash cap, still preparation,
  frame-size/quality limits; preview header storage corrected to a byte array.
- Modified `automatic_camera.h`: same focus/preparation path for automatic stills.

This repository ignores `/firmware/`; these local edits are not included in normal
Git diffs or commits. Keep the sketch folder and this report together when handing
off. No credentials, pairing values or pin assignments were changed. No files
deleted, dependencies installed, app/model/notebook changes, flash or push.

## Checks and limitations
- Inspected existing capture, streaming, SD, board and automatic-capture paths.
- Verified the public AF interface and one-buffer behavior against Espressif:
  https://github.com/espressif/esp32-camera
  https://github.com/espressif/esp32-camera/blob/master/driver/include/esp_camera_af.h
  https://github.com/espressif/esp32-camera/blob/master/Kconfig
- Existing workspace Clang performed C++11 syntax-only checks for the focus
  helper using local interface stubs in `.tools/camera-focus-check/`: AF disabled;
  AF enabled with the public API shape; AF configured but header absent. All
  three pass with `-Wall -Wextra -Werror` (stub-only unused warnings excluded).
  An initial stub unused-symbol failure was corrected in the check flags.
- These checks do not compile the whole Arduino sketch, validate the actual
  installed ESP32 SDK, or execute autofocus/frame-buffer behavior on hardware.
  No Arduino CLI, Xtensa toolchain or ESP camera headers were found in the
  workspace tool inventory. No SDK/library was downloaded or installed.
- No Flutter tests were rerun: this change affects only camera firmware and docs.
- No temperature, current, long-running capture, focus or model-quality result
  is claimed. One-buffer mode reduces DMA work, not sensor power to zero.

## Hardware acceptance before use
1. Compile the complete sketch folder with the actual ESP32 Arduino package and
   AI-Thinker pin/PSRAM settings. Confirm the detected sensor PID in Serial.
2. Check the Serial AF message. AF requires the driver's compiled support and an
   AF lens; defining a macro in the sketch alone does not add missing SDK code.
   Older Arduino packages may compile the fallback without providing autofocus.
3. Verify /capture returns a fresh 320x240 JPEG as the leaf moves, with acceptable
   detail in bright and low-light scenes. Compare inference on known examples;
   a lower-workload profile does not establish diagnostic accuracy.
4. Verify automatic captures, SD files, authentication, event deduplication,
   cooldown and focus-failure recovery. Recheck phone timeouts on standalone power.
5. Compare measured idle and repeated-capture temperature/current under identical
   power, enclosure and ambient conditions against the previous firmware.
   Check supply stability and ventilation; firmware cannot repair those issues.
6. Confirm preview is unavailable by default and no flash remains on between
   requests. If preview is enabled for debugging, verify the time/frame-rate cap.
