# Offline example photos

These 16 JPEG files were copied, unmodified, from the friend's FloraScan project
with the user's explicit permission on 2026-10-29. FloraScan was not modified.

Source: `FloraScan/mobile/assets/pathology_reference/`.
FloraScan's `ml/scripts/extract_reference_photos.py` describes extracting these
512-by-512 examples from its labelled training-data folders. Their original
dataset/image ownership and diagnostic labels have not been independently
verified. These are illustrative examples, not verified diagnostic ground truth.

`lib/features/diagnosis/disease_example.dart` explicitly maps supported crop and
model labels to files. Generic categories (insect pest, leaf spot, wilt, nutrient
deficiency) show one supplied example, not every cause in that category.
Conditions without a matching supplied example have no example button; no image
from another condition is substituted. Photos are bundled for offline use and
are not supplied to the model or used for calibration.
