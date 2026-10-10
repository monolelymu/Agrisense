import 'package:hive_ce/hive.dart';
import 'models.dart';
import 'repositories.dart';

Map<String, dynamic> _map(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

class HiveHistoryRepository implements HistoryRepository {
  HiveHistoryRepository(this.box);
  final Box<dynamic> box;
  @override
  Future<HistorySnapshot> load() async {
    final raw = box.get('history');
    if (raw == null) return const HistorySnapshot();
    final j = _map(raw);
    return HistorySnapshot(
      readings: (j['readings'] as List)
          .map((r) => SensorReading.fromJson(_map(r)))
          .toList(),
      alerts: (j['alerts'] as List)
          .map((r) => Alert.fromJson(_map(r)))
          .toList(),
      results: (j['results'] as List)
          .map((r) => DiseaseResult.fromJson(_map(r)))
          .toList(),
    );
  }

  @override
  Future<void> save(HistorySnapshot snapshot) => box.put('history', {
    'version': 1,
    'readings': snapshot.readings.map((r) => r.toJson()).toList(),
    'alerts': snapshot.alerts.map((r) => r.toJson()).toList(),
    'results': snapshot.results.map((r) => r.toJson()).toList(),
  });
  @override
  Future<void> clear() => box.delete('history');
}

class HiveSettingsRepository implements SettingsRepository {
  HiveSettingsRepository(this.box);
  final Box<dynamic> box;
  @override
  Future<SettingsSnapshot> load() async {
    final raw = box.get('settings');
    if (raw == null) return const SettingsSnapshot();
    final j = _map(raw);
    return SettingsSnapshot(
      fahrenheit: j['fahrenheit'] ?? false,
      crops: {
        for (final crop in Crop.values)
          if (j[crop.name] != null)
            crop: CropSettings.fromJson(_map(j[crop.name])),
      },
    );
  }

  @override
  Future<void> save(SettingsSnapshot settings) => box.put('settings', {
    'version': 1,
    'fahrenheit': settings.fahrenheit,
    for (final e in settings.crops.entries) e.key.name: e.value.toJson(),
  });
  @override
  Future<void> clear() => box.delete('settings');
}
