# Phase 6 — app polish and review APK

## State
Phase 6 complete; review APK available. Dark-green design/navigation retained. No changes to
models, image preparation, scores, uncertainty, monitoring/background behavior,
stored data, firmware or dependencies. Preserve unrelated untracked notebook work.

## Checkpoints
- A: shared layout, Diagnosis/results, wrong-crop guidance — complete.
- B: Dashboard, History, Devices/settings, Help and wording — complete.
- C: full tests once, static analysis, offline debug APK, versioned copy/hash — complete.

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

## Checkpoint C — pre-build recovery checkpoint
Checkpoint B commit: `ad55977`.
- Full regression ran once: `flutter --suppress-analytics --no-version-check test
  --no-pub --reporter expanded` — all 144 tests pass (42 seconds reported).
  Log `.tools/phase6-tests.log` has no Warning/off-screen-hit messages.
- Static analysis: `flutter --suppress-analytics --no-version-check analyze --no-pub`
  — no issues found (11.5 seconds). Log `.tools/phase6-analyze.log`.
- Previous APK preserved at `agrisense/build/review/agrisense-before-phase6-debug-608f588f68b9.apk`.
  SHA-256: `608f588f68b95c9e4bf7835473fb743eb7b393a4514a569f7fd200115fc65acb`.
- No dependencies installed, no model/native/service/storage changes and no emulator.

Exact next action: run `gradlew.bat --offline --no-daemon :app:assembleDebug
--console=plain` from `agrisense/android`, using Android Studio's existing JBR for
this process only. Then verify packaged model/label bytes against source, preserve
a versioned review copy, report its SHA-256 and save checkpoint C locally. Do not
push, start an emulator or install the APK.

## Checkpoint C — final result
- The single offline Gradle build succeeded in 2m 40s: 151 tasks, 36 executed,
  115 up-to-date. No dependency installation/download. Existing Java native-access,
  Kotlin/AGP deprecation and SDK XML-version warnings were retained; no toolchain,
  security settings or dependencies changed to suppress them.
- APK: `agrisense/build/review/agrisense-phase6-debug-a6327e5d4841.apk`
- SHA-256: `a6327e5d484108aca9c1a5a3ae76eabaae4fc01e5b721b5e5d81cb8981a3c6e3`
- Size: 216,697,855 bytes. Original standard output also remains at
  `agrisense/build/app/outputs/apk/debug/app-debug.apk`.
- ZIP CRC integrity passed. Packaged Tomato/Eggplant models and ordered label
  files match source bytes; label counts remain 17/9. Model hashes remain
  `ef87a0106a2950b4926bf7bb0de4e1eddf1600fd6aac972c8b12358a91b11665`
  and `fe09161efc0cbc5bce233ba47979db781d8cd106a47764f4a67a19ad34c0aad2`.
- APK includes ARM64, ARMv7 and x86-64 Flutter libraries. Phase 6 “Analyzing as”
  wording is present in the packaged debug kernel. The versioned copy hash matches.
- Artifact manifest: `agrisense/build/review/phase6-review.json`; build log:
  `.tools/phase6-build.log`. These build/test artifacts remain ignored by Git.
- Previous APK backup retained. No emulator startup, installation, firmware/model
  changes, remote push or new persistent process. Only local checkpoint commits.

Exact next action: user reviews the APK on their emulator/phone using PHASE_6.md.
Physical phone/ESP32/background acceptance and model reliability remain Phase 7
and separate model work. No Phase 6 implementation blockers remain.
