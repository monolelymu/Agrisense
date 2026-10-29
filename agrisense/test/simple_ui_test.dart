import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/core/theme.dart';
import 'package:agrisense/core/widgets.dart';
import 'package:agrisense/features/monitoring/notification_settings_screen.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/board_discovery.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/data/soil_calibration.dart';
import 'package:agrisense/data/daily_photo_schedule.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';
import 'package:agrisense/features/diagnosis/tomato_scan_screen.dart';
import 'package:agrisense/features/diagnosis/tomato_classifier.dart';
import 'package:agrisense/features/monitoring/photo_times_sheet.dart';
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
  Future<BoardIdentity> identity(String address) async => BoardIdentity(
    kitId: demoKitId,
    deviceId: address.endsWith('.20') ? 'sensor-one' : '001122334455',
    role: address.endsWith('.20') ? 'sensor' : 'camera',
    ready: address.endsWith('.20') || !badPhoto,
    capabilities: [address.endsWith('.20') ? 'readings' : 'capture'],
    sensorCrop: address.endsWith('.20') ? Crop.tomato : null,
  );

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
  _MonitoringController(super.box, {required super.client, super.classifier});
  final started = Completer<void>();
  @override
  DailyPhotoSchedule schedule(Crop crop) =>
      photoSchedules[crop] ?? super.schedule(crop);
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

class _RetryModel extends TomatoClassifier {
  bool fail = true;
  @override
  Future<TomatoScan> classifyCrop(Crop crop, Uint8List bytes) async {
    if (fail) throw StateError('test model unavailable');
    return TomatoScan(
      id: 'test',
      timestamp: DateTime.now(),
      crop: crop,
      label: 'healthy',
      score: .9,
      preview: bytes,
      modelVersion: 'test',
    );
  }
}

class _RetryStore extends TomatoScanStore {
  _RetryStore(super.box);
  bool fail = true;
  @override
  Future<void> save(TomatoScan scan) async {
    if (fail) throw StateError('test storage unavailable');
    await super.save(scan);
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
    expect(find.text('Choose crop'), findsOneWidget);
    for (final icon in ['🍅', '🌶️', '🍆']) {
      expect(find.text(icon), findsOneWidget);
    }
    expect(
      tester.getTopLeft(find.text('Tomato')).dy,
      tester.getTopLeft(find.text('Eggplant')).dy,
    );
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
    await tester.runAsync(() async {
      await tester.tap(find.text('Connect AgriSense'));
      await hardware.started.future.timeout(const Duration(seconds: 10));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('No kit found'), findsOneWidget);
    expect(find.text('Allow local hardware access'), findsNothing);
    expect(client.reads + client.photos, 0);
    expect(hardware.allowLocalHttp, isTrue);
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
    'camera crop changes stay quiet and keep the same screen state',
    (tester) async {
      hardware.assignments[Crop.tomato] = {
        'sensor': 'http://192.168.1.20',
        'sensorId': 'sensor-one',
      };
      await tester.runAsync(
        () => hardware.withPollingPaused(
          () => hardware.startMonitoring(Crop.tomato),
        ),
      );
      await show(tester);
      await openSimplePage(tester, 'Camera');
      final before = tester.state(find.byType(TomatoScanScreen));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      for (final name in ['Chili', 'Eggplant', 'Tomato']) {
        await tester.ensureVisible(find.text(name));
        await tester.tap(find.text(name));
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(
          tester.widget<CropPicker>(find.byType(CropPicker)).value.label,
          name,
        );
        expect(hardware.polling, isTrue);
        expect(
          find.textContaining('Checking for an interrupted'),
          findsNothing,
        );
        expect(
          identical(tester.state(find.byType(TomatoScanScreen)), before),
          isTrue,
        );
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets('sensor alert options open directly from Home on one page', (
    tester,
  ) async {
    await show(tester);
    await tester.ensureVisible(find.text('Edit sensor alerts'));
    final panel = find
        .ancestor(
          of: find.text('Edit sensor alerts'),
          matching: find.byType(Panel),
        )
        .first;
    expect(
      find.descendant(of: panel, matching: find.text('Edit times')),
      findsOneWidget,
    );
    await tester.tap(find.text('Edit sensor alerts'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
    expect(find.text('Tomato sensor alerts'), findsOneWidget);
    expect(find.text('Enable sensor alerts'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Enable sensor alerts'),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('capture-on-alert')),
          )
          .value,
      isTrue,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('auto-analyze')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const ValueKey('auto-analyze')))
          .value,
      isTrue,
    );
    await tester.scrollUntilVisible(
      find.text('Sensitive'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Sensitive'));
    await tester.pumpAndSettle();
    expect(find.text('Connect your sensor to use Sensitive.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Sensitive obtains a fresh sensor baseline in one tap', (
    tester,
  ) async {
    hardware.assignments[Crop.tomato] = {
      'sensor': 'http://192.168.1.20',
      'sensorId': 'sensor-one',
    };
    await show(tester);
    await tester.ensureVisible(find.text('Edit sensor alerts'));
    await tester.tap(find.text('Edit sensor alerts'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sensitive'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Sensitive'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(client.reads, 1);
    await tester.scrollUntilVisible(
      find.text('Sensitive'),
      -150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Sensitive'))
          .selected,
      isTrue,
    );
    expect(
      find.text(
        'Sensitive limits are ready. Review them below, then Save settings.',
      ),
      findsOneWidget,
    );
    expect(hardware.notificationSettings[Crop.tomato]!.awaitingLimits, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'background sensor refresh does not block navigation or show loading',
    (tester) async {
      hardware.assignments[Crop.tomato] = {
        'sensor': 'http://192.168.1.20',
        'sensorId': 'sensor-one',
      };
      await show(tester);
      final before = tester.getTopLeft(find.text('Tomato overview'));
      client.readGate = Completer<void>();
      late Future<void> reading;
      await tester.runAsync(() async {
        reading = hardware.refresh(Crop.tomato);
      });
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.getTopLeft(find.text('Tomato overview')), before);
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

  testWidgets('Home shows actual uncalibrated soil, temperature and humidity', (
    tester,
  ) async {
    hardware.samples.add(
      HardwareSample(
        id: 'raw-reading',
        crop: Crop.tomato,
        receivedAt: DateTime.now(),
        temperature: 26.5,
        humidity: 61,
        soil: null,
        soilRaw: 2300,
        gasRaw: 400,
        soilCalibrated: false,
      ),
    );
    hardware.status[Crop.tomato] = 'Received';
    await show(tester, largeText: true);
    expect(find.text('2300 raw'), findsOneWidget);
    expect(find.text('26.5°C'), findsOneWidget);
    expect(find.text('61%'), findsOneWidget);
    expect(find.text('Sensor reading'), findsOneWidget);
    expect(find.text('Monitoring'), findsNothing);
    hardware.assignments[Crop.tomato] = {'sensor': 'http://192.168.1.20'};
    await tester.runAsync(
      () => hardware.saveSoilCalibration(
        Crop.tomato,
        SoilCalibration(dry: 3000, wet: 1000),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('35%'), findsOneWidget);
    expect(find.text('Relative moisture'), findsOneWidget);
    expect(find.text('2300 raw'), findsNothing);
    expect(find.text('26.5°C'), findsOneWidget);
    expect(find.text('61%'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'photo times can be cleared and editing an off schedule keeps it off',
    (tester) async {
      for (final clearAll in [true, false]) {
        DailyPhotoSchedule? saved;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    saved = await showModalBottomSheet<DailyPhotoSchedule>(
                      context: context,
                      builder: (_) => const PhotoTimesSheet(
                        schedule: DailyPhotoSchedule(minutes: [480, 600]),
                      ),
                    );
                  },
                  child: const Text('Edit'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Remove time').first);
        await tester.pump();
        if (clearAll) {
          await tester.tap(find.byTooltip('Remove time'));
          await tester.pump();
        }
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save times'),
              )
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.text('Save times'));
        await tester.pumpAndSettle();
        expect(saved!.enabled, isFalse);
        expect(saved!.minutes, clearAll ? isEmpty : [600]);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('Back keeps alert edits until discard is confirmed', (
    tester,
  ) async {
    await show(tester);
    await tester.ensureVisible(find.text('Edit sensor alerts'));
    await tester.tap(find.text('Edit sensor alerts'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Enable sensor alerts'),
    );
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Enable sensor alerts'),
          )
          .value,
      isFalse,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(hardware.notificationSettings[Crop.tomato]!.enabled, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'failed camera analysis keeps the original and retries without another capture',
    (tester) async {
      hardware.dispose();
      final model = _RetryModel();
      hardware = _MonitoringController(box, client: client, classifier: model)
        ..load();
      hardware.assignments[Crop.tomato] = {'camera': 'http://192.168.1.21'};
      final store = TomatoScanStore(box);
      await tester.pumpWidget(
        HardwareApp(hardware: hardware, scans: store, showTutorial: false),
      );
      await openSimplePage(tester, 'Camera');
      await tester.ensureVisible(find.text('Check plant now'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Check plant now'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(client.photos, 1);
      expect(
        TomatoScanStore(box).pendingCameraPhotos(Crop.tomato),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      model.fail = false;
      final reopened = TomatoScanStore(box);
      await tester.pumpWidget(
        HardwareApp(hardware: hardware, scans: reopened, showTutorial: false),
      );
      await openSimplePage(tester, 'Camera');
      await tester.ensureVisible(find.text('Retry photo analysis'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Retry photo analysis'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(client.photos, 1);
      expect(reopened.load(), hasLength(1));
      expect(reopened.pendingCameraPhotos(Crop.tomato), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets('crop switching preserves a result whose save failed', (
    tester,
  ) async {
    final store = _RetryStore(box);
    final result = TomatoScan(
      id: 'unsaved',
      timestamp: DateTime.now(),
      label: 'healthy',
      score: .9,
      preview: client.badPhoto
          ? Uint8List(0)
          : Uint8List.fromList(img.encodeJpg(img.Image(width: 4, height: 4))),
      modelVersion: 'test',
    );
    store.unsavedResults[Crop.tomato] = result;
    await tester.pumpWidget(
      HardwareApp(hardware: hardware, scans: store, showTutorial: false),
    );
    await openSimplePage(tester, 'Camera');
    expect(find.text('Retry saving'), findsOneWidget);
    await tester.ensureVisible(find.text('Chili'));
    await tester.tap(find.text('Chili'));
    await tester.pumpAndSettle();
    expect(find.text('Retry saving'), findsNothing);
    await tester.tap(find.text('Tomato'));
    await tester.pumpAndSettle();
    expect(find.text('Retry saving'), findsOneWidget);
    store.fail = false;
    await tester.ensureVisible(find.text('Retry saving'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Retry saving'));
      await box.flush();
    });
    await tester.pumpAndSettle();
    expect(store.load().single.id, 'unsaved');
    expect(store.unsavedResults, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
    testWidgets(
      'Connect verifies saved boards without capture; unready=$badPhoto',
      (tester) async {
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
        expect(client.photos, 0);
        expect(client.reads, greaterThanOrEqualTo(1));
        expect(hardware.polling, isTrue);
        expect(find.text('Sensor: Receiving readings'), findsOneWidget);
        expect(
          find.textContaining(
            badPhoto
                ? 'Camera: Board reachable; camera unavailable'
                : 'Camera: Camera ready',
          ),
          findsOneWidget,
        );
        expect(hardware.address(Crop.tomato, 'camera'), 'http://192.168.1.21');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
