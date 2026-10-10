import 'models.dart';
import 'repositories.dart';

class MockMonitoringRepository implements MonitoringRepository {
  @override
  List<SensorReading> seed(Crop crop, DateTime now) => List.generate(29, (i) {
    final time = now.subtract(Duration(hours: (28 - i) * 6));
    return SensorReading(
      id: '${crop.name}-seed-$i',
      crop: crop,
      timestamp: time,
      soil: 48 + (i % 5) * 2 + crop.index.toDouble(),
      temperature: 25 + (i % 4).toDouble(),
      humidity: 60 + (i % 6).toDouble(),
      gas: 140 + (i % 7) * 10,
    );
  });
  @override
  Future<SensorReading> sample(
    Crop crop,
    CropSettings settings, {
    required bool stressed,
  }) async {
    final now = DateTime.now();
    return SensorReading(
      id: '${crop.name}-${now.microsecondsSinceEpoch}',
      crop: crop,
      timestamp: now,
      soil: stressed
          ? settings.soilMax + 10
          : (settings.soilMin + settings.soilMax) / 2,
      temperature: stressed
          ? settings.tempMax + 6
          : (settings.tempMin + settings.tempMax) / 2,
      humidity: stressed
          ? settings.humidityMax + 10
          : (settings.humidityMin + settings.humidityMax) / 2,
      gas: stressed ? settings.gasMax + 150 : settings.gasMax / 2,
    );
  }
}

class MockDeviceRepository implements DeviceRepository {
  MockDeviceRepository({this.delay = const Duration(milliseconds: 650)});
  final Duration delay;
  @override
  Future<List<NodeKind>> scan(Crop crop) async {
    await Future<void>.delayed(delay);
    return NodeKind.values;
  }

  @override
  Future<DeviceStatus> connect(Crop crop, NodeKind kind) async {
    await Future<void>.delayed(delay);
    return DeviceStatus(
      crop: crop,
      kind: kind,
      state: ConnectionState.connected,
    );
  }

  @override
  Future<void> disconnect(Crop crop, NodeKind kind) async {}
}

class MockDiagnosisRepository implements DiagnosisRepository {
  MockDiagnosisRepository({this.delay = const Duration(milliseconds: 900)});
  final Duration delay;
  @override
  Future<DiseaseResult> classify(Crop crop, SensorReading reading) async {
    await Future<void>.delayed(delay);
    final now = DateTime.now();
    return DiseaseResult(
      id: '${crop.name}-diagnosis-${now.microsecondsSinceEpoch}',
      crop: crop,
      timestamp: now,
      label: switch (crop) {
        Crop.tomato => 'Early blight • sample result',
        Crop.chili => 'Leaf curl • sample result',
        Crop.eggplant => 'Leaf Spot • sample result',
      },
      confidence: switch (crop) {
        Crop.tomato => 0.92,
        Crop.chili => 0.87,
        Crop.eggplant => 0.89,
      },
      treatment:
          'Illustrative care information only. Inspect the plant and document changes in its leaves. A qualified grower or plant specialist should confirm the cause before treatment. This demo has not analyzed the image.',
    );
  }
}
