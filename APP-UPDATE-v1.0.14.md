# AgriSense v1.0.14 — simple scan guidance

Android version name `1.0.14`, version code `15` (also set in pubspec.yaml).

## Changes

- One optional **See example** button opens the saved photo and an offline
  reference example. Sixteen explicit crop/label matches are supported.
  Other conditions receive no unrelated substitute image. The comparison
  remains in a dismissible sheet rather than a new navigation screen.
  The sheet keeps 24 px outer padding and 8/16 px content spacing, with a
  permanently visible **Back to result** button below the scrolling photos.
- A short explanation uses only the sensor assessment saved with the capture.
  Missing/unsupported context and uploaded photos remain photo-only. A mismatch
  does not rule out an older infection; agreement does not confirm disease.
- Uncertain predictions request another clear photo. If saved sensor evidence
  also conflicts, the retake explanation says so. Strong predictions are retained.
- Models, scores, uncertainty threshold, firmware, connectivity, polling and
  dependencies are unchanged. No calibration or disease re-ranking was introduced.

## Files

- Modified: `agrisense/pubspec.yaml`, `simple_result_card.dart`,
  `tomato_scan_screen.dart` (the latter two under `lib/features/diagnosis/`).
- Added: `lib/features/diagnosis/disease_example.dart`, `scan_guidance.dart`,
  `test/scan_guidance_test.dart`, and 16 JPEGs plus provenance notes under
  `assets/pathology_reference/` (all relative to `agrisense/`).
- No files deleted. FloraScan was read/copied from with permission, not modified.

## Validation

- `dart --suppress-analytics analyze lib test/scan_guidance_test.dart`: no issues.
- `flutter test --no-pub test/scan_guidance_test.dart test/simple_ui_test.dart
  test/tomato_context_widgets_test.dart test/tomato_assessment_test.dart
  test/camera_controls_test.dart test/crop_model_pipeline_test.dart`:
  58 passed, one existing legacy dashboard test failed.
- The same failing test, **growing panel supports researched crops without
  starting monitoring**, was reproduced from checkpoint `9bd3234` in an isolated
  folder. It expects a GrowingConditionsPanel absent from the existing simple
  Home UI. No unrelated dashboard/test rewrite was made.
- New tests check unchanged diagnoses/scores, upload and legacy-context handling,
  disagreement/retake behavior, offline asset decoding and label matching, missing
  mappings, and the comparison sheet at 320 px with 1.5x text.
- The final eight scan-guidance tests passed separately, including an assertion
  that Back to result is visible without scrolling at large text size.
- `git diff --check` and targeted Dart formatting were run.
- Android release build passed using `gradlew.bat assembleRelease --offline
  --no-daemon --console=plain` with the existing JDK 21. Build properties were
  prepared for version `1.0.14`, code `15`; the APK manifest was independently
  verified with `aapt dump badging`.
- Both old/new APK signatures passed `apksigner verify --print-certs`, with
  matching signing certificates. The final APK contains all 16 JPEG assets.
- Installer: `AgriSense-v1.0.14.apk` at repository root. SHA-256:
  `F07345897AB2817859EC0AEA4AD94FE628A94DCF3EB829752F77F082938AB10E`.
  Install over the existing app without uninstalling. APKs remain local artifacts,
  rather than large binary additions to Git.
- No physical kit or phone validation was performed. Reference images are
  illustrative supplied labels, not independently verified diagnostic truth.

## Rollback

Previous app: **v1.0.13, build 14**. GitHub source checkpoint:
<https://github.com/monolelymu/Agrisense/commit/9bd3234>.

The local original installer `AgriSense-v1.0.13.apk` is preserved. SHA-256:
`6F713BCF8667001E20564DC40852E196F874884CDA37C99BE725A1ECD9ED427C`.

To roll back without deleting phone history, rebuild checkpoint `9bd3234` using
the same application ID/signing key and a version code higher than the installed
one, for example `--build-name=1.0.13 --build-number=16` after build 15. Alternatively,
revert this feature commit and rebuild with the higher code. Do not uninstall
the app to downgrade if local records must be preserved. See ROLLBACK-v1.0.13.md.
