import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';
import 'package:agrisense/features/monitoring/hardware_dashboard.dart';
import 'simple_ui_navigation.dart';

Map<String, dynamic> packet() => {
  'version': 1,
  'crop': 'tomato',
  'sample_id': 'board-boot-1',
  'age_ms': 100,
  'temp_c': 25.0,
  'humidity_pct': 60.0,
  'soil_raw': 2300,
  'soil_pct': null,
  'soil_calibrated': false,
  'gas_raw': 400,
};

class FakeHardware extends HardwareClient {
  int calls = 0;
  bool fail = false;
  @override
  Future<HardwareSample> read(String address, Crop crop) async {
    calls++;
    if (fail) throw const SocketException('offline');
    return HardwareSample.fromDevice(packet(), crop);
  }

  @override
  Future<Uint8List> capture(String address) async {
    calls++;
    return Uint8List(0);
  }
}

void main() {
  testWidgets(
    'saved hardware readings and diagnoses share dashboard, trends and history',
    (tester) async {
      late Directory directory;
      late Box<dynamic> box;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('hardware-results-');
        Hive.init(directory.path);
        box = await Hive.openBox<dynamic>('hardware-results');
        await box.put('hardware-readings-v1', [
          HardwareSample.fromDevice(packet(), Crop.tomato).toJson(),
        ]);
        await TomatoScanStore(box).save(
          TomatoScan(
            id: 'real-photo',
            timestamp: DateTime.now(),
            label: 'leaf_miner',
            score: .57,
            modelVersion: 'test-model',
            source: 'camera',
            preview: Uint8List.fromList(
              img.encodePng(img.Image(width: 1, height: 1)),
            ),
          ),
        );
      });
      final h = HardwareController(box, client: FakeHardware())..load();
      addTearDown(() async {
        h.dispose();
        await box.close();
        await directory.delete(recursive: true);
      });
      await tester.pumpWidget(
        HardwareApp(
          hardware: h,
          scans: TomatoScanStore(box),
          showTutorial: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('25.0°C'), findsOneWidget);
      expect(find.text('400 raw'), findsNothing);
      await tester.ensureVisible(find.text('More growing conditions'));
      await tester.tap(find.text('More growing conditions'));
      await tester.pumpAndSettle();
      expect(find.text('400 raw'), findsOneWidget);
      expect(find.text('Tomato • leaf miner'), findsOneWidget);
      await openSimplePage(tester, 'Trends');
      expect(find.textContaining('1 samples'), findsOneWidget);
      await openSimplePage(tester, 'History');
      await tester.ensureVisible(find.text('Tomato • leaf miner'));
      await tester.tap(find.text('Tomato • leaf miner'));
      await tester.pumpAndSettle();
      expect(find.text('UNCERTAIN'), findsOneWidget);
      expect(find.text('leaf miner'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Eggplant'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Eggplant'));
      await tester.pumpAndSettle();
      expect(find.text('Tomato • leaf miner'), findsNothing);
      await chooseRecordCategory(tester, 'Readings');
      expect(find.text('No sensor readings saved.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('only explicit private IPv4 HTTP endpoints are accepted', () {
    expect(
      hardwareAddress('192.168.1.50:8080').toString(),
      'http://192.168.1.50:8080',
    );
    for (final address in [
      '8.8.8.8',
      '127.0.0.1',
      'localhost',
      '169.254.169.254',
      '192.168.1.50/capture',
      'https://192.168.1.50',
      'http://user@192.168.1.50',
      'http://192.168.1.50?redirect=1',
      '192.168.1.999',
      '172.32.0.1',
    ]) {
      expect(
        () => hardwareAddress(address),
        throwsFormatException,
        reason: address,
      );
    }
  });
  test('protocol rejects stale, wrong-crop and invalid readings', () {
    expect(
      () => HardwareSample.fromDevice(packet(), Crop.eggplant),
      throwsFormatException,
    );
    for (final invalid in [
      {...packet(), 'age_ms': 30001},
      {...packet(), 'temp_c': double.nan},
      {...packet(), 'humidity_pct': 101},
      {...packet(), 'gas_raw': -1},
      {...packet(), 'version': 2},
    ]) {
      expect(
        () => HardwareSample.fromDevice(invalid, Crop.tomato),
        throwsFormatException,
      );
    }
    final r = HardwareSample.fromDevice({
      ...packet(),
      'temp_c': null,
      'soil_pct': 50,
    }, Crop.tomato);
    expect(r.temperature, isNull);
    expect(
      r.soil,
      isNull,
    ); // Uncalibrated soil is never treated as a percentage.
  });

  test(
    'HTTP opt-in, crop assignments, deduplication, persistence and failures',
    () async {
      final directory = await Directory.systemTemp.createTemp('hardware-test-');
      Hive.init(directory.path);
      final box = await Hive.openBox<dynamic>('hardware');
      final client = FakeHardware();
      final controller = HardwareController(box, client: client)..load();
      addTearDown(() async {
        controller.dispose();
        await box.close();
        await directory.delete(recursive: true);
      });
      await controller.assign(Crop.tomato, 'sensor', '192.168.1.50');
      await controller.assign(Crop.tomato, 'camera', '192.168.1.51');
      await controller.refresh(Crop.tomato);
      expect(() => controller.capture(Crop.tomato), throwsFormatException);
      controller.startPolling(Crop.tomato);
      expect(controller.polling, isFalse);
      expect(client.calls, 0);
      await expectLater(
        controller.assign(Crop.eggplant, 'sensor', '192.168.1.50'),
        throwsFormatException,
      );
      await controller.setHttpAllowed(true);
      await controller.refresh(Crop.tomato);
      await controller.refresh(Crop.tomato);
      expect(controller.samples.length, 1);
      expect(controller.readings(Crop.eggplant), isEmpty);
      final restored = HardwareController(box, client: client)..load();
      expect(restored.samples.length, 1);
      expect(restored.address(Crop.tomato, 'sensor'), 'http://192.168.1.50');
      restored.dispose();
      client.fail = true;
      await controller.refresh(Crop.tomato);
      expect(controller.status[Crop.tomato], 'Unavailable');
      expect(controller.samples.length, 1);
      await controller.setHttpAllowed(false);
      final previous = client.calls;
      await controller.refresh(Crop.tomato);
      expect(client.calls, previous);
      expect(controller.fresh(Crop.tomato), isFalse);
    },
  );

  testWidgets('real dashboard is empty without hardware and has HTTP off', (
    tester,
  ) async {
    late Directory directory;
    late Box<dynamic> box;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('hardware-ui-');
      Hive.init(directory.path);
      box = await Hive.openBox<dynamic>('hardware-ui');
      // Legacy demo storage must not become live readings.
      await box.put('history', {
        'readings': ['mock'],
      });
    });
    final h = HardwareController(box, client: FakeHardware())..load();
    addTearDown(() async {
      h.dispose();
      await box.close();
      await directory.delete(recursive: true);
    });
    await tester.pumpWidget(
      HardwareApp(
        hardware: h,
        scans: TomatoScanStore(box),
        showTutorial: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No sensor readings yet'), findsOneWidget);
    expect(find.text('MOCK READINGS'), findsNothing);
    await openSimplePage(tester, 'Devices');
    expect(find.text('Allow local hardware access'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
      isFalse,
    );
    await openSimplePage(tester, 'Trends');
    expect(find.text('No readings for this metric'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
