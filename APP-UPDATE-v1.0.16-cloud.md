# AgriSense v1.0.16a-cloud — Remote Cloud Telemetry & Control (Consensus Fix Release)

APK: `AgriSense-v1.0.16a-cloud.apk`, Android versionName `1.0.16a-cloud`, versionCode 23. Flutter source version: `1.0.16-a+23`. Size: 154,724,986 bytes. SHA-256: `5681afdef9bcf9eb3e516b582a5576a8cbf13d365a6d5644ee211d1c53b0cf87`. Install over the existing app to preserve local history/settings; signing certificate matches v1.0.15e/v1.0.15d.

## Fixes in v1.0.16a-cloud

1. **Persistent Hive Auth Storage:**
   - App's default `FirebaseCloudClient` is connected to persistent Hive box (`firebase-anon-auth-v1`).
   - Anonymous credentials and refresh tokens persist across app restarts without re-authenticating every session.
2. **Form-Encoded Token Refresh:**
   - Google Secure Token endpoint (`https://securetoken.googleapis.com/v1/token`) is called with `application/x-www-form-urlencoded` (`grant_type=refresh_token&refresh_token=...`) per OAuth2/Firebase specification.
3. **Dual Freshness Protection:**
   - Server-timestamp verification (`uploaded_at_ms`): On initial read or session start, rejects any reading older than 45 seconds immediately, preventing stale telemetry display from offline kits.
   - Live sample tracking (`sample_id`): Rejects readings if `sample_id` fails to update for > 30 seconds during continuous polling.
4. **Target Device Validation & Clean Test Interface:**
   - Maintained strict 1-positional parameter signature `Future<Uint8List> capture(String address)` on `HardwareClient`, preserving compatibility across all test suites and mock subclasses.
   - Stored and tracked `lastVerifiedCameraId` automatically upon camera identity discovery.
5. **Zero New Dependencies & Complete Test Pass:**
   - `dart analyze`: Clean, 0 issues found across all modified files.
   - Flutter tests: All 49 tests passed (8 cloud client tests, 9 kit discovery tests, 8 camera control tests, 18 hardware transport tests, 3 dashboard records tests, 3 sensor trend tests).

## Accepted Demo Limitations

- **SetInsecure TLS on ESP32:** Camera board has no RTC and neither board blocks on NTP; certificate dates are not verified on ESP32.
- **One-Phone Priority:** No distributed lease/lock negotiation; demo runs with single primary controller phone.
- **Private Scan History Stays Local:** History is preserved locally in Hive (`TomatoScanStore`) without uploading photos to cloud database.
- **Open Authenticated Demo-Kit Access:** Access restricted to authenticated clients (`auth != null`) under `/kits/demo` during defense demo.
