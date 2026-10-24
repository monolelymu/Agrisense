# Shared training notebook — quick start

Upload only `agrisense/tools/AgriSense_Training.ipynb` to Colab. Python helpers are
embedded; no separate `.py` uploads. Each teammate uses a separate runtime/crop.
The dataset must already be extracted in Drive.

## Six sections, in order

1. **Choose settings and connect Drive.** Select crop and B0. Set the Drive base
   and dataset folders. Example: base `/content/drive/MyDrive/AgriSense`, dataset
   `eggplant`. Choose New run. Run every code cell here, including collapsed helper
   cells, and approve Google's Drive prompt.
2. **Check the dataset.** Run the audit. Read counts and sample review sheets below
   the cell. Full reports and CSV image paths stay in the printed Drive folder.
3. **Review and approve.** Check obvious unrelated photos, collages and folder
   mistakes. Enter exclusions if needed, tick REVIEW_APPROVED, then run. No biological
   diagnosis required. Chili also requires checking its downloaded files/source/license.
4. **Prepare images on Colab SSD.** Run to verify hashes and copy eligible images.
   Original files remain intact; reviewed splits and decisions stay in Drive.
   Progress shows verified/copied/reused counts and elapsed minutes. Missing files
   are copied with a single source read. Hash-verified local snapshots are reused
   during training without rereading their originals from Drive. This does not
   preserve SSD files after a runtime is deleted; copying may need repeating.
5. **Train the model.** Use a GPU, tick START_TRAINING and run. The tiny compatibility
   trial runs first; only if it passes does real training/export proceed. Compatible
   checkpoints are saved. The smoke model is never for the app.
6. **Results and model files.** Run to see the export folder and its Drive search
   link. Get `<crop>_model.tflite`, labels and metadata for integration. Keep the
   `.keras` model and reports for future model work.

Sections 3 and 5 deliberately pause until approved. After approving, continue
downward; no ACTION switching or repeating the whole notebook is needed. Optional
evaluation/photo tools can be skipped on the first run.

## After disconnection or changing runtime

Reopen the notebook, restore the same crop/paths/settings, select **Resume saved
run**, and run Section 1. Choose your run in the dropdown. Run Section 2. In
Section 3, leave approval unticked to reuse the saved decisions, then run Sections
4–5, ticking training when ready. SSD copies may need rebuilding. Matching smoke
results/checkpoints are reused; incompatible settings are rejected. Never share
one saved run between two active runtimes.

## Evaluation

Use the optional Trained export evaluation for full validation metrics. Reserve
Final test for the chosen candidate's final report. Follow the notebook's CSV
example for independent phone/ESP32 photos; unknown labels stay blank.

Export-verification metrics cover a small compatibility subset, not final accuracy.
Actual Colab/GPU training/export and Android inference remain pending until run.
