# AgriSense v1.0.10 — app first

Install `AgriSense-v1.0.10.apk` over the existing app. Signing matches v1.0.9; all three bundled models are unchanged. The rollback checkpoint is `a8d770b` on `v2-ui-simple`.

## Changes

- Live camera panel with an On/Off switch, connection feedback and retry. Live view stops when leaving Camera or backgrounding the app.
- Streaming pauses before still-photo capture and resumes afterward. Stream failures do not declare the board disconnected.
- Visible Up, Down, Left, Right and Center controls. Movement stays unavailable until compatible sensor firmware advertises support. Commands require matching device identity and acknowledgement, and are never automatically repeated after timeout.
- Optional app-status heartbeat prepared for the next firmware's status LEDs. Existing firmware receives no unsupported commands.

No firmware, dependencies, models, records or signing configuration were changed. Future firmware interfaces and proposed pins are documented in `CAMERA-CONTROL-PROTOCOL-v1.md`.

## Validation

`flutter analyze --no-pub`: no issues. Focused Flutter tests: 74 passed across camera controls, simple UI, alerts, daily/background monitoring, discovery and automatic diagnosis. Release build completed with version 1.0.10 / build 11. `git diff --check` passed. No emulator was used.

## Test on the phone before updating firmware

1. Install the APK without uninstalling the old app; join the kit's Huawei Wi-Fi and connect.
2. Open Camera and enable Live if available. Confirm a moving scene updates. Unsupported firmware should leave live view unavailable.
3. Capture a photo while Live is on. Confirm the result saves and live view resumes when returning to Camera.
4. Leave Camera, lock/unlock the phone and reopen Camera. Check live view restarts without duplicate captures.
5. Briefly restart the camera or interrupt Wi-Fi. Check Retry and automatic recovery; verify uploaded-photo analysis still works.
6. Confirm all five movement controls are visible but unavailable on the current sensor firmware.

Actual streaming, power stability and later servo movement require physical kit validation. Install and review this app before proceeding to the separate firmware update.
