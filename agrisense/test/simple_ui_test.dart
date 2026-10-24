import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/core/theme.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/data/daily_photo_schedule.dart';
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
  Completer<void>? readGate;

  @override
  Future<HardwareSample> read(String address, Crop crop) async {
    reads++;
    await readGate?.future;
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
  // Real persistence is covered by daily_monitoring_test; keep UI animations
  // independent of operating-system file events in the widget-test clock.
  @override
  Future<void> saveSchedule(Crop crop, DailyPhotoSchedule value) async {
    value.validate();
    photoSchedules[crop] = value;
    notifyListeners();
  }

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
    expect(hardware.allowLocalHttp, isTrue);
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
              find.widgetWithText(FilledButton, 'Check plant now'),
            )
            .onPressed,
        isNull,
      );
      for (final label in [
        'Move camera left',
        'Center camera',
        'Move camera right',
      ]) {
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) => widget is IconButton && widget.tooltip == label,
                ),
              )
              .onPressed,
          isNull,
        );
      }
      await openSimplePage(tester, 'History');
      expect(find.text('No saved leaf checks'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Choose date'), findsOneWidget);
      expect(find.text('Bookmarked'), findsOneWidget);
      expect(client.reads + client.photos, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.linux}),
  );

  testWidgets(
    'background sensor refresh does not block navigation or show loading',
    (tester) async {
      hardware.assignments[Crop.tomato] = {
        'sensor': 'http://192.168.1.20',
        'sensorId': 'sensor-one',
      };
      await show(tester);
      client.readGate = Completer<void>();
      late Future<void> reading;
      await tester.runAsync(() async {
        reading = hardware.refresh(Crop.tomato);
      });
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .onDestinationSelected,
        isNotNull,
      );
      await tester.tap(find.widgetWithText(NavigationDestination, 'Records'));
      await tester.pumpAndSettle();
      expect(find.text('Choose date'), findsOneWidget);
      await tester.runAsync(() async {
        client.readGate!.complete();
        await reading;
      });
      await tester.pumpAndSettle();
      expect(find.text('Choose date'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('photo times are edited and saved directly from Home', (
    tester,
  ) async {
    await show(tester, largeText: true);
    await tester.ensureVisible(find.text('Edit times'));
    await tester.tap(find.text('Edit times'));
    await tester.pumpAndSettle();
    expect(find.text('Automatic photo times'), findsOneWidget);
    await tester.tap(find.text('Add time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save times'));
    await tester.tap(find.text('Save times'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(hardware.schedule(Crop.tomato).minutes, hasLength(1));
    expect(find.textContaining('Every day:'), findsOneWidget);
    expect(find.text('Automatic photo times'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
          badPhoto
              ? 'Camera: Reconnecting…'
              : 'Camera: Photo connection checked',
        ),
        findsOneWidget,
      );
      expect(hardware.address(Crop.tomato, 'camera'), 'http://192.168.1.21');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
