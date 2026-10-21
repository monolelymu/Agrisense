# Phase 4: Eggplant references and shared model pipeline

## Current release behavior

- Tomato diagnosis, image preprocessing, top-three scores and model version are
  preserved. Phase 2 monitoring/service logic is unchanged.
- Eggplant has a growing-condition panel and offline **knowledge & care** browser
  covering all nine export labels. Its bundled model is **enabled for experimental
  testing by explicit user request**, using provisional RGB stretch to 224x224,
  antialiased bilinear and float32 /255. Manual/upload/automatic paths share this
  preparation. Training parity and accuracy are unverified; UI and saved result
  versions identify the provisional preparation. Automatic analysis defaults Off.
- Chili retains monitoring; no classifier or crop references have been invented.
- Both crops use the shared result explanation and saved-context display. Legacy
  Tomato records remain readable under the original storage keys and version.
- New Eggplant camera/automatic results retain same-crop sensor context where
  available. Uploads never acquire current sensor data. No Eggplant
  disease exposure rule or sensor-derived probability is adopted.

## Research and paper references

`RESEARCH_REGISTER.json` records stable source IDs, author/organization, year,
URL/DOI, access date, supported claims, crop/labels, sections and verification
limitations. `RESEARCH_BIBLIOGRAPHY.md` is an APA-style working bibliography.
Source IDs also appear in the app. Existing Tomato references and the Phase 3
local-context source are retained. Incomplete author/year details are explicitly
flagged; verify these before paper submission. The previous project proposal and
all earlier conversational sources have not been exhaustively audited.

Eggplant growth: approximately **21.1–29.4 C**, converted from 70–85 F in Virginia
Cooperative Extension's Eggplant publication, Environmental Preferences (2025).
This is a general advisory reference without a day/night split. Humidity and
calibrated soil are displayed without invented suitable percentages. Gas is not
assessed. Same freshness, calibration and device restrictions as Phase 3 apply.

Broad labels `leaf_spot`, `insect_pest` and `wilt` do not identify a pathogen or
species. `downy_mildew` is an unverified Eggplant training label: its entry provides
clearly labeled general background only. The Phomopsis source's laboratory growth
and post-harvest temperatures are not converted into infection thresholds.

## Model verification and enabling Eggplant

The supplied export's exact label order is:
`alternaria_leaf_spot`, `downy_mildew`, `healthy`, `insect_pest`, `leaf_spot`,
`mosaic_virus`, `phomopsis_blight`, `powdery_mildew`, `wilt`.

Static inspection: TFL3, one graph, float32 input [1,224,224,3] and float32 output
[1,9]. Keras architecture is EfficientNetB0 with a 9-unit softmax head and outer
255 rescaling before internal 1/255 rescaling. This strongly suggests external
0–1 input; it does not establish external color, crop or resize behavior.
Model SHA256:
`fe09161efc0cbc5bce233ba47979db781d8cd106a47764f4a67a19ad34c0aad2`.

The teammate recalls using an earlier shared training procedure. The available
corrected notebook is Tomato-specific; recollection and matching architecture
alone cannot verify which image loader produced this Eggplant export.
The earlier `tools/agrisense_training.py` uses RGB decoding and default TensorFlow
resize without explicit antialiasing, and its model lacks the export's outer
255 rescaling layer. The corrected notebook and supplied graph therefore do not
prove that the earlier loader was used unchanged.

Before treating the testing preparation as verified:
1. Obtain the matching loader/inference code or a confirmed preprocessing
   specification: RGB/BGR, crop/stretch, resize method/antialias and normalization.
2. Match the app's preparation to it. Prefer a non-square labeled sample with
   notebook output or prepared pixels for parity; confirm the exact label order.
3. Confirm or correct `preparation` in the Eggplant catalog entry, remove its
   provisional testing notice and update the version only after verification.
4. Run the real Android inference smoke check, then representative unseen labeled
   Eggplant photos. Valid probabilities verify runtime, not diagnostic accuracy.
5. Exercise manual/upload/automatic paths and retain the experimental wording.

## Replacing a model

The authoritative per-crop configuration is `model_catalog.dart`. Replace the
paired model and labels, update the SHA256-derived version, class count and
verified preparation. Update the crop knowledge entries if labels change.
Validate input/output float32 contracts and ordered labels; then rebuild the APK.
There is no model download, installed-app import or automatic model migration.
Old history keeps its original label, score, model version and assessment snapshot.
Knowledge text is the currently bundled reference material, not a frozen claim
about the model's training validity.

## Validation and remaining acceptance

See `PHASE_4_PROGRESS.md` for actual commands/results. No accuracy or calibrated
confidence claim is made. Android Eggplant inference and real phone/board checks
remain pending. Experimental scanning is enabled, with preprocessing still
provisional. No new dependencies, firmware,
native services, segmentation or Bayesian ranking are introduced.
