import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/data/soil_calibration.dart';
import 'package:agrisense/features/monitoring/soil_calibration_screen.dart';

// Real persistence/device isolation is covered in immediate_update_test.dart.
// Keep widget animations independent of filesystem event timing.
class _SoilFormController extends HardwareController {
  _SoilFormController(super.box);
  SoilCalibration? reference;
  @override
  SoilCalibration? soilCalibration(Crop crop, [dynamic sample]) => reference;
  @override
  Future<void> saveSoilCalibration(Crop crop, SoilCalibration? value) async {
    reference = value;
    notifyListeners();
  }
}

void main() {
  late Directory dir;
  late Box<dynamic> box;
  setUp(() async {
    dir = await Directory('test').createTemp('soil-reference-');
    Hive.init(dir.path);
    box = await Hive.openBox<dynamic>('soil-reference');
  });
  tearDown(() async {
    await box.close();
    await dir.delete(recursive: true);
  });
  test(
    'dry/wet endpoints, both sensor directions and out-of-range clamping',
    () {
      for (final values in [(3000, 1000), (1000, 3000)]) {
        final c = SoilCalibration(dry: values.$1, wet: values.$2);
        expect(c.percentage(c.dry), 0);
        expect(c.percentage(c.wet), 100);
        expect(c.percentage(2000), 50);
        expect(c.percentage(0), inInclusiveRange(0, 100));
        expect(c.percentage(4095), inInclusiveRange(0, 100));
        expect(SoilCalibration.tryFromJson(c.toJson())!.percentage(2000), 50);
      }
      expect(SoilCalibration(dry: 3000, wet: 1000).percentage(4000), 0);
      expect(SoilCalibration(dry: 3000, wet: 1000).percentage(0), 100);
    },
  );

  test(
    'invalid, equal, corrupt or unsupported references stay unavailable',
    () {
      for (final values in [(-1, 1000), (4096, 1000), (2000, 2000)]) {
        expect(
          () => SoilCalibration(dry: values.$1, wet: values.$2),
          throwsFormatException,
        );
      }
      for (final json in [
        null,
        {},
        {'version': 2, 'dry': 3000, 'wet': 1000},
        {'version': 1, 'dry': 3000.5, 'wet': 1000},
        {'version': 1, 'dry': 1000, 'wet': 1000},
      ]) {
        expect(SoilCalibration.tryFromJson(json), isNull);
      }
    },
  );

  testWidgets(
    'setup validates inputs and saves at narrow width with large text',
    (tester) async {
      final h = _SoilFormController(box);
      h.assignments[Crop.tomato] = {
        'sensor': 'http://192.168.1.20',
        'sensorId': 'kit-one',
      };
      addTearDown(h.dispose);
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
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SoilCalibrationScreen(hardware: h, crop: Crop.tomato),
                  ),
                ),
                child: const Text('Open setup'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open setup'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save percentage'));
      await tester.tap(find.text('Save percentage'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter both readings'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '3000');
      await tester.enterText(find.byType(TextField).at(1), '1000');
      await tester.ensureVisible(find.text('Save percentage'));
      await tester.tap(find.text('Save percentage'));
      await tester.pumpAndSettle();
      expect(h.soilCalibration(Crop.tomato)!.percentage(2000), 50);
      expect(find.text('Open setup'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
