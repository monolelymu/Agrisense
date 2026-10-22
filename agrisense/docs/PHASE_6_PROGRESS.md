# Phase 6 — app polish and review APK

## State
Implementation in progress. Dark-green design/navigation retained. No changes to
models, image preparation, scores, uncertainty, monitoring/background behavior,
stored data, firmware or dependencies. Preserve unrelated untracked notebook work.

## Checkpoints
- A: shared layout, Diagnosis/results, wrong-crop guidance — complete.
- B: Dashboard, History, Devices/settings, Help and wording — pending.
- C: full tests once, static analysis, offline debug APK, versioned copy/hash — pending.

## Verification
Focused screen tests during development; final full regression once and static
analysis. Test 360/430/800-pixel widths, including 1.5× text, long labels, unavailable
models, saved/missing sensor data and recovery states. Investigate notification
checkbox hit-test warning instead of suppressing it. One offline Gradle debug build,
preserving the old APK first. No emulator startup or automatic installation.

## Checkpoint A
Responsive shared title blocks, phone card padding (16), spacing, readable tags,
48-pixel button/icon targets and wider-screen heading styles. Diagnosis groups
crop/photo actions and shows “Analyzing as” plus the matching-crop instruction.
Result scores precede uncertainty, ranked labels wrap/stack, longer knowledge is
expandable, and duplicate save retry actions are removed. Input bytes, scores,
models and classification thresholds are untouched.

Focused command: `flutter --no-version-check test --no-pub test/phase_six_test.dart
test/tomato_context_widgets_test.dart test/eggplant_context_widgets_test.dart
test/tomato_scan_test.dart --reporter expanded` — all 26 tests pass. New coverage
includes 360/430/800 widths at 1× and 1.5× text, long predictions, score/uncertainty
order and unavailable Chili analysis. Existing explanation tests explicitly open
the new disclosure before checking content. Formatting and whitespace checks pass.

Exact next action: polish Dashboard/History/device settings and Help spacing,
investigate the notification checkbox hit target, then save checkpoint B.
