# AgriSense v1.0.11 — hold camera controls

Install AgriSense-v1.0.11.apk over the existing app; keep app data.

- Press and hold a direction to send repeated 5-degree steps, approximately every 200ms when acknowledgements are quick. Slow communication reduces the rate; requests never overlap or build up in a queue.
- Release, move the finger outside the button, leave Camera, background the app, or encounter a failed command to stop repeats. One already accepted step can finish. Resume/reconnect does not restart holding; press again deliberately.
- Short taps still take one step. Center remains a single tap.
- Existing demo-pan-tilt sensor firmware already supports these steps and the 75..105-degree starting limits. No new firmware flash or dependencies are required for this app update.

Changed source: camera_gamepad.dart and focused camera_controls_test.dart. Static analysis passed; 15 camera-control tests passed. No emulator, model changes or hardware tests.

On the kit: hold Left briefly, release and confirm movement stops; repeat Right. Check Center. Do not widen limits until the mount is checked. The upper servo's failure is still unconfirmed: test it unloaded on the lower servo's known-working power/signal connection. This app change does not establish that a faulty servo, wire or mount is fixed.
