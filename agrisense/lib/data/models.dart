enum Crop { tomato, chili }

extension CropLabel on Crop {
  String get label => this == Crop.tomato ? 'Tomato' : 'Chili';
  String get subtitle =>
      this == Crop.tomato ? 'Solanum lycopersicum' : 'Capsicum • demo setup';
}

enum NodeKind { sensor, vision }

enum ConnectionState { disconnected, connecting, connected }

class SensorReading {
  const SensorReading({
    required this.id,
    required this.crop,
    required this.timestamp,
    required this.soil,
    required this.temperature,
    required this.humidity,
    required this.gas,
    this.isMock = true,
  });
  final String id;
  final Crop crop;
  final DateTime timestamp;
  final double soil, temperature, humidity, gas;
  final bool isMock;
  Map<String, dynamic> toJson() => {
    'id': id,
    'crop': crop.name,
    'time': timestamp.toIso8601String(),
    'soil': soil,
    'temperature': temperature,
    'humidity': humidity,
    'gas': gas,
    'mock': isMock,
  };
  factory SensorReading.fromJson(Map<String, dynamic> j) => SensorReading(
    id: j['id'],
    crop: Crop.values.byName(j['crop']),
    timestamp: DateTime.parse(j['time']),
    soil: (j['soil'] as num).toDouble(),
    temperature: (j['temperature'] as num).toDouble(),
    humidity: (j['humidity'] as num).toDouble(),
    gas: (j['gas'] as num).toDouble(),
    isMock: j['mock'] ?? true,
  );
}

class StressScore {
  const StressScore({
    required this.crop,
    required this.timestamp,
    required this.contributions,
    this.isMock = true,
  });
  final Crop crop;
  final DateTime timestamp;
  final Map<String, int> contributions;
  final bool isMock;
  int get value => contributions.values.fold(0, (a, b) => a + b);
}

class DiseaseResult {
  const DiseaseResult({
    required this.id,
    required this.crop,
    required this.timestamp,
    required this.label,
    required this.confidence,
    required this.treatment,
    this.imageAsset,
    this.isMock = true,
  });
  final String id, label, treatment;
  final Crop crop;
  final DateTime timestamp;
  final double confidence;
  final String? imageAsset;
  final bool isMock;
  Map<String, dynamic> toJson() => {
    'id': id,
    'crop': crop.name,
    'time': timestamp.toIso8601String(),
    'label': label,
    'confidence': confidence,
    'treatment': treatment,
    'image': imageAsset,
    'mock': isMock,
  };
  factory DiseaseResult.fromJson(Map<String, dynamic> j) => DiseaseResult(
    id: j['id'],
    crop: Crop.values.byName(j['crop']),
    timestamp: DateTime.parse(j['time']),
    label: j['label'],
    confidence: (j['confidence'] as num).toDouble(),
    treatment: j['treatment'],
    imageAsset: j['image'],
    isMock: j['mock'] ?? true,
  );
}

class DeviceStatus {
  const DeviceStatus({
    required this.crop,
    required this.kind,
    this.state = ConnectionState.disconnected,
    this.isMock = true,
  });
  final Crop crop;
  final NodeKind kind;
  final ConnectionState state;
  final bool isMock;
}

class Alert {
  const Alert({
    required this.id,
    required this.crop,
    required this.timestamp,
    required this.score,
    this.diagnosisId,
    this.resolved = false,
    this.isMock = true,
  });
  final String id;
  final Crop crop;
  final DateTime timestamp;
  final int score;
  final String? diagnosisId;
  final bool resolved, isMock;
  Alert copyWith({String? diagnosisId, bool? resolved}) => Alert(
    id: id,
    crop: crop,
    timestamp: timestamp,
    score: score,
    diagnosisId: diagnosisId ?? this.diagnosisId,
    resolved: resolved ?? this.resolved,
    isMock: isMock,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'crop': crop.name,
    'time': timestamp.toIso8601String(),
    'score': score,
    'diagnosis': diagnosisId,
    'resolved': resolved,
    'mock': isMock,
  };
  factory Alert.fromJson(Map<String, dynamic> j) => Alert(
    id: j['id'],
    crop: Crop.values.byName(j['crop']),
    timestamp: DateTime.parse(j['time']),
    score: j['score'],
    diagnosisId: j['diagnosis'],
    resolved: j['resolved'] ?? false,
    isMock: j['mock'] ?? true,
  );
}

class CropSettings {
  const CropSettings({
    this.soilMin = 30,
    this.soilMax = 70,
    this.tempMin = 18,
    this.tempMax = 32,
    this.humidityMin = 40,
    this.humidityMax = 80,
    this.gasMax = 300,
    this.threshold = 50,
  });
  final double soilMin,
      soilMax,
      tempMin,
      tempMax,
      humidityMin,
      humidityMax,
      gasMax;
  final int threshold;
  Map<String, dynamic> toJson() => {
    'soilMin': soilMin,
    'soilMax': soilMax,
    'tempMin': tempMin,
    'tempMax': tempMax,
    'humidityMin': humidityMin,
    'humidityMax': humidityMax,
    'gasMax': gasMax,
    'threshold': threshold,
  };
  factory CropSettings.fromJson(Map<String, dynamic> j) => CropSettings(
    soilMin: (j['soilMin'] as num).toDouble(),
    soilMax: (j['soilMax'] as num).toDouble(),
    tempMin: (j['tempMin'] as num).toDouble(),
    tempMax: (j['tempMax'] as num).toDouble(),
    humidityMin: (j['humidityMin'] as num).toDouble(),
    humidityMax: (j['humidityMax'] as num).toDouble(),
    gasMax: (j['gasMax'] as num).toDouble(),
    threshold: j['threshold'],
  );
}
