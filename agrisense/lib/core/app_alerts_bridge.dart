import 'dart:io';
import 'package:flutter/services.dart';

class AppAlertsBridge {
  static const channel = MethodChannel('agrisense/app_alerts');
  bool get supported => Platform.isAndroid;
  void listen(Future<void> Function() refresh) {
    if (supported) {
      channel.setMethodCallHandler((call) async {
        if (call.method == 'changed') {
          await refresh();
        }
      });
    }
  }

  Future<Map> snapshot() async => supported
      ? await channel.invokeMapMethod<dynamic, dynamic>('snapshot') ?? {}
      : {};
  Future<Map> configure(int? minute, bool enabled) async =>
      await channel.invokeMapMethod<dynamic, dynamic>('configure', {
        'minute': minute,
        'enabled': enabled,
      }) ??
      {};
  Future<void> requestPrecise() async {
    if (supported) await channel.invokeMethod<void>('precise');
  }

  Future<void> restore() async {
    if (supported) await channel.invokeMethod<void>('restore');
  }

  Future<void> acknowledge(String token) async {
    if (supported) {
      await channel.invokeMethod<void>('acknowledge', {'token': token});
    }
  }

  Future<bool> post(Map<String, dynamic> event) async =>
      supported && (await channel.invokeMethod<bool>('post', event) ?? false);
}
