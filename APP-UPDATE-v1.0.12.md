# AgriSense v1.0.12

Install the APK over the existing app without uninstalling.

Camera hold controls now keep one steady Moving camera message and keep capture/refresh/photo-selection actions disabled throughout the hold, including gaps between requests. Release stops repeats; the UI returns to normal after an already pending command finishes. Failed commands retain their warning; per-step success messages are hidden.

Changed: hardware_controller.dart, camera_gamepad.dart, tomato_scan_screen.dart and focused camera_controls_test.dart. Static analysis: clean. Camera-control tests: 15 passed. No emulator, dependencies, firmware, model or signing-configuration changes.

Phone check: hold Left/Right briefly, confirm the status and capture button stay steady, then release. Test Up/Down with the replacement motor. Actual phone verification remains pending.

Firmware tuning is separate: sensor_node_full/demo_controls.h controls SERVO_STEP (currently 5 degrees per command) and SERVO_MIN/SERVO_MAX (currently 75..105 degrees). Keep 5-degree steps for the current 200ms hold cadence. Widen travel gradually only after checking mount clearance; do not assume 0..180 is mechanically safe. Reflash only the sensor if changing these constants.
