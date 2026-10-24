import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/core/theme.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';
import 'package:agrisense/features/monitoring/hardware_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:image/image.dart' as img;

import 'simple_ui_navigation.dart';

class _ExistingBoards extends HardwareClient {
  int reads = 0, photos = 0;
  bool badPhoto = false;

  @override
  Future<HardwareSample> read(String address, Crop crop) async {
    reads++;
    expect(address, 'http://192.168.1.20');
    return HardwareSample(
      id: 'reading-$reads',
      deviceId: 'sensor-one',
      crop: crop,
      receivedAt: DateTime.now(),
      temperature: 25,
      humidity: 60,
      soil: 50,
      soilRaw: 2000,
      gasRaw: 400,
      soilCalibrated: true,
    );
  }

  @override
  Future<Uint8List> capture(String address) async {
    photos++;
    expect(address, 'http://192.168.1.21');
    return badPhoto
        ? Uint8List(0)
        : Uint8List.fromList(img.encodeJpg(img.Image(width: 4, height: 4)));
  }
}

class _MonitoringController extends HardwareController {
  _MonitoringController(super.box, {required super.client});
  final started = Completer<void>();
  @override
  Future<void> startMonitoring(Crop crop) async {
    await super.startMonitoring(crop);
    if (!started.isCompleted) started.complete();
  }
}

void main() {
  late Directory directory;
  late Box<dynamic> box;
  late _ExistingBoards client;
  late _MonitoringController hardware;
  setUp(() async {
    directory = await Directory('test').createTemp('simple-ui-');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('simple-ui');
    client = _ExistingBoards();
    hardware = _MonitoringController(box, client: client)..load();
  });
  tearDown(() async {
    hardware.dispose();
    await box.close();
    await directory.delete(recursive: true);
  });

  Future<void> show(WidgetTester tester, {bool largeText = false}) async {
    if (largeText) {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(largeText ? 1.5 : 1)),
          child: child!,
        ),
        home: HardwareDashboard(
          hardware: hardware,
          scans: TomatoScanStore(box),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('three simple tabs, familiar branding and safe first setup', (
    tester,
  ) async {
    await show(tester, largeText: true);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.text('No More GuessPlant'), findsOneWidget);
    expect(find.byTooltip('Scan leaf'), findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      isNull,
    );
    expect(
      Theme.of(
        tester.element(find.byType(NavigationBar)),
      ).scaffoldBackgroundColor,
      background,
    );
    await tester.ensureVisible(find.text('Connect AgriSense'));
    await tester.tap(find.text('Connect AgriSense'));
    await tester.pumpAndSettle();
    expect(find.text('Allow local hardware access'), findsOneWidget);
    expect(client.reads + client.photos, 0);
    expect(hardware.allowLocalHttp, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'camera and records remain usable without unsupported hardware features',
    (tester) async {
      await show(tester, largeText: true);
      await openSimplePage(tester, 'Camera');
      expect(find.text('Choose Photo'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Capture & Analyze'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Camera movement & live view'));
      await tester.tap(find.text('Camera movement & live view'));
      await tester.pumpAndSettle();
      for (final label in ['Left', 'Center', 'Right']) {
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, label),
              )
              .onPressed,
          isNull,
        );
      }
      await openSimplePage(tester, 'History');
      expect(find.text('No saved leaf checks'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await chooseRecordCategory(tester, 'Readings');
      expect(find.text('No sensor readings saved.'), findsOneWidget);
      expect(client.reads + client.photos, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.linux}),
  );

  for (final badPhoto in [false, true]) {
    testWidgets('Connect checks saved legacy boards; invalid photo=$badPhoto', (
      tester,
    ) async {
      hardware.allowLocalHttp = true;
      hardware.assignments[Crop.tomato] = {
        'sensor': 'http://192.168.1.20',
        'sensorId': 'sensor-one',
        'camera': 'http://192.168.1.21',
      };
      client.badPhoto = badPhoto;
      await show(tester);
      expect(find.text('Sensor: Not checked. Tap Connect.'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Connect AgriSense'));
        await hardware.started.future.timeout(const Duration(seconds: 10));
      });
      await tester.pumpAndSettle();
      expect(client.photos, 1);
      expect(client.reads, greaterThanOrEqualTo(1));
      expect(hardware.polling, isTrue);
      expect(find.text('Sensor: Receiving readings'), findsOneWidget);
      expect(
        find.textContaining(
          badPhoto ? 'Camera: Unavailable.' : 'Camera: Photo received.',
        ),
        findsOneWidget,
      );
      expect(hardware.address(Crop.tomato, 'camera'), 'http://192.168.1.21');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
