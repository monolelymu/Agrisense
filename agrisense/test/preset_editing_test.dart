import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/core/sensor_notifications.dart';
import 'package:agrisense/core/theme.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/monitoring/notification_settings_screen.dart';

void main() {
  testWidgets(
    'editing Sensitive into Custom retains focus and saves the complete number',
    (tester) async {
      late Directory dir;
      late Box<dynamic> box;
      await tester.runAsync(() async {
        dir = await Directory('test').createTemp('preset-edit-');
        Hive.init(dir.path);
        box = await Hive.openBox<dynamic>('preset');
      });
      final h = HardwareController(box)..load();
      h.samples.add(
        HardwareSample(
          id: 'fresh',
          crop: Crop.tomato,
          receivedAt: DateTime.now(),
          temperature: 35,
          humidity: 90,
          soil: null,
          soilRaw: 1,
          gasRaw: 1,
          soilCalibrated: false,
        ),
      );
      h.status[Crop.tomato] = 'Received';
      h.assignments[Crop.tomato] = {'camera': 'http://192.168.1.21'};
      final sensitive = SensorAlertSettings.sensitive(
        h.samples.single,
        DateTime.now(),
      );
      h.notificationSettings[Crop.tomato] = sensitive;
      addTearDown(() async {
        h.dispose();
        await box.close();
        await dir.delete(recursive: true);
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: NotificationSettingsScreen(hardware: h, crop: Crop.tomato),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Sensitive'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Sensitive'));
      await tester.pumpAndSettle();
      final maximum = find.byKey(const ValueKey('notification-Maximum')).first;
      await tester.scrollUntilVisible(
        maximum,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(maximum), alignment: .5);
      await tester.pumpAndSettle();
      await tester.showKeyboard(maximum);
      tester.testTextInput.enterText('36.');
      await tester.pump();
      final editor = find.descendant(
        of: maximum,
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(editor).focusNode.hasFocus, isTrue);
      tester.testTextInput.enterText('34.5');
      await tester.pump();
      final save = find.text('Save notification settings');
      await tester.scrollUntilVisible(
        save,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(save), alignment: .5);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(save);
        await box.flush();
      });
      await tester.pumpAndSettle();
      final saved = h.notificationSettings[Crop.tomato]!;
      expect(saved.preset, 'custom');
      expect(saved.rules[0].maximum, 34.5);
      expect(saved.cooldown, 60);
      expect(saved.baseline!['sample_id'], 'fresh');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
