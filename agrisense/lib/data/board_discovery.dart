import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'models.dart';

const demoKitId = String.fromEnvironment(
  'AGRISENSE_KIT_ID',
  defaultValue: 'agrisense-demo-kit',
);

class BoardIdentity {
  const BoardIdentity({
    required this.kitId,
    required this.deviceId,
    required this.role,
    required this.ready,
    required this.capabilities,
    this.sensorCrop,
  });
  final String kitId, deviceId, role;
  final bool ready;
  final List<String> capabilities;
  final Crop? sensorCrop;

  factory BoardIdentity.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    final id = json['device_id'];
    final kit = json['kit_id'];
    final capabilities = json['capabilities'];
    final crop = json['sensor_crop'];
    if (json['version'] != 1 ||
        role is! String ||
        !['camera', 'sensor'].contains(role) ||
        id is! String ||
        !RegExp(r'^[a-f0-9]{12}$').hasMatch(id) ||
        kit is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,48}$').hasMatch(kit) ||
        json['ready'] is! bool ||
        capabilities is! List ||
        capabilities.length > 16 ||
        capabilities.any((c) => c is! String || c.length > 40) ||
        (role == 'sensor' && !Crop.values.any((c) => c.name == crop))) {
      throw const FormatException('Unrecognized AgriSense device identity.');
    }
    return BoardIdentity(
      kitId: kit,
      deviceId: id,
      role: role,
      ready: json['ready'] as bool,
      capabilities: capabilities.cast<String>(),
      sensorCrop: role == 'sensor' ? Crop.values.byName(crop as String) : null,
    );
  }
}

/// Discovery advertises addresses only; HTTP identity verification is mandatory.
class BoardDiscovery {
  static const channel = MethodChannel('agrisense/discovery');
  bool get supported => Platform.isAndroid;
  Future<List<String>>? _pending;

  Future<List<String>> discover() {
    return _pending ??= _discover().whenComplete(() => _pending = null);
  }

  Future<List<String>> _discover() async {
    if (!supported) return [];
    final values = await channel
        .invokeListMethod<dynamic>('discover')
        .timeout(const Duration(seconds: 10));
    return (values ?? []).whereType<String>().take(16).toList();
  }

  Future<void> cancel() async {
    if (supported) {
      try {
        await channel.invokeMethod<void>('cancel');
      } catch (_) {
        /* Session timeout also cleans up. */
      }
    }
  }
}
