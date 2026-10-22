import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:image/image.dart' as img;
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/core/app_issue.dart';
import 'package:agrisense/core/sensor_notifications.dart';
import 'package:agrisense/data/automatic_capture.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/data/monitoring_alert.dart';
import 'package:agrisense/features/diagnosis/tomato_classifier.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';

class FakeNotifications extends SensorNotifications {
  bool posted = false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<bool> show(int id, String title, String body) async => posted;
}

class FakeCamera extends HardwareClient {
  int reads = 0, captures = 0;
  bool fail = false;
  Completer<void>? gate;
  late final bytes = Uint8List.fromList(
    img.encodeJpg(img.Image(width: 8, height: 8)),
  );
  @override
  Future<HardwareSample> read(String address, Crop crop) async =>
      HardwareSample(
        id: '${++reads}',
        crop: crop,
        receivedAt: DateTime(2026),
        temperature: 35,
        humidity: 90,
        soil: null,
        soilRaw: 1,
        gasRaw: 1,
        soilCalibrated: false,
      );
  @override
  Future<Uint8List> capture(String address) async {
    captures++;
    if (gate != null) await gate!.future;
    if (fail) throw const SocketException('offline');
    return bytes;
  }
}

class FakeClassifier extends TomatoClassifier {
  bool eggEnabled = false;
  bool enabled = true;
  Completer<void>? gate;
  @override
  bool supports(Crop crop) =>
      enabled &&
      (super.supports(crop) || (eggEnabled && crop == Crop.eggplant));
  int calls = 0;
  bool fail = false;
  Uint8List? input;
  @override
  Future<TomatoScan> classifyCrop(Crop crop, Uint8List photo) async {
    calls++;
    input = photo;
    if (gate != null) await gate!.future;
    if (fail) throw StateError('model failed');
    return TomatoScan(
      id: 'ignored',
      timestamp: DateTime(2026),
      label: 'healthy',
      score: .55,
      preview: Uint8List(0),
      modelVersion: 'fake-v1',
      crop: crop,
      predictions: const [ScanPrediction('healthy', .55)],
    );
  }
}

class FailingScans extends TomatoScanStore {
  FailingScans(super.box);
  bool fail = false;
  @override
  Future<void> save(TomatoScan scan) async {
    if (fail) throw StateError('storage');
    await super.save(scan);
  }
}

class FailingAlerts extends MonitoringAlertStore {
  FailingAlerts(super.box);
  bool fail = false;
  @override
  Future<void> save(MonitoringAlert alert) async {
    if (fail) throw StateError('storage');
    await super.save(alert);
  }
}

void main() {
  late Directory dir;
  late Box<dynamic> box;
  late HardwareController h;
  late FakeCamera camera;
  late FakeClassifier classifier;
  late FailingScans scans;
  late FailingAlerts alerts;
  var now = DateTime(2026);
  const rules = [
    CaptureRule(true, 20, 30),
    CaptureRule(true, 40, 80),
    CaptureRule(false, 0, 100),
  ];
  const settings = SensorAlertSettings(
    enabled: true,
    capturePhoto: true,
    analyzePhoto: true,
    duration: 10,
    cooldown: 30,
    rules: rules,
  );
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('auto-diagnosis-');
    Hive.init(dir.path);
    box = await Hive.openBox<dynamic>('diagnosis');
    now = DateTime(2026);
    camera = FakeCamera();
    classifier = FakeClassifier();
    scans = FailingScans(box);
    alerts = FailingAlerts(box);
    h = HardwareController(
      box,
      client: camera,
      notifications: FakeNotifications(),
      classifier: classifier,
      scanStore: scans,
      alertStore: alerts,
      clock: () => now,
    )..load();
    h.assignments[Crop.tomato] = {
      'sensor': 'http://192.168.1.50',
      'camera': 'http://192.168.1.51',
    };
    h.allowLocalHttp = true;
    await h.saveNotificationSettings(Crop.tomato, settings);
  });
  tearDown(() async {
    h.dispose();
    await box.close();
    await dir.delete(recursive: true);
  });
  Future<void> start([Crop crop = Crop.tomato]) async {
    final done = Completer<void>();
    void listen() {
      if (!h.busy && !done.isCompleted) done.complete();
    }

    h.addListener(listen);
    h.startPolling(crop);
    await done.future;
    h.removeListener(listen);
  }

  Future<void> trigger([Crop crop = Crop.tomato]) async {
    await start(crop);
    now = now.add(const Duration(seconds: 10));
    await h.refresh(crop);
  }

  test(
    'verified-model capability routes Eggplant alerts to linked Eggplant history',
    () async {
      // Workflow fake only. Production remains gated until preprocessing is verified.
      classifier.eggEnabled = true;
      h.assignments[Crop.eggplant] = {
        'sensor': 'http://192.168.1.60',
        'camera': 'http://192.168.1.61',
      };
      await h.saveNotificationSettings(Crop.eggplant, settings);
      await trigger(Crop.eggplant);
      expect(classifier.calls, 1);
      expect(h.alerts.single.crop, Crop.eggplant);
      expect(h.alerts.single.state, 'completed');
      final scan = scans.load().single;
      expect(scan.crop, Crop.eggplant);
      expect(scan.source, 'auto');
      expect(scan.alertId, h.alerts.single.id);
      expect(scan.assessment!['reference_version'], startsWith('eggplant-'));
      await h.retryAlert(h.alerts.single.id, capture: false);
      expect(scans.load().length, 1);
      expect(classifier.calls, 1);
    },
  );

  test(
    'denied notifications still capture original and save one linked uncertain result',
    () async {
      await trigger();
      expect(camera.captures, 1);
      expect(classifier.calls, 1);
      expect(classifier.input, camera.bytes);
      expect(h.alerts.single.metrics, [0, 1]);
      expect(h.alerts.single.state, 'completed');
      final result = scans.load().single;
      expect(result.alertId, h.alerts.single.id);
      expect(result.source, 'auto');
      expect(result.uncertain, isTrue);
      expect(result.sensorContext!['temp_c'], 35);
      expect(h.photoFor(h.alerts.single.id)!.jpeg, camera.bytes);
      await h.refresh(Crop.tomato);
      expect(camera.captures, 1);
      expect(h.pollingActive, isTrue);
    },
  );
  test(
    'capture failure is persistent and only manual retry recovers',
    () async {
      camera.fail = true;
      await trigger();
      final id = h.alerts.single.id;
      expect(h.alerts.single.state, 'capture_failed');
      now = now.add(const Duration(seconds: 30));
      await h.refresh(Crop.tomato);
      expect(camera.captures, 1);
      camera.fail = false;
      await h.retryAlert(id, capture: true);
      expect(h.alerts.single.state, 'completed');
      expect(scans.load().length, 1);
      await h.retryAlert(id, capture: false);
      expect(scans.load().length, 1);
      expect(classifier.calls, 1);
    },
  );
  test(
    'offline analysis retry uses retained original without hardware or recapture',
    () async {
      classifier.fail = true;
      await trigger();
      expect(h.alerts.single.state, 'analysis_failed');
      await h.setHttpAllowed(false);
      h.assignments.clear();
      final reads = camera.reads;
      classifier.fail = false;
      await h.retryAlert(h.alerts.single.id, capture: false);
      expect(camera.captures, 1);
      expect(classifier.calls, 2);
      expect(scans.load().length, 1);
      expect(camera.reads, reads);
      await h.retryAlert(h.alerts.single.id, capture: false);
      expect(classifier.calls, 2);
      expect(scans.load().length, 1);
    },
  );
  test(
    'offline saving retry reuses prediction without hardware or inference',
    () async {
      scans.fail = true;
      await trigger();
      expect(h.alerts.single.state, 'save_failed');
      await h.setHttpAllowed(false);
      h.assignments.clear();
      final reads = camera.reads;
      await h.retryAlert(h.alerts.single.id, capture: false);
      expect(h.alerts.single.state, 'save_failed');
      expect(h.canRetrySaving(h.alerts.single.id), isTrue);
      scans.fail = false;
      await h.retryAlert(h.alerts.single.id, capture: false);
      expect(classifier.calls, 1);
      expect(camera.captures, 1);
      expect(camera.reads, reads);
      expect(scans.load().single.id, h.alerts.single.resultId);
      await h.retryAlert(h.alerts.single.id, capture: false);
      expect(scans.load().length, 1);
      expect(classifier.calls, 1);
      expect(h.canRetrySaving(h.alerts.single.id), isFalse);
    },
  );
  test(
    'capture retries still require hardware access and matching assignment',
    () async {
      camera.fail = true;
      await trigger();
      final id = h.alerts.single.id;
      await h.setHttpAllowed(false);
      camera.fail = false;
      await expectLater(h.retryAlert(id, capture: true), throwsFormatException);
      expect(camera.captures, 1);
      h.allowLocalHttp = true;
      h.assignments[Crop.tomato]!.remove('camera');
      await h.retryAlert(id, capture: true);
      expect(camera.captures, 1);
      expect(h.alerts.single.issueCode, AppIssue.assignment.code);
      expect(scans.load(), isEmpty);
    },
  );
  test(
    'offline analysis cannot recover a missing original or unavailable model',
    () async {
      classifier.fail = true;
      await trigger();
      final id = h.alerts.single.id;
      await h.setHttpAllowed(false);
      classifier.fail = false;
      classifier.enabled = false;
      await h.retryAlert(id, capture: false);
      expect(h.alerts.single.state, 'model_unavailable');
      expect(h.alerts.single.issueCode, AppIssue.unsupported.code);
      expect(classifier.calls, 1);
      classifier.enabled = true;
      h.alertPhotos.clear();
      await h.retryAlert(id, capture: false);
      expect(h.alerts.single.issueCode, AppIssue.photo.code);
      expect(scans.load(), isEmpty);
      expect(camera.captures, 1);
      expect(classifier.calls, 1);
    },
  );
  test(
    'local recovery remains foreground-only and prevents overlapping retries',
    () async {
      classifier.fail = true;
      await trigger();
      final id = h.alerts.single.id;
      await h.setHttpAllowed(false);
      h.setForeground(false);
      await expectLater(
        h.retryAlert(id, capture: false),
        throwsA(AppIssue.busy),
      );
      expect(classifier.calls, 1);
      h.setForeground(true);
      classifier.fail = false;
      classifier.gate = Completer<void>();
      final retry = h.retryAlert(id, capture: false);
      while (classifier.calls < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      await expectLater(
        h.retryAlert(id, capture: false),
        throwsFormatException,
      );
      classifier.gate!.complete();
      await retry;
      expect(scans.load().length, 1);
      expect(camera.captures, 1);
      expect(classifier.calls, 2);
    },
  );
  test(
    'automatic capture still stops analysis when hardware access is disabled',
    () async {
      await start();
      camera.gate = Completer<void>();
      now = now.add(const Duration(seconds: 10));
      final work = h.refresh(Crop.tomato);
      while (camera.captures == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      h.allowLocalHttp = false;
      camera.gate!.complete();
      await work;
      expect(classifier.calls, 0);
      expect(h.alerts.single.state, 'interrupted');
    },
  );
  test('alert storage failure prevents camera operation', () async {
    alerts.fail = true;
    await trigger();
    expect(camera.captures, 0);
    expect(h.alerts, isEmpty);
    expect(h.samples.length, 2);
    expect(h.status[Crop.tomato], 'Received');
  });
  test(
    'stop during capture saves photo but does not start inference',
    () async {
      await start();
      camera.gate = Completer<void>();
      now = now.add(const Duration(seconds: 10));
      final work = h.refresh(Crop.tomato);
      while (camera.captures == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      h.stopPolling();
      camera.gate!.complete();
      await work;
      expect(classifier.calls, 0);
      expect(h.alerts.single.state, 'interrupted');
    },
  );
  test(
    'restart reconciles saved results and marks unfinished records interrupted',
    () async {
      await trigger();
      final completed = h.alerts.single;
      await alerts.save(completed.change('saving'));
      await alerts.save(
        MonitoringAlert(
          id: 'unfinished',
          sample: completed.sample,
          settings: settings,
          metrics: [0],
          timestamp: now,
          camera: completed.camera,
          state: 'capturing',
        ),
      );
      final restored = HardwareController(box)..load();
      await restored.reconcileAlerts();
      expect(
        restored.alerts.firstWhere((a) => a.id == completed.id).state,
        'completed',
      );
      expect(
        restored.alerts.firstWhere((a) => a.id == 'unfinished').state,
        'interrupted',
      );
      expect(restored.polling, isFalse);
      restored.dispose();
    },
  );
  test(
    'photo retention stays bounded and expired original does not delete diagnosis',
    () async {
      await trigger();
      final id = h.alerts.single.id;
      h.notificationSettings[Crop.tomato] = const SensorAlertSettings(
        enabled: true,
        capturePhoto: true,
        duration: 10,
        cooldown: 30,
        repeat: true,
        rules: rules,
      );
      for (var i = 0; i < 21; i++) {
        now = now.add(const Duration(seconds: 30));
        await h.refresh(Crop.tomato);
      }
      expect(h.alertPhotos.length, 20);
      expect(h.photoFor(id), isNull);
      expect(h.alerts.length, 22);
      await h.retryAlert(
        id,
        capture: false,
      ); // An already saved diagnosis is idempotent.
      expect(scans.load().length, 1);
      expect(h.alerts.firstWhere((a) => a.id == id).state, 'completed');
    },
  );
}
