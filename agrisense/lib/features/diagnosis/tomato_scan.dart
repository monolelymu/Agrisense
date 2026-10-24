import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import '../../data/models.dart';

String diseaseDisplayName(String label) => label
    .replaceAll('_', ' ')
    .split(' ')
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

class ScanPrediction {
  const ScanPrediction(this.label, this.score);
  final String label;
  final double score;
  String get displayLabel => diseaseDisplayName(label);
  Map<String, dynamic> toJson() => {'label': label, 'score': score};
  factory ScanPrediction.fromJson(Map<dynamic, dynamic> json) => ScanPrediction(
    json['label'] as String,
    (json['score'] as num).toDouble(),
  );
}

class TomatoScan {
  const TomatoScan({
    required this.id,
    required this.timestamp,
    required this.label,
    required this.score,
    required this.preview,
    required this.modelVersion,
    this.crop = Crop.tomato,
    this.predictions = const [],
    this.source = 'upload',
    this.alertId,
    this.sensorContext,
    this.assessment,
  });

  final String id, label, modelVersion;
  final String source;
  final String? alertId;
  final Map<String, dynamic>? sensorContext;
  final Map<String, dynamic>? assessment;
  final DateTime timestamp;
  final double score;
  final Uint8List preview;
  final Crop crop;
  final List<ScanPrediction> predictions;
  List<ScanPrediction> get rankedPredictions =>
      predictions.isEmpty ? [ScanPrediction(label, score)] : predictions;
  // Matches the notebook's provisional threshold, not a calibrated guarantee.
  bool get uncertain => score < 0.60;
  String get displayLabel => diseaseDisplayName(label);

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'label': label,
    'score': score,
    'preview': preview,
    'modelVersion': modelVersion,
    'crop': crop.name,
    'source': source,
    'alert_id': alertId,
    'sensor_context': sensorContext,
    'assessment': assessment,
    'predictions': predictions.map((p) => p.toJson()).toList(),
  };

  factory TomatoScan.fromJson(Map<dynamic, dynamic> json) => TomatoScan(
    id: json['id'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    label: json['label'] as String,
    score: (json['score'] as num).toDouble(),
    preview: Uint8List.fromList((json['preview'] as List).cast<int>()),
    modelVersion: json['modelVersion'] as String,
    crop: Crop.values.byName(json['crop'] as String? ?? 'tomato'),
    source: json['source'] as String? ?? 'upload',
    alertId: json['alert_id'] as String?,
    sensorContext: json['sensor_context'] == null
        ? null
        : Map<String, dynamic>.from(json['sensor_context'] as Map),
    assessment: json['assessment'] is Map
        ? Map<String, dynamic>.from(json['assessment'] as Map)
        : null,
    predictions: (json['predictions'] as List? ?? [])
        .map((p) => ScanPrediction.fromJson(p as Map))
        .toList(),
  );
}

/// Separate keys keep real scans out of simulated history and demo resets.
class TomatoScanStore {
  TomatoScanStore(this.box);
  // Session-only: Android picker recovery must not repeat on crop/tab changes.
  bool photoRecoveryChecked = false;
  final Box<dynamic> box;
  static const prefix = 'tomato-photo-v1/';
  bool bookmarked(String id) =>
      box.get('scan-bookmark-v1/$id', defaultValue: false) == true;
  Future<void> bookmark(String id, bool value) =>
      box.put('scan-bookmark-v1/$id', value);

  List<TomatoScan> load() {
    final scans = box.keys
        .whereType<String>()
        .where((key) => key.startsWith(prefix))
        .map((key) => TomatoScan.fromJson(box.get(key) as Map))
        .toList();
    scans.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return scans;
  }

  Future<void> save(TomatoScan scan) =>
      box.put('$prefix${scan.id}', scan.toJson());
}
