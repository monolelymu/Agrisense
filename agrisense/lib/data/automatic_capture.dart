import 'models.dart';

const automaticMetrics = ['temp', 'humidity', 'soil'];

class CaptureRule {
  const CaptureRule(this.enabled, this.minimum, this.maximum);
  final bool enabled;
  final double minimum, maximum;
  void validate(int index) {
    if (!minimum.isFinite ||
        !maximum.isFinite ||
        minimum >= maximum ||
        minimum < (index == 0 ? -40 : 0) ||
        maximum > (index == 0 ? 80 : 100)) {
      throw const FormatException(
        'Enter valid minimum and maximum limits (minimum must be lower).',
      );
    }
  }
}

class AutomaticCapture {
  const AutomaticCapture({
    required this.deviceId,
    required this.crop,
    this.enabled = false,
    this.camera = '',
    this.cameraId = '',
    this.duration = 30,
    this.cooldown = 300,
    this.soilCalibrated = false,
    this.status = 'idle',
    this.rules = const [
      CaptureRule(false, -40, 80),
      CaptureRule(false, 0, 100),
      CaptureRule(false, 0, 100),
    ],
  });
  final String deviceId, camera, cameraId, status;
  final Crop crop;
  final bool enabled, soilCalibrated;
  final int duration, cooldown;
  final List<CaptureRule> rules;

  void validate() {
    if (!RegExp(r'^[a-f0-9]{12}$').hasMatch(deviceId) ||
        rules.length != 3 ||
        duration < 10 ||
        duration > 3600 ||
        cooldown < 60 ||
        cooldown > 86400) {
      throw const FormatException(
        'Use a duration of 10–3600 seconds and cooldown of 60–86400 seconds.',
      );
    }
    for (var i = 0; i < rules.length; i++) {
      rules[i].validate(i);
    }
    if (enabled &&
        (!rules.any((r) => r.enabled) ||
            !RegExp(r'^[a-f0-9]{12}$').hasMatch(cameraId))) {
      throw const FormatException(
        'Select at least one measurement and pair the camera.',
      );
    }
    if (enabled && rules[2].enabled && !soilCalibrated) {
      throw const FormatException(
        'Calibrate the soil sensor in firmware before enabling soil alerts.',
      );
    }
  }

  Map<String, String> form() => {
    'device_id': deviceId,
    'crop': crop.name,
    'enabled': enabled ? '1' : '0',
    if (enabled) ...{
      'camera': camera,
      'camera_id': cameraId,
      'duration': '$duration',
      'cooldown': '$cooldown',
      for (var i = 0; i < 3; i++) ...{
        '${automaticMetrics[i]}_enabled': rules[i].enabled ? '1' : '0',
        '${automaticMetrics[i]}_min': rules[i].minimum.toStringAsFixed(2),
        '${automaticMetrics[i]}_max': rules[i].maximum.toStringAsFixed(2),
      },
    },
  };

  factory AutomaticCapture.fromJson(Map<String, dynamic> json) {
    try {
      if (json['version'] != 1) {
        throw const FormatException(
          'Update the sensor firmware for automatic capture.',
        );
      }
      final value = AutomaticCapture(
        deviceId: json['device_id'] as String,
        crop: Crop.values.byName(json['crop'] as String),
        enabled: json['enabled'] as bool,
        camera: json['camera'] as String,
        cameraId: json['camera_id'] as String,
        duration: json['duration'] as int,
        cooldown: json['cooldown'] as int,
        soilCalibrated: json['soil_calibrated'] as bool,
        status: json['status'] as String,
        rules: [
          for (final metric in automaticMetrics)
            CaptureRule(
              json['${metric}_enabled'] as bool,
              (json['${metric}_min'] as num).toDouble(),
              (json['${metric}_max'] as num).toDouble(),
            ),
        ],
      );
      value.validate();
      return value;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Invalid automatic capture settings from sensor.',
      );
    }
  }
}
