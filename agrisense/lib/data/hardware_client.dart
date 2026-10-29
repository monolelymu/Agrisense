import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'models.dart';
import 'automatic_capture.dart';
import 'kit_warning.dart';
import 'board_discovery.dart';
import 'camera_stream.dart';
import 'firebase_cloud_client.dart';
import '../core/firebase_config.dart';

class HardwareHttpException extends FormatException {
  const HardwareHttpException(this.status, super.message);
  final int status;
}

/// Only explicitly assigned private IPv4 nodes; no DNS, redirects or proxies.
Uri hardwareAddress(String value) {
  final text = value.trim();
  if (text == FirebaseConfig.cloudSensorAddress ||
      text == FirebaseConfig.cloudCameraAddress ||
      text == 'cloud://sensor' ||
      text == 'cloud://camera') {
    return Uri.parse(text);
  }
  final uri = Uri.tryParse(text.contains('://') ? text : 'http://$text');
  if (uri == null ||
      uri.scheme != 'http' ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      uri.port < 1 ||
      uri.port > 65535) {
    throw const FormatException(
      'Enter a local IPv4 address, optionally with a port.',
    );
  }
  final parts = uri.host.split('.');
  final bytes = parts.map(int.tryParse).toList();
  if (bytes.length != 4 ||
      bytes.any((n) => n == null || n < 0 || n > 255) ||
      List.generate(4, (i) => bytes[i].toString()).join('.') != uri.host) {
    throw const FormatException(
      'Use the board’s numeric private IPv4 address.',
    );
  }
  final private =
      bytes[0] == 10 ||
      (bytes[0] == 172 && bytes[1]! >= 16 && bytes[1]! <= 31) ||
      (bytes[0] == 192 && bytes[1] == 168);
  if (!private) {
    throw const FormatException('Only private LAN addresses are allowed.');
  }
  return uri.replace(path: '');
}

class SensorConfiguration {
  const SensorConfiguration({required this.deviceId, required this.crop});
  final String deviceId;
  final Crop crop;

  factory SensorConfiguration.fromJson(Map<String, dynamic> json) {
    final id = json['device_id'];
    if (json['crop_protocol'] != 1 ||
        id is! String ||
        !RegExp(r'^[a-f0-9]{12}$').hasMatch(id) ||
        !Crop.values.any((c) => c.name == json['crop'])) {
      throw const FormatException(
        'Sensor needs the app-controlled crop firmware.',
      );
    }
    return SensorConfiguration(
      deviceId: id,
      crop: Crop.values.byName(json['crop'] as String),
    );
  }
}

class HardwareSample {
  const HardwareSample({
    required this.id,
    required this.crop,
    required this.receivedAt,
    required this.temperature,
    required this.humidity,
    required this.soil,
    required this.soilRaw,
    required this.gasRaw,
    required this.soilCalibrated,
    this.deviceId = '',
  });
  final String id;
  final String deviceId;
  final Crop crop;
  final DateTime receivedAt;
  final double? temperature, humidity, soil;
  final int soilRaw, gasRaw;
  final bool soilCalibrated;

  static double? _number(dynamic value, double min, double max) {
    if (value == null) return null;
    if (value is! num || !value.isFinite || value < min || value > max) {
      throw const FormatException('Invalid sensor measurement.');
    }
    return value.toDouble();
  }

  factory HardwareSample.fromDevice(
    Map<String, dynamic> json,
    Crop crop, {
    DateTime? now,
  }) {
    if (json['version'] != 1 || json['crop'] != crop.name) {
      throw const FormatException(
        'Sensor crop or protocol does not match this setup.',
      );
    }
    final id = json['sample_id'];
    final age = json['age_ms'];
    final dhtAge = json['dht_age_ms'];
    if (dhtAge != null && (dhtAge is! int || dhtAge < 0)) {
      throw const FormatException('Invalid temperature/humidity age.');
    }
    if (id is! String ||
        id.isEmpty ||
        id.length > 100 ||
        age is! int ||
        age < 0 ||
        age > 30000) {
      throw const FormatException('Sensor has no fresh sample. Try again.');
    }
    final raw = json['soil_raw'];
    final gas = json['gas_raw'];
    if (raw is! int ||
        gas is! int ||
        raw < 0 ||
        raw > 4095 ||
        gas < 0 ||
        gas > 4095 ||
        json['soil_calibrated'] is! bool) {
      throw const FormatException('Invalid sensor response.');
    }
    final calibrated = json['soil_calibrated'] as bool;
    final soil = _number(json['soil_pct'], 0, 100);
    return HardwareSample(
      id: id,
      crop: crop,
      receivedAt: (now ?? DateTime.now()).subtract(Duration(milliseconds: age)),
      temperature: dhtAge is int && dhtAge > 5000
          ? null
          : _number(json['temp_c'], -40, 80),
      humidity: dhtAge is int && dhtAge > 5000
          ? null
          : _number(json['humidity_pct'], 0, 100),
      soil: calibrated ? soil : null,
      soilRaw: raw,
      gasRaw: gas,
      soilCalibrated: calibrated,
      deviceId: json['device_id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'device_id': deviceId,
    'sample_id': id,
    'crop': crop.name,
    'age_ms': 0,
    'temp_c': temperature,
    'humidity_pct': humidity,
    'soil_pct': soil,
    'soil_raw': soilRaw,
    'gas_raw': gasRaw,
    'soil_calibrated': soilCalibrated,
    'received_at': receivedAt.toIso8601String(),
  };
  factory HardwareSample.fromSaved(Map<dynamic, dynamic> json) =>
      HardwareSample.fromDevice(
        Map<String, dynamic>.from(json),
        Crop.values.byName(json['crop'] as String),
        now: DateTime.parse(json['received_at'] as String),
      );
}

class HardwareClient {
  HardwareClient({
    HttpClient Function()? httpClientFactory,
    FirebaseCloudClient? cloud,
  })  : _httpClientFactory = httpClientFactory ?? HttpClient.new,
        _explicitCloud = cloud;
  final HttpClient Function() _httpClientFactory;
  FirebaseCloudClient? _explicitCloud;
  FirebaseCloudClient get cloud => _explicitCloud ??= FirebaseCloudClient(
        httpClientFactory: _httpClientFactory,
      );

  CameraFrameConnection cameraStream(String address) {
    final base = hardwareAddress(address);
    if (base.port >= 65535) throw const FormatException('Invalid stream port.');
    return CameraFrameConnection(
      base.replace(port: base.port + 1, path: '/stream'),
      factory: _httpClientFactory,
    );
  }

  Future<void> panTilt(
    String address, {
    required String deviceId,
    required String requestId,
    required String action,
  }) async {
    if (address.startsWith('cloud://')) {
      return cloud.sendPanTilt(
        deviceId: deviceId,
        requestId: requestId,
        action: action,
      );
    }
    if (!['up', 'down', 'left', 'right', 'center'].contains(action)) {
      throw const FormatException('Invalid movement.');
    }
    final bytes = await _request(
      address,
      '/pan-tilt',
      'application/json',
      2048,
      timeout: const Duration(seconds: 3),
      form: {
        'version': '1',
        'device_id': deviceId,
        'request_id': requestId,
        'action': action,
      },
    );
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map ||
        json['version'] != 1 ||
        json['device_id'] != deviceId ||
        json['request_id'] != requestId ||
        json['ready'] != true ||
        json['pan'] is! int ||
        json['tilt'] is! int ||
        json['pan'] < 0 ||
        json['pan'] > 180 ||
        json['tilt'] < 0 ||
        json['tilt'] > 180) {
      throw const FormatException(
        'Movement was not confirmed by the intended board.',
      );
    }
  }

  Future<void> appStatus(
    String address, {
    required String deviceId,
    required String sessionId,
    required bool cameraReady,
    required String cameraId,
  }) async {
    final bytes = await _request(
      address,
      '/app-status',
      'application/json',
      2048,
      timeout: const Duration(seconds: 3),
      form: {
        'version': '1',
        'device_id': deviceId,
        'session_id': sessionId,
        'camera_ready': cameraReady ? '1' : '0',
        'camera_device_id': cameraId,
      },
    );
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map || json['version'] != 1 || json['device_id'] != deviceId) {
      throw const FormatException(
        'Status was not accepted by the intended board.',
      );
    }
  }

  Future<Uint8List> _request(
    String address,
    String path,
    String mime,
    int limit, {
    Map<String, String>? form,
    String? pairingCode,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final uri = hardwareAddress(address).replace(path: path);
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 5)
      ..findProxy = (_) => 'DIRECT';
    try {
      return await (() async {
        final request = await client.openUrl(
          form == null ? 'GET' : 'POST',
          uri,
        );
        request.followRedirects = false;
        request.headers.set(HttpHeaders.acceptHeader, mime);
        if (pairingCode != null) {
          request.headers.set('X-AgriSense-Key', pairingCode);
        }
        if (form != null) {
          request.headers.contentType = ContentType(
            'application',
            'x-www-form-urlencoded',
            charset: 'utf-8',
          );
          // ESP32 WebServer expects a fixed-length form body, not chunked POST.
          final body = utf8.encode(Uri(queryParameters: form).query);
          request.contentLength = body.length;
          request.add(body);
        }
        final response = await request.close();
        if (response.statusCode != 200) {
          throw HardwareHttpException(
            response.statusCode,
            await _httpError(response, path),
          );
        }
        final actualMime = response.headers.contentType?.mimeType;
        if (actualMime != mime) {
          throw FormatException(
            '$path: HTTP 200, but received ${actualMime ?? 'no Content-Type'}; expected $mime. Check the board IP and firmware.',
          );
        }
        if (response.contentLength > limit) {
          throw const FormatException('Board response is too large.');
        }
        final data = BytesBuilder(copy: false);
        await for (final chunk in response) {
          if (data.length + chunk.length > limit) {
            throw const FormatException('Board response is too large.');
          }
          data.add(chunk);
        }
        return data.takeBytes();
      })().timeout(timeout);
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _httpError(HttpClientResponse response, String path) async {
    var detail = switch (response.statusCode) {
      400 => 'The board rejected the settings request.',
      401 => 'Pairing code was rejected. Check the code from Serial Monitor.',
      404 => 'Endpoint not found. Check the board IP and installed firmware.',
      409 => 'A different sensor answered at this IP. Check the board address.',
      503 => 'The sensor is not ready. Check its Serial Monitor.',
      _ => 'The board rejected the request. Check its firmware.',
    };
    // Show only known firmware diagnostics, never arbitrary responses or secrets.
    if (response.headers.contentType?.mimeType == 'application/json') {
      final data = BytesBuilder(copy: false);
      await for (final chunk in response) {
        if (data.length + chunk.length > 4096) break;
        data.add(chunk);
      }
      try {
        final json = jsonDecode(utf8.decode(data.takeBytes()));
        if (json is Map) {
          detail = switch (json['error']) {
            'invalid_crop_request' =>
              'The sensor could not read a valid crop and device ID from the assignment request.',
            'configuration_storage_unavailable' =>
              'Sensor configuration storage is unavailable. Restart the sensor and check Serial Monitor.',
            'save_failed_restart_sensor' =>
              'The sensor could not save settings. Restart it, then reload and retry.',
            'invalid_automation' =>
              'Check selected measurements, limits, duration, cooldown, camera pairing and soil calibration.',
            'wrong_device_or_crop' =>
              'Sensor identity or crop changed. Check the assignment before saving.',
            'no_fresh_sample' =>
              'No fresh sensor reading is ready. Wait ten seconds and retry.',
            _ => detail,
          };
        }
      } on FormatException {
        // Retain the HTTP status when the optional diagnostic is malformed.
      }
    }
    return '$path: HTTP ${response.statusCode}. $detail';
  }

  Future<HardwareSample> read(String address, Crop crop) async {
    if (address.startsWith('cloud://')) {
      return cloud.readSample(crop);
    }
    final bytes = await _request(
      address,
      '/readings',
      'application/json',
      16384,
    );
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid sensor JSON.');
    }
    return HardwareSample.fromDevice(json, crop);
  }

  Future<BoardIdentity> identity(String address) async {
    if (address.startsWith('cloud://')) {
      final role = address.replaceFirst('cloud://', '');
      final id = await cloud.readIdentity(role);
      if (id == null) {
        throw const FormatException('Cloud board identity not available.');
      }
      return id;
    }
    final bytes = await _request(
      address,
      '/identity',
      'application/json',
      4096,
      timeout: const Duration(seconds: 3),
    );
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid device identity.');
    }
    return BoardIdentity.fromJson(json);
  }

  Future<Uint8List> capture(String address) {
    if (address.startsWith('cloud://')) {
      return cloud.requestSnapshot();
    }
    return _request(address, '/capture', 'image/jpeg', 15 * 1024 * 1024);
  }

  Future<KitWarning?> warningConfiguration(String address, String code) async {
    if (address.startsWith('cloud://')) return null;
    final bytes = await _request(
      address,
      '/warnings',
      'application/json',
      4096,
      pairingCode: code,
      timeout: const Duration(seconds: 3),
    );
    final value = jsonDecode(utf8.decode(bytes)) as Map;
    if (value['configured'] == false && value['version'] == 1) return null;
    return KitWarning.fromJson(value);
  }

  Future<void> setWarnings(
    String address,
    String code,
    KitWarning settings,
  ) async {
    if (address.startsWith('cloud://')) return;
    final bytes = await _request(
      address,
      '/warnings',
      'application/json',
      4096,
      pairingCode: code,
      form: settings.form(),
      timeout: const Duration(seconds: 3),
    );
    final result = KitWarning.fromJson(jsonDecode(utf8.decode(bytes)) as Map);
    if (!settings.matches(result)) {
      throw const FormatException('Kit did not confirm the warning limits.');
    }
  }

  Future<AutomaticCapture?> automaticConfiguration(
    String address,
    String code,
  ) async {
    if (address.startsWith('cloud://')) return null;
    try {
      final bytes = await _request(
        address,
        '/automation',
        'application/json',
        4096,
        pairingCode: code,
      );
      return AutomaticCapture.fromJson(
        Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map),
      );
    } on HardwareHttpException catch (e) {
      if (e.status == 404) {
        return null; // Legacy firmware has no automation to stop.
      }
      rethrow;
    }
  }

  Future<String> cameraAutomationIdentity(String address, String code) async {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(code)) {
      throw const FormatException(
        'Enter the camera’s 32-character pairing code from Serial Monitor.',
      );
    }
    final bytes = await _request(
      address,
      '/automation-info',
      'application/json',
      4096,
      pairingCode: code,
    );
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map ||
        json['version'] != 1 ||
        json['device_id'] is! String ||
        !RegExp(r'^[a-f0-9]{12}$').hasMatch(json['device_id'] as String)) {
      throw const FormatException(
        'Update the camera firmware for automatic capture.',
      );
    }
    if (json['sd_ready'] != true) {
      throw const FormatException(
        'Camera SD card is not ready. Check the card and restart the camera.',
      );
    }
    return json['device_id'] as String;
  }

  Future<AutomaticCapture> setAutomatic(
    String address,
    String sensorCode,
    AutomaticCapture settings, {
    String cameraCode = '',
  }) async {
    settings.validate();
    if (settings.enabled) {
      final uri = hardwareAddress(settings.camera);
      if (uri.port != 80 || !RegExp(r'^[a-f0-9]{32}$').hasMatch(cameraCode)) {
        throw const FormatException(
          'Automatic capture requires camera port 80 and a valid camera pairing code.',
        );
      }
    }
    final bytes = await _request(
      address,
      '/automation',
      'application/json',
      4096,
      pairingCode: sensorCode,
      form: {
        ...settings.form(),
        if (settings.enabled) 'camera_key': cameraCode,
      },
    );
    final confirmed = AutomaticCapture.fromJson(
      Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map),
    );
    verifyAutomatic(settings, confirmed);
    return confirmed;
  }

  void verifyAutomatic(AutomaticCapture requested, AutomaticCapture actual) {
    final expected = requested.form(), received = actual.form();
    if (expected.entries.any((e) => received[e.key] != e.value)) {
      throw const FormatException(
        'Sensor did not confirm the requested automatic capture settings. Reload and retry.',
      );
    }
  }

  Future<SensorConfiguration> configuration(String address) async {
    if (address.startsWith('cloud://')) {
      return const SensorConfiguration(
        deviceId: 'cloud-sensor',
        crop: Crop.tomato,
      );
    }
    final bytes = await _request(address, '/config', 'application/json', 4096);
    return _configuration(bytes);
  }

  SensorConfiguration _configuration(Uint8List bytes) {
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid sensor configuration.');
    }
    return SensorConfiguration.fromJson(json);
  }

  Future<SensorConfiguration> setCrop(
    String address,
    Crop crop,
    String deviceId,
    String pairingCode,
  ) async {
    if (address.startsWith('cloud://')) {
      return SensorConfiguration(deviceId: deviceId, crop: crop);
    }
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(pairingCode)) {
      throw const FormatException(
        'Enter the 32-character pairing code from Serial Monitor.',
      );
    }
    final bytes = await _request(
      address,
      '/crop',
      'application/json',
      4096,
      form: {'crop': crop.name, 'device_id': deviceId},
      pairingCode: pairingCode,
    );
    final result = _configuration(bytes);
    if (result.deviceId != deviceId || result.crop != crop) {
      throw const FormatException(
        'Sensor did not confirm the requested crop. Retry the assignment.',
      );
    }
    return result;
  }
}
