import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../data/automatic_capture.dart';
import '../data/hardware_client.dart';

class SensorAlertSettings {
  const SensorAlertSettings({
    this.enabled = false,
    this.capturePhoto = false,
    this.analyzePhoto = false,
    this.showNotifications = true,
    this.repeat = false,
    this.preset = 'custom',
    this.baseline,
    this.duration = 30,
    this.cooldown = 300,
    this.rules = const [
      CaptureRule(false, -40, 80),
      CaptureRule(false, 0, 100),
      CaptureRule(false, 0, 100),
    ],
  });
  final bool enabled, capturePhoto, analyzePhoto, showNotifications, repeat;
  final String preset;
  final Map<String, dynamic>? baseline;
  final int duration, cooldown;
  final List<CaptureRule> rules;
  void validate() {
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
      rules[i].validate(i);
    }
    if (enabled && !rules.any((r) => r.enabled)) {
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

  static SensorAlertSettings sensitive(HardwareSample sample, DateTime now) {
    final age = now.difference(sample.receivedAt);
    if (age.isNegative || age.inSeconds > 30) {
      throw const FormatException(
        'Read a fresh sensor sample before applying Sensitive.',
      );
    }
    final values = [
      sample.temperature,
      sample.humidity,
      sample.soilCalibrated ? sample.soil : null,
    ];
    final rules = <CaptureRule>[];
    for (var i = 0; i < 3; i++) {
      final value = values[i];
      final lower = i == 0 ? -40.0 : 0.0, upper = i == 0 ? 80.0 : 100.0;
      final valid =
          value != null && value.isFinite && value >= lower && value <= upper;
      final offset = i == 0 ? 1.0 : 5.0;
      rules.add(
        CaptureRule(
          valid,
          valid ? math.max(lower, value - offset) : lower,
          valid ? math.min(upper, value + offset) : upper,
        ),
      );
    }
    if (!rules.any((r) => r.enabled)) {
      throw const FormatException(
        'No usable measurements for Sensitive. Read sensors again.',
      );
    }
    return SensorAlertSettings(
      enabled: true,
      duration: 10,
      cooldown: 30,
      repeat: true,
      preset: 'sensitive',
      baseline: sample.toJson(),
      rules: rules,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'capture_photo': capturePhoto,
    'analyze_photo': analyzePhoto,
    'show_notifications': showNotifications,
    'repeat': repeat,
    'preset': preset,
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
      sample.soilCalibrated ? sample.soil : null,
    ];
    final ready = <int>[];
    for (var i = 0; i < 3; i++) {
      final value = values[i], rule = settings.rules[i];
      final outside =
          rule.enabled &&
          value != null &&
          value.isFinite &&
          value >= (i == 0 ? -40 : 0) &&
          value <= (i == 0 ? 80 : 100) &&
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
