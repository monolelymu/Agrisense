# Chili knowledge and sensor context — 22 October 2026

## Delivered
- Six offline entries in planned export order; all disease rules null.
- General pepper advisory reference 21.1–23.9 C, from the verified Virginia
  Extension Pepper section (70–75 F). No day/night schedule, numerical humidity
  rule or universal soil-moisture target. Regional limitations are displayed.
- Dashboard and diagnosis-screen knowledge navigation; Chili explanations and
  saved growing context are supported without enabling Chili inference.
- Camera context retains assigned-device, same-crop and 30-second freshness
  checks. Automatic context uses the fresh same-crop trigger. Uploads remain
  unlinked; historical assessments retain their saved reference and readings.
- Five Chili research records and bibliography entries added; TM-03 includes
  Chili. Direct TNAU disease pages, source dates and limitations recorded.

## Changed files (relative to agrisense/)
Created:
- lib/features/diagnosis/chili_knowledge.dart
- test/chili_context_test.dart
- docs/CHILI_KNOWLEDGE_PROGRESS.md

Modified:
- lib/features/diagnosis/crop_knowledge_screen.dart
- lib/features/diagnosis/tomato_assessment.dart
- lib/features/diagnosis/tomato_context_widgets.dart
- lib/features/diagnosis/tomato_scan_screen.dart
- lib/features/monitoring/hardware_dashboard.dart
- lib/core/hardware_controller.dart
- docs/RESEARCH_REGISTER.json
- docs/RESEARCH_BIBLIOGRAPHY.md
- test/eggplant_knowledge_test.dart
- test/tomato_context_widgets_test.dart
- test/phase_six_test.dart

Deleted: none. No dependencies changed. No tools/notebooks, model assets,
model catalog, firmware, thresholds or storage schemas changed. Unrelated
untracked work preserved. No build, installation, commit or push performed.

## Commands and verification
Existing Flutter/Dart SDK used with approved external SDK access:
- `dart format` on changed Dart files.
- Focused `flutter --suppress-analytics --no-version-check test --no-pub`
  runs for Chili, knowledge, model pipeline and context widgets. Initial
  failures were stale Chili-exclusion expectations and navigation-test setup;
  corrected expectations, scrolled controls into view and returned from routes.
- `flutter --suppress-analytics --no-version-check analyze --no-pub`:
  no issues found (final run 6.0 seconds).
- `flutter --suppress-analytics --no-version-check test --no-pub --reporter expanded`:
  final full run all 153 tests pass (33 seconds). Ignored log:
  `.dart_tool/chili-regression.log`.
- `git diff --check`: passes (Git line-ending notices only).
- Read-only Git/file inspection and official extension-source verification.

## Remaining limits
Chili model lookup remains null and `modelAvailable(Crop.chili)` remains false;
scan and automatic-inference gates are unchanged. Synthetic scan tests establish
context compatibility, not production Chili inference or accuracy. Physical
phone/ESP32/camera acceptance and a new review APK remain separate work.
