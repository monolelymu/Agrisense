import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/core/sensor_notifications.dart';
import 'package:agrisense/data/automatic_capture.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/core/theme.dart';
import 'package:agrisense/features/monitoring/notification_settings_screen.dart';
import 'package:agrisense/features/monitoring/hardware_dashboard.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';

const settings = SensorAlertSettings(
  enabled: true,
  duration: 10,
  cooldown: 60,
  rules: [
    CaptureRule(true, 20, 30),
    CaptureRule(true, 40, 80),
    CaptureRule(true, 20, 80),
  ],
);
HardwareSample sample(
  String id, {
  double? temperature = 35,
  double? humidity = 50,
  bool calibrated = false,
  double? soil = 0,
}) => HardwareSample(
  id: id,
  crop: Crop.tomato,
  receivedAt: DateTime(2026),
  temperature: temperature,
  humidity: humidity,
  soil: soil,
  soilRaw: 1000,
  gasRaw: 200,
  soilCalibrated: calibrated,
);

class NotificationStub extends SensorNotifications {
  bool permitted = true, posted = true;
  final messages = <String>[];
  @override
  bool get supported => true;
  @override
  Future<bool> requestPermission() async => permitted;
  @override
  Future<bool> show(int id, String title, String body) async {
    if (posted) messages.add('$title: $body');
    return posted;
  }
}

class ReadingStub extends HardwareClient {
  int sequence = 0;
  int captures = 0;
  bool failCapture = false;
  @override
  Future<Uint8List> capture(String address) async {
    captures++;
    if (failCapture) throw const SocketException('camera offline');
    return Uint8List.fromList(img.encodeJpg(img.Image(width: 4, height: 4)));
  }

  bool fail = false;
  Completer<void>? pause;
  @override
  Future<HardwareSample> read(String address, Crop crop) async {
    if (fail) throw const SocketException('offline');
    if (pause != null) await pause!.future;
    return sample('${++sequence}');
  }
}

void main() {
  test('sustained excursion, deduplication, recovery and cooldown', () {
    final tracker = SensorAlertTracker();
    var now = DateTime(2026);
    expect(tracker.evaluate(sample('1'), settings, now), isEmpty);
    now = now.add(const Duration(seconds: 10));
    expect(
      tracker.evaluate(sample('1'), settings, now),
      isEmpty,
    ); // Cached sample.
    expect(tracker.evaluate(sample('2'), settings, now), [0]);
    tracker.delivered([0], now);
    now = now.add(const Duration(seconds: 10));
    expect(tracker.evaluate(sample('3'), settings, now), isEmpty);
    expect(
      tracker.evaluate(sample('4', temperature: 25), settings, now),
      isEmpty,
    );
    now = now.add(const Duration(seconds: 10));
    expect(tracker.evaluate(sample('5'), settings, now), isEmpty);
    now = now.add(const Duration(seconds: 10));
    expect(tracker.evaluate(sample('6'), settings, now), isEmpty); // Cooldown.
    now = now.add(const Duration(seconds: 20));
    expect(tracker.evaluate(sample('7'), settings, now), isEmpty);
    now = now.add(const Duration(seconds: 10));
    expect(tracker.evaluate(sample('8'), settings, now), [0]);
  });
  test(
    'missing measurements, gaps, uncalibrated soil, boundaries and reset',
    () {
      final tracker = SensorAlertTracker();
      var now = DateTime(2026);
      expect(tracker.evaluate(sample('1'), settings, now), isEmpty);
      now = now.add(const Duration(seconds: 10));
      expect(
        tracker.evaluate(sample('2', temperature: null), settings, now),
        isEmpty,
      );
      now = now.add(const Duration(seconds: 10));
      expect(tracker.evaluate(sample('3'), settings, now), isEmpty);
      now = now.add(const Duration(seconds: 31));
      expect(
        tracker.evaluate(sample('4'), settings, now),
        isEmpty,
      ); // Gap starts over.
      now = now.add(const Duration(seconds: 10));
      expect(
        tracker.evaluate(
          sample('5', temperature: 30, humidity: 80),
          settings,
          now,
        ),
        isEmpty,
      );
      expect(
        tracker.evaluate(
          sample('6', temperature: 25, calibrated: true),
          settings,
          now,
        ),
        isEmpty,
      );
      now = now.add(const Duration(seconds: 10));
      expect(
        tracker.evaluate(
          sample('7', temperature: 25, calibrated: true),
          settings,
          now,
        ),
        [2],
      );
      tracker.reset();
      expect(
        tracker.evaluate(
          sample('8', temperature: 25, calibrated: true),
          settings,
          now,
        ),
        isEmpty,
      );
    },
  );
  test('invalid rules are rejected', () {
    expect(
      () => const SensorAlertSettings(enabled: true).validate(),
      throwsFormatException,
    );
    expect(
      () => const SensorAlertSettings(cooldown: 0).validate(),
      throwsFormatException,
    );
    expect(
      () => const CaptureRule(true, double.nan, 10).validate(0),
      throwsFormatException,
    );
  });
  group('notification controller', () {
    late Directory dir;
    late Box<dynamic> box;
    late HardwareController h;
    late NotificationStub notifications;
    late ReadingStub client;
    late DateTime now;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('agrisense-notifications-');
      Hive.init(dir.path);
      box = await Hive.openBox<dynamic>('notifications');
      notifications = NotificationStub();
      client = ReadingStub();
      now = DateTime(2026);
      h = HardwareController(
        box,
        client: client,
        notifications: notifications,
        clock: () => now,
      )..load();
      h.assignments[Crop.tomato] = {'sensor': 'http://192.168.1.50'};
      await h.setHttpAllowed(true);
    });
    tearDown(() async {
      h.dispose();
      await box.close();
      await dir.delete(recursive: true);
    });
    Future<void> startAndWait() async {
      final complete = Completer<void>();
      void listener() {
        if (!h.busy && !complete.isCompleted) complete.complete();
      }

      h.addListener(listener);
      h.startPolling(Crop.tomato);
      await complete.future;
      h.removeListener(listener);
    }

    const photoSettings = SensorAlertSettings(
      enabled: true,
      capturePhoto: true,
      duration: 10,
      cooldown: 60,
      rules: [
        CaptureRule(true, 20, 30),
        CaptureRule(false, 0, 100),
        CaptureRule(false, 0, 100),
      ],
    );
    test(
      'warning takes one photo, persists it and keeps polling active',
      () async {
        h.assignments[Crop.tomato]!['camera'] = 'http://192.168.1.51';
        await h.saveNotificationSettings(Crop.tomato, photoSettings);
        await h.testNotification(Crop.tomato);
        expect(client.captures, 0);
        await startAndWait();
        now = now.add(const Duration(seconds: 10));
        await h.refresh(Crop.tomato);
        expect(client.captures, 1);
        expect(h.alertPhotos.single.crop, Crop.tomato);
        expect(h.alertPhotos.single.jpeg, isNotEmpty);
        expect(h.pollingActive, isTrue);
        await h.refresh(Crop.tomato);
        expect(client.captures, 1);
        final restored = HardwareController(box)..load();
        expect(
          restored.alertPhotos.single.sampleId,
          h.alertPhotos.single.sampleId,
        );
        expect(
          restored.notificationSettings[Crop.tomato]!.capturePhoto,
          isTrue,
        );
        restored.dispose();
      },
    );
    test(
      'camera failure does not repeat the alert or stop sensor polling',
      () async {
        h.assignments[Crop.tomato]!['camera'] = 'http://192.168.1.51';
        client.failCapture = true;
        await h.saveNotificationSettings(Crop.tomato, photoSettings);
        await startAndWait();
        now = now.add(const Duration(seconds: 10));
        await h.refresh(Crop.tomato);
        expect(h.alerts.single.state, 'capture_failed');
        await h.refresh(Crop.tomato);
        expect(client.captures, 1);
        expect(notifications.messages.length, 1);
        expect(h.error, isNull);
        expect(h.pollingActive, isTrue);
        expect(h.busy, isFalse);
      },
    );
    test(
      'photo switch requires an assigned camera; blocked notifications still capture',
      () async {
        await expectLater(
          h.saveNotificationSettings(Crop.tomato, photoSettings),
          throwsFormatException,
        );
        h.assignments[Crop.tomato]!['camera'] = 'http://192.168.1.51';
        await h.saveNotificationSettings(Crop.tomato, photoSettings);
        notifications.posted = false;
        await startAndWait();
        now = now.add(const Duration(seconds: 10));
        await h.refresh(Crop.tomato);
        expect(client.captures, 1);
        expect(h.alertPhotos, hasLength(1));
      },
    );

    test(
      'notification denial preserves alert settings; independent crops survive reload',
      () async {
        notifications.permitted = false;
        await h.saveNotificationSettings(Crop.tomato, settings);
        expect(h.notificationSettings[Crop.tomato]!.enabled, isTrue);
        notifications.permitted = true;
        await h.saveNotificationSettings(Crop.tomato, settings);
        final restored = HardwareController(box)..load();
        expect(restored.notificationSettings[Crop.tomato]!.enabled, isTrue);
        expect(restored.notificationSettings[Crop.chili]!.enabled, isFalse);
        restored.dispose();
      },
    );
    test(
      'manual reads do not notify; polling notifies once then stop cancels duration',
      () async {
        await h.saveNotificationSettings(Crop.tomato, settings);
        await h.refresh(Crop.tomato);
        expect(notifications.messages, isEmpty);
        await startAndWait();
        now = now.add(const Duration(seconds: 10));
        await h.refresh(Crop.tomato);
        expect(notifications.messages.length, 1);
        expect(client.captures, 0);
        expect(
          notifications.messages.single,
          contains('Tomato: sensor limit exceeded'),
        );
        await h.refresh(Crop.tomato);
        expect(notifications.messages.length, 1);
        h.stopPolling();
        now = now.add(const Duration(seconds: 100));
        await h.refresh(Crop.tomato);
        expect(notifications.messages.length, 1);
      },
    );
    test(
      'notification failure keeps successful readings and reports delivery problem',
      () async {
        await h.saveNotificationSettings(Crop.tomato, settings);
        notifications.posted = false;
        await startAndWait();
        now = now.add(const Duration(seconds: 10));
        await h.refresh(Crop.tomato);
        expect(h.samples.length, 2);
        expect(h.error, isNull);
        expect(h.status[Crop.tomato], 'Received');
        expect(h.notificationIssue?.code, 'PER-001');
      },
    );
    test('in-flight read after polling stops cannot send an alert', () async {
      await h.saveNotificationSettings(Crop.tomato, settings);
      await startAndWait();
      now = now.add(const Duration(seconds: 10));
      client.pause = Completer<void>();
      final request = h.refresh(Crop.tomato);
      h.stopPolling();
      client.pause!.complete();
      await request;
      expect(notifications.messages, isEmpty);
    });
    test('test notification works without a sensor request', () async {
      await h.saveNotificationSettings(Crop.tomato, settings);
      await h.testNotification(Crop.tomato);
      expect(client.sequence, 0);
      expect(notifications.messages.single, contains('This is a test'));
    });
    test(
      'settings saves and transient inactive states preserve monitoring intent',
      () async {
        await startAndWait();
        expect(h.pollingActive, isTrue);
        h.setForeground(false);
        expect(h.polling, isTrue);
        expect(h.pollingActive, isFalse);
        h.setForeground(true);
        expect(h.pollingActive, isTrue);
        await h.saveNotificationSettings(Crop.tomato, settings);
        expect(h.polling, isTrue);
        expect(h.pollingActive, isTrue);
        await h.testNotification(Crop.tomato);
        expect(h.pollingActive, isTrue);
      },
    );
    test(
      'nested settings pauses resume once; explicit OFF stays off',
      () async {
        await startAndWait();
        await h.withPollingPaused(() async {
          expect(h.polling, isTrue);
          expect(h.pollingActive, isFalse);
          await h.withPollingPaused(() async {
            h.setForeground(false);
            h.setForeground(true);
            expect(h.pollingActive, isFalse);
          });
          expect(h.pollingActive, isFalse);
        });
        expect(h.pollingActive, isTrue);
        await h.withPollingPaused(() async {
          h.stopPolling();
        });
        h.setForeground(false);
        h.setForeground(true);
        expect(h.polling, isFalse);
        expect(h.pollingActive, isFalse);
      },
    );
    test('background time cannot satisfy notification duration', () async {
      await h.saveNotificationSettings(Crop.tomato, settings);
      await startAndWait();
      h.setForeground(false, resetDuration: true);
      now = now.add(const Duration(seconds: 120));
      await h.refresh(Crop.tomato);
      expect(notifications.messages, isEmpty);
      h.setForeground(true);
      await h.refresh(Crop.tomato);
      expect(notifications.messages, isEmpty);
      now = now.add(const Duration(seconds: 10));
      await h.refresh(Crop.tomato);
      expect(notifications.messages.length, 1);
    });
    testWidgets('notification controls fit a narrow phone with larger text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: NotificationSettingsScreen(hardware: h, crop: Crop.tomato),
        ),
      );
      for (var i = 0; i < 3; i++) {
        final checkbox = find.byKey(ValueKey('notification-metric-$i'));
        await tester.scrollUntilVisible(
          checkbox,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        // A partially visible tall tile can have its center outside the viewport.
        // Center the actual control and verify the tap changes its value.
        await Scrollable.ensureVisible(tester.element(checkbox), alignment: .5);
        await tester.pumpAndSettle();
        expect(checkbox.hitTestable(), findsOneWidget);
        final previous = tester.widget<CheckboxListTile>(checkbox).value;
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(checkbox).value, !previous!);
        expect(tester.takeException(), isNull);
      }
      final duration = find.byKey(
        const ValueKey('notification-Duration (seconds)'),
      );
      final cooldown = find.byKey(
        const ValueKey('notification-Cooldown (seconds)'),
      );
      await tester.scrollUntilVisible(
        cooldown,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(cooldown).top - tester.getRect(duration).bottom,
        greaterThan(20),
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('Trends chart fits a narrow phone with constant readings', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      h.samples.add(sample('chart'));
      await tester.pumpWidget(
        HardwareApp(
          hardware: h,
          scans: TomatoScanStore(box),
          showTutorial: false,
        ),
      );
      await tester.tap(find.text('Trends').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Temperature (°C)'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('1 samples'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    test(
      'failed sensor request resets the sustained-reading duration',
      () async {
        await h.saveNotificationSettings(Crop.tomato, settings);
        await startAndWait();
        now = now.add(const Duration(seconds: 10));
        client.fail = true;
        await h.refresh(Crop.tomato);
        client.fail = false;
        now = now.add(const Duration(seconds: 10));
        await h.refresh(Crop.tomato);
        expect(notifications.messages, isEmpty);
        now = now.add(const Duration(seconds: 10));
        await h.refresh(Crop.tomato);
        expect(notifications.messages.length, 1);
      },
    );
  });
}
