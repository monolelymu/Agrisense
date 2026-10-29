# AgriSense v1.0.15e — readable sensor trends

APK: `AgriSense-v1.0.15e.apk`, Android versionName `1.0.15e`, versionCode 21. Flutter source version: `1.0.15-e+21`. Install over the existing app to preserve local history/settings; signing certificate matches v1.0.15d.

## Changes

- Last 24 hours uses a shorter line chart with smaller dots. Long gaps remain blank. Time labels sit below the plot, use readable AM/PM times and reduce in number when space or text scaling requires it. Sub-two-minute records show seconds. Date information is above the chart and in touch details.
- Last 7/30 days uses daily low–high range bars with an average dot. Empty days stay blank. All-time spans longer than 31 calendar days use explicitly labeled multi-day ranges, capped at about 30 buckets to keep the overview readable.
- Fewer than three readings show a short list instead of a largely empty chart. Repeated readings at one instant also use a summary.
- Latest recorded value and its timestamp lead the card. Lowest/highest appear below the chart; counts and sample averages move into expandable Reading details. Statistics describe recorded readings, not continuous coverage or a time-weighted average.
- Axis spacing accounts for larger text. Tooltips stay inside the chart, and the distracting vertical touch stem is removed. Soil percentages still require calibrated values; no raw reading is relabeled as a percentage.

## Files

Created `agrisense/lib/features/monitoring/sensor_trend_card.dart` and `agrisense/test/sensor_trend_card_test.dart`. Modified the Trends section/import in `agrisense/lib/features/monitoring/hardware_dashboard.dart`, its integration test in `agrisense/test/dashboard_records_test.dart`, and version in `agrisense/pubspec.yaml`. Generated Android local build-version properties and normal build outputs updated. Created this note and the APK; preview fixtures and metadata are under `output/trends-redesign/`. No source files deleted. Existing unrelated app edits were preserved.

## Verification and commands

- `dart --suppress-analytics format` on the four affected Dart files.
- `dart --suppress-analytics analyze` on those files: no issues.
- `flutter test --no-pub --dart-define=TREND_PREVIEWS=true test/sensor_trend_card_test.dart test/dashboard_records_test.dart --reporter expanded`: all 10 tests passed. Tests cover sparse data, gap preservation, bounded tooltips, daily aggregation/averages, missing days, large text, multi-day all-time aggregation, 31-calendar-day rolling windows, period switching, crop filtering, records and persistence behavior.
- Layout fixtures rendered at a 390-logical-pixel phone width and 1.6 text scaling. These use Flutter's test font for geometry checks; they are not native-font phone screenshots. Real-device review remains needed.
- `gradlew.bat assembleRelease --offline --no-daemon --console=plain` with process-scoped existing Java 21: success. No dependency installation. Existing Gradle/Kotlin deprecation warnings remain.
- SDK `apksigner verify --print-certs`: new APK valid, same public certificate SHA-256 as v1.0.15d: `6bc1cc146c0af99cb155bc6ebe04001aad6965ad3306ca1986aeb4d5a01ec6b8`.
- SDK `aapt dump badging`: application `com.example.agrisense`, versionName `1.0.15e`, versionCode 21.
- Python standard-library ZIP/hash checks: all 32 reference images and 3 TFLite models byte-identical to v1.0.15d; new chart text exists in each packaged architecture; ZIP CRC validation passed.

The existing Dart runtime/Flutter tool snapshot was used directly to avoid the wrapper stalling. Flutter test/build tooling required access to the existing SDK lock/cache; automatic review allowed the test/build commands. No global configuration or setup scripts were changed. No hardware access, firmware changes, new dependencies, model changes, data migration or Git commits/pushes.

APK size: 155,160,806 bytes. SHA-256: `b017d90c5ad93c6ff15a8a01fa62f6c142e33b2e55da53ed714d0958d0ee1666`. Metadata: `output/trends-redesign/release.json`.
