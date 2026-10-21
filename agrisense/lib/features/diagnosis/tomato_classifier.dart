import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'tomato_scan.dart';
import 'photo_processing.dart';
export 'photo_processing.dart' show maxPhotoBytes;
import '../../data/models.dart';
import 'model_catalog.dart';
export 'model_catalog.dart' show tomatoModelVersion;

// Retain the public class name for existing controller injection and test fakes.
class TomatoClassifier {
  bool supports(Crop crop) => modelAvailable(crop);

  Future<TomatoScan> classifyCrop(Crop crop, Uint8List photo) {
    if (!supports(crop)) {
      throw StateError('Model not available: ${modelStatus(crop)}');
    }
    return crop == Crop.tomato ? classify(photo) : _classifyCrop(crop, photo);
  }

  Future<TomatoScan> classify(Uint8List photo) =>
      _classifyCrop(Crop.tomato, photo);

  Future<TomatoScan> _classifyCrop(Crop crop, Uint8List photo) async {
    final metadata = cropModels[crop];
    if (metadata == null || !metadata.available) {
      throw StateError('Model not available: ${modelStatus(crop)}');
    }
    if (photo.isEmpty || photo.length > maxPhotoBytes) {
      throw const FormatException('Choose a photo smaller than 15 MB.');
    }
    final model = await rootBundle.load(metadata.modelAsset);
    final labels =
        (jsonDecode(await rootBundle.loadString(metadata.labelsAsset)) as List)
            .cast<String>();
    return compute(_classify, (
      photo,
      model.buffer.asUint8List(model.offsetInBytes, model.lengthInBytes),
      labels,
      metadata,
    ));
  }
}

TomatoScan _classify((Uint8List, Uint8List, List<String>, CropModel) request) {
  final (bytes, model, labels, metadata) = request;
  final image = decodeLeafPhoto(bytes);
  final input = switch (metadata.preparation) {
    ImagePreparation.rgbBilinearAntialiasZeroToOne => preprocessTomato(
      image,
      size: metadata.inputSize,
    ),
    null => throw StateError('Model preprocessing is unverified.'),
  };
  final interpreter = Interpreter.fromBuffer(model);
  try {
    final inputTensor = interpreter.getInputTensor(0);
    final outputTensor = interpreter.getOutputTensor(0);
    if (!listEquals(inputTensor.shape, [
          1,
          metadata.inputSize,
          metadata.inputSize,
          3,
        ]) ||
        inputTensor.type != TensorType.float32 ||
        !listEquals(outputTensor.shape, [1, labels.length]) ||
        outputTensor.type != TensorType.float32 ||
        labels.length != metadata.classCount ||
        labels.any((label) => label.trim().isEmpty) ||
        labels.toSet().length != labels.length) {
      throw StateError(
        'The ${metadata.crop.label} model and labels are incompatible.',
      );
    }
    final output = [List<double>.filled(labels.length, 0)];
    interpreter.run(input.buffer, output);
    final scores = output.single;
    if (scores.any((s) => !s.isFinite || s < 0 || s > 1) ||
        (scores.reduce((a, b) => a + b) - 1).abs() > .01) {
      throw StateError('The model returned invalid prediction scores.');
    }
    final ranked = List.generate(scores.length, (i) => i)
      ..sort((a, b) {
        final order = scores[b].compareTo(scores[a]);
        return order == 0 ? a.compareTo(b) : order;
      });
    final best = ranked.first;
    final now = DateTime.now();
    return TomatoScan(
      id: now.microsecondsSinceEpoch.toString(),
      timestamp: now,
      label: labels[best],
      score: scores[best],
      preview: leafPreview(image),
      modelVersion: metadata.version,
      crop: metadata.crop,
      predictions: ranked
          .take(3)
          .map((i) => ScanPrediction(labels[i], scores[i]))
          .toList(),
    );
  } finally {
    interpreter.close();
  }
}

/// TensorFlow resize convention: half-pixel centers and a widened triangle
/// filter when downsampling (bilinear, antialias=true), then RGB / 255.
Float32List preprocessTomato(img.Image image, {int size = 224}) {
  List<List<(int, double)>> weights(int source) {
    final scale = source / size;
    final support = math.max(1.0, scale);
    return List.generate(size, (target) {
      final center = (target + .5) * scale - .5;
      final taps = <(int, double)>[];
      var total = 0.0;
      for (
        var i = math.max(0, (center - support).ceil());
        i <= math.min(source - 1, (center + support).floor());
        i++
      ) {
        final weight = math.max(0.0, 1 - (i - center).abs() / support);
        taps.add((i, weight));
        total += weight;
      }
      return taps.map((tap) => (tap.$1, tap.$2 / total)).toList();
    });
  }

  final horizontal = weights(image.width);
  final vertical = weights(image.height);
  final rows = Float32List(image.height * size * 3);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < size; x++) {
      final offset = (y * size + x) * 3;
      for (final (sourceX, weight) in horizontal[x]) {
        final pixel = image.getPixel(sourceX, y);
        rows[offset] += pixel.rNormalized * weight;
        rows[offset + 1] += pixel.gNormalized * weight;
        rows[offset + 2] += pixel.bNormalized * weight;
      }
    }
  }
  final result = Float32List(size * size * 3);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      for (final (sourceY, weight) in vertical[y]) {
        for (var c = 0; c < 3; c++) {
          result[(y * size + x) * 3 + c] +=
              rows[(sourceY * size + x) * 3 + c] * weight;
        }
      }
    }
  }
  return result;
}
