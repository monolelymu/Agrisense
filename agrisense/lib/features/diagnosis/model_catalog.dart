import '../../data/models.dart';

enum ImagePreparation { rgbBilinearAntialiasZeroToOne }

/// Bundled model contract. Unknown preprocessing fails closed.
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
    this.inputSize = 224,
  });
  final Crop crop;
  final String modelAsset, labelsAsset, version, sha256;
  final int inputSize, classCount;
  final ImagePreparation? preparation;
  final String? unavailableReason;
  // Both current exports use float32 NHWC RGB input and float32 softmax output.
  bool get available => preparation != null && unavailableReason == null;
}

const tomatoModelVersion = 'tomato-v1-ef87a0106a29';
const cropModels = <Crop, CropModel>{
  Crop.tomato: CropModel(
    crop: Crop.tomato,
    modelAsset: 'assets/models/tomato_model.tflite',
    labelsAsset: 'assets/models/tomato_labels.json',
    version: tomatoModelVersion,
    sha256: 'ef87a0106a2950b4926bf7bb0de4e1eddf1600fd6aac972c8b12358a91b11665',
    classCount: 17,
    preparation: ImagePreparation.rgbBilinearAntialiasZeroToOne,
  ),
  Crop.eggplant: CropModel(
    crop: Crop.eggplant,
    modelAsset: 'assets/models/eggplant_model.tflite',
    labelsAsset: 'assets/models/eggplant_labels.json',
    version: 'eggplant-v1-fe09161efc0c',
    sha256: 'fe09161efc0cbc5bce233ba47979db781d8cd106a47764f4a67a19ad34c0aad2',
    classCount: 9,
    // The graph implies 0–1 input, but external resize/crop/color is unconfirmed.
    unavailableReason:
        'Eggplant model is installed. Photo preparation still needs verification before analysis can be enabled.',
  ),
};

bool modelAvailable(Crop crop) => cropModels[crop]?.available ?? false;
String modelStatus(Crop crop) => modelAvailable(crop)
    ? '${crop.label} photo analysis available · Experimental.'
    : cropModels[crop]?.unavailableReason ??
          'No disease model installed for ${crop.label}.';
