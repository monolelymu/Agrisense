import 'dart:io';
import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/core/widgets.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';
import 'package:agrisense/features/monitoring/hardware_dashboard.dart';
import 'simple_ui_navigation.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;
  setUp(() async {
    directory = await Directory('test').createTemp('records-runtime-');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('records');
  });
  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  test(
    'graph reset persists per crop, preserves history and can be restored',
    () async {
      final at = DateTime(2026, 10, 23, 12);
      await box.put('hardware-readings-v1', [sample(at).toJson()]);
      final h = HardwareController(box, clock: () => at)..load();
      await h.resetTrendView(Crop.tomato);
      final restored = HardwareController(box)..load();
      expect(restored.trendStart(Crop.tomato), at);
      expect(restored.trendStart(Crop.eggplant), isNull);
      expect(restored.readings(Crop.tomato), hasLength(1));
      await restored.restoreTrendView(Crop.tomato);
      expect(restored.trendStart(Crop.tomato), isNull);
      expect(restored.readings(Crop.tomato), hasLength(1));
      h.dispose();
      restored.dispose();
    },
  );

  testWidgets('records use date and bookmarks without bulky search filters', (
    tester,
  ) async {
    final store = TomatoScanStore(box);
    await tester.runAsync(() async {
      for (final label in ['healthy', 'mosaic_virus']) {
        await store.save(
          TomatoScan(
            id: label,
            timestamp: label == 'healthy'
                ? DateTime.now()
                : DateTime.now().subtract(const Duration(days: 1)),
            label: label,
            score: .9,
            preview: Uint8List(0),
            modelVersion: 'test',
          ),
        );
      }
    });
    final h = HardwareController(box)..load();
    await tester.pumpWidget(
      HardwareApp(hardware: h, scans: store, showTutorial: false),
    );
    await openSimplePage(tester, 'History');
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(find.text('Tomato • Mosaic Virus'), findsOneWidget);
    expect(find.text('Tomato • Healthy'), findsOneWidget);
    final tile = find.widgetWithText(ListTile, 'Tomato • Healthy');
    await tester.ensureVisible(tile);
    await tester.runAsync(() async {
      await tester.tap(
        find.descendant(of: tile, matching: find.byTooltip('Bookmark')),
      );
      await box.flush();
    });
    await tester.pumpAndSettle();
    expect(TomatoScanStore(box).bookmarked('healthy'), isTrue);
    await tester.ensureVisible(find.text('Bookmarked'));
    await tester.tap(find.text('Bookmarked'));
    await tester.pumpAndSettle();
    expect(find.text('Tomato • Healthy'), findsOneWidget);
    expect(find.text('Tomato • Mosaic Virus'), findsNothing);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Tomato • Healthy'), findsOneWidget);
    expect(find.text('Tomato • Mosaic Virus'), findsNothing);
    expect(find.text('Clear date'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    h.dispose();
  });

  testWidgets('trends use compact dropdowns and retain long gaps', (
    tester,
  ) async {
    final now = DateTime.now();
    final h = _GraphController(box)..load();
    h.samples.addAll([
      sample(now.subtract(const Duration(hours: 2))),
      sample(now.subtract(const Duration(minutes: 1))),
    ]);
    await tester.pumpWidget(
      HardwareApp(
        hardware: h,
        scans: TomatoScanStore(box),
        showTutorial: false,
      ),
    );
    await openSimplePage(tester, 'Trends');
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.single.spots, hasLength(3));
    expect(chart.data.lineBarsData.single.spots[1], FlSpot.nullSpot);
    expect(find.text('Reset view'), findsNothing);
    expect(find.text('Gas raw'), findsNothing);
    expect(find.byType(CropPicker), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Humidity').last);
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
    expect(h.readings(Crop.tomato), hasLength(2));
    await tester.ensureVisible(find.text('Eggplant'));
    await tester.tap(find.text('Eggplant'));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('No readings yet'), findsOneWidget);
    expect(find.text('Tap a point to see its reading and time.'), findsNothing);
    expect(h.readings(Crop.tomato), hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
    h.dispose();
  });
}

// Persistence is covered separately; widget tests use synchronous storage.
class _GraphController extends HardwareController {
  _GraphController(super.box);
  DateTime? start;
  @override
  DateTime? trendStart(Crop crop) => start;
  @override
  Future<void> resetTrendView(Crop crop) async {
    start = DateTime.now();
    notifyListeners();
  }

  @override
  Future<void> restoreTrendView(Crop crop) async {
    start = null;
    notifyListeners();
  }
}

HardwareSample sample(DateTime at) => HardwareSample(
  id: at.toIso8601String(),
  crop: Crop.tomato,
  deviceId: 'test',
  receivedAt: at,
  temperature: 25,
  humidity: 60,
  soil: 50,
  soilRaw: 2000,
  gasRaw: 400,
  soilCalibrated: true,
);
