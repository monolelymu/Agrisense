# Tomato model integration

## Baseline and scope
- App baseline: `e681a8f`; no tracked edits at start. Preserve unrelated untracked notebooks, research and imports.
- Phase 1: hardware/settings/usability (`dd89a3d`). Phase 2: alerts/presets (`5bbe820`), automatic diagnosis/background (`6877cca`), acceptance records (`8be8577`).
- Phase 3: 17 Tomato knowledge entries (`1abd7e4`), assessments/history (`9b6468c`), interface (`8b94371`), verification (`faa0fe2`).
- Phase 3.5: notebook work remains untracked/separate. Phase 4: Eggplant research (`e4617d3`), shared pipeline (`d81c04e`), explanations (`feb64a9`), experimental enablement (`7faf9fe`). Chili diagnosis unavailable.
- Phase 5: guidance (`7387a64`), offline recovery (`3197df6`). Phase 6: layouts (`0da6bbd`, `ad55977`), verification/APK (`e681a8f`).
- Recorded baseline checks: 144 Flutter tests pass; analysis clean. Physical phone/ESP32/camera/Wi-Fi/sustained background acceptance remains pending.
- Existing review APK: `build/review/agrisense-phase6-debug-a6327e5d4841.apk`, SHA-256 `a6327e5d484108aca9c1a5a3ae76eabaae4fc01e5b721b5e5d81cb8981a3c6e3`.

## Models and provenance
- Old: `tomato-v1-ef87a0106a29`; SHA-256 `ef87a0106a2950b4926bf7bb0de4e1eddf1600fd6aac972c8b12358a91b11665`.
- New: `tomato-b0-4e75ac1379db`; SHA-256 `4e75ac1379db8e3c90808b4a875ddc2a94b1ae045907aff404c44b1c7c27bdc7`.
- Both hashes verified locally. Old model/labels preserved under repository `.tools/tomato-integration/` (ignored, not packaged). Existing APK retained.
- Export has the identical ordered 17 labels and declared RGB/EXIF/bilinear antialias stretch/224/float32/div255 contract.
- Argon confirms final field-fine-tuned model soup and center-weighted pooling. Bundled training history is stale baseline history; preserve it, do not rewrite as independently verified lineage.
- Argon-reported final validation: 91.67% accuracy / 90.38% macro-F1 (5,488); test: 91.44% / 89.66% (5,301). Matching full final evaluation files not supplied/independently verified.
- Export parity reports 100% top-1 agreement, maximum score difference 0.0031192898750305176, tolerance 0.01, passed. This supersedes report wording of zero difference; it is sample conversion agreement, not diagnostic validation.

## Progress
- Backup/import verification complete. No dependencies or firmware changes.
- Existing Flutter SDK access approved for checks/build. No Android device connected; Android image/tensor inference remains pending, not passed.
- Exact next action: verify supplied tensor preprocessing, integrate only model/catalog, run focused checks then full suite once and analysis, build offline APK and verify packaged hashes.

## Focused checks
- Tomato asset/catalog updated only; ordered labels unchanged. Eggplant hash remains `fe09161efc0cbc5bce233ba47979db781d8cd106a47764f4a67a19ad34c0aad2`. Old review APK hash rechecked unchanged.
- Added export fixtures (PNG, little-endian float32 reference, expected prediction, ordered labels) under `test/fixtures/tomato_export/`; test fixtures are not production assets.
- Supplied PNG through existing decode/preprocessing passes maximum absolute tensor difference <= 0.00001 without changes to preprocessing.
- Focused command: `flutter --suppress-analytics --no-version-check test --no-pub test/tomato_export_test.dart test/tomato_scan_test.dart test/crop_model_pipeline_test.dart --reporter expanded`.
- Initial run: one stale test asserted old catalog version; updated expected version. Rerun: 15 tests pass, including old/new version serialization and existing Hive restart persistence tests.
- Full regression once and analysis now running; logs in `.tools/tomato-integration/`.
- Exact next action: record full test/analysis results before the offline APK build. Android inference remains pending until a device is connected.

## Recovery
Restore old Tomato asset from `.tools/tomato-integration/tomato-old.tflite` and old catalog version/hash in a normal commit, or revert the integration commit. Do not reset history. Old results retain their saved version; no storage migration.

## Pre-build checkpoint
- Full Flutter regression suite ran once: all 147 tests pass (18 seconds reported). Static analysis running separately in the same verification session.
- `git diff --check` passes (Git line-ending notices only).
- Build next: `gradlew.bat --offline --no-daemon :app:assembleDebug --console=plain`, existing Android Studio JBR process-only. Do not install the delivery APK.
- Android tensor/image inference has not run: `adb devices` reported no connected targets. Review APK may be built, but full integration acceptance stays pending that check and physical testing.

## Delivered review build
- Full suite: 147 tests pass. Static analysis: no issues (82.8 seconds). No preprocessing/threshold changes; no dependencies installed.
- Offline Gradle build succeeds in 1m 26s; 151 tasks, 23 executed, 128 up-to-date. Existing Gradle deprecation warnings retained.
- Review APK: `build/review/agrisense-tomato-update-debug-0e4129fd1b6d.apk`. Old Phase 6 APK remains unchanged.
- APK SHA-256: `0e4129fd1b6d2f6168c14b4f5e4b0cd9670dcdda516a99c53a1720c7e1eed780`; size 216,697,565 bytes.
- All four packaged model/label assets hash-match source; Tomato is the new hash, Eggplant remains unchanged. Versioned APK copy retained.
- User reported emulator open, then explicitly requested APK delivery instead of inference testing. No emulator actions or delivery APK installation performed.
- Android supplied-tensor/image inference remains pending. Integration is packaged and locally regression-checked, not fully accepted on Android yet.
- Changed: Tomato binary/catalog version/hash; corresponding old-version assertion; new compatibility tests and four fixture files plus fixture README; this progress document. No firmware/storage/UI/background behavior changes. Preserve all unrelated untracked files.
- Exact next action: user installs/reviews the APK; run supplied example tensor and image on Android (expected top label `bacterial_spot`, all score differences <= 0.01), then real phone/ESP32 acceptance. Argon final full evaluation reports remain outstanding.
