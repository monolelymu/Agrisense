import 'automatic_capture.dart';
import 'models.dart';

/// LED settings are independent of photo automation and its timers.
class KitWarning {
  const KitWarning({
    required this.deviceId,
    required this.crop,
    required this.soilRaw,
    required this.rules,
  });
  final String deviceId;
  final Crop crop;
  final bool soilRaw;
  final List<CaptureRule> rules;

  void validate() {
    if (deviceId.isEmpty || rules.length != 4) {
      throw const FormatException('Invalid kit warning configuration.');
    }
    for (var i = 0; i < 4; i++) {
      final r = rules[i];
      final upper = i == 0
          ? 80
          : i == 3 || (i == 2 && soilRaw)
          ? 4095
          : 100;
      if (!r.minimum.isFinite ||
          !r.maximum.isFinite ||
          r.minimum < (i == 0 ? -40 : 0) ||
          r.maximum > upper ||
          r.minimum >= r.maximum) {
        throw const FormatException('Check the warning limits.');
      }
    }
  }

  Map<String, String> form() {
    validate();
    return {
      'version': '1',
      'device_id': deviceId,
      'crop': crop.name,
      'soil_raw': soilRaw ? '1' : '0',
      for (var i = 0; i < 4; i++) ...{
        '${names[i]}_enabled': rules[i].enabled ? '1' : '0',
        '${names[i]}_min': '${rules[i].minimum}',
        '${names[i]}_max': '${rules[i].maximum}',
      },
    };
  }

  static const names = ['temp', 'humidity', 'soil', 'gas'];
  factory KitWarning.fromJson(Map json) {
    if (json['version'] != 1 ||
        json['soil_raw'] is! bool ||
        json['configured'] != true) {
      throw const FormatException('Kit warning limits were not confirmed.');
    }
    final result = KitWarning(
      deviceId: json['device_id'] as String,
      crop: Crop.values.byName(json['crop'] as String),
      soilRaw: json['soil_raw'] as bool,
      rules: [
        for (final name in names)
          CaptureRule(
            json['${name}_enabled'] as bool,
            (json['${name}_min'] as num).toDouble(),
            (json['${name}_max'] as num).toDouble(),
          ),
      ],
    );
    result.validate();
    return result;
  }
  bool matches(KitWarning other) =>
      deviceId == other.deviceId &&
      crop == other.crop &&
      soilRaw == other.soilRaw &&
      List.generate(
        4,
        (i) =>
            rules[i].enabled == other.rules[i].enabled &&
            (rules[i].minimum - other.rules[i].minimum).abs() < .001 &&
            (rules[i].maximum - other.rules[i].maximum).abs() < .001,
      ).every((v) => v);
}
