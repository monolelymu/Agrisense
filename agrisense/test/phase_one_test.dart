import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:agrisense/core/app_issue.dart';
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/core/issue_card.dart';
import 'package:agrisense/core/theme.dart';
import 'package:agrisense/core/sensor_notifications.dart';
import 'package:agrisense/data/automatic_capture.dart';
import 'package:agrisense/data/alert_photo.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';
import 'package:agrisense/features/help/help_screen.dart';
import 'package:agrisense/features/monitoring/hardware_dashboard.dart';
import 'package:agrisense/features/monitoring/monitoring_settings_screen.dart';
import 'package:agrisense/features/monitoring/notification_settings_screen.dart';

class NoNetwork extends HardwareClient {
  int calls = 0;
  @override
  Future<HardwareSample> read(String address, Crop crop) async {
    calls++;
    throw const SocketException('offline');
  }
}

void main() {
  test(
    'stable errors map known failures and never expose exception contents',
    () {
      expect(
        AppIssue.from(TimeoutException('private data')),
        AppIssue.connection,
      );
      expect(
        AppIssue.from(const HardwareHttpException(401, 'secret')),
        AppIssue.pairing,
      );
      expect(
        AppIssue.from(const HardwareHttpException(409, 'secret')),
        AppIssue.identity,
      );
      expect(
        AppIssue.from(PlatformException(code: 'photo_access_denied')),
        AppIssue.permission,
      );
      expect(
        AppIssue.from(
          const FormatException('Only private LAN addresses are allowed.'),
        ),
        AppIssue.address,
      );
      expect(
        AppIssue.from(
          const FormatException('Select at least one measurement.'),
        ),
        AppIssue.selection,
      );
      expect(
        AppIssue.from(StateError('secret pairing key')).recovery,
        isNot(contains('secret')),
      );
      expect(
        AppIssue.all.map((e) => e.code).toSet().length,
        AppIssue.all.length,
      );
    },
  );

  late Directory directory;
  late Box<dynamic> box;
  late HardwareController hardware;
  late NoNetwork client;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('agrisense-phase-one-');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('phase-one');
    client = NoNetwork();
    hardware = HardwareController(box, client: client)..load();
  });
  tearDown(() async {
    hardware.dispose();
    await box.close();
    await directory.delete(recursive: true);
  });

  testWidgets(
    'first launch can skip, persists completion, and replays from Help',
    (tester) async {
      await tester.pumpWidget(
        HardwareApp(hardware: hardware, scans: TomatoScanStore(box)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome to AgriSense'), findsOneWidget);
      await tester.ensureVisible(find.text('Skip tutorial'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Skip tutorial'));
        await box.flush();
      });
      await tester.pumpAndSettle();
      expect(box.get('tutorial-complete-v1'), isTrue);
      expect(client.calls, 0);
      await tester.tap(find.byTooltip('Help & troubleshooting'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replay tutorial'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to AgriSense'), findsOneWidget);
      await tester.ensureVisible(find.text('Get started'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Get started'));
        await box.flush();
      });
      await tester.pumpAndSettle();
      expect(find.text('Help & troubleshooting'), findsNothing);
      expect(find.text('A closer look at your crops.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        HardwareApp(hardware: hardware, scans: TomatoScanStore(box)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome to AgriSense'), findsNothing);
      expect(client.calls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'history categories isolate photos and readings without changing storage',
    (tester) async {
      hardware.alertPhotos.add(
        AlertPhoto(
          sampleId: 'warning',
          crop: Crop.tomato,
          timestamp: DateTime(2026),
          reason: 'Humidity high',
          jpeg: Uint8List(0),
        ),
      );
      await tester.pumpWidget(
        HardwareApp(
          hardware: hardware,
          scans: TomatoScanStore(box),
          showTutorial: false,
        ),
      );
      await tester.tap(find.text('History').last);
      await tester.pumpAndSettle();
      expect(find.text('Warning photos'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Readings'));
      await tester.pumpAndSettle();
      expect(find.text('No sensor readings saved.'), findsOneWidget);
      expect(find.text('No saved scans'), findsNothing);
      expect(hardware.alertPhotos.single.sampleId, 'warning');
      expect(box.keys, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'invalid limits show field errors and never save or contact hardware',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: NotificationSettingsScreen(
            hardware: hardware,
            crop: Crop.tomato,
          ),
        ),
      );
      final duration = find.byKey(
        const ValueKey('notification-Duration (seconds)'),
      );
      await tester.scrollUntilVisible(
        duration,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(duration, 'invalid');
      final save = find.text('Save notification settings');
      await tester.scrollUntilVisible(
        save,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Enter whole seconds.'), findsOneWidget);
      expect(box.get('foreground-notification-rules-v1'), isNull);
      expect(client.calls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('saving other settings preserves disabled measurement limits', (
    tester,
  ) async {
    hardware.notificationSettings[Crop.tomato] = const SensorAlertSettings(
      rules: [
        CaptureRule(false, 18, 32),
        CaptureRule(false, 40, 80),
        CaptureRule(false, 20, 70),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: NotificationSettingsScreen(hardware: hardware, crop: Crop.tomato),
      ),
    );
    final save = find.text('Save notification settings');
    await tester.scrollUntilVisible(
      save,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(save), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(save);
      await box.flush();
    });
    await tester.pumpAndSettle();
    final stored = SensorAlertSettings.fromJson(
      box.get('foreground-notification-rules-v1')['tomato'] as Map,
    );
    expect(stored.rules[0].minimum, 18);
    expect(stored.rules[2].maximum, 70);
    expect(client.calls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'main pages and monitoring settings fit a small phone at large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget largeText(BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.5)),
        child: child!,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          builder: largeText,
          home: HardwareDashboard(
            hardware: hardware,
            scans: TomatoScanStore(box),
          ),
        ),
      );
      for (final page in ['Devices', 'Trends', 'History', 'Dashboard']) {
        await tester.tap(find.text(page).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: page);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          builder: largeText,
          home: MonitoringSettingsScreen(hardware: hardware, crop: Crop.tomato),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'issue recovery and offline help fit narrow screens with large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: IssueCard(
                issue: AppIssue.camera,
                onRetry: () => retried = true,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
      await tester.tap(find.text('Troubleshoot'));
      await tester.pumpAndSettle();
      expect(find.byType(HelpScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: MonitoringSettingsScreen(hardware: hardware, crop: Crop.tomato),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sensor limits & warning photos'), findsOneWidget);
      expect(find.text('Manage board SD capture'), findsNothing);
      expect(client.calls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
