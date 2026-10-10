import 'package:agrisense/data/models.dart';
import 'package:agrisense/data/repositories.dart';
import 'package:agrisense/features/monitoring/stress_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';

void main() {
  test(
    'Eggplant has independent events, preferences, and serialized history',
    () async {
      final history = MemoryHistory();
      final preferences = MemorySettings();
      final c = makeController(history: history, preferences: preferences);
      await c.initialize();
      c.selectCrop(Crop.eggplant);
      await c.scan();
      expect(c.discovered[Crop.eggplant], NodeKind.values);
      await c.toggleDevice(NodeKind.sensor);
      await c.toggleDevice(NodeKind.vision);
      await c.sample(stressed: true);
      expect(c.results.single.crop, Crop.eggplant);
      expect(c.results.single.label, 'Leaf Spot • sample result');
      expect(c.results.single.isMock, isTrue);
      expect(c.activeAlerts(Crop.tomato), isEmpty);
      expect(c.activeAlerts(Crop.chili), isEmpty);
      expect(c.connected(Crop.tomato, NodeKind.sensor), isFalse);
      expect(c.connected(Crop.chili, NodeKind.vision), isFalse);
      expect(
        SensorReading.fromJson(c.latest(Crop.eggplant).toJson()).crop,
        Crop.eggplant,
      );
      expect(
        DiseaseResult.fromJson(c.results.single.toJson()).crop,
        Crop.eggplant,
      );
      expect(Alert.fromJson(c.alerts.single.toJson()).crop, Crop.eggplant);
      await c.saveSettings(
        Crop.eggplant,
        const CropSettings(threshold: 75),
        false,
      );
      final restored = makeController(
        history: history,
        preferences: preferences,
      );
      await restored.initialize();
      expect(restored.settingsFor(Crop.eggplant).threshold, 75);
      expect(restored.settingsFor(Crop.tomato).threshold, 50);
      expect(restored.settingsFor(Crop.chili).threshold, 50);
      expect(restored.results.single.crop, Crop.eggplant);
      expect(restored.connected(Crop.eggplant, NodeKind.sensor), isFalse);
      c.dispose();
      restored.dispose();
    },
  );

  test(
    'existing two-crop saves gain Eggplant without losing data or reseeding twice',
    () async {
      final history = MemoryHistory();
      final preferences = MemorySettings();
      final old = makeController(history: history, preferences: preferences);
      await old.initialize();
      await old.toggleDevice(NodeKind.sensor);
      await old.toggleDevice(NodeKind.vision);
      await old.sample(stressed: true);
      await old.saveSettings(
        Crop.chili,
        const CropSettings(threshold: 75),
        true,
      );
      final existing = old.readings
          .where((r) => r.crop != Crop.eggplant)
          .toList();
      history.value = HistorySnapshot(
        readings: existing,
        alerts: List.of(old.alerts),
        results: List.of(old.results),
      );
      final restored = makeController(
        history: history,
        preferences: preferences,
      );
      await restored.initialize();
      expect(
        restored.readings
            .where((r) => r.crop != Crop.eggplant)
            .map((r) => r.id),
        existing.map((r) => r.id),
      );
      expect(
        restored.readings.where((r) => r.crop == Crop.eggplant).length,
        29,
      );
      expect(restored.results.single.id, old.results.single.id);
      expect(restored.alerts.single.id, old.alerts.single.id);
      expect(restored.settingsFor(Crop.chili).threshold, 75);
      expect(restored.fahrenheit, isTrue);
      await restored.initialize();
      expect(restored.readings.length, existing.length + 29);
      old.dispose();
      restored.dispose();
    },
  );

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
      expect(restored.readings.length, 29 * Crop.values.length);
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
