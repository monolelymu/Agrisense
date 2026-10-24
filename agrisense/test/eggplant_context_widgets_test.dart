import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/crop_knowledge_screen.dart';
import 'package:agrisense/features/diagnosis/tomato_context_widgets.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';
import 'package:agrisense/features/diagnosis/tomato_scan_screen.dart';
import 'package:agrisense/features/monitoring/notification_settings_screen.dart';
import 'package:agrisense/core/hardware_controller.dart';
import 'dart:io';
import 'package:hive_ce/hive.dart';
import 'package:image/image.dart' as img;
import 'crop_model_pipeline_test.dart' as fixture;

Widget page(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('Eggplant advisory panel expires without Tomato RH or schedule', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var now = fixture.at;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: SingleChildScrollView(
              child: GrowingConditionsPanel(
                crop: Crop.eggplant,
                sample: fixture.sample(),
                clock: () => now,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('21.1–29.4'), findsOneWidget);
    expect(find.textContaining('65–75%'), findsNothing);
    expect(find.textContaining('25.0 °C'), findsOneWidget);
    expect(
      find.textContaining('No numerical reference assigned'),
      findsOneWidget,
    );
    now = now.add(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 31));
    expect(find.textContaining('Air temperature: Unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all nine Eggplant entries can be browsed offline with limitations and sources',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CropKnowledgeScreen(crop: Crop.eggplant)),
      );
      expect(find.byType(ExpansionTile), findsNWidgets(9));
      final target = find.byKey(const ValueKey('downy_mildew'));
      await tester.ensureVisible(target);
      await tester.tap(
        find.descendant(of: target, matching: find.text('downy mildew')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('does not establish this disease on Eggplant'),
        findsOneWidget,
      );
      final sources = find.descendant(
        of: target,
        matching: find.text('Research sources'),
      );
      await tester.ensureVisible(sources);
      await tester.tap(sources);
      await tester.pumpAndSettle();
      expect(find.textContaining('[EG-DOWN-01]'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Eggplant History card shows crop-specific explanation and unchanged score',
    (tester) async {
      final scan = TomatoScan.fromJson({
        ...fixture.prediction(source: 'upload').toJson(),
        'preview': img.encodePng(img.Image(width: 1, height: 1)),
      });
      await tester.pumpWidget(page(TomatoResultCard(scan: scan)));
      expect(find.text('Model score: 71.0%'), findsOneWidget);
      await tester.ensureVisible(find.text('Explanation & care'));
      await tester.tap(find.text('Explanation & care'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Wilting may reflect water stress'),
        findsOneWidget,
      );
      expect(find.textContaining('Do not equate wilt'), findsOneWidget);
      expect(find.textContaining('capture time and plant'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('automatic analysis is available with on-device photo guidance', (
    tester,
  ) async {
    late Directory dir;
    late Box<dynamic> box;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('eggplant-ui-');
      Hive.init(dir.path);
      box = await Hive.openBox<dynamic>('ui');
    });
    final h = HardwareController(box)..load();
    addTearDown(() async {
      h.dispose();
      await tester.runAsync(() async {
        await Hive.close();
        await dir.delete(recursive: true);
      });
    });
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSettingsScreen(hardware: h, crop: Crop.eggplant),
      ),
    );
    final control = find.byKey(const ValueKey('auto-analyze'));
    await tester.scrollUntilVisible(
      control,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<SwitchListTile>(control).onChanged, isNotNull);
    expect(tester.widget<SwitchListTile>(control).value, isFalse);
    expect(
      find.textContaining('Eggplant photo analysis runs on this device.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
