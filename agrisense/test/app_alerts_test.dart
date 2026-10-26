import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:image/image.dart' as img;
import 'package:agrisense/core/app_alerts_bridge.dart';
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/core/sensor_notifications.dart';
import 'package:agrisense/core/theme.dart';
import 'package:agrisense/data/app_alert_event.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';
import 'package:agrisense/features/diagnosis/camera_photo_preview.dart';
import 'package:agrisense/features/monitoring/app_alerts_screen.dart';
import 'package:agrisense/features/monitoring/hardware_dashboard.dart';
import 'package:agrisense/features/monitoring/watering_reminder_card.dart';

class _Native extends AppAlertsBridge {
  @override
  bool get supported => true;
  Map<String, dynamic> value = {
    'enabled': false,
    'minute': null,
    'precise': false,
    'events': <Map>[],
  };
  String? acknowledged;
  @override
  Future<Map> snapshot() async => value;
  @override
  Future<Map> configure(int? minute, bool enabled) async {
    value = {...value, 'enabled': enabled, 'minute': minute};
    return value;
  }

  @override
  Future<void> restore() async {}
  @override
  void listen(Future<void> Function() refresh) {}
  @override
  Future<void> acknowledge(String token) async {
    acknowledged = token;
    value.remove('tap');
  }

  @override
  Future<bool> post(Map<String, dynamic> event) async => true;
}

class _Notifications extends SensorNotifications {
  @override
  Future<bool> requestPermission() async => true;
}

class _Camera extends HardwareClient {
  Object? failure;
  late Uint8List bytes = Uint8List.fromList(
    img.encodeJpg(img.Image(width: 320, height: 240)),
  );
  @override
  Future<Uint8List> capture(String address) async {
    if (failure != null) throw failure!;
    return bytes;
  }
}

HardwareSample _sample(
  String id,
  DateTime at, {
  double? temp = 25,
  double? humidity = 60,
  int soil = 2000,
}) => HardwareSample(
  id: id,
  crop: Crop.tomato,
  receivedAt: at,
  temperature: temp,
  humidity: humidity,
  soil: null,
  soilRaw: soil,
  gasRaw: 200,
  soilCalibrated: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Box<dynamic> box;
  late HardwareController h;
  late _Native native;
  late _Camera camera;
  setUp(() async {
    dir = await Directory('test').createTemp('app-alerts-');
    Hive.init(dir.path);
    box = await Hive.openBox<dynamic>('app-alerts');
    native = _Native();
    camera = _Camera();
    h = HardwareController(
      box,
      appAlerts: native,
      client: camera,
      notifications: _Notifications(),
    )..load();
  });
  tearDown(() async {
    h.dispose();
    await box.close();
    await dir.delete(recursive: true);
  });

  test(
    'new defaults initialize all three once, persist units, and wait for missing values',
    () {
      final at = DateTime(2026);
      final initial = SensorAlertSettings.initial;
      expect(initial.rules.every((r) => r.enabled), isTrue);
      expect(initial.awaitingLimits, isTrue);
      final first = initial.initializeFrom(_sample('1', at, humidity: null));
      expect(first.rules[0].minimum, 24);
      expect(first.rules[2].minimum, 1850);
      expect(first.rules[2].maximum, 2150);
      expect(first.baseline!.containsKey('metric_1'), isFalse);
      final later = first.initializeFrom(
        _sample('2', at, temp: 40, humidity: 60, soil: 3000),
      );
      expect(
        later.rules[0].minimum,
        24,
      ); // No moving baseline to conceal changes.
      expect(later.rules[1].minimum, 55);
      final restored = SensorAlertSettings.fromJson(later.toJson());
      expect(restored.soilRaw, isTrue);
      expect(restored.cooldown, 60);
      final tracker = SensorAlertTracker();
      expect(
        tracker.evaluate(_sample('3', at, soil: 2400), restored, at),
        isEmpty,
      );
      expect(
        tracker.evaluate(
          _sample('4', at.add(const Duration(seconds: 10)), soil: 2400),
          restored,
          at.add(const Duration(seconds: 10)),
        ),
        [2],
      );
    },
  );

  test(
    'legacy percentage soil rules retain units and saved off configuration',
    () async {
      const old = SensorAlertSettings();
      await box.put('foreground-notification-rules-v1', {
        'tomato': old.toJson(),
      });
      final restored = HardwareController(box)..load();
      expect(restored.notificationSettings[Crop.tomato]!.enabled, isFalse);
      expect(restored.notificationSettings[Crop.tomato]!.soilRaw, isFalse);
      restored.dispose();
    },
  );

  test('late first readings preserve explicitly edited limits', () {
    final saved = SensorAlertSettings.fromJson({
      ...SensorAlertSettings.initial.toJson(),
      'preset': 'custom',
      'baseline': {'manual_0': true},
      'rules': [
        {'enabled': true, 'min': 20, 'max': 30},
        {'enabled': true, 'min': 0, 'max': 100},
        {'enabled': true, 'min': 0, 'max': 4095},
      ],
    });
    final ready = saved.initializeFrom(_sample('1', DateTime(2026), temp: 40));
    expect(ready.rules[0].minimum, 20);
    expect(ready.rules[0].maximum, 30);
    expect(ready.rules[2].minimum, 1850);
  });

  test(
    'legacy unconfigured warnings adopt defaults without overriding a saved off choice',
    () async {
      await box.put('foreground-notification-rules-v1', {
        'tomato': {
          'enabled': true,
          'rules': [
            {'enabled': false},
            {'enabled': false},
            {'enabled': false},
          ],
        },
        'chili': const SensorAlertSettings().toJson(),
      });
      final restored = HardwareController(box)..load();
      expect(
        restored.notificationSettings[Crop.tomato]!.rules.every(
          (r) => r.enabled,
        ),
        isTrue,
      );
      expect(restored.notificationSettings[Crop.chili]!.enabled, isFalse);
      restored.dispose();
    },
  );

  test(
    'reminders save edit disable and clear without monitoring or hardware access',
    () async {
      h.allowLocalHttp = false;
      await h.saveWatering(600, true);
      expect(h.watering.minute, 600);
      expect(h.watering.enabled, isTrue);
      expect(h.polling, isFalse);
      await h.saveWatering(650, true);
      expect(h.watering.minute, 650);
      await h.saveWatering(650, false);
      expect(h.watering.enabled, isFalse);
      await h.saveWatering(null, false);
      expect(h.watering.minute, isNull);
      await expectLater(h.saveWatering(null, true), throwsFormatException);
    },
  );

  test(
    'native delivery receipts merge once and notification target is acknowledged',
    () async {
      final event = AppAlertEvent(
        id: 'water-1',
        type: 'watering',
        title: 'Watering reminder',
        body: 'Check the soil.',
        at: DateTime(2026),
        target: 'water-1',
      );
      native.value['events'] = [event.toJson()];
      native.value['tap'] = {
        'type': 'watering',
        'target': 'water-1',
        'token': 'tap-1',
      };
      await h.initializeAppAlerts();
      await h.syncAppAlerts();
      expect(h.events, hasLength(1));
      expect(h.alertTarget!.target, 'water-1');
      await h.acknowledgeAlertTarget('tap-1');
      expect(native.acknowledged, 'tap-1');
      expect(h.alertTarget, isNull);
      final restored = HardwareController(box)..load();
      expect(restored.events.single.id, 'water-1');
      restored.dispose();
    },
  );

  test(
    'HTTP capture failure and timeout are separate from loss of communication',
    () async {
      h.assignments[Crop.tomato] = {'camera': 'http://192.168.1.21'};
      camera.failure = const HardwareHttpException(500, 'capture_failed');
      await expectLater(
        h.capture(Crop.tomato),
        throwsA(isA<HardwareHttpException>()),
      );
      expect(h.cameraStatus[Crop.tomato], 'Capture failed');
      camera.failure = TimeoutException('timeout');
      await expectLater(
        h.capture(Crop.tomato),
        throwsA(isA<TimeoutException>()),
      );
      expect(h.cameraStatus[Crop.tomato], 'Timed out');
      camera.failure = const SocketException('offline');
      await expectLater(
        h.capture(Crop.tomato),
        throwsA(isA<SocketException>()),
      );
      expect(h.cameraStatus[Crop.tomato], 'Unreachable');
      camera.failure = null;
      final bytes = await h.capture(Crop.tomato);
      expect(h.lastCameraPhoto!.$1, same(bytes));
      expect(h.cameraStatus[Crop.tomato], 'Received');
      camera.bytes = Uint8List.fromList([1, 2, 3]);
      await expectLater(h.capture(Crop.tomato), throwsFormatException);
      expect(h.cameraStatus[Crop.tomato], 'Capture failed');
      expect(h.lastCameraPhoto!.$1, same(bytes)); // Keep the last valid image.
      expect(h.lastCameraOriginal, same(camera.bytes));
    },
  );

  testWidgets(
    'bell exists on all three tabs and watering card exposes delayed timing',
    (tester) async {
      h.watering = const WateringReminder(
        enabled: true,
        minute: 600,
        precise: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: HardwareDashboard(hardware: h, scans: TomatoScanStore(box)),
        ),
      );
      for (final index in [0, 1, 2]) {
        await tester.tap(find.byType(NavigationDestination).at(index));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Alerts'), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Alerts'));
      await tester.pumpAndSettle();
      expect(find.byType(AppAlertsScreen), findsOneWidget);
      expect(find.text('No alerts yet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: WateringReminderCard(hardware: h),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Android may delay'), findsOneWidget);
      expect(find.text('Clear reminder time'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Clear reminder time'));
      });
      await tester.pumpAndSettle();
      expect(h.watering.minute, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'cold notification opens matching reminder and missing target stays in Alerts',
    (tester) async {
      final event = AppAlertEvent(
        id: 'water-1',
        type: 'watering',
        title: 'Watering reminder',
        body: 'Check the soil.',
        at: DateTime(2026),
        target: 'water-1',
      );
      h.events.add(event);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: AppAlertsScreen(
            hardware: h,
            initialTarget: const AlertTarget('watering', 'water-1', 'tap'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Check the soil.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AppAlertsScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: AppAlertsScreen(
            hardware: h,
            initialTarget: const AlertTarget('sensor', 'missing', 'tap2'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alerts'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'shared preview renders original bytes and capture time consistently',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraPhotoPreview(
              bytes: camera.bytes,
              at: DateTime(2026, 10, 26, 12, 30),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as MemoryImage).bytes, same(camera.bytes));
      expect(find.textContaining('12:30'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'warm notification routes from Records into its reminder and back to Home',
    (tester) async {
      final event = AppAlertEvent(
        id: 'water-warm',
        type: 'watering',
        title: 'Watering reminder',
        body: 'Check this soil.',
        at: DateTime(2026),
        target: 'water-warm',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: HardwareDashboard(hardware: h, scans: TomatoScanStore(box)),
        ),
      );
      await tester.tap(find.byType(NavigationDestination).at(2));
      await tester.pumpAndSettle();
      native.value['events'] = [event.toJson()];
      native.value['tap'] = {
        'type': 'watering',
        'target': event.id,
        'token': 'warm',
      };
      await tester.runAsync(h.syncAppAlerts);
      await tester.pumpAndSettle();
      expect(find.text('Check this soil.'), findsOneWidget);
      expect(native.acknowledged, 'warm');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'native bridge preserves nullable clear and linked target payloads',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AppAlertsBridge.channel, (call) async {
            calls.add(call);
            return {'enabled': false, 'minute': null};
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(AppAlertsBridge.channel, null),
      );
      await AppAlertsBridge().configure(null, false);
      expect(calls.single.method, 'configure');
      expect(calls.single.arguments['minute'], isNull);
    },
  );
}
