# Tomato export compatibility fixture

Supplied by the project team in export `3dc196602a01` on 2026-10-22.
Model SHA-256: `4e75ac1379db8e3c90808b4a875ddc2a94b1ae045907aff404c44b1c7c27bdc7`.

`expected_input.f32`: 1 x 224 x 224 x 3, little-endian float32 NHWC RGB,
EXIF-oriented, bilinear antialias stretch, divided by 255.
`preprocessing_example.png` is its supplied source example.
`example_prediction.json` records the export's expected output; it is a
compatibility reference, not an independently verified disease annotation.
`tomato_labels.json` preserves the export output order.

These are test-only files and are not declared Flutter production assets.
The Dart test checks preprocessing at maximum absolute difference 0.00001.
Android inference on both the reference tensor and decoded image is still
required; compare all scores within 0.01 and require the same top label.
