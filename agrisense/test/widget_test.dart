// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agrisense/core/app.dart';
import 'package:agrisense/core/widgets.dart';
import 'package:agrisense/data/models.dart';
import 'support.dart';

void main() {
  testWidgets('three crop choices wrap on a small screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Crop? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: CropPicker(
              value: Crop.tomato,
              onChanged: (crop) => selected = crop,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Eggplant'));
    expect(selected, Crop.eggplant);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
    testWidgets('navigation and demo work at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = makeController();
      await c.initialize();
      addTearDown(c.dispose);
      await tester.pumpWidget(AgriSenseApp(controller: c));
      await tester.pumpAndSettle();
      expect(find.text('A closer look at your crops.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Devices').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Eggplant'));
      await tester.pumpAndSettle();
      expect(c.selectedCrop, Crop.eggplant);
      await tester.ensureVisible(find.text('Scan simulated nodes'));
      await tester.tap(find.text('Scan simulated nodes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Connect').first);
      await tester.tap(find.text('Connect').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Connect').last);
      await tester.tap(find.text('Connect').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dashboard').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Simulate stress'));
      await tester.tap(find.text('Simulate stress'));
      await tester.pumpAndSettle();
      expect(c.results.length, 1);
      expect(c.results.single.crop, Crop.eggplant);
      await tester.tap(find.byTooltip('Alerts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View mock diagnosis'));
      await tester.pumpAndSettle();
      expect(find.text('MOCK DIAGNOSIS'), findsOneWidget);
      expect(find.text('Leaf Spot • sample result'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      for (final label in ['Trends', 'History', 'Settings']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(find.text('Save settings'));
      await tester.tap(find.text('Save settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings saved on this device.'), findsOneWidget);
    });
  }
}
