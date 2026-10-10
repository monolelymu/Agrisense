import 'package:flutter/foundation.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import '../features/monitoring/stress_calculator.dart';

class AppController extends ChangeNotifier {
  AppController({
    required this.monitoring,
    required this.devices,
    required this.diagnosis,
    required this.history,
    required this.preferences,
  });
  final MonitoringRepository monitoring;
  final DeviceRepository devices;
  final DiagnosisRepository diagnosis;
  final HistoryRepository history;
  final SettingsRepository preferences;
  Crop selectedCrop = Crop.tomato;
  bool ready = false, busy = false, fahrenheit = false;
  String? error;
  String activity = '';
  final List<SensorReading> readings = [];
  final List<Alert> alerts = [];
  final List<DiseaseResult> results = [];
  final Map<Crop, CropSettings> settings = {};
  final Map<Crop, List<NodeKind>> discovered = {};
  final Map<(Crop, NodeKind), DeviceStatus> _connections = {};
  final Map<Crop, bool> _above = {};

  CropSettings settingsFor(Crop crop) => settings[crop] ?? const CropSettings();
  DeviceStatus device(Crop crop, NodeKind kind) =>
      _connections[(crop, kind)] ?? DeviceStatus(crop: crop, kind: kind);
  bool connected(Crop crop, NodeKind kind) =>
      device(crop, kind).state == ConnectionState.connected;
  SensorReading latest(Crop crop) => readings.lastWhere((r) => r.crop == crop);
  StressScore score(Crop crop) =>
      calculateStress(latest(crop), settingsFor(crop));
  List<Alert> activeAlerts(Crop crop) =>
      alerts.where((a) => a.crop == crop && !a.resolved).toList();
  DiseaseResult? resultById(String? id) {
    for (final r in results) {
      if (r.id == id) return r;
    }
    return null;
  }

  String temperature(double c) =>
      '${(fahrenheit ? c * 9 / 5 + 32 : c).toStringAsFixed(1)}°${fahrenheit ? 'F' : 'C'}';
  void selectCrop(Crop crop) {
    selectedCrop = crop;
    notifyListeners();
  }

  Future<void> _run(String message, Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    error = null;
    activity = message;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      error = '$message failed. $e';
    } finally {
      busy = false;
      activity = '';
      notifyListeners();
    }
  }

  Future<void> initialize() => _run('Loading local demo', () async {
    final saved = await history.load();
    final prefs = await preferences.load();
    readings
      ..clear()
      ..addAll(saved.readings);
    alerts
      ..clear()
      ..addAll(saved.alerts);
    results
      ..clear()
      ..addAll(saved.results);
    settings
      ..clear()
      ..addAll(prefs.crops);
    fahrenheit = prefs.fahrenheit;
    for (final crop in Crop.values) {
      if (!readings.any((r) => r.crop == crop)) {
        readings.addAll(monitoring.seed(crop, DateTime.now()));
      }
      _above[crop] = score(crop).value >= settingsFor(crop).threshold;
    }
    await _saveHistory();
    ready = true;
  });

  Future<void> _saveHistory() => history.save(
    HistorySnapshot(
      readings: List.of(readings),
      alerts: List.of(alerts),
      results: List.of(results),
    ),
  );
  Future<void> _saveSettings() => preferences.save(
    SettingsSnapshot(crops: Map.of(settings), fahrenheit: fahrenheit),
  );
  Future<void> retrySave() => _run('Saving local data', () async {
    await _saveHistory();
    await _saveSettings();
  });

  Future<void> scan() {
    final crop = selectedCrop;
    return _run('Scanning simulated ${crop.label} nodes', () async {
      discovered[crop] = await devices.scan(crop);
    });
  }

  Future<void> toggleDevice(NodeKind kind) {
    final crop = selectedCrop;
    return _run('Updating simulated connection', () async {
      if (connected(crop, kind)) {
        await devices.disconnect(crop, kind);
        _connections[(crop, kind)] = DeviceStatus(crop: crop, kind: kind);
      } else {
        _connections[(crop, kind)] = DeviceStatus(
          crop: crop,
          kind: kind,
          state: ConnectionState.connecting,
        );
        notifyListeners();
        try {
          _connections[(crop, kind)] = await devices.connect(crop, kind);
        } catch (_) {
          _connections[(crop, kind)] = DeviceStatus(crop: crop, kind: kind);
          rethrow;
        }
      }
    });
  }

  Future<void> sample({required bool stressed}) {
    final crop = selectedCrop;
    return _run(
      stressed ? 'Simulating stress' : 'Recording normal sample',
      () async {
        if (!connected(crop, NodeKind.sensor)) {
          throw StateError('Connect the simulated Sensor Node first.');
        }
        final reading = await monitoring.sample(
          crop,
          settingsFor(crop),
          stressed: stressed,
        );
        readings.add(reading);
        final value = score(crop).value;
        final isAbove = value >= settingsFor(crop).threshold;
        Alert? raised;
        if (isAbove && !(_above[crop] ?? false)) {
          raised = Alert(
            id: 'alert-${reading.id}',
            crop: crop,
            timestamp: reading.timestamp,
            score: value,
          );
          alerts.add(raised);
        }
        if (!isAbove) {
          for (var i = 0; i < alerts.length; i++) {
            if (alerts[i].crop == crop && !alerts[i].resolved) {
              alerts[i] = alerts[i].copyWith(resolved: true);
            }
          }
        }
        _above[crop] = isAbove;
        await _saveHistory();
        notifyListeners();
        if (raised != null && connected(crop, NodeKind.vision)) {
          await _diagnose(raised);
        }
      },
    );
  }

  Future<void> _diagnose(Alert alert) async {
    if (!connected(alert.crop, NodeKind.sensor) ||
        !connected(alert.crop, NodeKind.vision)) {
      throw StateError('Connect both simulated nodes, then retry.');
    }
    activity = 'Simulating capture and classification';
    notifyListeners();
    final reading = readings.lastWhere(
      (r) => r.crop == alert.crop && !r.timestamp.isAfter(alert.timestamp),
      orElse: () => latest(alert.crop),
    );
    final result = await diagnosis.classify(alert.crop, reading);
    results.add(result);
    final index = alerts.indexWhere((a) => a.id == alert.id);
    alerts[index] = alerts[index].copyWith(diagnosisId: result.id);
    await _saveHistory();
  }

  Future<void> retryDiagnosis(Alert alert) =>
      _run('Retrying mock diagnosis', () async {
        final current = alerts.firstWhere((a) => a.id == alert.id);
        if (current.diagnosisId == null) await _diagnose(current);
      });

  Future<void> saveSettings(
    Crop crop,
    CropSettings value,
    bool useFahrenheit,
  ) => _run('Saving settings', () async {
    final next = Map<Crop, CropSettings>.of(settings)..[crop] = value;
    await preferences.save(
      SettingsSnapshot(crops: next, fahrenheit: useFahrenheit),
    );
    settings[crop] = value;
    fahrenheit = useFahrenheit;
    // Settings changes establish a new baseline; they do not fabricate sensor events.
    _above[crop] = score(crop).value >= value.threshold;
  });

  Future<void> reset() => _run('Resetting demo', () async {
    await history.clear();
    await preferences.clear();
    readings.clear();
    alerts.clear();
    results.clear();
    settings.clear();
    discovered.clear();
    _connections.clear();
    _above.clear();
    fahrenheit = false;
    selectedCrop = Crop.tomato;
    for (final crop in Crop.values) {
      readings.addAll(monitoring.seed(crop, DateTime.now()));
      _above[crop] = false;
    }
    await _saveHistory();
  });
}
