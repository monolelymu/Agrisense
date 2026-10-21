import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/tomato_assessment.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';

final noon = DateTime(2026, 10, 21, 12);
HardwareSample reading({
  DateTime? at,
  String id = 'a',
  String device = 'sensor-a',
  Crop crop = Crop.tomato,
  double? t = 25,
  double? rh = 70,
  double? soil = 45,
  bool calibrated = true,
}) => HardwareSample(
  id: id,
  deviceId: device,
  crop: crop,
  receivedAt: at ?? noon,
  temperature: t,
  humidity: rh,
  soil: soil,
  soilRaw: 1,
  gasRaw: 4095,
  soilCalibrated: calibrated,
);
TomatoScan prediction({
  String source = 'camera',
  String label = 'early_blight',
}) => TomatoScan(
  id: 'scan',
  timestamp: noon,
  label: label,
  score: .8,
  preview: Uint8List(0),
  modelVersion: 'unchanged',
  source: source,
  predictions: [ScanPrediction(label, .8), const ScanPrediction('healthy', .2)],
);
List<HardwareSample> exposure({double t = 20, double rh = 95}) => List.generate(
  1201,
  (i) => reading(
    id: '$i',
    at: noon.subtract(Duration(seconds: 30 * i)),
    t: t,
    rh: rh,
  ),
);

void main() {
  test('day/night boundaries and inclusive temperature/RH references', () {
    for (final hour in [6, 12, 17]) {
      final at = DateTime(2026, 10, 21, hour);
      expect(
        GrowingConditions.assess(
          reading(at: at, t: 21, rh: 65),
          at,
        ).temperaturePosition,
        ReferencePosition.within,
      );
      expect(
        GrowingConditions.assess(
          reading(at: at, t: 29, rh: 75),
          at,
        ).humidityPosition,
        ReferencePosition.within,
      );
      expect(
        GrowingConditions.assess(
          reading(at: at, t: 29.1),
          at,
        ).temperaturePosition,
        ReferencePosition.above,
      );
      expect(
        GrowingConditions.assess(
          reading(at: at, t: 20.9),
          at,
        ).temperaturePosition,
        ReferencePosition.below,
      );
    }
    for (final hour in [0, 5, 18, 23]) {
      final at = DateTime(2026, 10, 21, hour);
      final c = GrowingConditions.assess(reading(at: at, t: 18), at);
      expect(c.daytime, isFalse);
      expect(c.temperaturePosition, ReferencePosition.within);
      expect(
        GrowingConditions.assess(
          reading(at: at, t: 21.1),
          at,
        ).temperaturePosition,
        ReferencePosition.above,
      );
    }
  });
  test(
    'freshness is exact, rejects future/wrong crop, and preserves missing states',
    () {
      expect(
        GrowingConditions.assess(
          reading(),
          noon.add(const Duration(seconds: 30)),
        ).temperaturePosition,
        ReferencePosition.within,
      );
      for (final sample in [
        null,
        reading(at: noon.add(const Duration(seconds: 1))),
        reading(at: noon.subtract(const Duration(milliseconds: 30001))),
        reading(crop: Crop.chili),
      ]) {
        expect(
          GrowingConditions.assess(sample, noon).temperaturePosition,
          ReferencePosition.unavailable,
        );
      }
      final partial = GrowingConditions.assess(reading(t: null), noon);
      expect(partial.temperaturePosition, ReferencePosition.unavailable);
      expect(partial.humidityPosition, ReferencePosition.within);
      expect(
        GrowingConditions.assess(
          reading(t: double.nan, rh: 101),
          noon,
        ).humidityPosition,
        ReferencePosition.unavailable,
      );
    },
  );
  test('soil requires calibration; no gas assessment is serialized', () {
    expect(
      GrowingConditions.assess(reading(calibrated: false), noon).soil,
      isNull,
    );
    expect(GrowingConditions.assess(reading(soil: 101), noon).soil, isNull);
    final c = GrowingConditions.assess(reading(), noon);
    expect(c.soil, 45);
    expect(c.toJson().keys.any((k) => k.contains('gas')), isFalse);
    expect(c.toJson().keys.any((k) => k.contains('soil_position')), isFalse);
  });
  test('unsupported, partial and current evidence cannot claim infection', () {
    expect(
      assessTomatoEvidence('mosaic_virus', reading(), [], noon).state,
      EvidenceState.notAssessable,
    );
    expect(
      assessTomatoEvidence('unknown-future-label', reading(), [], noon).state,
      EvidenceState.notAssessable,
    );
    expect(
      assessTomatoEvidence('bacterial_spot', reading(t: 28), [], noon).state,
      EvidenceState.partial,
    );
    expect(
      assessTomatoEvidence(
        'early_blight',
        reading(t: 28, rh: 90),
        [],
        noon,
      ).state,
      EvidenceState.currentMatch,
    );
    expect(
      assessTomatoEvidence(
        'early_blight',
        reading(t: 28, rh: 89.9),
        [],
        noon,
      ).state,
      EvidenceState.notMatching,
    );
    expect(
      assessTomatoEvidence('leaf_mold', reading(rh: 85), [], noon).state,
      EvidenceState.partial,
    );
    expect(
      assessTomatoEvidence('early_blight', reading(rh: null), [], noon).state,
      EvidenceState.noContext,
    );
  });
  test('late blight needs full duration and strictly greater than 90 RH', () {
    final rows = exposure();
    final full = assessTomatoEvidence('late_blight', rows.first, rows, noon);
    expect(full.state, EvidenceState.favorableHistory);
    expect(full.observedSeconds, 36000);
    expect(full.averageTemperature, closeTo(20, 1e-9));
    expect(
      assessTomatoEvidence(
        'late_blight',
        rows.first,
        rows.take(1200),
        noon,
      ).state,
      EvidenceState.durationNotEstablished,
    );
    final boundary = exposure(rh: 90);
    expect(
      assessTomatoEvidence('late_blight', boundary.first, boundary, noon).state,
      EvidenceState.durationNotEstablished,
    );
  });
  test(
    'late blight uses average temperature and clips to the exposure window',
    () {
      final rows = exposure();
      for (var i = 0; i < rows.length; i++) {
        rows[i] = reading(
          id: '$i',
          at: rows[i].receivedAt,
          t: i.isEven ? 10 : 30,
          rh: 95,
        );
      }
      final evidence = assessTomatoEvidence(
        'late_blight',
        rows.first,
        rows,
        noon,
      );
      expect(evidence.state, EvidenceState.favorableHistory);
      expect(evidence.averageTemperature, closeTo(20, 1e-9));
      final hot = exposure(t: 35);
      expect(
        assessTomatoEvidence('late_blight', hot.first, hot, noon).state,
        EvidenceState.notMatching,
      );
    },
  );
  test(
    'gaps, missing values and intervening device changes break exposure',
    () {
      final rows = exposure();
      for (final altered in [
        rows.where((r) => r.id != '1').toList(),
        [
          rows.first,
          reading(
            id: 'changed',
            device: 'sensor-b',
            at: noon.subtract(const Duration(seconds: 15)),
          ),
          ...rows.skip(1),
        ],
        [
          rows.first,
          reading(id: '1', at: rows[1].receivedAt, rh: null),
          ...rows.skip(2),
        ],
      ]) {
        expect(
          assessTomatoEvidence('late_blight', rows.first, altered, noon).state,
          EvidenceState.durationNotEstablished,
        );
      }
      final unknown = reading(device: '', rh: 95);
      expect(
        assessTomatoEvidence('late_blight', unknown, rows, noon).state,
        EvidenceState.durationNotEstablished,
      );
    },
  );
  test(
    'duplicates cannot advance exposure; future and other-crop rows are excluded',
    () {
      final duplicates = List.generate(
        1201,
        (i) => reading(
          id: 'cached',
          at: noon.subtract(Duration(seconds: i * 30)),
          rh: 95,
        ),
      );
      expect(
        assessTomatoEvidence(
          'late_blight',
          duplicates.first,
          duplicates,
          noon,
        ).observedSeconds,
        0,
      );
      final rows = exposure();
      final extras = [
        ...rows,
        reading(id: 'future', at: noon.add(const Duration(seconds: 10)), rh: 1),
        reading(id: 'chili', crop: Crop.chili, rh: 1),
      ];
      expect(
        assessTomatoEvidence('late_blight', rows.first, extras, noon).state,
        EvidenceState.favorableHistory,
      );
    },
  );
  test(
    'leaf wetness never inferred from RH, regardless of available history',
    () {
      final rows = exposure(t: 30, rh: 100);
      final evidence = assessTomatoEvidence(
        'target_spot',
        rows.first,
        rows,
        noon,
      );
      expect(evidence.state, EvidenceState.durationNotEstablished);
      expect(evidence.message, contains('leaf wetness'));
    },
  );
  test(
    'optional future or damaged assessments do not break history parsing',
    () {
      expect(TomatoAssessment.tryFromJson({'version': 999}), isNull);
      expect(TomatoAssessment.tryFromJson({'version': 1}), isNull);
      expect(
        TomatoScan.fromJson({
          ...prediction().toJson(),
          'assessment': 'bad',
        }).assessment,
        isNull,
      );
    },
  );
  test(
    'camera/automatic context persists; uploads and old scans stay unassociated',
    () async {
      final dir = await Directory.systemTemp.createTemp('tomato-assessment-');
      Hive.init(dir.path);
      final box = await Hive.openBox<dynamic>('assessment');
      final h = HardwareController(box)..load();
      addTearDown(() async {
        h.dispose();
        await box.close();
        await dir.delete(recursive: true);
      });
      h.assignments[Crop.tomato] = {'sensorId': 'sensor-a'};
      final sample = reading(t: 28, rh: 95);
      h.samples.addAll([
        sample,
        reading(id: 'wrong-device', device: 'b'),
        reading(id: 'future', at: noon.add(const Duration(seconds: 1))),
      ]);
      final scan = h.attachScanContext(prediction(), at: noon);
      expect(scan.sensorContext!['sample_id'], sample.id);
      expect(scan.score, .8);
      expect(scan.modelVersion, 'unchanged');
      expect(scan.rankedPredictions.map((p) => p.label), [
        'early_blight',
        'healthy',
      ]);
      final frozen = scan.assessment;
      await TomatoScanStore(box).save(scan);
      h.samples.clear();
      final saved = TomatoScanStore(box).load().single;
      expect(saved.assessment, frozen);
      final decoded = TomatoAssessment.tryFromJson(saved.assessment)!;
      expect(decoded.conditions.temperature, 28);
      expect(decoded.context, 'Readings preceding camera capture');
      final automatic = h.attachScanContext(
        prediction(source: 'auto'),
        at: noon,
        trigger: sample,
      );
      expect(
        TomatoAssessment.tryFromJson(automatic.assessment)!.context,
        'Alert trigger readings',
      );
      h.samples.add(sample);
      expect(
        h.attachScanContext(prediction(source: 'upload'), at: noon).assessment,
        isNull,
      );
      expect(
        h
            .attachScanContext(
              prediction(),
              at: noon.add(const Duration(seconds: 31)),
            )
            .assessment,
        isNull,
      );
      h.assignments[Crop.tomato] = {'sensorId': 'other'};
      expect(h.attachScanContext(prediction(), at: noon).assessment, isNull);
      final legacy = prediction().toJson()
        ..remove('assessment')
        ..remove('sensor_context');
      expect(TomatoScan.fromJson(legacy).assessment, isNull);
    },
  );
}
