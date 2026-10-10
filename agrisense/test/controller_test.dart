import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/monitoring/stress_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';

void main() {
  test('stress uses inclusive ranges and 25-point contributions', () {
    SensorReading r(double soil, double temp, double humidity, double gas) =>
        SensorReading(
          id: 'test',
          crop: Crop.tomato,
          timestamp: DateTime(2026),
          soil: soil,
          temperature: temp,
          humidity: humidity,
          gas: gas,
        );
    expect(calculateStress(r(30, 18, 40, 300), const CropSettings()).value, 0);
    expect(calculateStress(r(70, 32, 80, 300), const CropSettings()).value, 0);
    expect(
      calculateStress(r(29.9, 32.1, 80, 300), const CropSettings()).value,
      50,
    );
    expect(
      calculateStress(r(71, 33, 81, 301), const CropSettings()).value,
      100,
    );
  });
  test(
    'connections gate samples, alerts deduplicate, crops stay isolated',
    () async {
      final c = makeController();
      await c.initialize();
      final count = c.readings.length;
      await c.sample(stressed: true);
      expect(c.error, contains('Connect'));
      expect(c.readings.length, count);
      await c.toggleDevice(NodeKind.sensor);
      await c.sample(stressed: true);
      expect(c.alerts.length, 1);
      expect(c.results, isEmpty);
      await c.sample(stressed: true);
      expect(c.alerts.length, 1);
      await c.toggleDevice(NodeKind.vision);
      await c.retryDiagnosis(c.alerts.single);
      expect(c.results.length, 1);
      expect(c.alerts.single.diagnosisId, c.results.single.id);
      await c.retryDiagnosis(c.alerts.single);
      expect(c.results.length, 1);
      await c.sample(stressed: false);
      expect(c.alerts.single.resolved, isTrue);
      await c.sample(stressed: true);
      expect(c.alerts.length, 2);
      expect(c.results.length, 2);
      expect(c.score(Crop.chili).value, 0);
      c.selectCrop(Crop.chili);
      expect(c.connected(Crop.chili, NodeKind.sensor), isFalse);
      expect(c.activeAlerts(Crop.chili), isEmpty);
      await c.toggleDevice(NodeKind.sensor);
      await c.sample(stressed: true);
      expect(c.alerts.last.crop, Crop.chili);
      c.dispose();
    },
  );
  test(
    'history and settings restore while simulated connections reset',
    () async {
      final history = MemoryHistory();
      final settings = MemorySettings();
      final c = makeController(history: history, preferences: settings);
      await c.initialize();
      await c.toggleDevice(NodeKind.sensor);
      await c.toggleDevice(NodeKind.vision);
      await c.sample(stressed: true);
      await c.saveSettings(Crop.chili, const CropSettings(threshold: 75), true);
      final restored = makeController(history: history, preferences: settings);
      await restored.initialize();
      expect(restored.results.length, 1);
      expect(restored.settingsFor(Crop.chili).threshold, 75);
      expect(restored.fahrenheit, isTrue);
      expect(restored.connected(Crop.tomato, NodeKind.sensor), isFalse);
      await restored.toggleDevice(NodeKind.sensor);
      await restored.sample(stressed: true);
      expect(restored.alerts.length, 1);
      await restored.reset();
      expect(restored.results, isEmpty);
      expect(restored.alerts, isEmpty);
      expect(restored.fahrenheit, isFalse);
      expect(restored.readings.length, 58);
      c.dispose();
      restored.dispose();
    },
  );
  test('save failures are visible and retry preserves the event', () async {
    final history = MemoryHistory();
    final c = makeController(history: history);
    await c.initialize();
    await c.toggleDevice(NodeKind.sensor);
    history.fail = true;
    await c.sample(stressed: true);
    expect(c.error, contains('disk full'));
    expect(c.alerts.length, 1);
    history.fail = false;
    await c.retrySave();
    expect(c.error, isNull);
    expect(history.value.alerts.length, 1);
    c.dispose();
  });
}
