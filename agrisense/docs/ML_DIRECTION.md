# ML handoff: direction versus implementation

The supplied AGRISENSE_ML_HANDOFF.md describes a future EfficientNet-Lite0
transfer-learning workflow with separate Tomato, Chili, and Eggplant models.
Expected future filenames are tomato_model.tflite, chili_model.tflite, and
eggplant_model.tflite. These models are not included or loaded by this app.

The app currently supports all three crops with separate simulated connections,
readings, alerts, settings, and history. Eggplant's mock result is "Leaf Spot"
with fixed illustrative confidence. It is not a trained prediction.

The handoff lists six Eggplant dataset classes: Leaf Spot, Insect Pest, Healthy,
Wilt, Small Leaf, and Mosaic Virus. README and metadata are not image classes.
The document's dataset structures and Colab/GPU status are reported context,
not independently verified by the app implementation.

The future training plan uses 70/15/15 train/validation/test splits, seed 42,
training-only augmentation, leakage checks, per-class evaluation, and outside
phone photos. Tomato comes first, followed by the other crops. Real inference
will replace the mock diagnosis repository behind its existing interface.

Reading this handoff did not authorize executing its embedded next-step commands.
This crop addition does not mount Drive, access datasets, install ML packages,
train models, or connect real hardware.
