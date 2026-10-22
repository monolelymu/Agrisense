import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:image/image.dart' as img;
import 'package:agrisense/core/app_issue.dart';
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/core/sensor_notifications.dart';
import 'package:agrisense/core/theme.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/alert_photo.dart';
import 'package:agrisense/data/monitoring_alert.dart';
import 'package:agrisense/features/diagnosis/model_catalog.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';
import 'package:agrisense/features/diagnosis/tomato_scan_screen.dart';
import 'package:agrisense/features/help/help_screen.dart';
import 'package:agrisense/features/monitoring/hardware_dashboard.dart';
import 'package:agrisense/features/monitoring/alert_detail_screen.dart';
import 'package:agrisense/features/monitoring/monitoring_settings_screen.dart';
import 'package:agrisense/data/models.dart';

class _OfflineClient extends HardwareClient {
  int calls = 0;
  @override
  Future<HardwareSample> read(String address, Crop crop) async {
    calls++;
    throw const SocketException('offline');
  }
}

void main() {
  late Directory directory;
  late Box<dynamic> box;
  late HardwareController hardware;
  late _OfflineClient client;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('agrisense-phase-five-');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('phase-five');
    client = _OfflineClient();
    hardware = HardwareController(box, client: client)..load();
  });
  tearDown(() async {
    hardware.dispose();
    await box.close();
    await directory.delete(recursive: true);
  });

  testWidgets(
    'help uses catalog availability and opens the relevant error first',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: const HelpScreen(issue: AppIssue.camera),
        ),
      );
      await tester.pumpAndSettle();
      for (final crop in Crop.values) {
        expect(find.textContaining(modelStatus(crop)), findsOneWidget);
      }
      expect(find.text(AppIssue.camera.recovery), findsOneWidget);
      expect(find.byKey(const ValueKey('CAM-001')), findsOneWidget);
      expect(find.textContaining('Only Tomato analysis'), findsNothing);
      expect(find.text('History → Alerts'), findsNothing);
      expect(client.calls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final action in [
    'Scan leaf',
    'Devices',
    'Monitoring & Auto Scan',
    'History → Alerts',
  ]) {
    testWidgets(
      'dashboard Help shortcut $action preserves Eggplant',
      (tester) async {
        await tester.pumpWidget(
          HardwareApp(
            hardware: hardware,
            scans: TomatoScanStore(box),
            showTutorial: false,
          ),
        );
        await tester.tap(find.widgetWithText(ChoiceChip, 'Eggplant'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Help & troubleshooting'));
        await tester.pumpAndSettle();
        expect(find.text('Selected crop: Eggplant'), findsOneWidget);
        await tester.ensureVisible(find.widgetWithText(OutlinedButton, action));
        await tester.tap(find.widgetWithText(OutlinedButton, action));
        await tester.pumpAndSettle();
        if (action == 'Scan leaf') {
          expect(
            tester
                .widget<TomatoScanScreen>(find.byType(TomatoScanScreen))
                .initialCrop,
            Crop.eggplant,
          );
        } else if (action == 'Monitoring & Auto Scan') {
          expect(
            tester
                .widget<MonitoringSettingsScreen>(
                  find.byType(MonitoringSettingsScreen),
                )
                .crop,
            Crop.eggplant,
          );
        } else {
          expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            action == 'Devices' ? 2 : 3,
          );
          expect(
            tester
                .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Eggplant'))
                .selected,
            isTrue,
          );
          if (action == 'History → Alerts') {
            expect(
              tester
                  .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Alerts'))
                  .selected,
              isTrue,
            );
          }
        }
        expect(client.calls, 0);
        expect(hardware.polling, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant({TargetPlatform.linux}),
    );
  }

  testWidgets(
    'Diagnosis opens crop-specific offline Help and returns to the same crop',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TomatoScanScreen(
            store: TomatoScanStore(box),
            initialCrop: Crop.chili,
          ),
        ),
      );
      await tester.tap(find.byTooltip('Help & troubleshooting'));
      await tester.pumpAndSettle();
      expect(find.text('Selected crop: Chili'), findsOneWidget);
      expect(find.text(modelStatus(Crop.chili)), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Chili'))
            .selected,
        isTrue,
      );
      expect(client.calls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.linux}),
  );

  testWidgets(
    'Help topics and tutorial fit a narrow phone with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget app(Widget child) => MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: child,
      );
      await tester.pumpWidget(
        app(const HelpScreen(crop: Crop.tomato, showShortcuts: true)),
      );
      for (final title in [
        'Scan a useful leaf photo',
        'Understand your prediction',
        'Connect your devices',
        'Monitoring and background operation',
        'History and local storage',
        'Recover a failed action',
      ]) {
        await tester.ensureVisible(find.text(title));
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: title);
      }
      await tester.pumpWidget(app(TutorialScreen(onDone: () async {})));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Get started'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final retained in [false, true]) {
    testWidgets(
      retained
          ? 'alert explains an unavailable model without offering analysis'
          : 'alert explains an expired original without offering analysis',
      (tester) async {
        final crop = retained ? Crop.chili : Crop.tomato;
        final now = DateTime(2026);
        final alert = MonitoringAlert(
          id: 'recovery',
          sample: HardwareSample(
            id: 'reading',
            crop: crop,
            receivedAt: now,
            temperature: 25,
            humidity: 50,
            soil: null,
            soilRaw: 1,
            gasRaw: 1,
            soilCalibrated: false,
          ),
          settings: const SensorAlertSettings(
            capturePhoto: true,
            analyzePhoto: true,
          ),
          metrics: [0],
          timestamp: now,
          camera: '',
          capturedAt: now,
          state: 'analysis_failed',
        );
        hardware.alerts.add(alert);
        if (retained) {
          hardware.alertPhotos.add(
            AlertPhoto(
              sampleId: 'reading',
              crop: crop,
              timestamp: now,
              reason: 'test',
              jpeg: Uint8List.fromList(
                img.encodeJpg(img.Image(width: 2, height: 2)),
              ),
              alertId: alert.id,
            ),
          );
        }
        await tester.pumpWidget(
          MaterialApp(
            home: AlertDetailScreen(hardware: hardware, id: alert.id),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Retry analysis'), findsNothing);
        expect(
          find.textContaining(
            retained
                ? 'This crop has no available analysis model.'
                : 'Retry analysis is unavailable because the original photo',
          ),
          findsOneWidget,
        );
        if (!retained) expect(find.text('Capture a new photo'), findsOneWidget);
        expect(client.calls, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
