import 'dart:io';
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrisense/core/theme.dart';
import 'package:agrisense/features/monitoring/sensor_trend_card.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    List<TrendPoint> points, {
    bool daily = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('preview'),
        child: MaterialApp(
          theme: buildTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SensorTrendCard(
                    metric: 'Temperature',
                    unit: '°C',
                    points: points,
                    daily: daily,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> preview(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('TREND_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = Directory('../output/trends-redesign');
      await output.create(recursive: true);
      await File(
        '${output.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('two readings show a short summary instead of an empty chart', (
    tester,
  ) async {
    await show(tester, [
      TrendPoint(DateTime(2026, 10, 29, 22, 20), 31.5),
      TrendPoint(DateTime(2026, 10, 29, 22, 21), 31.5),
    ]);
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('Only 2 readings recorded'), findsOneWidget);
    expect(find.text('Lowest 31.5 °C'), findsNothing);
    await preview(tester, 'sparse');
  });

  final recent = [
    TrendPoint(DateTime(2026, 10, 29, 22, 20), 31.6),
    TrendPoint(DateTime(2026, 10, 29, 22, 25), 31.4),
    TrendPoint(DateTime(2026, 10, 29, 22, 30), 31.2),
    TrendPoint(DateTime(2026, 10, 29, 23, 40), 31.1),
  ];
  testWidgets('24h labels fit and gaps remain blank with bounded tooltips', (
    tester,
  ) async {
    await show(tester, recent);
    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    expect(data.maxX, 1);
    expect(
      data.lineBarsData.single.spots.where((p) => p == FlSpot.nullSpot),
      hasLength(1),
    );
    expect(data.titlesData.bottomTitles.sideTitles.showTitles, isFalse);
    expect(find.text('10:20 PM'), findsOneWidget);
    expect(find.text('11:40 PM'), findsOneWidget);
    expect(data.lineTouchData.touchTooltipData.fitInsideHorizontally, isTrue);
    expect(data.lineTouchData.touchTooltipData.fitInsideVertically, isTrue);
    final spot = LineBarSpot(
      data.lineBarsData.single,
      0,
      data.lineBarsData.single.spots.last,
    );
    expect(
      data.lineTouchData.touchTooltipData.getTooltipItems([spot]).single!.text,
      contains('31.1 °C'),
    );
    await preview(tester, '24-hours');
  });

  testWidgets(
    'daily ranges show low/high and average without filling missing days',
    (tester) async {
      await show(tester, [
        TrendPoint(DateTime(2026, 10, 26, 10), 29),
        TrendPoint(DateTime(2026, 10, 26, 12), 32),
        TrendPoint(DateTime(2026, 10, 29, 10), 31),
      ], daily: true);
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(find.text('Daily low–high · dot = average'), findsOneWidget);
      expect(data.lineBarsData, hasLength(3));
      expect(data.lineBarsData.first.spots, [
        const FlSpot(0, 29),
        const FlSpot(0, 32),
      ]);
      expect(data.lineBarsData.last.spots, [
        const FlSpot(0, 30.5),
        const FlSpot(3, 31),
      ]);
      expect(data.maxX, 3.5);
      final spot = LineBarSpot(
        data.lineBarsData.last,
        2,
        data.lineBarsData.last.spots.first,
      );
      expect(
        data.lineTouchData.touchTooltipData
            .getTooltipItems([spot])
            .single!
            .text,
        contains('Low 29.0 · High 32.0'),
      );
      await preview(tester, 'daily-ranges');
      await tester.tap(find.text('Reading details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('3 recorded readings'), findsOneWidget);
    },
  );

  testWidgets(
    'large text keeps time labels and statistics inside a phone screen',
    (tester) async {
      await show(tester, recent, scale: 1.6);
      expect(find.text('10:20 PM'), findsOneWidget);
      expect(find.text('11:40 PM'), findsOneWidget);
      await preview(tester, 'large-text');
    },
  );

  testWidgets('all-time buckets stay readable and exclude invalid values', (
    tester,
  ) async {
    await show(tester, [
      for (var i = 0; i < 180; i++)
        TrendPoint(DateTime(2026, 1, 1 + i), 20 + i % 10.0),
      TrendPoint(DateTime(2026, 1, 1), double.nan),
    ], daily: true);
    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    expect(find.text('6-day low–high · dot = average'), findsOneWidget);
    expect(data.lineBarsData, hasLength(31));
    expect(data.lineBarsData.last.spots, hasLength(30));
  });

  testWidgets('a rolling 30-day window keeps daily ranges across midnight', (
    tester,
  ) async {
    await show(tester, [
      for (var i = 0; i <= 30; i++)
        TrendPoint(DateTime(2026, 9, 30 + i), 25.0 + i % 3),
    ], daily: true);
    expect(find.text('Daily low–high · dot = average'), findsOneWidget);
    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    expect(data.lineBarsData.last.spots, hasLength(31));
  });
}
