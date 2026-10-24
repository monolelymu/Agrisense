import '../../data/models.dart';

enum ImagePreparation { rgbBilinearAntialiasZeroToOne }

/// Bundled model contract. Provisional preparation requires explicit opt-in here.
class CropModel {
  const CropModel({
    required this.crop,
    required this.modelAsset,
    required this.labelsAsset,
    required this.version,
    required this.sha256,
    required this.classCount,
    this.preparation,
    this.unavailableReason,
    this.testingNotice,
    this.inputSize = 224,
  });
  final Crop crop;
  final String modelAsset, labelsAsset, version, sha256;
  final int inputSize, classCount;
  final ImagePreparation? preparation;
  final String? unavailableReason;
  final String? testingNotice;
  // All exports have float32 NHWC three-channel input and float32 output.
  // The external color/resize contract must be verified separately.
  bool get available => preparation != null && unavailableReason == null;
}

const tomatoModelVersion = 'tomato-b0-4e75ac1379db';
const eggplantTestingNotice =
    'Eggplant photo analysis runs on this device. Choose a clear leaf photo.';
const cropModels = <Crop, CropModel>{
  Crop.tomato: CropModel(
    crop: Crop.tomato,
    modelAsset: 'assets/models/tomato_model.tflite',
    labelsAsset: 'assets/models/tomato_labels.json',
    version: tomatoModelVersion,
    sha256: '4e75ac1379db8e3c90808b4a875ddc2a94b1ae045907aff404c44b1c7c27bdc7',
    classCount: 17,
    preparation: ImagePreparation.rgbBilinearAntialiasZeroToOne,
  ),
  Crop.eggplant: CropModel(
    crop: Crop.eggplant,
    modelAsset: 'assets/models/eggplant_model.tflite',
    labelsAsset: 'assets/models/eggplant_labels.json',
    version: 'eggplant-b0-f715c3c81603',
    sha256: 'f715c3c81603358f2c149da4c873f1ee26ca1b67a14a838c877641a0a46c6334',
    classCount: 9,
    // Uses the shared RGB bilinear antialias resize and /255 pipeline.
    preparation: ImagePreparation.rgbBilinearAntialiasZeroToOne,
    testingNotice: eggplantTestingNotice,
  ),
  Crop.chili: CropModel(
    crop: Crop.chili,
    modelAsset: 'assets/models/chili_model.tflite',
    labelsAsset: 'assets/models/chili_labels.json',
    version: 'chili-b0-a312bad7109e',
    sha256: 'a312bad7109e100c57807afe07bb6dd9b78389772fea698c98a5cc1ca6f14fb0',
    classCount: 6,
    // The supplied calibration tester uses EXIF-corrected RGB, bilinear resize
    // with antialiasing and /255. Logit shifts are baked into the export.
    preparation: ImagePreparation.rgbBilinearAntialiasZeroToOne,
    testingNotice:
        'Chili photo analysis runs on this device. Choose a clear leaf photo.',
  ),
};

bool modelAvailable(Crop crop) => cropModels[crop]?.available ?? false;
String modelStatus(Crop crop) => modelAvailable(crop)
    ? cropModels[crop]!.testingNotice ??
          '${crop.label} photo analysis available.'
    : cropModels[crop]?.unavailableReason ??
          'No disease model installed for ${crop.label}.';
