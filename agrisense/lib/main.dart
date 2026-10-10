import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'core/app.dart';
import 'core/app_controller.dart';
import 'core/theme.dart';
import 'data/local_storage.dart';
import 'data/mock_repositories.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Hive.initFlutter();
    final box = await Hive.openBox<dynamic>('agrisense_v1');
    final controller = AppController(
      monitoring: MockMonitoringRepository(),
      devices: MockDeviceRepository(),
      diagnosis: MockDiagnosisRepository(),
      history: HiveHistoryRepository(box),
      preferences: HiveSettingsRepository(box),
    );
    runApp(AgriSenseApp(controller: controller));
    await controller.initialize();
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
                  const Text('AgriSense could not open local storage.'),
                  const SizedBox(height: 8),
                  const Text(
                    'Allow browser storage or try a regular browser window.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: main, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
