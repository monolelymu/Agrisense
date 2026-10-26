import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/core/monitoring_service.dart';
import 'package:agrisense/data/models.dart';

class FakeService extends MonitoringServiceBridge {
  int starts = 0, stops = 0;
  bool accepted = true;
  void Function(String)? callback;
  @override
  bool get supported => true;
  @override
  void listen(void Function(String event) onEvent) {
    callback = onEvent;
  }

  @override
  Future<bool> start(String crop) async {
    starts++;
    return accepted;
  }

  @override
  Future<void> stop() async {
    stops++;
    callback?.call('serviceStopped');
  }
}

void main() {
  late Directory dir;
  late Box<dynamic> box;
  late FakeService service;
  late HardwareController h;
  setUp(() async {
    dir = await Directory('test').createTemp('background-monitoring-');
    Hive.init(dir.path);
    box = await Hive.openBox<dynamic>('background');
    service = FakeService();
    h = HardwareController(box, service: service)..load();
    h.bindService();
    h.allowLocalHttp = true;
    h.assignments[Crop.tomato] = {'sensor': 'http://192.168.1.50'};
  });
  tearDown(() async {
    h.dispose();
    await box.close();
    await dir.delete(recursive: true);
  });
  Future<void> startPaused() => h.withPollingPaused(() async {
    await h.setBackgroundEnabled(true);
    await h.startMonitoring(Crop.tomato);
  });

  test(
    'explicit service start survives Activity pause and does not duplicate timers on return',
    () async {
      await startPaused();
      expect(service.starts, 1);
      expect(h.pollingActive, isTrue);
      service.callback!('activityPaused');
      expect(h.pollingActive, isTrue);
      for (var i = 0; i < 5; i++) {
        service.callback!('activityResumed');
      }
      expect(service.starts, 1);
      expect(h.pollingActive, isTrue);
      service.callback!('stopRequested');
      expect(h.polling, isFalse);
      expect(h.backgroundActive, isFalse);
      service.callback!('activityResumed');
      expect(h.polling, isFalse);
    },
  );
  test(
    'turning background off keeps foreground monitoring and respects later pause',
    () async {
      await startPaused();
      await h.setBackgroundEnabled(false);
      expect(h.polling, isTrue);
      expect(h.pollingActive, isTrue);
      expect(service.stops, 1);
      service.callback!('activityPaused');
      expect(h.pollingActive, isFalse);
    },
  );
  test(
    'unexpected service termination stops monitoring rather than silently falling back',
    () async {
      await startPaused();
      service.callback!('serviceStopped');
      expect(h.polling, isFalse);
    },
  );
  test(
    'saved preference does not automatically start a new process session',
    () async {
      await h.setBackgroundEnabled(true);
      final restored = HardwareController(box, service: service)..load();
      expect(restored.backgroundEnabled, isTrue);
      expect(restored.polling, isFalse);
      expect(restored.backgroundActive, isFalse);
      expect(service.starts, 0);
      restored.dispose();
    },
  );
  test('native start rejection leaves no active poller', () async {
    service.accepted = false;
    await h.setBackgroundEnabled(true);
    await expectLater(h.startMonitoring(Crop.tomato), throwsA(anything));
    expect(h.polling, isFalse);
    expect(h.backgroundActive, isFalse);
  });
}
