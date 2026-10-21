import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:agrisense/core/sensor_notifications.dart';
import 'package:agrisense/data/automatic_capture.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/data/monitoring_alert.dart';

HardwareSample reading(
  String id,
  DateTime now, {
  double? temp = 25,
  double? humidity = 50,
  double? soil = 40,
  bool calibrated = true,
}) => HardwareSample(
  id: id,
  crop: Crop.tomato,
  receivedAt: now,
  temperature: temp,
  humidity: humidity,
  soil: soil,
  soilRaw: 1000,
  gasRaw: 300,
  soilCalibrated: calibrated,
);

void main() {
  test('legacy settings preserve behavior, new capabilities are opt-in', () {
    final legacy = SensorAlertSettings.fromJson({
      'enabled': true,
      'capture_photo': true,
      'duration': 10,
      'cooldown': 60,
      'rules': [
        {'enabled': true, 'min': 20, 'max': 30},
        {'enabled': false, 'min': 0, 'max': 100},
        {'enabled': false, 'min': 0, 'max': 100},
      ],
    });
    expect(legacy.preset, 'custom');
    expect(legacy.showNotifications, isTrue);
    expect(legacy.analyzePhoto, isFalse);
    expect(legacy.repeat, isFalse);
    expect(legacy.capturePhoto, isTrue);
  });
  test(
    'Sensitive baseline is fixed, clamped, and excludes missing/uncalibrated metrics',
    () {
      final now = DateTime(2026);
      final sensitive = SensorAlertSettings.sensitive(
        reading('1', now, temp: 80, humidity: 2, calibrated: false),
        now,
      );
      sensitive.validate();
      expect(sensitive.rules[0].minimum, 79);
      expect(sensitive.rules[0].maximum, 80);
      expect(sensitive.rules[1].minimum, 0);
      expect(sensitive.rules[1].maximum, 7);
      expect(sensitive.rules[2].enabled, isFalse);
      expect(sensitive.repeat, isTrue);
      expect(sensitive.duration, 10);
      expect(sensitive.cooldown, 30);
      expect(
        SensorAlertSettings.fromJson(sensitive.toJson()).baseline!['sample_id'],
        '1',
      );
      expect(
        () => SensorAlertSettings.sensitive(
          reading('1', now),
          now.add(const Duration(seconds: 31)),
        ),
        throwsFormatException,
      );
      expect(
        () => SensorAlertSettings.sensitive(
          reading('1', now, temp: null, humidity: null, calibrated: false),
          now,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'repeat respects accepted-at cooldown, fresh IDs, and missing readings',
    () {
      var now = DateTime(2026);
      final rules = SensorAlertSettings(
        enabled: true,
        duration: 10,
        cooldown: 30,
        repeat: true,
        rules: const [
          CaptureRule(true, 20, 30),
          CaptureRule(false, 0, 100),
          CaptureRule(false, 0, 100),
        ],
      );
      final tracker = SensorAlertTracker();
      expect(
        tracker.evaluate(reading('0', now, temp: 35), rules, now),
        isEmpty,
      );
      now = now.add(const Duration(seconds: 10));
      expect(tracker.evaluate(reading('1', now, temp: 35), rules, now), [0]);
      tracker.delivered([0], now);
      for (var i = 2; i <= 3; i++) {
        now = now.add(const Duration(seconds: 10));
        expect(
          tracker.evaluate(reading('$i', now, temp: 35), rules, now),
          isEmpty,
        );
      }
      now = now.add(const Duration(seconds: 10));
      expect(tracker.evaluate(reading('4', now, temp: 35), rules, now), [0]);
      tracker.delivered([0], now);
      expect(
        tracker.evaluate(
          reading('4', now, temp: 35),
          rules,
          now.add(const Duration(seconds: 30)),
        ),
        isEmpty,
      );
      now = now.add(const Duration(seconds: 30));
      expect(
        tracker.evaluate(reading('5', now, temp: null), rules, now),
        isEmpty,
      );
      expect(
        tracker.evaluate(reading('6', now, temp: 35), rules, now),
        isEmpty,
      );
    },
  );
  test(
    'alerts persist, retain newest 500, and do not touch old scans',
    () async {
      final dir = await Directory.systemTemp.createTemp('monitoring-alert-');
      Hive.init(dir.path);
      final box = await Hive.openBox<dynamic>('events');
      try {
        await box.put('tomato-photo-v1/existing', {'keep': true});
        final store = MonitoringAlertStore(box);
        final now = DateTime(2026);
        // Seed older metadata in a batch to keep this retention check fast.
        await box.putAll({
          for (var i = 0; i < 500; i++)
            '${MonitoringAlertStore.prefix}$i': MonitoringAlert(
              id: '$i',
              sample: reading('$i', now),
              settings: const SensorAlertSettings(),
              metrics: [0],
              timestamp: now.add(Duration(seconds: i)),
              camera: '',
            ).toJson(),
        });
        await store.save(
          MonitoringAlert(
            id: 'last',
            sample: reading('last', now),
            settings: const SensorAlertSettings(),
            metrics: [0],
            timestamp: now.add(const Duration(seconds: 501)),
            camera: '',
          ),
        );
        expect(store.load().length, 500);
        expect(store.load().first.id, 'last');
        expect(box.get('${MonitoringAlertStore.prefix}0'), isNull);
        expect(box.get('tomato-photo-v1/existing'), {'keep': true});
        await box.close();
        final reopened = await Hive.openBox<dynamic>('events');
        expect(
          MonitoringAlertStore(reopened).load().first.resultId,
          'auto-last',
        );
        await reopened.close();
      } finally {
        if (box.isOpen) await box.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
