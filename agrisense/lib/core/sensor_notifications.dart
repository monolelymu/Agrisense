import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../data/automatic_capture.dart';
import '../data/hardware_client.dart';

class SensorAlertSettings {
  // Fresh valid readings initialize new warning limits without a setup wizard.
  static const initial = SensorAlertSettings(
    enabled: true,
    capturePhoto: true,
    analyzePhoto: true,
    autoBaseline: true,
    soilRaw: true,
    duration: 10,
    cooldown: 60,
    preset: 'sensitive',
    rules: [
      CaptureRule(true, -40, 80),
      CaptureRule(true, 0, 100),
      CaptureRule(true, 0, 4095),
    ],
  );
  bool get awaitingLimits =>
      enabled &&
      ((autoBaseline && baseline == null) ||
          !rules.any((rule) => rule.enabled));
  const SensorAlertSettings({
    this.enabled = false,
    this.capturePhoto = false,
    this.analyzePhoto = false,
    this.showNotifications = true,
    this.repeat = false,
    this.preset = 'custom',
    this.baseline,
    this.autoBaseline = false,
    this.soilRaw = false,
    this.soilDelta = 150,
    this.duration = 30,
    this.cooldown = 300,
    this.rules = const [
      CaptureRule(false, -40, 80),
      CaptureRule(false, 0, 100),
      CaptureRule(false, 0, 100),
    ],
    this.gasRule = const CaptureRule(false, 0, 4095),
  });
  final bool enabled, capturePhoto, analyzePhoto, showNotifications, repeat;
  final String preset;
  final bool autoBaseline, soilRaw;
  final double soilDelta;
  final Map<String, dynamic>? baseline;
  final int duration, cooldown;
  final List<CaptureRule> rules;
  final CaptureRule gasRule;
  void validate() {
    if (!gasRule.minimum.isFinite ||
        !gasRule.maximum.isFinite ||
        gasRule.minimum < 0 ||
        gasRule.maximum > 4095 ||
        gasRule.minimum >= gasRule.maximum) {
      throw const FormatException(
        'Gas limits must be between 0 and 4095 raw units.',
      );
    }
    if (rules.length != 3 ||
        duration < 10 ||
        duration > 3600 ||
        cooldown < 30 ||
        cooldown > 86400) {
      throw const FormatException(
        'Use 10–3600 seconds for duration and 30–86400 seconds for cooldown.',
      );
    }
    for (var i = 0; i < rules.length; i++) {
      if (i == 2 && soilRaw) {
        if (!rules[i].minimum.isFinite ||
            !rules[i].maximum.isFinite ||
            rules[i].minimum < 0 ||
            rules[i].maximum > 4095 ||
            rules[i].minimum >= rules[i].maximum) {
          throw const FormatException('Check soil warning sensitivity.');
        }
      } else {
        rules[i].validate(i);
      }
    }
    if (!soilDelta.isFinite || soilDelta < 25 || soilDelta > 1000) {
      throw const FormatException('Check soil warning sensitivity.');
    }
    if (enabled && !rules.any((r) => r.enabled) && !gasRule.enabled) {
      throw const FormatException('Select at least one measurement.');
    }
    if (analyzePhoto && !capturePhoto) {
      throw const FormatException(
        'Enable warning photos before automatic analysis.',
      );
    }
    if (!const ['standard', 'sensitive', 'custom'].contains(preset)) {
      throw const FormatException('Choose a valid monitoring preset.');
    }
  }

  SensorAlertSettings initializeFrom(HardwareSample sample) {
    final saved = Map<String, dynamic>.from(baseline ?? sample.toJson());
    final values = [
      sample.temperature,
      sample.humidity,
      soilRaw
          ? sample.soilRaw.toDouble()
          : sample.soilCalibrated
          ? sample.soil
          : null,
    ];
    final next = List<CaptureRule>.of(rules);
    var changed = false;
    for (var i = 0; i < 3; i++) {
      if (saved.containsKey('metric_$i') || saved['manual_$i'] == true) {
        continue;
      }
      final value = values[i];
      final low = i == 0 ? -40.0 : 0.0,
          high = i == 0
              ? 80.0
              : i == 2 && soilRaw
              ? 4095.0
              : 100.0;
      if (value == null || !value.isFinite || value < low || value > high) {
        continue;
      }
      final offset = i == 0
          ? 1.0
          : i == 1
          ? 5.0
          : soilRaw
          ? soilDelta
          : 5.0;
      next[i] = CaptureRule(
        rules[i].enabled,
        math.max(low, value - offset),
        math.min(high, value + offset),
      );
      saved['metric_$i'] = value;
      changed = true;
    }
    if (!changed) return this;
    saved['received_at'] = sample.receivedAt.toIso8601String();
    return SensorAlertSettings(
      enabled: enabled,
      capturePhoto: capturePhoto,
      analyzePhoto: analyzePhoto,
      showNotifications: showNotifications,
      repeat: repeat,
      preset: preset,
      autoBaseline: autoBaseline,
      soilRaw: soilRaw,
      soilDelta: soilDelta,
      baseline: saved,
      duration: duration,
      cooldown: cooldown,
      rules: next,
      gasRule: gasRule,
    );
  }

  static SensorAlertSettings sensitive(HardwareSample sample, DateTime now) {
    final age = now.difference(sample.receivedAt);
    if (age.isNegative || age.inSeconds > 30) {
      throw const FormatException(
        'Read a fresh sensor sample before applying Sensitive.',
      );
    }
    return const SensorAlertSettings(
      enabled: true,
      preset: 'sensitive',
      autoBaseline: true,
      soilRaw: true,
      duration: 10,
      cooldown: 60,
      rules: [
        CaptureRule(true, -40, 80),
        CaptureRule(true, 0, 100),
        CaptureRule(true, 0, 4095),
      ],
    ).initializeFrom(sample);
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'capture_photo': capturePhoto,
    'analyze_photo': analyzePhoto,
    'show_notifications': showNotifications,
    'repeat': repeat,
    'preset': preset,
    'auto_baseline': autoBaseline,
    'soil_raw': soilRaw,
    'soil_delta': soilDelta,
    'gas_rule': {
      'enabled': gasRule.enabled,
      'min': gasRule.minimum,
      'max': gasRule.maximum,
    },
    if (baseline != null) 'baseline': baseline,
    'duration': duration,
    'cooldown': cooldown,
    'rules': [
      for (final r in rules)
        {'enabled': r.enabled, 'min': r.minimum, 'max': r.maximum},
    ],
  };
  factory SensorAlertSettings.fromJson(Map value) {
    final settings = SensorAlertSettings(
      enabled: value['enabled'] as bool,
      capturePhoto: value['capture_photo'] as bool? ?? false,
      analyzePhoto: value['analyze_photo'] as bool? ?? false,
      showNotifications: value['show_notifications'] as bool? ?? true,
      repeat: value['repeat'] as bool? ?? false,
      preset: value['preset'] as String? ?? 'custom',
      autoBaseline: value['auto_baseline'] == true,
      soilRaw: value['soil_raw'] == true,
      soilDelta: (value['soil_delta'] as num?)?.toDouble() ?? 150,
      gasRule: value['gas_rule'] is Map
          ? CaptureRule(
              value['gas_rule']['enabled'] as bool,
              (value['gas_rule']['min'] as num).toDouble(),
              (value['gas_rule']['max'] as num).toDouble(),
            )
          : const CaptureRule(false, 0, 4095),
      baseline: value['baseline'] == null
          ? null
          : Map<String, dynamic>.from(value['baseline'] as Map),
      duration: value['duration'] as int,
      cooldown: value['cooldown'] as int,
      rules: [
        for (final r in value['rules'] as List)
          CaptureRule(
            r['enabled'] as bool,
            (r['min'] as num).toDouble(),
            (r['max'] as num).toDouble(),
          ),
      ],
    );
    settings.validate();
    return settings;
  }
}

class SensorNotifications {
  static const channel = MethodChannel('agrisense/sensor_notifications');
  bool get supported => Platform.isAndroid;
  Future<bool> requestPermission() async =>
      supported &&
      (await channel.invokeMethod<bool>('requestPermission') ?? false);
  Future<bool> show(int id, String title, String body) async =>
      supported &&
      (await channel.invokeMethod<bool>('show', {
            'id': id,
            'title': title,
            'body': body,
          }) ??
          false);
}

/// One notification per sustained excursion. Recovery re-arms that measurement.
class SensorAlertTracker {
  final since = List<DateTime?>.filled(3, null);
  final sent = List<bool>.filled(3, false);
  DateTime? lastSample, lastNotification;
  String? lastId;
  void reset() {
    for (var i = 0; i < 3; i++) {
      since[i] = null;
      sent[i] = false;
    }
    lastSample = null;
    lastId = null;
  }

  List<int> evaluate(
    HardwareSample sample,
    SensorAlertSettings settings,
    DateTime now,
  ) {
    if (lastNotification != null && now.isBefore(lastNotification!)) {
      lastNotification = null;
    }
    if (lastSample != null &&
        (now.difference(lastSample!).inSeconds > 30 ||
            now.isBefore(lastSample!))) {
      reset();
    }
    if (sample.id == lastId) return [];
    lastId = sample.id;
    lastSample = now;
    final values = [
      sample.temperature,
      sample.humidity,
      settings.soilRaw
          ? sample.soilRaw.toDouble()
          : sample.soilCalibrated
          ? sample.soil
          : null,
    ];
    final ready = <int>[];
    for (var i = 0; i < 3; i++) {
      final value = values[i], rule = settings.rules[i];
      final outside =
          rule.enabled &&
          (!settings.autoBaseline ||
              settings.baseline?.containsKey('metric_$i') == true ||
              settings.baseline?['manual_$i'] == true) &&
          value != null &&
          value.isFinite &&
          value >= (i == 0 ? -40 : 0) &&
          value <=
              (i == 0
                  ? 80
                  : i == 2 && settings.soilRaw
                  ? 4095
                  : 100) &&
          (value < rule.minimum || value > rule.maximum);
      if (!outside) {
        since[i] = null;
        sent[i] = false;
        continue;
      }
      since[i] ??= now;
      if ((!sent[i] || settings.repeat) &&
          now.difference(since[i]!).inSeconds >= settings.duration) {
        ready.add(i);
      }
    }
    if (lastNotification != null &&
        now.difference(lastNotification!).inSeconds < settings.cooldown) {
      return [];
    }
    return ready;
  }

  void delivered(List<int> metrics, DateTime now) {
    for (final i in metrics) {
      sent[i] = true;
    }
    lastNotification = now;
  }
}
