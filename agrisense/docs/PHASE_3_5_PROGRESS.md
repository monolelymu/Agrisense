# Phase 3.5 progress

## Scope and current state — 21 October 2026
Self-contained notebook implemented at `agrisense/tools/AgriSense_Training.ipynb`.
Interface updated to `agrisense-sequential-1.1`: six sequential sections, crop/model
dropdowns, explicit saved-run selection, no repeated ACTION changes or run-ID copying.
Helper contract remains `agrisense-shared-1.0`; this interface update does not change
preprocessing, labels or the training recipe. Three separate models, one crop per
runtime. Preserve raw images, supplied notebooks, existing models and app work.

## Checkpoints
- A: portable audit, cleaning, review, protected splits and SSD cache implemented;
  local fixtures pass.
- B: training, resume, evaluation and versioned exports implemented. Actual
  TensorFlow training/conversion/parity verification remains pending in Colab.
- C: self-contained sequential notebook and quick-start guide implemented. Bundled
  candidate provenance is present; original dataset URLs/licenses and consolidated
  paper register still need completion/verification from original source records.
- D: 23 local tests pass. Includes generated notebook syntax/copy consistency,
  synthetic audit→review→SSD flow, saved-review reuse, changed-settings guards,
  training approval, smoke-before-training order and smoke failure stopping training.
  Actual GPU smoke, real dataset review, accuracy and Android checks remain pending.

## Six-section interface
1. Settings, library checks, embedded helpers, Drive and saved-run dropdown.
2. Audit summary and inline contact sheets; completed audit reused in the session.
3. Explicit review approval; saved decisions reused when resuming.
4. Verified SSD copying.
5. Explicit training checkbox; matching smoke trial first, then real training/export.
6. Model paths, version and Drive folder-search link.

Optional model evaluation and personal-photo testing default to off. Never open
the same saved run in two active runtimes. If widgets are unavailable, resume has
an explicit text-ID fallback; no packages are installed automatically.

## Commands and results
Using the existing bundled Python runtime:
```
python agrisense/tools/shared_training/build_notebook.py
python -m unittest discover -s agrisense/tools/shared_training -p test_workflow.py -v
```
23 tests passed. Tests use synthetic images inside the workspace; orchestration
training tests use stubs, not TensorFlow. No app tests/builds required for this change.
No dependencies installed, datasets uploaded/downloaded, remote pushes or app changes.

## Defaults
Tomato 17 labels; Eggplant 9; Chili 6 candidate labels. Chili dataset is not
downloaded or inspected; its source/license must be confirmed by the operator.
B0 default (224), B3 optional Tomato challenger (300). Three warmup, up to ten
fine-tune epochs. Audit mode first, explicit review before training. No automatic
package installation, dataset downloads, Drive mounting locally, or remote push.
Versioned crop/run folders prevent teammates overwriting each other's work.

## Validation constraints
Export follow-up: real Tomato training completed through fine-tune epoch 10
(final epoch validation accuracy 0.8848). The optimized export failed parity:
max score delta 0.1573551 and top-1 agreement 0.9411765. Quantization is a suspected
cause, not confirmed. Default conversion now disables Optimize.DEFAULT and records
float32_unquantized in successful export metadata. Keep the existing tolerance
and require a new parity report; do not bypass failed exports. Recover using
export_saved from finished checkpoints, not a new training run. The user's current
Colab session needs the same one-line helper patch before export_saved. Float32
conversion/runtime parity and Android inference remain pending until executed.

22 October transfer follow-up: user reported a
five-hour Section 4 copy followed by runtime expiry. Removed the up-front stat
of every Drive image. New copies read the source once while hashing, then verify
the local copy before promotion. Existing cache snapshots matching the frozen
manifest hash are reused without reopening Drive images in ready_data (including
Section 5). Changed original files are rejected when a fresh copy is needed;
explicit default cache_images recheck mode retains source-change detection.
Progress starts immediately and reports copied/reused counts and elapsed minutes
after the first file, every 100 files, or 10 seconds between completed files.
Partial/verified copies help only while the same runtime disk survives. Runtime
deletion still requires copying again; no persistent archive/shard cache exists.
26 local tests pass, including source-read counting, source mutation rejection,
verified local snapshot reuse without source reads and corrupt-cache repair.
Real Colab/Drive throughput remains unmeasured; no completion-time promise.

22 October fix: known pre-augmented and other-task exclusions now precede missing
label checks. Their unmapped folders no longer block preparation. Added a fixture
verifying those exclusions while genuinely unknown folders still require review.
Regenerated notebook; 24 local tests pass. Current Colab sessions can explicitly
exclude these flagged images and the two uncertain plantwild tobacco folders from
their saved inventory without rescanning. No automatic tobacco-to-Tomato mapping.

Bundled Python has Pillow and NumPy, but no TensorFlow or sklearn. Use existing
libraries and standard-library tests for cleaning/splits/metrics/cache and notebook
syntax. Actual Colab training/export/parity checks remain pending until run there;
do not claim local syntax checks establish TensorFlow runtime compatibility.

Exact next action: upload the updated notebook to Colab, choose one crop and its
existing Drive dataset, run Sections 1–2, inspect reports, approve Section 3,
prepare Section 4, then use a GPU for the first actual Section 5 compatibility
trial. Resolve runtime failures before full training. Independently complete
original dataset provenance for the paper. Do not claim models trained from local tests.
