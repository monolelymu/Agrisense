import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/model_catalog.dart';
import 'package:agrisense/features/diagnosis/tomato_classifier.dart';
import 'package:agrisense/features/diagnosis/tomato_assessment.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';

final at = DateTime(2026, 10, 21, 12);
HardwareSample sample({
  Crop crop = Crop.eggplant,
  double t = 25,
  DateTime? time,
}) => HardwareSample(
  id: '${crop.name}-1',
  crop: crop,
  deviceId: 'egg-sensor',
  receivedAt: time ?? at,
  temperature: t,
  humidity: 80,
  soil: 50,
  soilCalibrated: true,
  soilRaw: 1000,
  gasRaw: 4095,
);
TomatoScan prediction({String source = 'camera'}) => TomatoScan(
  id: 'egg-scan',
  timestamp: at,
  label: 'wilt',
  score: .71,
  preview: Uint8List(0),
  modelVersion: 'eggplant-original-version',
  crop: Crop.eggplant,
  source: source,
  predictions: const [
    ScanPrediction('wilt', .71),
    ScanPrediction('healthy', .2),
  ],
);

void main() {
  test(
    'model metadata matches ordered label files and bundled model identity',
    () {
      expect(cropModels[Crop.chili], isNull);
      expect(modelAvailable(Crop.tomato), isTrue);
      expect(modelAvailable(Crop.eggplant), isFalse);
      expect(modelStatus(Crop.eggplant), contains('verification'));
      expect(cropModels[Crop.tomato]!.version, 'tomato-v1-ef87a0106a29');
      for (final m in cropModels.values) {
        final labels =
            jsonDecode(File(m.labelsAsset).readAsStringSync()) as List;
        expect(labels.length, m.classCount);
        expect(labels.toSet().length, m.classCount);
        final bytes = File(m.modelAsset).readAsBytesSync();
        expect(ascii.decode(bytes.sublist(4, 8)), 'TFL3');
        expect(m.sha256.length, 64);
      }
      final egg = jsonDecode(
        File(cropModels[Crop.eggplant]!.labelsAsset).readAsStringSync(),
      );
      expect(egg, [
        'alternaria_leaf_spot',
        'downy_mildew',
        'healthy',
        'insect_pest',
        'leaf_spot',
        'mosaic_virus',
        'phomopsis_blight',
        'powdery_mildew',
        'wilt',
      ]);
    },
  );

  test(
    'unknown preprocessing and absent crops cannot reach inference',
    () async {
      final classifier = TomatoClassifier();
      for (final crop in [Crop.eggplant, Crop.chili]) {
        expect(classifier.supports(crop), isFalse);
        expect(
          () => classifier.classifyCrop(crop, Uint8List(1)),
          throwsStateError,
        );
      }
    },
  );

  test(
    'Eggplant uses its own general reference with fresh same-crop readings',
    () {
      for (final hour in [0, 12, 23]) {
        final time = DateTime(2026, 10, 21, hour);
        final c = GrowingConditions.assess(
          sample(time: time),
          time,
          crop: Crop.eggplant,
        );
        expect(c.minimumTemperature, 21.1);
        expect(c.maximumTemperature, 29.4);
        expect(c.temperaturePosition, ReferencePosition.within);
        expect(c.humidityPosition, ReferencePosition.unavailable);
        expect(c.humidity, 80);
        expect(c.soil, 50);
      }
      for (final t in [21.1, 29.4]) {
        expect(
          GrowingConditions.assess(
            sample(t: t),
            at,
            crop: Crop.eggplant,
          ).temperaturePosition,
          ReferencePosition.within,
        );
      }
      expect(
        GrowingConditions.assess(
          sample(t: 21),
          at,
          crop: Crop.eggplant,
        ).temperaturePosition,
        ReferencePosition.below,
      );
      expect(
        GrowingConditions.assess(
          sample(t: 30),
          at,
          crop: Crop.eggplant,
        ).temperaturePosition,
        ReferencePosition.above,
      );
      expect(
        GrowingConditions.assess(
          sample(),
          at.add(const Duration(seconds: 31)),
          crop: Crop.eggplant,
        ).temperature,
        isNull,
      );
      expect(
        GrowingConditions.assess(
          sample(crop: Crop.tomato),
          at,
          crop: Crop.eggplant,
        ).temperature,
        isNull,
      );
      expect(
        assessCropEvidence(Crop.eggplant, 'wilt', sample(), [], at).state,
        EvidenceState.notAssessable,
      );
    },
  );

  test(
    'Eggplant saved assessments keep crop, device, version, ranking and original context',
    () async {
      final dir = await Directory.systemTemp.createTemp('eggplant-context-');
      Hive.init(dir.path);
      final box = await Hive.openBox<dynamic>('egg');
      final h = HardwareController(box, clock: () => at);
      addTearDown(() async {
        h.dispose();
        await Hive.close();
        await dir.delete(recursive: true);
      });
      h.assignments[Crop.eggplant] = {'sensorId': 'egg-sensor'};
      h.samples.addAll([sample(crop: Crop.tomato), sample()]);
      final scan = h.attachScanContext(prediction(), at: at);
      final assessment = TomatoAssessment.tryFromJson(scan.assessment)!;
      expect(assessment.conditions.crop, Crop.eggplant);
      expect(assessment.referenceVersion, startsWith('eggplant-'));
      expect(assessment.evidence.state, EvidenceState.notAssessable);
      await TomatoScanStore(box).save(scan);
      h.samples.clear();
      final saved = TomatoScanStore(box).load().single;
      expect(saved.modelVersion, 'eggplant-original-version');
      expect(saved.predictions.map((p) => p.label), ['wilt', 'healthy']);
      expect(saved.assessment, scan.assessment);
      expect(saved.score, .71);
      expect(
        h.attachScanContext(prediction(source: 'upload'), at: at).assessment,
        isNull,
      );
      expect(
        h
            .attachScanContext(
              prediction(source: 'auto'),
              at: at,
              trigger: sample(crop: Crop.tomato),
            )
            .assessment,
        isNull,
      );
      expect(
        h
            .attachScanContext(
              prediction(source: 'auto'),
              at: at,
              trigger: sample(),
            )
            .assessment,
        isNotNull,
      );
      h.assignments[Crop.eggplant] = {'sensorId': 'other'};
      h.samples.add(sample());
      expect(h.attachScanContext(prediction(), at: at).assessment, isNull);
      final legacyConditions = assessment.conditions.toJson()..remove('crop');
      expect(GrowingConditions.fromJson(legacyConditions).crop, Crop.tomato);
    },
  );
}
