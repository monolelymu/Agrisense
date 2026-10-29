import 'tomato_assessment.dart';
import 'tomato_scan.dart';
import '../../data/hardware_client.dart';
import '../../data/soil_calibration.dart';

// Use only the assessment frozen with the photo; never today's live readings.
EnvironmentalEvidence? _evidence(TomatoScan scan) => scan.source == 'upload'
    ? null
    : TomatoAssessment.tryFromJson(scan.assessment)?.evidence;

/// Display the measurements frozen with the photo, never live values or an
/// uncalibrated soil ADC value presented as a percentage.
List<String> scanSensorMeasurements(TomatoScan scan) {
  if (scan.source == 'upload' || scan.sensorContext == null) return const [];
  HardwareSample sample;
  try {
    sample = HardwareSample.fromSaved(scan.sensorContext!);
  } catch (_) {
    return const [];
  }
  if (!recentCropSample(sample, scan.timestamp, scan.crop)) return const [];
  final local = SoilCalibration.tryFromJson(
    scan.sensorContext!['soil_display_calibration'],
  );
  final soil = sample.soilCalibrated
      ? sample.soil
      : local?.percentage(sample.soilRaw);
  String value(double? n, String unit) =>
      n == null ? 'No reading' : '${n.toStringAsFixed(1)}$unit';
  return [
    'Readings when photo was taken',
    soil == null
        ? 'Soil reading: ${sample.soilRaw}'
        : 'Soil moisture: ${value(soil, '%')}',
    'Temperature: ${value(sample.temperature, ' °C')}',
    'Humidity: ${value(sample.humidity, '%')}',
  ];
}

String scanSensorSummary(TomatoScan scan) => switch (_evidence(scan)?.state) {
  EvidenceState.currentMatch || EvidenceState.favorableHistory =>
    'Sensor readings fit this result. They cannot confirm disease.',
  EvidenceState.notMatching =>
    'Sensor readings differ from this result. Check the leaf and take another photo.',
  EvidenceState.partial || EvidenceState.durationNotEstablished =>
    'Not enough sensor readings to compare.',
  EvidenceState.notAssessable => 'These sensors cannot check this problem.',
  EvidenceState.noContext || null => 'Photo only. No matching sensor readings.',
};

String scanRetakeGuidance(TomatoScan scan) =>
    'Take another clear photo in good light. Show one leaf.';
