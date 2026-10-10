import '../../data/models.dart';

/// Deliberately simple demo logic, not an agronomically validated risk model.
StressScore calculateStress(SensorReading r, CropSettings s) => StressScore(
  crop: r.crop,
  timestamp: r.timestamp,
  isMock: r.isMock,
  contributions: {
    'Soil moisture': r.soil < s.soilMin || r.soil > s.soilMax ? 25 : 0,
    'Temperature': r.temperature < s.tempMin || r.temperature > s.tempMax
        ? 25
        : 0,
    'Humidity': r.humidity < s.humidityMin || r.humidity > s.humidityMax
        ? 25
        : 0,
    'Gas / VOC': r.gas > s.gasMax ? 25 : 0,
  },
);
