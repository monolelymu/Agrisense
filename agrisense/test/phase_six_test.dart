import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:image/image.dart' as img;
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/core/app_issue.dart';
import 'package:agrisense/core/sensor_notifications.dart';
import 'package:agrisense/core/theme.dart';
import 'package:agrisense/core/widgets.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/monitoring_alert.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';
import 'package:agrisense/features/diagnosis/tomato_scan_screen.dart';
import 'package:agrisense/features/monitoring/hardware_dashboard.dart';
import 'package:agrisense/features/monitoring/monitoring_settings_screen.dart';
import 'simple_ui_navigation.dart';

class _NoRequests extends HardwareClient {
  int calls = 0;
  @override
  Future<HardwareSample> read(String address, Crop crop) async {
    calls++;
    throw StateError('Unexpected network request in a layout test');
  }
}

void main() {
  late Directory directory;
  late Box<dynamic> box;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('agrisense-phase-six-');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('phase-six');
  });
  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });
  Widget app(Widget home, double scale) => MaterialApp(
    theme: buildTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home,
  );
  void viewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final width in [360.0, 430.0, 800.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'shared layout and long result labels fit $width at $scale text',
        (tester) async {
          viewport(tester, width);
          final scan = TomatoScan(
            id: 'long',
            timestamp: DateTime(2026),
            label: 'yellow_leaf_curl_virus',
            score: .55,
            modelVersion: 'unchanged',
            preview: Uint8List.fromList(
              img.encodePng(img.Image(width: 2, height: 2)),
            ),
            predictions: const [
              ScanPrediction('yellow_leaf_curl_virus', .55),
              ScanPrediction('magnesium_deficiency', .3),
              ScanPrediction('spotted_wilt_virus', .15),
            ],
          );
          await tester.pumpWidget(
            app(
              Scaffold(
                body: PageBody(
                  children: [
                    const SectionTitle(
                      'Growing conditions, diagnoses and saved records',
                      'Long guidance must wrap instead of overflowing.',
                      trailing: Text('Connection status'),
                    ),
                    TomatoResultCard(scan: scan),
                  ],
                ),
              ),
              scale,
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.text('Selected crop: Tomato'), findsOneWidget);
          expect(find.text('Model score: 55.0%'), findsOneWidget);
          expect(
            tester.getTopLeft(find.text('Model score: 55.0%')).dy,
            lessThan(tester.getTopLeft(find.text('UNCERTAIN')).dy),
          );
          await tester.ensureVisible(find.text('spotted wilt virus'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('55.0%'), findsOneWidget);
          expect(find.text('30.0%'), findsOneWidget);
          expect(find.text('15.0%'), findsOneWidget);
          expect(find.text('Symptoms & next steps'), findsNothing);
          expect(scan.score, .55);
          expect(scan.uncertain, isTrue);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
      testWidgets('Dashboard, history and settings fit $width at $scale text', (
        tester,
      ) async {
        viewport(tester, width);
        final client = _NoRequests();
        final hardware = HardwareController(box, client: client)..load();
        addTearDown(hardware.dispose);
        final sample = HardwareSample(
          id: 'saved',
          deviceId: 'old-device',
          crop: Crop.tomato,
          receivedAt: DateTime(2020),
          temperature: null,
          humidity: 55,
          soil: 72,
          soilRaw: 1234,
          gasRaw: 2000,
          soilCalibrated: false,
        );
        hardware.samples.add(sample);
        hardware.alerts.add(
          MonitoringAlert(
            id: 'failed',
            sample: sample,
            settings: const SensorAlertSettings(),
            metrics: [1],
            timestamp: DateTime(2020),
            capturedAt: DateTime(2020),
            camera: '',
            state: 'analysis_failed',
          ),
        );
        await tester.runAsync(() async {
          await TomatoScanStore(box).save(
            TomatoScan(
              id: 'history',
              timestamp: DateTime(2020),
              label: 'yellow_leaf_curl_virus',
              score: .55,
              modelVersion: 'unchanged',
              preview: Uint8List.fromList(
                img.encodePng(img.Image(width: 2, height: 2)),
              ),
            ),
          );
        });
        await tester.pumpWidget(
          app(
            HardwareDashboard(hardware: hardware, scans: TomatoScanStore(box)),
            scale,
          ),
        );
        expect(find.text('Connection & monitoring'), findsOneWidget);
        expect(
          find.text(
            'Historical reading. Read sensors again for current conditions.',
          ),
          findsOneWidget,
        );
        expect(find.text('Not calibrated'), findsOneWidget);
        expect(find.text('Unavailable'), findsOneWidget);
        expect(find.text('Uncalibrated MQ135 ADC; not ppm'), findsNothing);
        expect(find.text('Saved sensor readings'), findsNothing);
        for (final page in ['Devices', 'Trends', 'History']) {
          await openSimplePage(tester, page);
          expect(tester.takeException(), isNull, reason: page);
        }
        expect(find.text('Tomato • yellow leaf curl virus'), findsOneWidget);
        await chooseRecordCategory(tester, 'Alerts');
        expect(find.text('Sensor alerts'), findsOneWidget);
        expect(find.text('Analysis failed'), findsOneWidget);
        expect(find.text('Older warning photos'), findsNothing);
        await Scrollable.ensureVisible(
          tester.element(find.text('Analysis failed')),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        expect(find.text('Analysis failed').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Analysis failed'));
        await tester.pumpAndSettle();
        expect(
          find.text('Original photo has expired or is unavailable.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await chooseRecordCategory(tester, 'Readings');
        expect(find.text('Recent sensor readings'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          app(
            MonitoringSettingsScreen(hardware: hardware, crop: Crop.tomato),
            scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Manage board SD capture'), findsNothing);
        final advanced = find.text('Advanced: independent SD capture');
        await tester.ensureVisible(advanced);
        await tester.tap(advanced);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Manage board SD capture'));
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Manage board SD capture'),
              )
              .onPressed,
          isNull,
        );
        expect(
          find.textContaining(
            'Enable local hardware access and assign a sensor',
          ),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
        expect(client.calls, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets(
    'busy and error states remain readable and disable competing actions',
    (tester) async {
      viewport(tester, 360);
      final client = _NoRequests();
      final hardware = HardwareController(box, client: client)..load();
      addTearDown(hardware.dispose);
      hardware.busy = true;
      hardware.error = 'Request failed';
      hardware.issue = AppIssue.connection;
      await tester.pumpWidget(
        app(
          HardwareDashboard(hardware: hardware, scans: TomatoScanStore(box)),
          1.5,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Completing your request…'), findsOneWidget);
      expect(find.textContaining('NET-001'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Connect AgriSense'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      expect(client.calls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Diagnosis shows Chili model notice and keeps platform restrictions',
    (tester) async {
      viewport(tester, 360);
      final hardware = HardwareController(box)..load();
      addTearDown(hardware.dispose);
      await tester.pumpWidget(
        app(
          TomatoScanScreen(store: TomatoScanStore(box), hardware: hardware),
          1.5,
        ),
      );
      expect(find.text('Analyzing as Tomato'), findsOneWidget);
      expect(
        find.text('Choose the crop that matches your leaf.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Chili'));
      await tester.pumpAndSettle();
      expect(find.text('Analyzing as Chili'), findsOneWidget);
      expect(
        find.textContaining('Chili photo analysis runs on this device.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Scan leaf'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Capture and analyze'),
            )
            .onPressed,
        isNull,
      );
      final care = find.text('Chili knowledge & care');
      await tester.ensureVisible(care);
      await tester.tap(care);
      await tester.pumpAndSettle();
      expect(find.text('Chili knowledge & care'), findsOneWidget);
      expect(find.byKey(const ValueKey('nutrient_deficiency')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.textContaining('Assign this crop’s camera'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.linux}),
  );
}
