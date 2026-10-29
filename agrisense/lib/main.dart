import 'data/models.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'features/diagnosis/tomato_scan.dart';
import 'features/monitoring/hardware_dashboard.dart';
import 'core/hardware_controller.dart';
import 'core/theme.dart';
import 'core/app_issue.dart';
import 'core/issue_card.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Hive.initFlutter();
    final box = await Hive.openBox<dynamic>('agrisense_v1');
    final hardware = HardwareController(box)..load();
    await hardware.reconcileAlerts();
    hardware.bindService();
    await hardware.initializeAppAlerts();
    if (hardware.address(Crop.tomato, 'sensor').isEmpty) {
      unawaited(hardware.connectKit(Crop.tomato, quietly: true));
    }
    runApp(HardwareApp(scans: TomatoScanStore(box), hardware: hardware));
  } catch (error) {
    runApp(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storage_outlined, size: 48),
                  const SizedBox(height: 16),
                  IssueCard(issue: AppIssue.history, onRetry: main),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
