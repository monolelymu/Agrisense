import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/model_catalog.dart';
import 'package:agrisense/features/diagnosis/photo_processing.dart';
import 'package:agrisense/features/diagnosis/tomato_classifier.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Tomato export catalog and ordered labels match verified contract', () {
    final model = cropModels[Crop.tomato]!;
    expect(model.version, 'tomato-b0-4e75ac1379db');
    expect(
      model.sha256,
      '4e75ac1379db8e3c90808b4a875ddc2a94b1ae045907aff404c44b1c7c27bdc7',
    );
    expect(model.classCount, 17);
    expect(modelAvailable(Crop.chili), isFalse);
    expect(modelAvailable(Crop.eggplant), isTrue);
    final labels = jsonDecode(File(model.labelsAsset).readAsStringSync());
    final exportedLabels = jsonDecode(
      File('test/fixtures/tomato_export/tomato_labels.json').readAsStringSync(),
    );
    expect(labels, exportedLabels);
  });

  test('export example preprocessing agrees with supplied float32 tensor', () {
    final image = decodeLeafPhoto(
      File(
        'test/fixtures/tomato_export/preprocessing_example.png',
      ).readAsBytesSync(),
    );
    final actual = preprocessTomato(image);
    final expected = ByteData.sublistView(
      File('test/fixtures/tomato_export/expected_input.f32').readAsBytesSync(),
    );
    expect(expected.lengthInBytes, actual.length * 4);
    var maxDifference = 0.0;
    for (var i = 0; i < actual.length; i++) {
      maxDifference = math.max(
        maxDifference,
        (actual[i] - expected.getFloat32(i * 4, Endian.little)).abs(),
      );
    }
    // Keep the export contract's strict preprocessing tolerance.
    expect(
      maxDifference,
      lessThanOrEqualTo(0.00001),
      reason: 'max tensor difference: $maxDifference',
    );
  });

  test(
    'history retains both old and new model versions across serialization',
    () {
      for (final version in ['tomato-v1-ef87a0106a29', tomatoModelVersion]) {
        final scan = TomatoScan(
          id: version,
          timestamp: DateTime(2026, 10, 22),
          label: 'bacterial_spot',
          score: .9,
          preview: Uint8List(0),
          modelVersion: version,
        );
        expect(TomatoScan.fromJson(scan.toJson()).modelVersion, version);
      }
    },
  );
}
