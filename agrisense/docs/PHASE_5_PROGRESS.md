# Phase 5 — guidance and recovery

## State
Implementation in progress. Preserve model assets/preprocessing, existing history
and tutorial completion storage, automatic monitoring behavior and unrelated work.

## Checkpoints
- A: offline help, tutorial and navigation — complete.
- B: local recovery and regression verification — pending.

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

Exact next action: allow explicit local alert save/analysis recovery without hardware
access, preserve capture/automatic guards, add recovery tests and run focused checks.
