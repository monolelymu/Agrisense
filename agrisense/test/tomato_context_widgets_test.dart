import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:image/image.dart' as img;
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/core/theme.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/tomato_assessment.dart';
import 'package:agrisense/features/diagnosis/tomato_context_widgets.dart';
import 'package:agrisense/features/diagnosis/tomato_knowledge.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';
import 'package:agrisense/features/diagnosis/tomato_scan_screen.dart';
import 'package:agrisense/features/monitoring/hardware_dashboard.dart';

final noon = DateTime(2026, 10, 21, 12);
HardwareSample sample(DateTime at) => HardwareSample(
  id: 'a',
  deviceId: 'sensor',
  crop: Crop.tomato,
  receivedAt: at,
  temperature: 35,
  humidity: 95,
  soil: 50,
  soilRaw: 1,
  gasRaw: 4095,
  soilCalibrated: false,
);
TomatoScan scan({
  String source = 'upload',
  String label = 'mosaic_virus',
  Map<String, dynamic>? assessment,
}) => TomatoScan(
  id: 'scan',
  timestamp: noon,
  label: label,
  score: .8,
  preview: Uint8List.fromList(img.encodePng(img.Image(width: 1, height: 1))),
  modelVersion: 'unchanged',
  source: source,
  assessment: assessment,
);
Widget screen(Widget child, {double scale = 1}) => MaterialApp(
  theme: buildTheme(),
  home: Scaffold(
    body: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'Dashboard panel shows advisory references and unavailable soil',
    (tester) async {
      await tester.pumpWidget(
        screen(GrowingConditionsPanel(sample: sample(noon), clock: () => noon)),
      );
      expect(find.text('Growing conditions'), findsOneWidget);
      expect(find.textContaining('Above reference'), findsNWidgets(2));
      expect(find.textContaining('not a universal outdoor'), findsOneWidget);
      expect(find.textContaining('Soil moisture: unavailable'), findsOneWidget);
      expect(find.textContaining('Gas'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('current data expires without another network poll', (
    tester,
  ) async {
    var now = noon;
    await tester.pumpWidget(
      screen(GrowingConditionsPanel(sample: sample(noon), clock: () => now)),
    );
    now = noon.add(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 31));
    expect(find.textContaining('No recent reading'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'uploaded result has offline guidance without sensor association or changed score',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        screen(TomatoResultCard(scan: scan()), scale: 1.3),
      );
      expect(find.text('Model score: 80.0%'), findsOneWidget);
      final symptoms = find.text('Symptoms & next steps');
      await tester.ensureVisible(symptoms);
      await tester.pumpAndSettle();
      await tester.tap(symptoms);
      await tester.pumpAndSettle();
      expect(find.text('What to inspect'), findsOneWidget);
      expect(find.textContaining('capture time and plant'), findsOneWidget);
      expect(find.textContaining('cannot identify a virus'), findsOneWidget);
      expect(
        find.textContaining('Sensor context does not change'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'saved trigger context shows missing duration and frozen values',
    (tester) async {
      final assessment = TomatoAssessment.assess(
        label: 'late_blight',
        context: 'Alert trigger readings',
        sample: sample(noon),
        history: [],
        at: noon,
      );
      await tester.pumpWidget(
        screen(
          TomatoExplanation(
            scan: scan(
              source: 'auto',
              label: 'late_blight',
              assessment: assessment.toJson(),
            ),
          ),
        ),
      );
      expect(find.text('Alert trigger readings'), findsOneWidget);
      expect(find.textContaining('Duration not established'), findsOneWidget);
      final saved = find.text('Saved growing context');
      await tester.ensureVisible(saved);
      await tester.pumpAndSettle();
      await tester.tap(saved);
      await tester.pumpAndSettle();
      expect(find.textContaining('35.0 °C'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('old and unknown-version scans never acquire current context', (
    tester,
  ) async {
    for (final value in [
      null,
      <String, dynamic>{'version': 999},
    ]) {
      await tester.pumpWidget(
        screen(
          TomatoExplanation(
            scan: scan(source: 'camera', assessment: value),
          ),
        ),
      );
      expect(
        find.textContaining('Historical scans are not assessed'),
        findsOneWidget,
      );
      expect(find.text('Saved growing context'), findsNothing);
    }
  });
  testWidgets('source action copies only the public reference URL', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      screen(const ReferenceSources(sources: [growingTemperatureSource])),
    );
    await tester.tap(find.text('Research sources'));
    await tester.pumpAndSettle();
    final copy = find.text('Copy source link');
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(copied, growingTemperatureSource.url);
    expect(find.text('Source link copied.'), findsOneWidget);
  });
  testWidgets('growing panel is Tomato-only and does not start monitoring', (
    tester,
  ) async {
    late Directory dir;
    late Box<dynamic> box;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('tomato-ui-');
      Hive.init(dir.path);
      box = await Hive.openBox<dynamic>('ui');
    });
    final h = HardwareController(box)..load();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      h.dispose();
      await tester.runAsync(() async {
        await box.close();
        await dir.delete(recursive: true);
      });
    });
    await tester.pumpWidget(
      HardwareApp(
        hardware: h,
        scans: TomatoScanStore(box),
        showTutorial: false,
      ),
    );
    expect(find.byType(GrowingConditionsPanel), findsOneWidget);
    for (final crop in ['Chili', 'Eggplant']) {
      await tester.tap(find.text(crop).first);
      await tester.pumpAndSettle();
      expect(find.byType(GrowingConditionsPanel), findsNothing);
    }
    expect(h.polling, isFalse);
    expect(tester.takeException(), isNull);
  });
}
