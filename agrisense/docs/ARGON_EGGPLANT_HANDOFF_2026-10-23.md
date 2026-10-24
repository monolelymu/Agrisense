# Argon handoff: complete Eggplant training and plan integration

Date: 23 October 2026 (Asia/Manila)

## Objective and ownership

The user will use their existing Eggplant notebook in Colab. Help them complete the existing run, evaluate the resulting export, and then integrate an acceptable Eggplant model into AgriSense. Preserve the current Tomato and calibrated Chili models and the user's unrelated working changes.

This is a handoff report, not evidence that training has finished. Colab and Drive have not been accessed live. Training observations below come from the supplied ZIP and the notebook's saved output; current remote progress may be newer.

## Current app state

The Flutter Android app already supports crop-specific inference, ordered labels, top-three predictions, scan history, and camera/automatic scan workflows. Eggplant is already enabled using its older model; replacing it should be a localized asset/catalog change, not a classifier rewrite.

| Crop | Bundled version | SHA-256 |
| --- | --- | --- |
| Tomato | `tomato-b0-4e75ac1379db` | `4e75ac1379db8e3c90808b4a875ddc2a94b1ae045907aff404c44b1c7c27bdc7` |
| Chili | `chili-b0-a312bad7109e` | `a312bad7109e100c57807afe07bb6dd9b78389772fea698c98a5cc1ca6f14fb0` |
| Eggplant, older model | `eggplant-v1-fe09161efc0c-provisional-rgb-aa01` | `fe09161efc0cbc5bce233ba47979db781d8cd106a47764f4a67a19ad34c0aad2` |

The Chili logit shifts are already baked into its exported model. Do not apply them again in Dart or transfer those shifts to Eggplant.

The user requested removal of development wording from active app screens. That wording was removed while retaining prediction uncertainty and limitations. The user subsequently requested model versions back in Details; Details now shows each scan's saved `modelVersion`, including historical versions. Preserve both preferences.

Relevant repository files:

- `lib/features/diagnosis/model_catalog.dart`: crop assets, versions, hashes and preprocessing selection.
- `lib/features/diagnosis/tomato_classifier.dart`: shared inference implementation despite its historical class name.
- `lib/features/diagnosis/photo_processing.dart`: photo decoding and EXIF handling.
- `lib/features/diagnosis/tomato_scan.dart`: persisted scan identity, crop and predictions.
- `lib/features/diagnosis/tomato_scan_screen.dart`: scan workflow and saved-version display.
- `assets/models/eggplant_model.tflite` and `assets/models/eggplant_labels.json`: current Eggplant assets.
- `lib/features/diagnosis/eggplant_knowledge.dart`: existing care entries for the nine labels.
- `tools/shared_training/`: local reference implementation; the user's downloaded notebook has additional cells and settings.

## User-provided artifacts

Notebook the user intends to use:

`C:/Users/Samuel/Downloads/(Eggplant)_AgriSense_Training_Optimized.ipynb`

Inspected training archive:

`C:/Users/Samuel/Downloads/20261022T232519Z_0343566a54-20261023T014854Z-1-001.zip`

Saved run ID:

`20261022T232519Z_0343566a54`

Drive run directory:

`/content/drive/MyDrive/AgriSense/models/shared_training/eggplant/20261022T232519Z_0343566a54`

The archive was inspected as data without executing embedded code or extracting the full archive. No app model was replaced from it.

## What the ZIP proves

The main run's `checkpoints/state.json` records:

- Stage `fine_tune`, five completed fine-tuning epochs, `next_epoch: 5`, `finished: false`.
- Latest recorded validation accuracy: approximately 79.03%; validation loss: approximately 0.5954.
- Best checkpoint: `fine_tune_best_epoch_5.keras`.
- Last committed checkpoint: `fine_tune_last_1.keras`.
- Recipe: three warmup epochs, up to ten fine-tuning epochs, early-stopping patience three, batch size 32, seed 42, B0 backbone.

The notebook's saved Section 5 output continues into epoch 6/10, at 43/90 batches. This is a saved snapshot, not a live status indicator. After interruption, resume from the last committed epoch; do not expect mid-epoch batch recovery.

The ZIP contains no `latest_export.json` and no final `exports` package. Its only TFLite export is:

`smoke_exports/e076d610723f/eggplant_model.tflite`

Its metadata explicitly says `smoke_only: true`. Its recorded evaluation was 11.11% accuracy on 18 images, with every image predicted as downy mildew. This is the random-weight compatibility model, not the trained baseline. It was correctly excluded from app integration. Its successful Keras/TFLite parity check does not establish predictive quality.

The recorded dataset audit has 4,104 eligible images. Counts include 176 wilt images and 669 leaf-spot images. The possible near-duplicate report reached its 1,000-pair cap; the audit does not establish exhaustive duplicate removal or independent biological label verification. Consider these limitations when interpreting evaluation results.

## Exact notebook path forward

If Section 5 is currently running successfully in Colab, allow it to finish. Do not launch another runtime against the same saved run.

If execution stopped or the runtime reset:

1. Select a GPU runtime before restoring notebook state.
2. In **Crop, model and project settings**, use `CROP = "eggplant"`, `BACKBONE = "B0"`, and change `RUN_MODE` from its saved `"New run"` value to `"Resume saved run"`.
3. Keep the original settings, including `BASE_DIR = "/content/drive/MyDrive/AgriSense"`, `DATASET_FOLDER = "Eggplant/Original Images"`, folder mappings, seed, epoch limits and batch size. Do not change the resume contract to bypass an error.
4. Run every code cell in Section 1, including label/helper definitions and **Connect Drive and choose a saved run if resuming**. Select `20261022T232519Z_0343566a54` in the saved-run dropdown. `RESUME_RUN_ID` is only the fallback when that dropdown is unavailable.
5. Run Section 2, **Audit or reopen your selected run**.
6. In Section 3, **Confirm your review**, set `REVIEW_APPROVED = False`, leave `EXCLUDE_PATHS = []` and `CAPTURE_GROUPS = {}`, then run the cell. This reuses saved approval/exclusions rather than replacing them. The downloaded notebook currently has the approval flag set to True.
7. Run Section 4, **Verify and copy approved images**.
8. Run Section 5, **Run compatibility check, then train and export**, with `START_TRAINING = True`. It reuses a matching compatibility test and resumes the real checkpoint. Early stopping can validly finish before epoch ten.
9. Wait for training and conversion to finish, then run Section 6, **Show your saved model files**. It must find `latest_export.json` and verify the final model hash.
10. Run **Optional: evaluate a model** with `EVALUATION = "Trained export"` and `REPORT_PARTITION = "Validation"`. Preserve the printed full validation report directory.

If setup reports a contract, checkpoint hash, or environment mismatch, retain the exact error and investigate it. Do not delete checkpoints, edit `state.json` to mark training finished, or switch to a smoke model as a workaround.

## Optional notebook cells: planning decisions

- Section 7's **Centralized Model Tester** uses held-out test rows for its random disease grid. Avoid repeatedly using those test results to adjust training or biases. Use validation and separate development photos for iteration; reserve the final test for the chosen candidate's final report.
- The independent-photo evaluation cell currently has `TEST_PHOTOS = True` and expects an existing `evaluation_photos/photos.csv`. Skip it until those inputs are prepared, or disable the flag when deliberately running that cell. An upload-only tester can be used after export for qualitative inspection; unlabeled uploads do not measure accuracy.
- Section 8's **Universal 1-Click Finisher & Center-Weighted TFLite Export** is optional additional training: six more epochs followed by replacement of spatial pooling with fixed center weights. It requires `checkpoints/selected.keras`, which is created when Section 5 finishes. It is not a shortcut to complete the interrupted baseline.
- Complete and evaluate the baseline first. If the user later chooses Section 8, compare baseline and refined exports on the same validation data and independent development photos. The center-weighting change occurs after refinement training and must be evaluated separately. A successful export or parity check alone does not establish improvement.

## Artifacts needed for the next integration

Ask the user to ZIP the actual final export directory identified by `latest_export.json`, and include the full validation report directory if it is stored outside that export. Prefer the compact export package rather than another ZIP of every checkpoint.

Expected useful contents:

- `eggplant_model.tflite` and the matching `eggplant_labels.json`.
- `metadata.json`, including version, model hash, preprocessing contract, and `smoke_only: false`.
- Export verification reports, preprocessing example, expected input tensor and example predictions where produced.
- Full validation metrics, per-class precision/recall/F1/support and confusion matrix.
- Source provenance and split information; retain `eggplant_model.keras` for future conversion/refinement work.

Expected app contract is float32 NHWC input `[1, 224, 224, 3]`, float32 output `[1, 9]`, EXIF-corrected RGB, bilinear resize with antialiasing and pixel values divided by 255. Verify the actual export rather than relying only on these expected values.

Current ordered labels:

1. `alternaria_leaf_spot`
2. `downy_mildew`
3. `healthy`
4. `insect_pest`
5. `leaf_spot`
6. `mosaic_virus`
7. `phomopsis_blight`
8. `powdery_mildew`
9. `wilt`

Do not silently reorder the file or reuse labels from another export. Investigate changed labels and update care mappings explicitly if needed.

## Integration and verification plan

1. Inspect the final artifact and reports; reject the compatibility-only export. Review class-specific results and errors, including healthy/disease confusion and minority-class recall. No universal numeric acceptance threshold has been agreed with the user.
2. Preserve the currently bundled Eggplant model for rollback before replacement. Verify hashes and record the new export's version/hash in `model_catalog.dart`.
3. Reuse the existing classifier if the contract matches. Do not add dependencies or implement bias correction unless the delivered model actually requires it and its contract supports it.
4. Update model identity/label regression expectations. Retain saved historical model versions; do not relabel old predictions as the new model.
5. Run relevant Flutter tests for assets, crop routing, preprocessing, saved details, Eggplant care/context, and automatic diagnosis. Run `flutter analyze --no-pub` and `git diff --check`.
6. Build an Android APK and inspect its bundled assets against the supplied hashes. Existing successful build command used process-scoped `JAVA_HOME = C:\Program Files\Java\jdk-21` and `flutter build apk --debug --no-pub`.
7. Perform actual Android inference on known photos and compare against export predictions. Exercise upload, assigned-camera capture, automatic alert analysis, history persistence and model-version Details. A build and widget tests do not prove native inference parity or field accuracy.
8. Report the model version, checks completed, unresolved accuracy limitations and APK location. Preserve the user's preference for clear product wording without unsubstantiated accuracy claims.

## Verification already completed before this report

- Before the latest Chili replacement: full Flutter suite passed 162 tests.
- After the calibrated Chili replacement and restoration of Details versions: 36 targeted tests passed, Flutter analysis was clean, and the Android debug APK built successfully.
- The APK's Chili model hash was verified as `a312bad7109e100c57807afe07bb6dd9b78389772fea698c98a5cc1ca6f14fb0`, matching the user-supplied export.
- The new Eggplant model has not been integrated, trained locally, or tested on Android. The ZIP inspection did not alter the existing app model.

Current APK location:

`agrisense/build/app/outputs/flutter-apk/app-debug.apk` (relative to the outer repository root).

## Workspace and handoff boundaries

The repository already contains substantial uncommitted work from the user and previous tasks. Inspect current diffs before editing; do not reset, clean, mass-refactor, overwrite unrelated changes or create a catch-all commit. Work within the repository and follow the user's AGENTS instructions. Do not install new libraries without the required confirmation.

For this report task, the only created file is `docs/ARGON_EGGPLANT_HANDOFF_2026-10-23.md` inside the Flutter project. Read-only commands inspected the current model catalog, Git status, documentation filenames and training resume implementation. No tests were rerun for this documentation-only addition. No dependencies changed and no files were deleted.
