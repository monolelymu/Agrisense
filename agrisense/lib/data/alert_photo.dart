import 'dart:typed_data';
import 'models.dart';

class AlertPhoto {
  const AlertPhoto({
    required this.sampleId,
    required this.crop,
    required this.timestamp,
    required this.reason,
    required this.jpeg,
    this.alertId,
  });
  final String sampleId, reason;
  final String? alertId;
  final Crop crop;
  final DateTime timestamp;
  final Uint8List jpeg;
  Map<String, dynamic> toJson() => {
    'sample_id': sampleId,
    'crop': crop.name,
    'timestamp': timestamp.toIso8601String(),
    'reason': reason,
    'jpeg': jpeg,
    'alert_id': alertId,
  };
  factory AlertPhoto.fromJson(Map value) => AlertPhoto(
    sampleId: value['sample_id'] as String,
    crop: Crop.values.byName(value['crop'] as String),
    timestamp: DateTime.parse(value['timestamp'] as String),
    reason: value['reason'] as String,
    jpeg: value['jpeg'] as Uint8List,
    alertId: value['alert_id'] as String?,
  );
}
