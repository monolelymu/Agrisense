import 'tomato_assessment.dart';
import 'tomato_scan.dart';

// Use only the assessment frozen with the photo; never today's live readings.
EnvironmentalEvidence? _evidence(TomatoScan scan) => scan.source == 'upload'
    ? null
    : TomatoAssessment.tryFromJson(scan.assessment)?.evidence;

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
