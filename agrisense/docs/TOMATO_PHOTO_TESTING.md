# Experimental tomato photo diagnosis

The Android app opens to a crop-aware dashboard with Diagnosis, History and
Devices navigation. Only Tomato currently has a model; Chili and Eggplant
cannot start analysis. Demo mode opens the existing simulated workspace,
initialized only when requested. Real scans are stored under `tomato-photo-v1/`
keys in the existing local Hive box, separately from demo history. Reset demo
does not remove real scans. Uninstalling or clearing app data removes both.

## Input and model

- `assets/models/tomato_model.tflite`
- SHA-256: `ef87a0106a2950b4926bf7bb0de4e1eddf1600fd6aac972c8b12358a91b11665`
- Ordered labels: `assets/models/tomato_labels.json` (17 classes)
- RGB float32 `[1, 224, 224, 3]`, values in `[0, 1]`
- EXIF orientation is applied, then a separable bilinear antialiasing resize
  using half-pixel centers. Numerical parity with TensorFlow still needs
  confirmation using shared reference images and notebook outputs.
- JPEG/PNG only; up to 15 MB, 24 megapixels, and 12,000 pixels per side.
- The model runs in a worker isolate; no network inference is used.

The screen shows the leading prediction plus the top three model scores for
new scans. Uncertain results retain their predicted class. Older records that
only saved one score display that score without inventing runners-up.
Technical information appears under Details. Segmentation and combination
of original/white-background scores are not implemented yet. A score below
60% is shown as uncertain, following the notebook's provisional threshold.
This threshold is not calibrated. High scores do not verify crop identity,
image quality, or the diagnosis. No treatment recommendations are generated.

Each new saved record includes the crop, top three classes and scores,
timestamp, model version, and a
JPEG preview up to 512 pixels on its longest side. The original gallery image
is not modified. Save failures retain the prediction and offer a retry.

## Android manual verification

1. Open the app and select a known tomato JPEG/PNG from the gallery.
2. Confirm a result appears and reports that it was saved.
3. Open the entry under History. It opens in Diagnosis for the selected crop.
4. Restart the app and confirm that the image and result persist.
5. Cancel a photo selection and confirm the previous result remains.
6. Try an unsupported/oversized image and confirm an actionable error.
7. Open Demo mode, reset demo data, and confirm real scans remain.
8. Compare the same photo with the notebook's TFLite tester. Record top class,
   scores, and runtime. No real-photo accuracy or parity claim is made until
   this comparison is performed.

Hardware connections and crop/device assignments are not implemented in this
phase. The normal dashboard and Devices screen show no device connected,
without simulated sensor readings or a working hardware-capture button.

The test suite covers preprocessing invariants, local persistence across box
reopen/demo history reset, and uncertain-result presentation. It does not
replace on-device model execution and real-photo validation.
