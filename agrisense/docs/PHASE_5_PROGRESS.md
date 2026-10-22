# Phase 5 — guidance and recovery

## State
Phase 5 complete. Preserve model assets/preprocessing, existing history
and tutorial completion storage, automatic monitoring behavior and unrelated work.

## Checkpoints
- A: offline help, tutorial and navigation — complete.
- B: local recovery and regression verification — complete.

## Verification policy
Focused widget tests for A; fake-hardware recovery tests for B. Run full Flutter
suite once and static analysis at completion. No dependencies, emulator or APK
build. Local checkpoint commits only; no push.

## Checkpoint A results
Implemented catalog-derived crop status, six offline topics, focused error expansion,
updated four-step tutorial and Diagnosis Help. Dashboard consumes typed HelpDestination
results under its existing polling pause, retaining crop selection for all shortcuts.
Tutorial completion storage and model processing are unchanged. Corrected phone versus
board cooldown text without changing validators.

Focused commands: `flutter test --no-pub test/phase_five_test.dart test/phase_one_test.dart`.
Existing seven Phase 1 tests passed. Two new navigation tests initially waited on a
native image-picker call unavailable in widget tests; use Linux target variants for
navigation (matching existing scan navigation tests). Rerun of Phase 5: all seven pass,
including narrow layout at 1.5× text. Dart formatter passed. SDK bookkeeping needed
sandbox approval; no dependencies installed or SDK upgrade performed. Flutter emitted
its built-in available-update notice on the first test; subsequent commands disable
the version check.

Checkpoint A local commit: `7387a64`.

## Checkpoint B focused results
Local save/analysis retry no longer requires hardware HTTP access; capture retries
retain access and assignment guards. Automatic processing and lifecycle/concurrency
guards are preserved. Stable IDs/reconciliation still prevent duplicates. Alert UI
explains expired originals/unavailable models and retains a pending-save action
when scan storage succeeded but alert completion failed.

`flutter --no-version-check test --no-pub test/automatic_diagnosis_test.dart test/phase_five_test.dart`
passed all 22 focused tests. Added offline saving/analysis, failure persistence,
idempotence, missing original/model, capture guards, foreground/busy restrictions,
automatic hardware-access interruption and alert recovery messaging checks.

## Final checks
`flutter --no-version-check test --no-pub --reporter expanded` ran once: all 130
tests passed (35 seconds reported by the runner). A non-fatal off-screen tap warning
occurred in the unchanged notification-settings enlarged-text test; no assertion
failed. Flag that test's interaction/layout for Phase 6 review rather than hiding
the warning or changing unrelated settings UI here.

`flutter --no-version-check analyze --no-pub`: no issues found (122 seconds).
Diff whitespace checks pass. No dependency/model/manifest
changes, no emulator startup, APK build or remote push. Physical checks remain
pending for release verification, as planned.

Exact next action: Phase 6 UI polish, starting with cramped layouts and the flagged
notification-settings test interaction. No Phase 5 implementation blockers remain.
APK/phone/ESP32 acceptance belongs to the later release-verification checkpoint.
