import 'package:agrisense/core/app_controller.dart';
import 'package:agrisense/data/mock_repositories.dart';
import 'package:agrisense/data/repositories.dart';

class MemoryHistory implements HistoryRepository {
  HistorySnapshot value = const HistorySnapshot();
  bool fail = false;
  @override
  Future<HistorySnapshot> load() async => value;
  @override
  Future<void> save(HistorySnapshot snapshot) async {
    if (fail) throw StateError('Test disk full');
    value = snapshot;
  }

  @override
  Future<void> clear() async {
    value = const HistorySnapshot();
  }
}

class MemorySettings implements SettingsRepository {
  SettingsSnapshot value = const SettingsSnapshot();
  @override
  Future<SettingsSnapshot> load() async => value;
  @override
  Future<void> save(SettingsSnapshot settings) async {
    value = settings;
  }

  @override
  Future<void> clear() async {
    value = const SettingsSnapshot();
  }
}

AppController makeController({
  MemoryHistory? history,
  MemorySettings? preferences,
}) => AppController(
  monitoring: MockMonitoringRepository(),
  devices: MockDeviceRepository(delay: Duration.zero),
  diagnosis: MockDiagnosisRepository(delay: Duration.zero),
  history: history ?? MemoryHistory(),
  preferences: preferences ?? MemorySettings(),
);
