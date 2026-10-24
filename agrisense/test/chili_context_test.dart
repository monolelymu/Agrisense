import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:image/image.dart' as img;
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/chili_knowledge.dart';
import 'package:agrisense/features/diagnosis/crop_knowledge_screen.dart';
import 'package:agrisense/features/diagnosis/model_catalog.dart';
import 'package:agrisense/features/diagnosis/tomato_assessment.dart';
import 'package:agrisense/features/diagnosis/tomato_context_widgets.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';
import 'package:agrisense/features/diagnosis/tomato_scan_screen.dart';
import 'crop_model_pipeline_test.dart' as fixture;

final at = DateTime(2026, 10, 22, 12);
HardwareSample reading({
  Crop crop = Crop.chili,
  String device = 'chili-sensor',
  DateTime? time,
  double temperature = 23,
  double humidity = 80,
  double soil = 50,
  bool calibrated = true,
}) => HardwareSample(
  id: 'chili-reading',
  crop: crop,
  deviceId: device,
  receivedAt: time ?? at,
  temperature: temperature,
  humidity: humidity,
  soil: soil,
  soilCalibrated: calibrated,
  soilRaw: 1000,
  gasRaw: 4095,
);

// Synthetic records exercise storage and context compatibility.
TomatoScan prediction({String source = 'camera'}) => TomatoScan.fromJson({
  ...fixture.prediction(source: source).toJson(),
  'crop': 'chili',
  'label': 'bacterial_spot',
  'timestamp': at.toIso8601String(),
  'predictions': [
    {'label': 'bacterial_spot', 'score': .71},
    {'label': 'healthy', 'score': .2},
  ],
  'modelVersion': 'synthetic-chili-test',
  'preview': img.encodePng(img.Image(width: 1, height: 1)),
});

Widget page(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  test(
    'Chili reference is advisory, crop-specific and independent of day/night',
    () {
      for (final hour in [0, 12, 23]) {
        final time = DateTime(2026, 10, 22, hour);
        final c = GrowingConditions.assess(
          reading(time: time),
          time,
          crop: Crop.chili,
        );
        expect(c.minimumTemperature, 21.1);
        expect(c.maximumTemperature, 23.9);
        expect(c.temperaturePosition, ReferencePosition.within);
        expect(c.humidityPosition, ReferencePosition.unavailable);
        expect(c.humidity, 80);
        expect(c.soil, 50);
      }
      for (final t in [21.1, 23.9]) {
        expect(
          GrowingConditions.assess(
            reading(temperature: t),
            at,
            crop: Crop.chili,
          ).temperaturePosition,
          ReferencePosition.within,
        );
      }
      expect(
        GrowingConditions.assess(
          reading(temperature: 21),
          at,
          crop: Crop.chili,
        ).temperaturePosition,
        ReferencePosition.below,
      );
      expect(
        GrowingConditions.assess(
          reading(temperature: 24),
          at,
          crop: Crop.chili,
        ).temperaturePosition,
        ReferencePosition.above,
      );
      for (final s in [
        null,
        reading(crop: Crop.tomato),
        reading(time: at.subtract(const Duration(seconds: 31))),
        reading(time: at.add(const Duration(seconds: 1))),
        reading(temperature: double.nan, humidity: 101, soil: -1),
      ]) {
        final c = GrowingConditions.assess(s, at, crop: Crop.chili);
        expect(c.temperature, isNull);
        expect(c.humidity, isNull);
        expect(c.soil, isNull);
      }
      expect(
        GrowingConditions.assess(
          reading(calibrated: false),
          at,
          crop: Crop.chili,
        ).soil,
        isNull,
      );
      expect(
        GrowingConditions.assess(
          reading(time: at.subtract(const Duration(seconds: 30))),
          at,
          crop: Crop.chili,
        ).temperature,
        23,
      );
      for (final label in chiliKnowledge.keys) {
        expect(
          assessCropEvidence(Crop.chili, label, reading(), [], at).state,
          EvidenceState.notAssessable,
        );
        expect(
          assessCropEvidence(Crop.chili, label, null, [], at).state,
          EvidenceState.noContext,
        );
      }
      expect(cropModels[Crop.chili]!.classCount, 6);
      expect(modelAvailable(Crop.chili), isTrue);
    },
  );

  test(
    'Chili capture context is frozen, guarded and survives storage reopening',
    () async {
      final dir = await Directory.systemTemp.createTemp('chili-context-');
      Hive.init(dir.path);
      var box = await Hive.openBox<dynamic>('chili-context');
      final h = HardwareController(box, clock: () => at);
      addTearDown(() async {
        h.dispose();
        await Hive.close();
        await dir.delete(recursive: true);
      });
      h.assignments[Crop.chili] = {'sensorId': 'chili-sensor'};
      h.samples.addAll([reading(crop: Crop.tomato), reading()]);
      final scan = h.attachScanContext(prediction(), at: at);
      final assessment = TomatoAssessment.tryFromJson(scan.assessment)!;
      expect(assessment.conditions.crop, Crop.chili);
      expect(assessment.referenceVersion, chiliReferenceVersion);
      expect(assessment.evidence.state, EvidenceState.notAssessable);
      expect(scan.sensorContext?['device_id'], 'chili-sensor');
      expect(
        h.attachScanContext(prediction(source: 'upload'), at: at).assessment,
        isNull,
      );
      for (final trigger in [
        null,
        reading(crop: Crop.eggplant),
        reading(time: at.subtract(const Duration(seconds: 31))),
        reading(time: at.add(const Duration(seconds: 1))),
      ]) {
        expect(
          h
              .attachScanContext(
                prediction(source: 'auto'),
                at: at,
                trigger: trigger,
              )
              .assessment,
          isNull,
        );
      }
      expect(
        h
            .attachScanContext(
              prediction(source: 'auto'),
              at: at,
              trigger: reading(),
            )
            .assessment,
        isNotNull,
      );
      h.samples.clear();
      h.samples.add(reading(device: 'other'));
      expect(h.attachScanContext(prediction(), at: at).assessment, isNull);
      await TomatoScanStore(box).save(scan);
      await box.close();
      box = await Hive.openBox<dynamic>('chili-context');
      final saved = TomatoScanStore(box).load().single;
      expect(saved.crop, Crop.chili);
      expect(saved.assessment, scan.assessment);
      expect(saved.sensorContext, scan.sensorContext);
      expect(saved.modelVersion, scan.modelVersion);
      expect(saved.score, scan.score);
      expect(
        saved.predictions.map((p) => p.label),
        scan.predictions.map((p) => p.label),
      );
    },
  );

  testWidgets(
    'Chili panel shows reference and expires without humidity thresholds',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var now = at;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: SingleChildScrollView(
                child: GrowingConditionsPanel(
                  crop: Crop.chili,
                  sample: reading(),
                  clock: () => now,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('21.1–23.9'), findsOneWidget);
      expect(
        find.textContaining('No universal Chili humidity'),
        findsOneWidget,
      );
      expect(find.textContaining('65–75%'), findsNothing);
      expect(find.textContaining('regional pepper'), findsOneWidget);
      await tester.ensureVisible(find.text('Research sources'));
      await tester.tap(find.text('Research sources'));
      await tester.pumpAndSettle();
      expect(find.textContaining('[CH-GROW-01]'), findsOneWidget);
      now = at.add(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 31));
      expect(
        find.textContaining('Air temperature: Unavailable'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('six Chili references are browsable with the installed model', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CropKnowledgeScreen(crop: Crop.chili)),
    );
    expect(find.text('Chili knowledge & care'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNWidgets(6));
    final target = find.byKey(const ValueKey('leaf_curl'));
    await tester.ensureVisible(target);
    await tester.tap(
      find.descendant(of: target, matching: find.text('leaf curl')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('does not identify a virus'), findsOneWidget);
    expect(modelAvailable(Crop.chili), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'synthetic Chili history result uses Chili explanation and saved context',
    (tester) async {
      final assessment = TomatoAssessment.assess(
        crop: Crop.chili,
        label: 'bacterial_spot',
        context: 'Frozen Chili context',
        sample: reading(),
        history: [],
        at: at,
      );
      final scan = TomatoScan.fromJson({
        ...prediction().toJson(),
        'assessment': assessment.toJson(),
      });
      await tester.pumpWidget(page(TomatoResultCard(scan: scan)));
      await tester.ensureVisible(find.text('Explanation & care'));
      await tester.tap(find.text('Explanation & care'));
      await tester.pumpAndSettle();
      expect(
        find.text(chiliKnowledge['bacterial_spot']!.explanation),
        findsOneWidget,
      );
      expect(find.text('Frozen Chili context'), findsOneWidget);
      await tester.ensureVisible(find.text('Saved growing context'));
      await tester.tap(find.text('Saved growing context'));
      await tester.pumpAndSettle();
      expect(find.textContaining('21.1–23.9'), findsOneWidget);
      expect(find.textContaining(chiliReferenceVersion), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
