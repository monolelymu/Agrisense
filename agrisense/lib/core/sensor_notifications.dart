import 'dart:io';
import 'package:flutter/services.dart';
import '../data/automatic_capture.dart';
import '../data/hardware_client.dart';

class SensorAlertSettings {
  const SensorAlertSettings({
    this.enabled = false,
    this.capturePhoto = false,
    this.duration = 30,
    this.cooldown = 300,
    this.rules = const [
      CaptureRule(false, -40, 80),
      CaptureRule(false, 0, 100),
      CaptureRule(false, 0, 100),
    ],
  });
  final bool enabled, capturePhoto;
  final int duration, cooldown;
  final List<CaptureRule> rules;
  void validate() {
    if (rules.length != 3 ||
        duration < 10 ||
        duration > 3600 ||
        cooldown < 60 ||
        cooldown > 86400) {
      throw const FormatException(
        'Use 10–3600 seconds for duration and 60–86400 seconds for cooldown.',
      );
    }
    for (var i = 0; i < rules.length; i++) {
      rules[i].validate(i);
    }
    if (enabled && !rules.any((r) => r.enabled)) {
      throw const FormatException('Select at least one measurement.');
    }
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'capture_photo': capturePhoto,
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
          (value < rule.minimum || value > rule.maximum);
      if (!outside) {
        since[i] = null;
        sent[i] = false;
        continue;
      }
      since[i] ??= now;
      if (!sent[i] &&
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
