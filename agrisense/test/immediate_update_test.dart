import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/core/sensor_notifications.dart';
import 'package:agrisense/data/automatic_capture.dart';
import 'package:agrisense/data/board_discovery.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/kit_warning.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/simple_result_card.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';
import 'package:image/image.dart' as img;

class _Kit extends HardwareClient {
  _Kit(this.clock);
  final DateTime Function() clock;
  int sequence = 1, reads = 0, writes = 0;
  bool supported = true, fail = false;
  KitWarning? stored;
  Completer<void>? gate;
  @override
  Future<BoardIdentity> identity(String address) async => BoardIdentity(
    kitId: demoKitId,
    deviceId: 'aabbccddeeff',
    role: 'sensor',
    ready: true,
    capabilities: supported ? ['readings', 'warning_leds_v1'] : ['readings'],
    sensorCrop: Crop.tomato,
  );
  @override
  Future<HardwareSample> read(String address, Crop crop) async {
    reads++;
    await gate?.future;
    return HardwareSample(
      id: 'boot-$sequence',
      deviceId: 'aabbccddeeff',
      crop: crop,
      receivedAt: clock(),
      temperature: 25 + sequence.toDouble(),
      humidity: 60,
      soil: null,
      soilRaw: 2000,
      gasRaw: 400,
      soilCalibrated: false,
    );
  }

  @override
  Future<KitWarning?> warningConfiguration(String address, String code) async {
    if (fail) throw const SocketException('offline');
    return stored;
  }

  @override
  Future<void> setWarnings(
    String address,
    String code,
    KitWarning settings,
  ) async {
    if (fail) throw const SocketException('offline');
    expect(code, 'a' * 32);
    writes++;
    stored = settings;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Box<dynamic> box;
  late DateTime now;
  late _Kit kit;
  late HardwareController h;
  setUp(() async {
    directory = await Directory('test').createTemp('immediate-update-');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('immediate');
    now = DateTime(2026, 10, 29, 12);
    kit = _Kit(() => now);
    h = HardwareController(box, client: kit, clock: () => now)..load();
    h.assignments[Crop.tomato] = {
      'sensor': 'http://192.168.1.20',
      'sensorId': 'aabbccddeeff',
      'pairingCode': 'a' * 32,
    };
    h.notificationSettings[Crop.tomato] = const SensorAlertSettings();
  });
  tearDown(() async {
    h.dispose();
    await box.close();
    await directory.delete(recursive: true);
  });

  test(
    'live values update without shortening history; duplicates do not refresh age',
    () async {
      await h.refresh(Crop.tomato);
      final first = h.latest(Crop.tomato)!;
      now = now.add(const Duration(seconds: 1));
      await h.refresh(Crop.tomato);
      expect(h.latest(Crop.tomato)!.receivedAt, first.receivedAt);
      kit.sequence++;
      await h.refresh(Crop.tomato);
      expect(h.latest(Crop.tomato)!.id, 'boot-2');
      expect(h.samples, hasLength(1));
      final scan = h.attachScanContext(
        TomatoScan(
          id: 'scan',
          timestamp: now,
          label: 'early_blight',
          score: .9,
          preview: Uint8List(0),
          modelVersion: 'unchanged',
          source: 'camera',
        ),
        at: now,
      );
      expect(scan.sensorContext?['sample_id'], 'boot-2');
      now = now.add(const Duration(seconds: 9));
      kit.sequence++;
      await h.refresh(Crop.tomato);
      expect(h.samples, hasLength(2));
      now = now.add(const Duration(seconds: 31));
      await h.refresh(Crop.tomato);
      expect(h.fresh(Crop.tomato), isFalse);
    },
  );

  test(
    'polls every second, skips overlaps and yields to camera movement',
    () async {
      kit.gate = Completer<void>();
      h.startPolling(Crop.tomato);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(kit.reads, 1);
      kit.gate!.complete();
      await h.waitForIdle();
      h.setCameraControlActive(true);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(kit.reads, 1);
      h.setCameraControlActive(false);
      kit.sequence++;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(kit.reads, 2);
      h.stopPolling();
    },
  );

  test(
    'sync retries saved settings and avoids redundant board writes',
    () async {
      kit.fail = true;
      const settings = SensorAlertSettings(
        enabled: true,
        soilRaw: true,
        rules: [
          CaptureRule(true, 18, 30),
          CaptureRule(true, 40, 80),
          CaptureRule(true, 1500, 2500),
        ],
        gasRule: CaptureRule(true, 100, 800),
      );
      await h.saveNotificationSettings(Crop.tomato, settings);
      expect(h.warningStatus(Crop.tomato), 'Waiting to sync');
      expect(
        box.get(
          'foreground-notification-rules-v1',
        )['tomato']['gas_rule']['enabled'],
        true,
      );
      kit.fail = false;
      now = now.add(const Duration(seconds: 11));
      await h.refresh(Crop.tomato);
      expect(h.warningStatus(Crop.tomato), 'Saved to kit');
      expect(kit.stored!.rules[3].maximum, 800);
      now = now.add(const Duration(seconds: 31));
      kit.sequence++;
      await h.refresh(Crop.tomato);
      expect(kit.writes, 1);
      final restored = HardwareController(box, client: kit)..load();
      expect(restored.notificationSettings[Crop.tomato]!.gasRule.enabled, true);
      restored.dispose();
    },
  );

  test(
    'legacy firmware remains usable with a clear LED update message',
    () async {
      kit.supported = false;
      await h.refresh(Crop.tomato);
      expect(h.status[Crop.tomato], 'Received');
      expect(h.warningStatus(Crop.tomato), contains('Update sensor firmware'));
      expect(kit.writes, 0);
    },
  );

  test('gas defaults disabled and invalid raw limits are rejected', () {
    final value = const SensorAlertSettings().toJson()..remove('gas_rule');
    expect(SensorAlertSettings.fromJson(value).gasRule.enabled, false);
    expect(
      () => const SensorAlertSettings(
        gasRule: CaptureRule(true, 0, 4096),
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => const SensorAlertSettings(
        gasRule: CaptureRule(true, 100, 100),
      ).validate(),
      throwsFormatException,
    );
  });

  test(
    'sensor ages survive receipt and stale DHT fields become unavailable',
    () {
      final sample = HardwareSample.fromDevice(
        {
          'version': 1,
          'crop': 'tomato',
          'device_id': 'aabbccddeeff',
          'sample_id': '1',
          'age_ms': 400,
          'dht_age_ms': 6000,
          'temp_c': 25,
          'humidity_pct': 60,
          'soil_raw': 1000,
          'soil_pct': null,
          'soil_calibrated': false,
          'gas_raw': 400,
        },
        Crop.tomato,
        now: now,
      );
      expect(
        sample.receivedAt,
        now.subtract(const Duration(milliseconds: 400)),
      );
      expect(sample.temperature, isNull);
      expect(sample.humidity, isNull);
      expect(sample.gasRaw, 400);
    },
  );

  testWidgets(
    'disease descriptions expand on narrow screens with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final crop in Crop.values) {
        final label = crop == Crop.tomato
            ? 'early_blight'
            : crop == Crop.eggplant
            ? 'leaf_spot'
            : 'cercospora_leaf_spot';
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
                  scan: TomatoScan(
                    id: crop.name,
                    timestamp: now,
                    crop: crop,
                    label: label,
                    score: .9,
                    modelVersion: 'unchanged',
                    preview: Uint8List.fromList(
                      img.encodePng(img.Image(width: 2, height: 2)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.ensureVisible(find.text('What to look for'));
        await tester.tap(find.text('What to look for'));
        await tester.pumpAndSettle();
        expect(find.text('Typical signs'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
