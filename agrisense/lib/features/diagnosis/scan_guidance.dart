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
      n == null ? 'Unavailable' : '${n.toStringAsFixed(1)}$unit';
  return [
    'Readings at photo time',
    'Soil moisture: ${soil == null ? '${sample.soilRaw} raw' : value(soil, '%')}',
    'Air temperature: ${value(sample.temperature, ' °C')}',
    'Humidity: ${value(sample.humidity, '% RH')}',
  ];
}

String scanSensorSummary(TomatoScan scan) => switch (_evidence(scan)?.state) {
  EvidenceState.currentMatch || EvidenceState.favorableHistory =>
    'At photo time, sensor conditions supported this possibility. They do not confirm disease.',
  EvidenceState.notMatching =>
    'At photo time, sensor conditions did not match this possibility. An older infection is still possible.',
  EvidenceState.partial || EvidenceState.durationNotEstablished =>
    'The saved sensor readings are not enough to check this possibility.',
  EvidenceState.notAssessable =>
    'These sensors cannot check this condition. The result is based on the photo.',
  EvidenceState.noContext || null =>
    'Photo-only result. No usable sensor readings are linked to this photo.',
};

String scanRetakeGuidance(TomatoScan scan) =>
    _evidence(scan)?.state == EvidenceState.notMatching
    ? 'Please take another clear photo. The image is uncertain and the sensor conditions did not match. Use good light and photograph one leaf from another angle.'
    : 'Please take another clear photo. Use good light and photograph one leaf from another angle. Check both sides and nearby leaves.';
