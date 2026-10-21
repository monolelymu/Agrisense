import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:image/image.dart' as img;
import 'package:agrisense/data/local_storage.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/tomato_classifier.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';
import 'package:agrisense/features/diagnosis/tomato_scan_screen.dart';
import 'support.dart';

TomatoScan sample({double score = .8}) => TomatoScan(
  id: 'test-photo',
  timestamp: DateTime(2026, 10, 18),
  label: 'early_blight',
  score: score,
  preview: Uint8List.fromList(img.encodePng(img.Image(width: 1, height: 1))),
  modelVersion: tomatoModelVersion,
);

void main() {
  test('preprocessing preserves RGB order, normalization, and tensor size', () {
    final photo = img.Image(width: 3, height: 2);
    img.fill(photo, color: img.ColorRgb8(255, 128, 0));
    final tensor = preprocessTomato(photo);
    expect(tensor.length, 224 * 224 * 3);
    for (var i = 0; i < tensor.length; i += 3) {
      expect(tensor[i], closeTo(1, 1e-6));
      expect(tensor[i + 1], closeTo(128 / 255, 1e-6));
      expect(tensor[i + 2], closeTo(0, 1e-6));
    }
  });

  test('antialiasing retains both colors when reducing striped images', () {
    final photo = img.Image(width: 448, height: 224);
    for (var y = 0; y < photo.height; y++) {
      for (var x = 0; x < photo.width; x++) {
        photo.setPixelRgb(x, y, x.isEven ? 255 : 0, 0, x.isOdd ? 255 : 0);
      }
    }
    final tensor = preprocessTomato(photo);
    final center = (112 * 224 + 112) * 3;
    expect(tensor[center], closeTo(.5, 1e-6));
    expect(tensor[center + 1], 0);
    expect(tensor[center + 2], closeTo(.5, 1e-6));
  });

  test('real scans survive a restart and clearing demo history', () async {
    final directory = await Directory.systemTemp.createTemp('agrisense-test-');
    final hive = Hive;
    hive.init(directory.path);
    addTearDown(() async {
      await hive.close();
      await directory.delete(recursive: true);
    });
    var box = await hive.openBox<dynamic>('scan_test');
    final scan = sample();
    await TomatoScanStore(box).save(scan);
    await TomatoScanStore(box).save(scan); // A save retry must not duplicate.
    await HiveHistoryRepository(box).clear();
    await box.close();
    box = await hive.openBox<dynamic>('scan_test');
    final restored = TomatoScanStore(box).load();
    expect(restored.length, 1);
    expect(restored.single.label, scan.label);
    expect(restored.single.score, scan.score);
    expect(restored.single.preview, scan.preview);
    expect(restored.single.modelVersion, scan.modelVersion);
  });

  testWidgets('low score is uncertain and never presented as accuracy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TomatoResultCard(scan: sample(score: .59)),
          ),
        ),
      ),
    );
    expect(find.text('UNCERTAIN'), findsOneWidget);
    expect(find.text('early blight'), findsNWidgets(2));
    expect(find.text('Model score: 59.0%'), findsOneWidget);
    expect(find.text('Selected crop: Tomato'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'legacy scans retain only their saved prediction and default to tomato',
    () {
      final json = sample().toJson()
        ..remove('crop')
        ..remove('predictions');
      final restored = TomatoScan.fromJson(json);
      expect(restored.crop, Crop.tomato);
      expect(restored.rankedPredictions.length, 1);
      expect(restored.rankedPredictions.single.label, 'early_blight');
    },
  );

  test('top three predictions survive serialization', () {
    final json = sample().toJson();
    json['predictions'] = [
      const ScanPrediction('early_blight', .8).toJson(),
      const ScanPrediction('late_blight', .15).toJson(),
      const ScanPrediction('healthy', .05).toJson(),
    ];
    final restored = TomatoScan.fromJson(json);
    expect(restored.rankedPredictions.map((p) => p.label), [
      'early_blight',
      'late_blight',
      'healthy',
    ]);
    expect(restored.rankedPredictions.map((p) => p.score), [.8, .15, .05]);
  });

  test('unsupported crops cannot invoke the tomato model', () {
    final classifier = TomatoClassifier();
    for (final crop in [Crop.eggplant, Crop.chili]) {
      expect(
        () => classifier.classifyCrop(crop, Uint8List(0)),
        throwsStateError,
      );
    }
  });

  testWidgets(
    'real navigation filters history and separates demo readings',
    (tester) async {
      // Navigation is platform-independent; do not wait for a native picker
      // recovery call in this widget-only test environment.
      late Directory directory;
      late Box<dynamic> box;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('agrisense-ui-test-');
        Hive.init(directory.path);
        box = await Hive.openBox<dynamic>('ui_test');
        await TomatoScanStore(box).save(sample());
      });
      final controller = makeController();
      addTearDown(() async {
        controller.dispose();
        await box.close();
        await directory.delete(recursive: true);
      });
      await tester.pumpWidget(
        TomatoApp(store: TomatoScanStore(box), demoController: controller),
      );
      await tester.pumpAndSettle();
      expect(find.text('No device connected'), findsOneWidget);
      expect(find.text('MOCK READINGS'), findsNothing);
      expect(
        controller.ready,
        isFalse,
      ); // Demo is not initialized on app launch.
      await tester.tap(find.text('History').last);
      await tester.pumpAndSettle();
      expect(find.text('early blight'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Eggplant'));
      await tester.pumpAndSettle();
      expect(find.text('early blight'), findsNothing);
      await tester.tap(find.text('Diagnosis').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Model not available yet for Eggplant.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Scan leaf'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tomato'));
      await tester.pumpAndSettle();
      expect(find.text('early blight'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.linux}),
  );
}
