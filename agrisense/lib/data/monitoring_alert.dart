import 'package:hive_ce/hive.dart';
import 'hardware_client.dart';
import 'models.dart';
import '../core/sensor_notifications.dart';

/// No pairing keys or arbitrary device responses are persisted in an alert.
class MonitoringAlert {
  const MonitoringAlert({
    required this.id,
    required this.sample,
    required this.settings,
    required this.metrics,
    required this.timestamp,
    required this.camera,
    this.state = 'pending',
    this.issueCode,
    this.capturedAt,
  });
  final String id, camera, state;
  final String? issueCode;
  final HardwareSample sample;
  final SensorAlertSettings settings;
  final List<int> metrics;
  final DateTime timestamp;
  final DateTime? capturedAt;
  Crop get crop => sample.crop;
  String get resultId => 'auto-$id';
  bool get unfinished =>
      const ['pending', 'capturing', 'analyzing', 'saving'].contains(state);
  String get reason => metrics
      .map((i) {
        final value = [sample.temperature, sample.humidity, sample.soil][i];
        final rule = settings.rules[i];
        return '${const ['Temperature', 'Humidity', 'Soil moisture'][i]} ${value?.toStringAsFixed(1) ?? 'unavailable'} '
            '${i == 0 ? '°C' : '%'} (range ${rule.minimum}–${rule.maximum})';
      })
      .join('; ');
  MonitoringAlert change(
    String state, {
    String? issueCode,
    DateTime? capturedAt,
  }) => MonitoringAlert(
    id: id,
    sample: sample,
    settings: settings,
    metrics: metrics,
    timestamp: timestamp,
    camera: camera,
    state: state,
    issueCode: issueCode,
    capturedAt: capturedAt ?? this.capturedAt,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'sample': sample.toJson(),
    'settings': settings.toJson(),
    'metrics': metrics,
    'timestamp': timestamp.toIso8601String(),
    'camera': camera,
    'state': state,
    'issue': issueCode,
    'captured_at': capturedAt?.toIso8601String(),
  };
  factory MonitoringAlert.fromJson(Map value) => MonitoringAlert(
    id: value['id'] as String,
    sample: HardwareSample.fromSaved(value['sample'] as Map),
    settings: SensorAlertSettings.fromJson(value['settings'] as Map),
    metrics: (value['metrics'] as List).cast<int>(),
    timestamp: DateTime.parse(value['timestamp'] as String),
    camera: value['camera'] as String,
    state: value['state'] as String,
    issueCode: value['issue'] as String?,
    capturedAt: value['captured_at'] == null
        ? null
        : DateTime.parse(value['captured_at'] as String),
  );
}

class MonitoringAlertStore {
  MonitoringAlertStore(this.box);
  final Box<dynamic> box;
  static const prefix = 'monitoring-alert-v1/';
  List<MonitoringAlert> load() {
    final result = box.keys
        .whereType<String>()
        .where((k) => k.startsWith(prefix))
        .map((k) => MonitoringAlert.fromJson(box.get(k) as Map))
        .toList();
    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }

  Future<void> save(MonitoringAlert alert) async {
    await box.put('$prefix${alert.id}', alert.toJson());
    final records = load();
    if (records.length > 500) {
      await box.deleteAll(records.skip(500).map((a) => '$prefix${a.id}'));
    }
  }
}
