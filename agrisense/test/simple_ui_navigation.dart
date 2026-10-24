import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openSimplePage(WidgetTester tester, String page) async {
  while (find.byType(NavigationBar).evaluate().isEmpty) {
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
  }
  if (page == 'Devices' || page == 'Settings') {
    await tester.tap(find.widgetWithText(TextButton, 'Settings'));
    await tester.pumpAndSettle();
    if (page == 'Devices') {
      await tester.tap(find.widgetWithText(ListTile, 'Device setup'));
      await tester.pumpAndSettle();
    }
    return;
  }
  final label = switch (page) {
    'Dashboard' || 'Trends' => 'Home',
    'History' => 'Records',
    _ => page,
  };
  await tester.tap(find.widgetWithText(NavigationDestination, label));
  await tester.pumpAndSettle();
  if (page == 'Trends') {
    await tester.ensureVisible(find.text('View trends'));
    await tester.tap(find.text('View trends'));
    await tester.pumpAndSettle();
  }
}

Future<void> chooseRecordCategory(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
  await tester.tap(find.byType(DropdownButtonFormField<int>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> openDashboardHelp(WidgetTester tester) async {
  await openSimplePage(tester, 'Settings');
  await tester.ensureVisible(find.text('Help & troubleshooting'));
  await tester.tap(find.text('Help & troubleshooting'));
  await tester.pumpAndSettle();
}
