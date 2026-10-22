# Phase 6 — app polish and review APK

## State
Implementation in progress. Dark-green design/navigation retained. No changes to
models, image preparation, scores, uncertainty, monitoring/background behavior,
stored data, firmware or dependencies. Preserve unrelated untracked notebook work.

## Checkpoints
- A: shared layout, Diagnosis/results, wrong-crop guidance — complete.
- B: Dashboard, History, Devices/settings, Help and wording — complete.
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

Checkpoint A commit: `0da6bbd`.

## Checkpoint B
Removed redundant Dashboard crop cards (the existing crop picker stays). Grouped
connection/monitoring status separately from readings. Historical/unavailable and
uncalibrated soil states have explicit wording; raw gas qualification remains.
History has distinct sensor-alert and optional legacy-photo sections, clearer
status/timestamps and safe preview fallbacks. Device tests and disabled reasons
are grouped; advanced board controls stay collapsed/separate. Settings spacing,
baseline timestamp display and Help availability cards are consistent.

The notification warning came from partially visible tile centers, not overflow:
the unchanged test had not asserted a successful toggle. It now centers controls,
checks hitTestable and verifies actual value changes. No warning suppression.
New history-navigation tests needed the same explicit scroll before tapping the
alert at 360 pixels/1.5×; corrected without changing app behavior.

Focused screen/settings command covered phase_six, sensor_notifications, phase_one,
phase_five and preset_editing. All unrelated focused tests passed; one new history
test needed the scroll fix. Rerun of phase_six + sensor_notifications: all 31 pass
without the prior off-screen warning. Covers 360/430/800 widths at 1×/1.5×, saved
long-label scans, stale/missing data, history categories, expired alert originals,
advanced disabled controls, busy/error and unavailable-model states. No network
requests from layout tests. Existing model/preset semantics are unchanged.

Exact next action: full regression suite once, static analysis, preserve the old
APK, update this checkpoint before the offline Gradle build, then build/review/hash
one debug APK. No emulator or installation.
