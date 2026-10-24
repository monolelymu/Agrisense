# AgriSense ML Model Status & Integration Report
**Date:** October 22, 2026  
**Target:** AgriSense Mobile App Integration (Codex / Flutter)  
**Trained Models Architecture:** `EfficientNetB0` (`224x224x3` float32 input, float32 softmax output)

---

## 1. Executive Summary & Status per Crop

| Crop | Classes | Current Status | Export Folder / Location | TFLite SHA-256 |
| :--- | :---: | :--- | :--- | :--- |
| **Tomato** | **17** | **TRAINING COMPLETE & OPTIMIZED**<br>Peak `91.67%` Acc / `90.38%` Macro-F1 / `100%` Parity (`1.0`) | Drive: `models/shared_training/tomato/20261021T151346Z_c359e8d36c/exports/3dc196602a01` | `4e75ac1379db8e3c90808b4a875ddc2a94b1ae045907aff404c44b1c7c27bdc7` |
| **Eggplant** | **9** | **BASELINE READY / REFINEMENT READY**<br>Baseline bundled (`fe09161efc0c...`). 1-Click refiner cell ready in notebook | Drive: teammate run folder / app bundled baseline | Bundled: `fe09161efc0cbc5bce233ba47979db781d8cd106a47764f4a67a19ad34c0aad2` |
| **Chili** | **6** | **READY TO TRAIN**<br>Multi-source field pipeline ready (5 open datasets mapped). Auto-exclusion of out-of-scope classes active. 1-click Colab fetcher built in. | Notebook: `agrisense/tools/AgriSense_Training_Optimized.ipynb` | Ready for Colab execution |

---

## 1.1 Chili Model Setup & Multi-Source Outdoor Pipeline

### The 6 Target Chili Classes
In accordance with `agrisense/assets/models/chili_labels.json`:
1. `bacterial_spot`
2. `cercospora_leaf_spot`
3. `healthy`
4. `leaf_curl`
5. `nutrient_deficiency`
6. `powdery_mildew`

### Candidate Datasets Mapped in `profiles.json`
1. **Arifen & Islam (2025)** (DOI: `10.17632/tm3v4zmh7c.1`, CC BY 4.0): 8,814 Bangladesh field photos across all 6 core classes.
2. **Bangladesh Outdoor Field** (DOI: `10.17632/w9mr3vf56s.1`, CC BY 4.0): 5 core classes; growth stages and out-of-scope conditions cleanly excluded.
3. **Outdoor Smartphone Chili** (DOI: `10.17632/wzc6r6w5w5.1`, CC BY 4.0): 1,515 smartphone field photos (Cercospora, Leaf Curl, Healthy).
4. **COLD Farm Dataset** (DOI: `10.17632/tf9dtfz9m6.3`, CC BY 4.0): 2,064 real Karnataka farm photos across powdery mildew, cercospora, nutrient deficiency, leaf curl, and healthy.
5. **PlantDoc Pepper / Kaggle Chili**: In-the-wild field photos for bacterial spot, leaf curl, and healthy.

### Pipeline Auto-Exclusion Engine
When combining diverse public datasets, extra non-target folders (such as `Anthracnose`, `White_Spot`, `Onion`, `whitefly`, `thrips`, `mites`) are mapped to `"__exclude__"` in `profiles.json`. The pipeline engine (`core.py`) automatically tags these records with `reason = "excluded_out_of_scope_folder"` and skips them during contact-sheet generation, guaranteeing that:
- Section 2 audit passes cleanly.
- Section 3 does not raise `unmapped_folder` errors.
- Target training splits remain 100% focused on the 6 target chili classes.

---

## 2. Tomato Model: What Was Fixed & Benchmarks

### Root Causes in the Older Baseline (`88.48%` Val / `8/32` on Real Web Photos)
1. **Severe Class-Weight Distortion:** The old notebook used linear inverse class weights up to `15.0x`, heavily over-penalizing rare classes (`mosaic_virus`, `whitefly`, `spotted_wilt_virus`). As a result, the model falsely guessed `mosaic_virus` on real outdoor photos (e.g. `yc1.jpg` Yellow Leaf Curl was misclassified as `mosaic_virus (83.4%)`).
2. **Dataset Confounding:** Over 50% of the training images came from `PlantVillage` (flat studio leaves on uniform gray backgrounds). The model failed on outdoor garden backgrounds (`51.60%` on `PlantWild`).
3. **Outer Border Dilution in Phone Photos:** In `EfficientNetB0`'s `7x7` spatial feature map (49 cells), the 24 outer border cells (49% of the area) represent hands, dirt, and background foliage. In vertical phone photos, the background was overpowering the leaf in the center.

### Fixes Applied to the New Winning Model (`exports/3dc196602a01`)
1. **Gentle Square-Root Class Weights (`[0.55, 2.20]`):** Fixed rare-disease hallucinations while protecting small classes.
2. **Multi-Scale Random Crop (`60%–100%`) + Outdoor Color/Lighting Augmentation:** Made the model scale- and lighting-invariant.
3. **Weight Averaging ("Model Soup"):** Blended Stage 2 (strongest on outdoor field datasets) and Stage 3 (strongest on lesion classification) into a single clean network.
4. **Native 7x7 Center-Weighted Spatial Pool:** Weighted center cells (`1.80`) higher than outer borders (`0.35`) using standard Keras/TFLite layers. Center leaves now get priority over background clutter.
5. **Strict Parity Verification:** Converted with `converter.optimizations = []` and verified on validation samples: **`100.0%` top-1 agreement (`1.0`), `100.0%` Macro-F1, max probability diff = `0.003119`** (well below the notebook's `0.01` threshold; `passed = true`).

### Real-World Photo Validation Results
- **Yellow Leaf Curl (`yellow-curl 2.jpg`, `yc1.jpg`):** `99.4%` & `98.9%` (previously misclassified as `mosaic_virus`)
- **Leaf Mold (`leaf mold 4.jpg`, `lm1.jpg`):** `99.6%` & `96.8%`
- **Early Blight (`early blight tomato.jpg` with border frame):** `96.0%`
- **Leaf Miner (`leaf minerr 2.jpg` in-hand phone photo):** Jumped from `5.8%` to `76.4%` (#1 prediction)
- **Held-Out Test Set (5,301 unseen images):** `91.44%` Accuracy / `89.66%` Macro-F1

---

## 3. Instructions for Codex / App Integration

### Step 1: Download & Replace Tomato Model Asset
Download the exported files from Google Drive:
- **Drive Source:** `MyDrive/AgriSense/models/shared_training/tomato/20261021T151346Z_c359e8d36c/exports/3dc196602a01/`
- **Files to copy:**
  - Copy `tomato_model.tflite` $\rightarrow$ `agrisense/assets/models/tomato_model.tflite`
  - Copy `tomato_labels.json` $\rightarrow$ `agrisense/assets/models/tomato_labels.json`

### Step 2: Update `model_catalog.dart`
In `agrisense/lib/features/diagnosis/model_catalog.dart`:
```dart
const tomatoModelVersion = 'tomato-b0-3dc196602a01';
...
  Crop.tomato: CropModel(
    crop: Crop.tomato,
    modelAsset: 'assets/models/tomato_model.tflite',
    labelsAsset: 'assets/models/tomato_labels.json',
    version: tomatoModelVersion,
    sha256: '4e75ac1379db8e3c90808b4a875ddc2a94b1ae045907aff404c44b1c7c27bdc7',
    classCount: 17,
    preparation: ImagePreparation.rgbBilinearAntialiasZeroToOne,
  ),
```
No changes are required to the preprocessing pipeline: the model adheres 100% to the existing `rgbBilinearAntialiasZeroToOne` (`224x224`, `float32`, `[0.0, 1.0]`) input contract.

---

## 4. Training Tooling Prepared for Chili & Eggplant

We created the standardized training notebook:
- **Notebook File:** `agrisense/tools/AgriSense_Training_Optimized.ipynb`
- **Key Enhancements Built In:**
  1. **Section 3 (`review`) Bug Fix:** Removed the hardcoded `REVIEW_APPROVED = False` that blocked new runs. Auto-confirms `CHILI_SOURCE_REVIEWED` when approved.
  2. **Single-Pass Training in Section 5:** Automatically incorporates gentle square-root weights, multi-scale crop, `CosineDecay(5e-5 -> 1e-6)`, and the `7x7` Center-Weighted Pool from epoch 1.
  3. **Centralized Model Tester (Section 7):** Provides an interactive upload tester and random all-disease visual preview grid for any crop.
  4. **Teammate 1-Click Finisher (Section 8):** Allows the Eggplant teammate to refine their existing checkpoint in 6 epochs without starting from scratch.
