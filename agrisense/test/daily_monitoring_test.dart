import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:image/image.dart' as img;
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/core/monitoring_service.dart';
import 'package:agrisense/core/sensor_notifications.dart';
import 'package:agrisense/data/daily_photo_schedule.dart';
import 'package:agrisense/data/automatic_capture.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/tomato_classifier.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';

class _Service extends MonitoringServiceBridge {
  @override
  bool get supported => true;
  @override
  Future<bool> start(String crop) async => true;
  @override
  Future<void> stop() async {}
}

class _Boards extends HardwareClient {
  _Boards(this.clock);
  final DateTime Function() clock;
  int reads = 0, captures = 0, active = 0, maximumActive = 0;
  bool cameraOffline = false;
  Completer<void>? readingGate;
  final photo = Uint8List.fromList(
    img.encodeJpg(img.Image(width: 8, height: 8)),
  );
  void enter() {
    active++;
    if (active > maximumActive) maximumActive = active;
  }

  @override
  Future<HardwareSample> read(String address, Crop crop) async {
    enter();
    try {
      reads++;
      await readingGate?.future;
      return HardwareSample(
        id: 'sample-$reads',
        deviceId: 'sensor-one',
        crop: crop,
        receivedAt: clock(),
        temperature: 35,
        humidity: 70,
        soil: 40,
        soilRaw: 2000,
        gasRaw: 400,
        soilCalibrated: true,
      );
    } finally {
      active--;
    }
  }

  @override
  Future<Uint8List> capture(String address) async {
    enter();
    try {
      captures++;
      if (cameraOffline) throw const SocketException('offline');
      return photo;
    } finally {
      active--;
    }
  }
}

class _Model extends TomatoClassifier {
  _Model(this.box);
  final Box<dynamic> box;
  bool fail = false;
  int calls = 0;
  @override
  Future<TomatoScan> classifyCrop(Crop crop, Uint8List bytes) async {
    calls++;
    expect(
      box.keys.whereType<String>().any(
            (k) => k.startsWith('scheduled-original-v1/'),
          ) ||
          box.containsKey('notification-photos-v1'),
      isTrue,
    );
    if (fail) throw StateError('classification failed');
    return TomatoScan(
      id: 'model-output',
      timestamp: DateTime(2026),
      label: 'bacterial_spot',
      score: .8,
      preview: bytes,
      modelVersion: 'test-only',
      crop: crop,
    );
  }
}

void main() {
  late Directory directory;
  late Box<dynamic> box;
  late DateTime now;
  late _Boards boards;
  late _Model model;
  late HardwareController h;
  setUp(() async {
    directory = await Directory('test').createTemp('daily-monitoring-');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('daily');
    now = DateTime(2026, 10, 24, 8);
    boards = _Boards(() => now);
    model = _Model(box);
    h = HardwareController(
      box,
      client: boards,
      classifier: model,
      service: _Service(),
      clock: () => now,
    )..load();
    h.assignments[Crop.tomato] = {
      'sensor': 'http://192.168.1.20',
      'sensorId': 'sensor-one',
      'camera': 'http://192.168.1.21',
    };
  });
  tearDown(() async {
    h.dispose();
    await box.close();
    await directory.delete(recursive: true);
  });
  Future<void> start() =>
      h.withPollingPaused(() => h.startMonitoring(Crop.tomato));

  test(
    'legacy kit and times become shared without changing saved history or rules',
    () async {
      await box.put('hardware-nodes-v1', {
        'eggplant': {
          'sensor': 'http://192.168.1.20',
          'sensorId': 'sensor-one',
          'camera': 'http://192.168.1.21',
        },
      });
      await box.put('daily-photos-v1-eggplant', {
        'enabled': true,
        'minutes': [480],
      });
      final restored = HardwareController(
        box,
        client: boards,
        service: _Service(),
        clock: () => now,
      )..load();
      for (final crop in Crop.values) {
        expect(restored.address(crop, 'sensor'), 'http://192.168.1.20');
        expect(restored.address(crop, 'camera'), 'http://192.168.1.21');
        expect(restored.schedule(crop).minutes, [480]);
      }
      await restored.refresh(Crop.chili);
      expect(restored.samples.single.crop, Crop.chili);
      expect(restored.latest(Crop.chili)?.deviceId, 'sensor-one');
      await restored.saveSchedule(
        Crop.chili,
        const DailyPhotoSchedule(enabled: true, minutes: [600]),
      );
      final reloaded = HardwareController(box)..load();
      expect(reloaded.schedule(Crop.tomato).minutes, [600]);
      expect((box.get('daily-photos-v1-eggplant') as Map)['minutes'], [480]);
      expect(reloaded.samples.single.crop, Crop.chili);
      restored.dispose();
      reloaded.dispose();
    },
  );

  test(
    'selected crop controls alert rules and diagnosis even when firmware keeps its old crop',
    () async {
      await box.put('hardware-nodes-v1', {
        'tomato': {
          'sensor': 'http://192.168.1.20',
          'sensorId': 'sensor-one',
          'camera': 'http://192.168.1.21',
        },
      });
      h.dispose();
      h = HardwareController(
        box,
        client: boards,
        classifier: model,
        service: _Service(),
        clock: () => now,
      )..load();
      await h.saveNotificationSettings(
        Crop.chili,
        const SensorAlertSettings(
          enabled: true,
          capturePhoto: true,
          analyzePhoto: true,
          showNotifications: false,
          duration: 10,
          cooldown: 30,
          rules: [
            CaptureRule(true, 20, 30),
            CaptureRule(false, 0, 100),
            CaptureRule(false, 0, 100),
          ],
        ),
      );
      await h.withPollingPaused(() => h.startMonitoring(Crop.chili));
      await h.refresh(Crop.chili);
      now = now.add(const Duration(seconds: 10));
      await h.refresh(Crop.chili);
      expect(h.samples.every((sample) => sample.crop == Crop.chili), isTrue);
      expect(h.alerts.single.crop, Crop.chili);
      expect(h.scanStore.load().single.crop, Crop.chili);
      expect(boards.captures, 1);
    },
  );

  test(
    'conflicting legacy schedules require explicit shared confirmation',
    () async {
      await box.put('daily-photos-v1-tomato', {
        'enabled': true,
        'minutes': [480],
      });
      await box.put('daily-photos-v1-chili', {
        'enabled': true,
        'minutes': [600],
      });
      final restored = HardwareController(box)..load();
      expect(restored.schedule(Crop.tomato).enabled, isFalse);
      expect(restored.automaticStatus, contains('Edit times'));
      expect((box.get('daily-photos-v1-chili') as Map)['minutes'], [600]);
      restored.dispose();
    },
  );

  test(
    'switching crop does not capture the same scheduled minute twice',
    () async {
      await h.saveSchedule(
        Crop.tomato,
        const DailyPhotoSchedule(enabled: true, minutes: [480]),
      );
      await start();
      await h.monitorTick(Crop.tomato);
      await h.withPollingPaused(() => h.startMonitoring(Crop.chili));
      await h.monitorTick(Crop.chili);
      expect(boards.captures, 1);
      expect(h.address(Crop.chili, 'camera'), 'http://192.168.1.21');
      expect(h.scanStore.load().single.crop, Crop.tomato);
    },
  );

  test(
    'hardware access defaults on, explicit opt-out is retained, schedules start empty',
    () async {
      expect(h.allowLocalHttp, isTrue);
      expect(h.schedule(Crop.tomato).enabled, isFalse);
      expect(h.schedule(Crop.tomato).minutes, isEmpty);
      await h.setHttpAllowed(false);
      final restored = HardwareController(box)..load();
      expect(restored.allowLocalHttp, isFalse);
      restored.dispose();
    },
  );

  test('daily times validate, persist and find the next local day', () async {
    await h.saveSchedule(
      Crop.tomato,
      const DailyPhotoSchedule(enabled: true, minutes: [480, 960]),
    );
    final restored = HardwareController(box)..load();
    expect(restored.schedule(Crop.tomato).minutes, [480, 960]);
    expect(
      h.schedule(Crop.tomato).next(DateTime(2026, 10, 24, 17)),
      DateTime(2026, 10, 25, 8),
    );
    expect(
      () => const DailyPhotoSchedule(enabled: true).validate(),
      throwsFormatException,
    );
    expect(
      () => const DailyPhotoSchedule(minutes: [480, 480]).validate(),
      throwsFormatException,
    );
    expect(
      () => const DailyPhotoSchedule(minutes: [1440]).validate(),
      throwsFormatException,
    );
    restored.dispose();
  });

  test(
    'locked phone captures, saves original before inference and deduplicates across restart',
    () async {
      await h.saveSchedule(
        Crop.tomato,
        const DailyPhotoSchedule(enabled: true, minutes: [480]),
      );
      await start();
      h.setForeground(false);
      await h.monitorTick(Crop.tomato);
      await h.monitorTick(Crop.tomato);
      expect(h.backgroundActive, isTrue);
      expect(boards.captures, 1);
      expect(model.calls, 1);
      expect(h.scanStore.load().single.source, 'scheduled');
      expect(h.scanStore.load().single.displayLabel, 'Bacterial Spot');
      h.stopPolling();
      final restored = HardwareController(
        box,
        client: boards,
        classifier: model,
        service: _Service(),
        clock: () => now,
      )..load();
      restored.assignments[Crop.tomato] = h.assignments[Crop.tomato]!;
      await restored.withPollingPaused(
        () => restored.startMonitoring(Crop.tomato),
      );
      await restored.monitorTick(Crop.tomato);
      expect(boards.captures, 1);
      restored.dispose();
    },
  );

  test(
    'missed times are skipped and camera recovery does not replay them',
    () async {
      await h.saveSchedule(
        Crop.tomato,
        const DailyPhotoSchedule(enabled: true, minutes: [480, 482]),
      );
      await start();
      boards.cameraOffline = true;
      await h.monitorTick(Crop.tomato);
      expect(h.cameraStatus[Crop.tomato], 'Unavailable');
      boards.cameraOffline = false;
      now = DateTime(2026, 10, 24, 8, 1);
      await h.monitorTick(Crop.tomato);
      expect(h.cameraStatus[Crop.tomato], 'Received');
      expect(h.scanStore.load(), isEmpty);
      now = DateTime(2026, 10, 24, 8, 2);
      await h.monitorTick(Crop.tomato);
      expect(h.scanStore.load(), hasLength(1));
      expect(boards.captures, 3);
    },
  );

  test(
    'classification failure retains original and does not recapture the same slot',
    () async {
      model.fail = true;
      await h.saveSchedule(
        Crop.tomato,
        const DailyPhotoSchedule(enabled: true, minutes: [480]),
      );
      await start();
      await h.monitorTick(Crop.tomato);
      await h.monitorTick(Crop.tomato);
      expect(boards.captures, 1);
      expect(
        box.keys.whereType<String>().where(
          (k) => k.startsWith('scheduled-original-v1/'),
        ),
        hasLength(1),
      );
      expect(h.scanStore.load(), isEmpty);
      expect(h.automaticStatus, 'Photo saved. Analysis could not finish.');
    },
  );

  test(
    'manual camera request waits for quiet sensor reading without concurrent board requests',
    () async {
      boards.readingGate = Completer<void>();
      final reading = h.refresh(Crop.tomato);
      expect(h.busy, isTrue);
      expect(h.userBusy, isFalse);
      final photo = h.capture(Crop.tomato);
      expect(boards.captures, 0);
      boards.readingGate!.complete();
      await reading;
      await photo;
      expect(boards.maximumActive, 1);
    },
  );

  test(
    'sensor alert and scheduled check share one capture when their triggers coincide',
    () async {
      now = DateTime(2026, 10, 24, 7, 59, 50);
      h.notificationSettings[Crop.tomato] = const SensorAlertSettings(
        enabled: true,
        capturePhoto: true,
        analyzePhoto: true,
        showNotifications: false,
        duration: 10,
        rules: [
          CaptureRule(true, 18, 30),
          CaptureRule(false, 0, 100),
          CaptureRule(false, 0, 100),
        ],
      );
      await h.saveSchedule(
        Crop.tomato,
        const DailyPhotoSchedule(enabled: true, minutes: [480]),
      );
      await start();
      await h.monitorTick(Crop.tomato);
      now = DateTime(2026, 10, 24, 8);
      await h.monitorTick(Crop.tomato);
      expect(boards.captures, 1);
      expect(h.scanStore.load(), hasLength(1));
      expect(h.scanStore.load().single.source, 'auto');
    },
  );
}
