# Phase 4 progress

## Current testing override (2026-10-21)
User explicitly requested enabling Eggplant for testing despite unconfirmed
training preprocessing. This supersedes the earlier activation gate below.
Enabled provisional RGB stretch to 224x224, antialiased bilinear, float32 /255
using the existing pipeline. No accuracy/parity claim. Version now includes
`-provisional-rgb-aa01` so saved testing results remain identifiable. Testing
notice appears on scanning, automatic settings, Dashboard and saved results.
Automatic analysis still defaults Off; users can enable it in monitoring settings.
Exact training preprocessing, Android inference and prediction-quality validation
remain pending. Focused pipeline, interface, scan and automatic tests: 25 passed.
Static analysis passed (no issues); offline APK rebuild passed, exit 0,
`BUILD SUCCESSFUL in 1m 10s`. Checked the packaged kernel includes the provisional
Eggplant version and the model bytes match the supplied export. Existing Gradle
deprecation warnings remain. No dependencies installed or push performed.

Exact next action: install the updated debug APK, select Eggplant, choose a clear
leaf photo and check inference/results/history on Android. Automatic analysis is
available but defaults Off. Actual Android inference and accuracy are not claimed
by these focused tests or APK packaging. Obtain matching training preprocessing
and compare labeled images before treating this preparation as verified.

## Scope
Eggplant research, consolidated research register and bibliography, shared model
metadata/inference, growing context and explanations. Preserve Tomato predictions,
stored results and Phase 2 monitoring. No dependencies, firmware or native service
changes. Local checkpoint commits only; no push.

## Checkpoints
- A research: complete; 9 Eggplant entries, 26 registered app sources and working
  bibliography. Individual author/year details not verified are explicitly flagged.
  Focused knowledge tests: 4 passed (Eggplant and Tomato).
- B shared model pipeline/context: implemented and checked; Eggplant activation
  remains blocked on preprocessing verification. Tomato tensor generation/model
  bytes/version unchanged. 12 pipeline/navigation tests passed after updating an
  expected old availability message. Existing assessment/automatic tests passed
  in the initial grouped run (one navigation-copy expectation failed).
- C interface: complete; 11 Eggplant/Tomato widget tests passed. Existing
  Tomato-only panel expectation updated to include Eggplant, and lazy-list
  scrolling corrected in the new settings test. 9 automatic-diagnosis tests
  passed including a fake verified Eggplant capability with linked history and
  duplicate prevention. Production Eggplant inference remains disabled.
- D verification: full Flutter suite passed once, **117 tests**, exit 0 (38 s
  test time); `flutter analyze --no-pub` reports no issues, exit 0. Offline debug
  APK built successfully (54 s Gradle build, exit 0). Actual Android Eggplant
  inference remains pending; Phase 4 activation/acceptance is not complete.

## Model verification
Supplied `eggplant modes.zip` contains a 9-class float32 TFLite model with input
[1,224,224,3], output [1,9]. SHA256:
`fe09161efc0cbc5bce233ba47979db781d8cd106a47764f4a67a19ad34c0aad2`.
Static Keras/graph inspection suggests external 0–1 normalization; color order,
cropping and resizing are not confirmed. The local notebook is a dataset audit,
not the matching training notebook. Requested teammate confirmation. Diagnosis
must remain disabled until its preprocessing is verified; do not guess.

## Research decisions
Broad labels remain broad. Downy mildew's Eggplant training-label meaning is
unverified; do not substitute a cucurbit disease rule. Eggplant growing reference
is approximately 21–29.4 C (70–85 F), with no invented day/night or RH range.
Sources: TNAU, UC IPM and Virginia Cooperative Extension, accessed 2026-10-21.

## Validation policy
Focused tests per checkpoint; full suite once, static analysis, one offline APK
build. Actual Android inference smoke check is separate from prediction accuracy;
no labeled images/evaluation report supplied. All unavailable acceptance checks
remain pending. Do not stage unrelated C++ test or deliverables.

The teammate recalls deriving the training notebook from an earlier shared
procedure. The corrected Tomato notebook has RGB decoding, resize and 0–1 input,
but that recollection does not establish the exact Eggplant export procedure.
Also inspected `tools/agrisense_training.py` without executing it: its default
resize lacks explicit antialiasing and its earlier graph lacks the export's
outer rescaling layer. This confirms multiple procedure versions exist locally;
do not assume they are equivalent to the supplied model.

Prior gated-release next action (superseded by the testing override above): obtain the matching Eggplant loader/preprocessing confirmation
(color order, crop/stretch, resize/antialias, normalization). Then implement or
select the matching preparation, remove the availability gate, run actual Android
inference and representative labeled photos, and verify manual/automatic paths.
Do not remove the gate based only on recollection of notebook ancestry. The APK
can already be installed to review Eggplant knowledge and growing references.

Static inspection was repeated on the bundled Eggplant file: one graph,
float32 [1,224,224,3] -> [1,9], hash matches supplied export. The Tomato SHA256
remains ef87a0106a2950b4926bf7bb0de4e1eddf1600fd6aac972c8b12358a91b11665.
Register now includes 26 app sources plus one carried-forward local-context source.
Checkpoint A: e4617d3. No dependencies installed and no push.

Checkpoint B: d81c04e; C: feb64a9. Full regression command:
`flutter --suppress-analytics --no-version-check test --no-pub --reporter expanded`.
Output retained locally in `.tools/phase4-tests.log` (ignored, not part of paper).
Static analysis: `flutter --suppress-analytics --no-version-check analyze --no-pub`.
`git diff --check` passes. Only unrelated pre-existing C++ test and deliverables
remain untracked. Preparing build with `gradlew --offline --no-daemon
:app:assembleDebug --quiet`; no dependency installation authorized or needed.

Build recovery: the initial quiet/redirected runner produced an empty log and no
fresh APK. It was stopped; no running build Java process was found. One retry with
`gradlew --offline --no-daemon :app:assembleDebug --console=plain` completed:
`BUILD SUCCESSFUL in 54s`, 151 tasks (23 executed, 128 up-to-date), exit 0.
Existing Kotlin/AGP deprecation and SDK XML-version warnings did not fail the
build; no dependency or native configuration changes were made to suppress them.
APK: `build/app/outputs/apk/debug/app-debug.apk`. Both packaged model files and
label counts were checked against source assets; Tomato has 17 classes, Eggplant
9. No emulator, board simulator or physical phone was started. Runtime/accuracy
acceptance is explicitly pending, not inferred from unit tests or packaging.

All source changes are saved locally. Research sites were contacted through web
search/read tools only (TNAU, UC IPM, Virginia Cooperative Extension, PMC; public
extension searches). No private model/data was uploaded. No dependencies installed,
firmware changes, new services, remote push or unexpected background processes.
