# Phase 4 progress

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
- D checks/APK: pending.

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

Exact next action: final full Flutter regression suite once, static analysis and
one offline debug APK build. Eggplant activation and actual Android inference
remain pending exact training preprocessing confirmation. Do not remove the gate
based only on the teammate's recollection of notebook ancestry.

Static inspection was repeated on the bundled Eggplant file: one graph,
float32 [1,224,224,3] -> [1,9], hash matches supplied export. The Tomato SHA256
remains ef87a0106a2950b4926bf7bb0de4e1eddf1600fd6aac972c8b12358a91b11665.
Register now includes 26 app sources plus one carried-forward local-context source.
Checkpoint A: e4617d3. No dependencies installed and no push.
