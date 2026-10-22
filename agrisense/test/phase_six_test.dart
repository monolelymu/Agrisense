import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:image/image.dart' as img;
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/core/theme.dart';
import 'package:agrisense/core/widgets.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';
import 'package:agrisense/features/diagnosis/tomato_scan_screen.dart';

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
    }
  }
  testWidgets(
    'Diagnosis warns about chosen crop and keeps unavailable diagnosis disabled',
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
      expect(find.textContaining('Assign this crop’s camera'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({TargetPlatform.linux}),
  );
}
