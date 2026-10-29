import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:hive_ce/hive.dart';
import '../core/firebase_config.dart';
import 'board_discovery.dart';
import 'hardware_client.dart';
import 'models.dart';

class FirebaseCloudClient {
  FirebaseCloudClient({
    String? databaseUrl,
    String? apiKey,
    HttpClient Function()? httpClientFactory,
    this.box,
    DateTime Function()? clock,
  })  : databaseUrl = (databaseUrl ?? FirebaseConfig.databaseUrl)
            .replaceAll(RegExp(r'/+$'), ''),
        apiKey = apiKey ?? FirebaseConfig.apiKey,
        _httpClientFactory = httpClientFactory ?? HttpClient.new,
        _clock = clock ?? DateTime.now;

  final String databaseUrl;
  final String apiKey;
  final HttpClient Function() _httpClientFactory;
  final Box<dynamic>? box;
  final DateTime Function() _clock;

  String? _idToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  String? _uid;
  String? lastVerifiedCameraId;

  String? _lastObservedSampleId;
  DateTime? _lastSampleIdChange;

  String? get uid => _uid;

  Future<String> ensureAuthenticated({bool forceRefresh = false}) async {
    final now = _clock();
    if (!forceRefresh &&
        _idToken != null &&
        _tokenExpiry != null &&
        _tokenExpiry!.isAfter(now.add(const Duration(minutes: 5)))) {
      return _idToken!;
    }

    if (!forceRefresh && box != null && _idToken == null) {
      final cached = box!.get('firebase-anon-auth-v1');
      if (cached is Map) {
        final exp = DateTime.tryParse(cached['expires_at'] as String? ?? '');
        if (exp != null && exp.isAfter(now.add(const Duration(minutes: 5)))) {
          _idToken = cached['id_token'] as String?;
          _refreshToken = cached['refresh_token'] as String?;
          _uid = cached['uid'] as String?;
          _tokenExpiry = exp;
          if (_idToken != null) return _idToken!;
        } else if (cached['refresh_token'] is String) {
          _refreshToken = cached['refresh_token'] as String;
        }
      }
    }

    if (_refreshToken != null && _refreshToken!.isNotEmpty) {
      try {
        final refreshed = await _refreshIdToken(_refreshToken!);
        return refreshed;
      } catch (_) {
        // Fall back to new anonymous sign up if token refresh fails.
      }
    }

    return await _signInAnonymously();
  }

  Future<String> _signInAnonymously() async {
    final uri = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey');
    final response = await _httpPost(uri, {'returnSecureToken': true});
    final idToken = response['idToken'] as String?;
    final refreshToken = response['refreshToken'] as String?;
    final localId = response['localId'] as String?;
    final expiresInStr = response['expiresIn'] as String? ?? '3600';
    final expiresInSec = int.tryParse(expiresInStr) ?? 3600;

    if (idToken == null || idToken.isEmpty) {
      throw const FormatException('Firebase Anonymous Auth failed to return token.');
    }

    _idToken = idToken;
    _refreshToken = refreshToken;
    _uid = localId;
    _tokenExpiry = _clock().add(Duration(seconds: expiresInSec));

    if (box != null) {
      await box!.put('firebase-anon-auth-v1', {
        'id_token': _idToken,
        'refresh_token': _refreshToken,
        'uid': _uid,
        'expires_at': _tokenExpiry!.toIso8601String(),
      });
    }

    return _idToken!;
  }

  Future<String> _refreshIdToken(String refreshToken) async {
    final uri =
        Uri.parse('https://securetoken.googleapis.com/v1/token?key=$apiKey');
    final response = await _httpFormPost(
      uri,
      {'grant_type': 'refresh_token', 'refresh_token': refreshToken},
    );
    final idToken = response['id_token'] as String?;
    final newRefresh = response['refresh_token'] as String? ?? refreshToken;
    final expiresInStr = response['expires_in'] as String? ?? '3600';
    final expiresInSec = int.tryParse(expiresInStr) ?? 3600;

    if (idToken == null || idToken.isEmpty) {
      throw const FormatException('Firebase token refresh failed.');
    }

    _idToken = idToken;
    _refreshToken = newRefresh;
    _uid = response['user_id'] as String? ?? _uid;
    _tokenExpiry = _clock().add(Duration(seconds: expiresInSec));

    if (box != null) {
      await box!.put('firebase-anon-auth-v1', {
        'id_token': _idToken,
        'refresh_token': _refreshToken,
        'uid': _uid,
        'expires_at': _tokenExpiry!.toIso8601String(),
      });
    }

    return _idToken!;
  }

  Future<Map<String, dynamic>> _httpPost(
    Uri uri,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 5)
      ..findProxy = (_) => 'DIRECT';
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers.contentType =
          ContentType('application', 'json', charset: 'utf-8');
      final encoded = utf8.encode(jsonEncode(body));
      request.contentLength = encoded.length;
      request.add(encoded);
      final response = await request.close().timeout(timeout);
      final bodyText = await utf8.decodeStream(response).timeout(timeout);
      if (response.statusCode >= 400) {
        throw HardwareHttpException(
          response.statusCode,
          'Firebase Auth request failed (${response.statusCode}): $bodyText',
        );
      }
      final parsed = jsonDecode(bodyText);
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('Invalid auth response format.');
      }
      return parsed;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _httpFormPost(
    Uri uri,
    Map<String, String> body, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 5)
      ..findProxy = (_) => 'DIRECT';
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      final formString = body.entries
          .map((e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');
      final encoded = utf8.encode(formString);
      request.contentLength = encoded.length;
      request.add(encoded);
      final response = await request.close().timeout(timeout);
      final bodyText = await utf8.decodeStream(response).timeout(timeout);
      if (response.statusCode >= 400) {
        throw HardwareHttpException(
          response.statusCode,
          'Firebase Auth form request failed (${response.statusCode}): $bodyText',
        );
      }
      final parsed = jsonDecode(bodyText);
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('Invalid auth response format.');
      }
      return parsed;
    } finally {
      client.close(force: true);
    }
  }

  Future<dynamic> _rtdbRequest(
    String method,
    String path, {
    dynamic body,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final token = await ensureAuthenticated();
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$databaseUrl$cleanPath?auth=$token');
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 5)
      ..findProxy = (_) => 'DIRECT';
    try {
      final request = await client.openUrl(method, uri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        request.headers.contentType =
            ContentType('application', 'json', charset: 'utf-8');
        final encoded = utf8.encode(jsonEncode(body));
        request.contentLength = encoded.length;
        request.add(encoded);
      }
      final response = await request.close().timeout(timeout);
      final bodyText = await utf8.decodeStream(response).timeout(timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        _idToken = null;
        throw HardwareHttpException(
          response.statusCode,
          'Firebase permission denied or token expired.',
        );
      }
      if (response.statusCode >= 400) {
        throw HardwareHttpException(
          response.statusCode,
          'Firebase RTDB error (${response.statusCode}): $bodyText',
        );
      }
      if (bodyText.trim().isEmpty || bodyText.trim() == 'null') {
        return null;
      }
      return jsonDecode(bodyText);
    } finally {
      client.close(force: true);
    }
  }

  Future<BoardIdentity?> readIdentity(String role) async {
    final res = await _rtdbRequest('GET', '/kits/demo/$role/identity.json');
    if (res is! Map) return null;
    final map = Map<String, dynamic>.from(res);
    if (map['capabilities'] is String) {
      try {
        map['capabilities'] = jsonDecode(map['capabilities'] as String);
      } catch (_) {}
    }
    try {
      final id = BoardIdentity.fromJson(map);
      if (role == 'camera') {
        lastVerifiedCameraId = id.deviceId;
      }
      return id;
    } catch (_) {
      return null;
    }
  }

  Future<HardwareSample> readSample(Crop crop) async {
    dynamic res;
    try {
      res = await _rtdbRequest('GET', '/kits/demo/sensor.json');
    } catch (_) {
      // Fallback if sensor.json is unavailable
    }
    if (res == null ||
        (res is Map &&
            !res.containsKey('readings') &&
            !res.containsKey('crop') &&
            !res.containsKey('temp_c'))) {
      res = await _rtdbRequest('GET', '/kits/demo/sensor/readings.json');
    }

    if (res is! Map) {
      throw const FormatException(
          'Sensor has no fresh sample in the cloud. Try again.');
    }

    final rawMap = Map<String, dynamic>.from(res);
    final Map<String, dynamic> readings;
    if (rawMap.containsKey('readings') && rawMap['readings'] is Map) {
      readings = Map<String, dynamic>.from(rawMap['readings'] as Map);
      final uploadedAt = rawMap['uploaded_at_ms'] as num?;
      if (uploadedAt != null) {
        final age = _clock().millisecondsSinceEpoch - uploadedAt.toInt();
        if (age > 45000) {
          throw const FormatException(
              'Cloud sensor readings are stale (> 45s old).');
        }
      }
    } else {
      readings = rawMap;
      final uploadedAt = rawMap['uploaded_at_ms'] as num?;
      if (uploadedAt != null) {
        final age = _clock().millisecondsSinceEpoch - uploadedAt.toInt();
        if (age > 45000) {
          throw const FormatException(
              'Cloud sensor readings are stale (> 45s old).');
        }
      }
    }

    final sampleId = readings['sample_id'] as String? ?? '';
    if (sampleId.isNotEmpty) {
      if (_lastObservedSampleId == sampleId) {
        if (_lastSampleIdChange != null &&
            _clock().difference(_lastSampleIdChange!) >
                const Duration(seconds: 30)) {
          throw const FormatException(
            'Cloud sensor readings have stopped updating (> 30s unchanged).',
          );
        }
      } else {
        _lastObservedSampleId = sampleId;
        _lastSampleIdChange = _clock();
      }
    }

    return HardwareSample.fromDevice(readings, crop, now: _clock());
  }

  Future<void> sendPanTilt({
    required String deviceId,
    required String requestId,
    required String action,
  }) async {
    final command = {
      'version': 1,
      'device_id': deviceId,
      'request_id': requestId,
      'action': action,
      'timestamp': _clock().millisecondsSinceEpoch,
    };
    await _rtdbRequest('PUT', '/kits/demo/control/command.json', body: command);

    final deadline = _clock().add(const Duration(seconds: 6));
    while (_clock().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final receipt =
          await _rtdbRequest('GET', '/kits/demo/control/receipt.json');
      if (receipt is Map &&
          receipt['request_id'] == requestId &&
          receipt['device_id'] == deviceId) {
        if (receipt['ready'] == true) return;
        if (receipt['error'] is String) {
          throw FormatException('Movement rejected: ${receipt['error']}');
        }
        return;
      }
    }
    throw const FormatException('Camera movement timed out over cloud.');
  }

  Future<Uint8List> requestSnapshot({String? expectedCameraId}) async {
    final targetId = (expectedCameraId != null && expectedCameraId.isNotEmpty)
        ? expectedCameraId
        : (lastVerifiedCameraId ?? '');
    final requestId = _clock().microsecondsSinceEpoch.toRadixString(16);
    final request = {
      'version': 1,
      'device_id': targetId,
      'request_id': requestId,
      'timestamp': _clock().millisecondsSinceEpoch,
    };
    await _rtdbRequest('PUT', '/kits/demo/camera/request.json', body: request);

    final deadline = _clock().add(const Duration(seconds: 14));
    while (_clock().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final snapshot =
          await _rtdbRequest('GET', '/kits/demo/camera/snapshot.json');
      if (snapshot is Map &&
          snapshot['request_id'] == requestId &&
          (targetId.isEmpty || snapshot['device_id'] == targetId) &&
          snapshot['jpeg_b64'] is String) {
        final b64 = snapshot['jpeg_b64'] as String;
        return Uint8List.fromList(base64Decode(b64));
      }
    }
    throw const FormatException('Camera snapshot timed out over cloud.');
  }
}
