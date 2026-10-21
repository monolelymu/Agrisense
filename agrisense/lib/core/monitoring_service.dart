import 'dart:io';
import 'package:flutter/services.dart';

/// Native service retains this engine; it never creates a second Dart data owner.
class MonitoringServiceBridge {
  static const channel = MethodChannel('agrisense/monitoring_service');
  bool get supported => Platform.isAndroid;
  void listen(void Function(String event) onEvent) {
    channel.setMethodCallHandler((call) async => onEvent(call.method));
  }

  Future<bool> start(String crop) async =>
      supported &&
      (await channel.invokeMethod<bool>('start', {'crop': crop}) ?? false);
  Future<void> stop() async {
    if (supported) await channel.invokeMethod<void>('stop');
  }
}
