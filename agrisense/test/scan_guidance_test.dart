import 'dart:convert';

import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/disease_example.dart';
import 'package:agrisense/features/diagnosis/scan_guidance.dart';
import 'package:agrisense/features/diagnosis/simple_result_card.dart';
import 'package:agrisense/features/diagnosis/tomato_assessment.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';
import 'package:agrisense/features/diagnosis/reference_photo_credits.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

final _at = DateTime(2026, 10, 29, 12);

TomatoScan _scan({
  EvidenceState? evidence,
  double score = .5,
  String source = 'camera',
  String label = 'early_blight',
  Crop crop = Crop.tomato,
}) => TomatoScan(
  id: 'test',
  timestamp: _at,
  label: label,
  crop: crop,
  score: score,
  preview: Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2))),
  modelVersion: 'unchanged',
  source: source,
  predictions: [
    ScanPrediction(label, score),
    const ScanPrediction('healthy', .2),
  ],
  assessment: evidence == null
      ? null
      : TomatoAssessment(
          referenceVersion: 'test',
          context: 'Readings preceding camera capture',
          conditions: GrowingConditions.assess(null, _at, crop: crop),
          evidence: EnvironmentalEvidence(evidence, 'Saved evidence'),
        ).toJson(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all sensor explanations preserve the saved diagnosis and scores', () {
    for (final state in EvidenceState.values) {
      final scan = _scan(evidence: state);
      final before = jsonEncode(scan.toJson());
      expect(scanSensorSummary(scan), isNotEmpty);
      expect(scanRetakeGuidance(scan), contains('another clear photo'));
      expect(jsonEncode(scan.toJson()), before);
    }
  });

  test(
    'uploads never use a sensor assessment, including saved legacy data',
    () {
      final scan = _scan(source: 'upload', evidence: EvidenceState.notMatching);
      expect(scanSensorSummary(scan), startsWith('Photo-only result.'));
      expect(scanRetakeGuidance(scan), isNot(contains('did not match')));
    },
  );

  test('missing and unknown-version context stay photo-only', () {
    final scan = _scan();
    expect(scanSensorSummary(scan), startsWith('Photo-only result.'));
    final legacy = TomatoScan.fromJson({
      ...scan.toJson(),
      'assessment': {'version': 999},
    });
    expect(scanSensorSummary(legacy), startsWith('Photo-only result.'));
  });

  test('agreement does not confirm disease; mismatch cannot rule it out', () {
    expect(
      scanSensorSummary(_scan(evidence: EvidenceState.currentMatch)),
      contains('do not confirm'),
    );
    expect(
      scanSensorSummary(_scan(evidence: EvidenceState.notMatching)),
      contains('older infection is still possible'),
    );
    for (final state in [
      EvidenceState.partial,
      EvidenceState.durationNotEstablished,
    ]) {
      expect(scanSensorSummary(_scan(evidence: state)), contains('not enough'));
    }
  });

  test(
    'each reference matches a current model label and decodes offline',
    () async {
      final expected = <(Crop, String)>{};
      for (final crop in Crop.values) {
        final labels =
            jsonDecode(
                  await rootBundle.loadString(
                    'assets/models/${crop.name}_labels.json',
                  ),
                )
                as List;
        expected.addAll(labels.cast<String>().map((label) => (crop, label)));
      }
      expect(expected.length, 32);
      expect(diseaseExamples.keys.toSet(), expected);
      for (final item in diseaseExamples.entries) {
        final (crop, label) = item.key;
        final labels =
            jsonDecode(
                  await rootBundle.loadString(
                    'assets/models/${crop.name}_labels.json',
                  ),
                )
                as List;
        expect(labels, contains(label));
        expect(item.value, startsWith('${crop.name}_'));
        final data = await rootBundle.load(
          'assets/pathology_reference/${item.value}',
        );
        expect(img.decodeImage(data.buffer.asUint8List()), isNotNull);
        expect(referencePhotoCredits[item.value], isNotEmpty);
      }
    },
  );

  testWidgets(
    'uncertain mismatch asks for a retake; strong result is retained',
    (tester) async {
      Future<void> show(double score) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SimpleResultCard(
                scan: _scan(evidence: EvidenceState.notMatching, score: score),
              ),
            ),
          ),
        ),
      );
      await show(.5);
      expect(
        find.textContaining('image is uncertain and the sensor'),
        findsOneWidget,
      );
      await show(.9);
      expect(find.text('Possible Early Blight'), findsOneWidget);
      expect(
        find.textContaining('Please take another clear photo'),
        findsNothing,
      );
      expect(find.text('90.0%'), findsOneWidget);
    },
  );

  testWidgets('example opens offline with large text on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: DiseaseExampleButton(
            scan: _scan(crop: Crop.eggplant, label: 'downy_mildew'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('See example'));
    await tester.pumpAndSettle();
    expect(find.text('Your photo'), findsOneWidget);
    expect(find.text('Reference example'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('Example photo unavailable.'), findsNothing);
    expect(
      find.textContaining('disease identity on eggplant is unverified'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Photo source'));
    await tester.tap(find.text('Photo source'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hasnain Ahmad'), findsOneWidget);
    final back = find.text('Back to result');
    expect(back.hitTestable(), findsOneWidget);
    await tester.ensureVisible(back);
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text('Your photo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmapped conditions never receive an unrelated example', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DiseaseExampleButton(scan: _scan(label: 'unsupported_condition')),
      ),
    );
    expect(find.text('See example'), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: DiseaseExampleButton(
          scan: _scan(crop: Crop.chili, label: 'early_blight'),
        ),
      ),
    );
    expect(find.text('See example'), findsNothing);
  });

  test(
    'saved measurements retain units and reject unrelated or stale context',
    () {
      TomatoScan withSample({
        bool calibrated = false,
        int age = 0,
        Crop crop = Crop.tomato,
        String source = 'camera',
      }) => TomatoScan.fromJson({
        ..._scan(source: source).toJson(),
        'sensor_context': HardwareSample(
          id: 'sample',
          crop: crop,
          receivedAt: _at.subtract(Duration(seconds: age)),
          temperature: 26.5,
          humidity: 61.2,
          soil: calibrated ? 42.5 : null,
          soilRaw: 2300,
          gasRaw: 400,
          soilCalibrated: calibrated,
        ).toJson(),
      });
      expect(
        scanSensorMeasurements(withSample()),
        contains('Soil moisture: 2300 raw'),
      );
      expect(
        scanSensorMeasurements(withSample()),
        contains('Air temperature: 26.5 °C'),
      );
      expect(
        scanSensorMeasurements(withSample()),
        contains('Humidity: 61.2% RH'),
      );
      expect(
        scanSensorMeasurements(withSample(calibrated: true)),
        contains('Soil moisture: 42.5%'),
      );
      expect(scanSensorMeasurements(withSample(age: 31)), isEmpty);
      expect(scanSensorMeasurements(withSample(age: -1)), isEmpty);
      expect(scanSensorMeasurements(withSample(crop: Crop.chili)), isEmpty);
      expect(scanSensorMeasurements(withSample(source: 'upload')), isEmpty);
      final invalid = TomatoScan.fromJson({
        ...withSample().toJson(),
        'sensor_context': {'temp_c': 99},
      });
      expect(scanSensorMeasurements(invalid), isEmpty);
    },
  );

  testWidgets('all 32 labels retain collapsed guidance on uncertain results', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final (crop, label) in diseaseExamples.keys) {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SimpleResultCard(
                key: ValueKey('$crop-$label'),
                scan: _scan(crop: crop, label: label),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Uncertain result'), findsOneWidget);
      expect(find.text('See example'), findsOneWidget);
      expect(find.text('What to look for'), findsOneWidget);
      expect(find.text('Typical signs'), findsNothing);
      await tester.ensureVisible(find.text('What to look for'));
      await tester.tap(find.text('What to look for'));
      await tester.pumpAndSettle();
      expect(
        find.text(label == 'healthy' ? 'Healthy appearance' : 'Typical signs'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Please take another clear photo'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: '$crop/$label');
    }
  });
}
