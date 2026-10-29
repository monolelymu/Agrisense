# AgriSense v1.0.13 — reduced movement traffic

Install the versioned APK over the existing app without uninstalling.

- Reuse the sensor identity verified during Connect instead of querying identity before every movement step.
- Recheck identity after a movement failure or address change; normal Connect/recovery verification remains intact. Each movement still includes the device ID and requires a matching acknowledgement.
- Hold repeat cadence is now 300ms (slower when communication takes longer), with one movement request at a time. Release/failure/background cancellation and the steady movement UI are retained.
- Sensor polling remains 10 seconds. No firmware, pins, dependencies, models or signing configuration changed.

Changed source: hardware_controller.dart, camera_gamepad.dart and focused camera_controls_test.dart. Static analysis passed; 15 focused camera-control tests passed. No emulator or physical kit validation.

Phone test: compare movement with Live off, then Live on. Check connection status for each board and confirm release stops repeated commands. This reduces request load; it does not establish the cause of previous disconnects or guarantee a fix.
