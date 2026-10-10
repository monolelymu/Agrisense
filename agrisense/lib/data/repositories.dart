import 'models.dart';

abstract interface class MonitoringRepository {
  List<SensorReading> seed(Crop crop, DateTime now);
  Future<SensorReading> sample(
    Crop crop,
    CropSettings settings, {
    required bool stressed,
  });
}

abstract interface class DeviceRepository {
  Future<List<NodeKind>> scan(Crop crop);
  Future<DeviceStatus> connect(Crop crop, NodeKind kind);
  Future<void> disconnect(Crop crop, NodeKind kind);
}

abstract interface class DiagnosisRepository {
  Future<DiseaseResult> classify(Crop crop, SensorReading reading);
}

class HistorySnapshot {
  const HistorySnapshot({
    this.readings = const [],
    this.alerts = const [],
    this.results = const [],
  });
  final List<SensorReading> readings;
  final List<Alert> alerts;
  final List<DiseaseResult> results;
}

abstract interface class HistoryRepository {
  Future<HistorySnapshot> load();
  Future<void> save(HistorySnapshot snapshot);
  Future<void> clear();
}

class SettingsSnapshot {
  const SettingsSnapshot({this.crops = const {}, this.fahrenheit = false});
  final Map<Crop, CropSettings> crops;
  final bool fahrenheit;
}

abstract interface class SettingsRepository {
  Future<SettingsSnapshot> load();
  Future<void> save(SettingsSnapshot settings);
  Future<void> clear();
}
