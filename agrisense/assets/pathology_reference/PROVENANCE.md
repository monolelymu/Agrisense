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
The v1.0.15a update adds 16 references, covering all 32 current crop-label entries.
No image from another crop or condition is substituted. Photos are bundled for
offline use and are not supplied to the model or used for calibration.

`SOURCES.json` records each file's author, source, download URL, licence statement,
SHA-256 and caption. Each photo also has an expandable source credit in the app.
Downloaded files are unchanged. The app downsamples decoded previews to limit
memory use; it does not crop, recolour, generate or alter the reference photos.

New sources: PlantVillage (CC BY-SA 3.0), Goldlocki/Wikimedia Commons
(CC BY-SA 3.0), Downtowngal/Wikimedia Commons (CC0), Scot Nelson/Flickr
(CC0), and Ahmad, Roy and Hasan's Mendeley eggplant dataset (CC BY 4.0).
Tomato nitrogen deficiency comes from Gehlot, Saxena and Gandhi's publicly
provided Tomato-Village research dataset. Its repository does not specify a
standalone image licence; permission for wider redistribution/commercial use
has not been established. The 16 original FloraScan images also retain the
unverified original-rights limitation above.

Dataset labels are illustrative, not independent laboratory confirmation.
In particular, the eggplant downy-mildew image follows the dataset's label; its
pathogen identity is unverified. The app explicitly says so and retains the
existing knowledge limitation. Tomato spotted wilt uses a fruit symptom photo,
clearly captioned as fruit; whitefly uses immature stages, including parasitized
stages, clearly captioned. Pepper powdery mildew can vary between varieties.
