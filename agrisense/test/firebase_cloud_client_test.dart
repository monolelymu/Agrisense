import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:agrisense/data/firebase_cloud_client.dart';
import 'package:agrisense/data/models.dart';

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {};
  ContentType? _contentType;

  @override
  ContentType? get contentType => _contentType;

  @override
  set contentType(ContentType? type) => _contentType = type;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name.toLowerCase()] = [value.toString()];
  }

  @override
  List<String>? operator [](String name) => _headers[name.toLowerCase()];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(this.statusCode, this.body);

  @override
  final int statusCode;
  final String body;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(utf8.encode(body)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.method, this.uri, this.handler);

  @override
  final String method;
  @override
  final Uri uri;
  final Future<HttpClientResponse> Function(_FakeHttpClientRequest) handler;

  final List<List<int>> _body = [];
  final HttpHeaders _headers = _FakeHttpHeaders();

  @override
  HttpHeaders get headers => _headers;

  @override
  int contentLength = 0;

  @override
  void add(List<int> data) {
    _body.add(data);
  }

  String get bodyString =>
      utf8.decode(_body.expand((element) => element).toList());

  @override
  Future<HttpClientResponse> close() => handler(this);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClient implements HttpClient {
  _MockHttpClient(this.handler);

  final Future<HttpClientResponse> Function(_FakeHttpClientRequest) handler;

  @override
  Duration? connectionTimeout;

  @override
  set findProxy(String Function(Uri url)? f) {}

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _FakeHttpClientRequest(method, url, handler);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return _FakeHttpClientRequest('POST', url, handler);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBox implements Box<dynamic> {
  final Map<dynamic, dynamic> _storage = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _storage.containsKey(key) ? _storage[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _storage[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('FirebaseCloudClient signs in anonymously and reads sensor sample', () async {
    final client = FirebaseCloudClient(
      databaseUrl: 'https://test-project-default-rtdb.firebaseio.com',
      apiKey: 'test-api-key',
      httpClientFactory: () => _MockHttpClient((req) async {
        if (req.uri.host == 'identitytoolkit.googleapis.com') {
          return _FakeHttpClientResponse(
            200,
            jsonEncode({
              'idToken': 'fake-id-token',
              'refreshToken': 'fake-refresh-token',
              'localId': 'fake-uid-123',
              'expiresIn': '3600',
            }),
          );
        }
        if (req.uri.path.contains('/kits/demo/sensor/readings.json') ||
            req.uri.path.contains('/kits/demo/sensor.json')) {
          expect(req.uri.queryParameters['auth'], 'fake-id-token');
          return _FakeHttpClientResponse(
            200,
            jsonEncode({
              'readings': {
                'version': 1,
                'device_id': '001122334455',
                'crop': 'tomato',
                'sample_id': 'sample-abc-1',
                'age_ms': 500,
                'temp_c': 26.5,
                'humidity_pct': 65.0,
                'soil_raw': 2100,
                'soil_pct': 45.0,
                'soil_calibrated': true,
                'gas_raw': 750,
              },
              'uploaded_at_ms': DateTime.now().millisecondsSinceEpoch - 2000,
            }),
          );
        }
        return _FakeHttpClientResponse(404, 'Not found');
      }),
    );

    final token = await client.ensureAuthenticated();
    expect(token, 'fake-id-token');
    expect(client.uid, 'fake-uid-123');

    final sample = await client.readSample(Crop.tomato);
    expect(sample.deviceId, '001122334455');
    expect(sample.crop, Crop.tomato);
    expect(sample.temperature, 26.5);
    expect(sample.humidity, 65.0);
    expect(sample.soil, 45.0);
  });

  test('FirebaseCloudClient caches auth in Hive box and reuses on new instance', () async {
    final box = _FakeBox();
    var authCalls = 0;

    HttpClient makeClient(Future<HttpClientResponse> Function(_FakeHttpClientRequest) handler) =>
        _MockHttpClient(handler);

    final client1 = FirebaseCloudClient(
      databaseUrl: 'https://test-project-default-rtdb.firebaseio.com',
      apiKey: 'test-api-key',
      box: box,
      httpClientFactory: () => makeClient((req) async {
        if (req.uri.host == 'identitytoolkit.googleapis.com') {
          authCalls++;
          return _FakeHttpClientResponse(
            200,
            jsonEncode({
              'idToken': 'cached-id-token',
              'refreshToken': 'cached-refresh-token',
              'localId': 'user-123',
              'expiresIn': '3600',
            }),
          );
        }
        return _FakeHttpClientResponse(404, 'Not found');
      }),
    );

    final token1 = await client1.ensureAuthenticated();
    expect(token1, 'cached-id-token');
    expect(authCalls, 1);
    expect(box.get('firebase-anon-auth-v1'), isNotNull);

    // Second client instance with same box reuses cached token without HTTP call
    final client2 = FirebaseCloudClient(
      databaseUrl: 'https://test-project-default-rtdb.firebaseio.com',
      apiKey: 'test-api-key',
      box: box,
      httpClientFactory: () => makeClient((req) async {
        if (req.uri.host == 'identitytoolkit.googleapis.com') {
          authCalls++;
          return _FakeHttpClientResponse(200, '{}');
        }
        return _FakeHttpClientResponse(404, 'Not found');
      }),
    );

    final token2 = await client2.ensureAuthenticated();
    expect(token2, 'cached-id-token');
    expect(authCalls, 1); // No new network call
  });

  test('FirebaseCloudClient refreshes token with form-encoding', () async {
    final box = _FakeBox();
    box.put('firebase-anon-auth-v1', {
      'id_token': 'expired-token',
      'refresh_token': 'my-refresh-token',
      'uid': 'user-123',
      'expires_at': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
    });

    var refreshCalled = false;
    final client = FirebaseCloudClient(
      databaseUrl: 'https://test-project-default-rtdb.firebaseio.com',
      apiKey: 'test-api-key',
      box: box,
      httpClientFactory: () => _MockHttpClient((req) async {
        if (req.uri.host == 'securetoken.googleapis.com') {
          refreshCalled = true;
          expect(req.headers.contentType?.mimeType, 'application/x-www-form-urlencoded');
          expect(req.bodyString, contains('grant_type=refresh_token'));
          expect(req.bodyString, contains('refresh_token=my-refresh-token'));
          return _FakeHttpClientResponse(
            200,
            jsonEncode({
              'id_token': 'new-fresh-id-token',
              'refresh_token': 'next-refresh-token',
              'user_id': 'user-123',
              'expires_in': '3600',
            }),
          );
        }
        return _FakeHttpClientResponse(404, 'Not found');
      }),
    );

    final refreshed = await client.ensureAuthenticated();
    expect(refreshCalled, isTrue);
    expect(refreshed, 'new-fresh-id-token');
  });

  test('FirebaseCloudClient rejects stale readings (> 45s old)', () async {
    var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
    final client = FirebaseCloudClient(
      databaseUrl: 'https://test-project-default-rtdb.firebaseio.com',
      apiKey: 'test-api-key',
      clock: () => currentTime,
      httpClientFactory: () => _MockHttpClient((req) async {
        if (req.uri.host == 'identitytoolkit.googleapis.com') {
          return _FakeHttpClientResponse(
            200,
            jsonEncode({
              'idToken': 'fake-token',
              'refreshToken': 'fake-refresh',
              'localId': 'user-123',
              'expiresIn': '3600',
            }),
          );
        }
        if (req.uri.path.contains('/kits/demo/sensor.json')) {
          return _FakeHttpClientResponse(
            200,
            jsonEncode({
              'readings': {
                'version': 1,
                'device_id': '001122334455',
                'crop': 'tomato',
                'sample_id': 'sample-1',
                'temp_c': 25.0,
                'humidity_pct': 60.0,
                'soil_raw': 2000,
                'gas_raw': 500,
                'soil_calibrated': false,
              },
              // 50 seconds old
              'uploaded_at_ms': currentTime.millisecondsSinceEpoch - 50000,
            }),
          );
        }
        return _FakeHttpClientResponse(404, 'Not found');
      }),
    );

    await expectLater(
      client.readSample(Crop.tomato),
      throwsA(isA<FormatException>().having(
        (e) => e.message,
        'message',
        contains('Cloud sensor readings are stale (> 45s old).'),
      )),
    );
  });

  test('FirebaseCloudClient rejects reading if sample_id unchanged for > 30s', () async {
    var currentTime = DateTime(2026, 1, 1, 12, 0, 0);
    final client = FirebaseCloudClient(
      databaseUrl: 'https://test-project-default-rtdb.firebaseio.com',
      apiKey: 'test-api-key',
      clock: () => currentTime,
      httpClientFactory: () => _MockHttpClient((req) async {
        if (req.uri.host == 'identitytoolkit.googleapis.com') {
          return _FakeHttpClientResponse(
            200,
            jsonEncode({
              'idToken': 'fake-token',
              'refreshToken': 'fake-refresh',
              'localId': 'user-123',
              'expiresIn': '3600',
            }),
          );
        }
        if (req.uri.path.contains('/kits/demo/sensor.json')) {
          return _FakeHttpClientResponse(
            200,
            jsonEncode({
              'readings': {
                'version': 1,
                'device_id': '001122334455',
                'crop': 'tomato',
                'sample_id': 'stuck-sample-id',
                'age_ms': 500,
                'temp_c': 25.0,
                'humidity_pct': 60.0,
                'soil_raw': 2000,
                'gas_raw': 500,
                'soil_calibrated': false,
              },
              'uploaded_at_ms': currentTime.millisecondsSinceEpoch - 1000,
            }),
          );
        }
        return _FakeHttpClientResponse(404, 'Not found');
      }),
    );

    // Initial read succeeds
    final sample1 = await client.readSample(Crop.tomato);
    expect(sample1.id, 'stuck-sample-id');

    // Advance clock by 35 seconds without sample_id changing
    currentTime = currentTime.add(const Duration(seconds: 35));

    await expectLater(
      client.readSample(Crop.tomato),
      throwsA(isA<FormatException>().having(
        (e) => e.message,
        'message',
        contains('stopped updating (> 30s unchanged)'),
      )),
    );
  });

  test('FirebaseCloudClient reads board identity and stores lastVerifiedCameraId', () async {
    final client = FirebaseCloudClient(
      databaseUrl: 'https://test-project-default-rtdb.firebaseio.com',
      apiKey: 'test-api-key',
      httpClientFactory: () => _MockHttpClient((req) async {
        if (req.uri.host == 'identitytoolkit.googleapis.com') {
          return _FakeHttpClientResponse(
            200,
            jsonEncode({
              'idToken': 'fake-id-token',
              'refreshToken': 'fake-refresh-token',
              'localId': 'fake-uid-123',
              'expiresIn': '3600',
            }),
          );
        }
        if (req.uri.path.contains('/kits/demo/camera/identity.json')) {
          return _FakeHttpClientResponse(
            200,
            jsonEncode({
              'version': 1,
              'kit_id': 'agrisense-demo-kit',
              'device_id': '001122334455',
              'role': 'camera',
              'ready': true,
              'capabilities': '["capture","stream"]',
            }),
          );
        }
        return _FakeHttpClientResponse(404, 'Not found');
      }),
    );

    final id = await client.readIdentity('camera');
    expect(id, isNotNull);
    expect(id!.deviceId, '001122334455');
    expect(client.lastVerifiedCameraId, '001122334455');
  });

  test('FirebaseCloudClient sends pan/tilt command and receives receipt', () async {
    var receiptSent = false;
    final client = FirebaseCloudClient(
      databaseUrl: 'https://test-project-default-rtdb.firebaseio.com',
      apiKey: 'test-api-key',
      httpClientFactory: () => _MockHttpClient((req) async {
        if (req.uri.host == 'identitytoolkit.googleapis.com') {
          return _FakeHttpClientResponse(
            200,
            jsonEncode({
              'idToken': 'fake-id-token',
              'refreshToken': 'fake-refresh-token',
              'localId': 'fake-uid-123',
              'expiresIn': '3600',
            }),
          );
        }
        if (req.method == 'PUT' && req.uri.path.contains('/kits/demo/control/command.json')) {
          final body = jsonDecode(req.bodyString) as Map;
          expect(body['action'], 'left');
          expect(body['device_id'], '001122334455');
          receiptSent = true;
          return _FakeHttpClientResponse(200, '{"status":"ok"}');
        }
        if (req.method == 'GET' && req.uri.path.contains('/kits/demo/control/receipt.json')) {
          if (receiptSent) {
            return _FakeHttpClientResponse(
              200,
              jsonEncode({
                'version': 1,
                'device_id': '001122334455',
                'request_id': 'req-123',
                'ready': true,
                'pan': 80,
                'tilt': 90,
              }),
            );
          }
          return _FakeHttpClientResponse(200, 'null');
        }
        return _FakeHttpClientResponse(404, 'Not found');
      }),
    );

    await client.sendPanTilt(
      deviceId: '001122334455',
      requestId: 'req-123',
      action: 'left',
    );
    expect(receiptSent, isTrue);
  });

  test('FirebaseCloudClient requests snapshot and decodes base64', () async {
    final rawJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46]);
    final b64 = base64Encode(rawJpeg);
    var requestSeen = false;
    String? capturedReqId;

    final client = FirebaseCloudClient(
      databaseUrl: 'https://test-project-default-rtdb.firebaseio.com',
      apiKey: 'test-api-key',
      httpClientFactory: () => _MockHttpClient((req) async {
        if (req.uri.host == 'identitytoolkit.googleapis.com') {
          return _FakeHttpClientResponse(
            200,
            jsonEncode({
              'idToken': 'fake-id-token',
              'refreshToken': 'fake-refresh-token',
              'localId': 'fake-uid-123',
              'expiresIn': '3600',
            }),
          );
        }
        if (req.method == 'PUT' && req.uri.path.contains('/kits/demo/camera/request.json')) {
          requestSeen = true;
          final body = jsonDecode(req.bodyString) as Map;
          capturedReqId = body['request_id'] as String?;
          expect(body['device_id'], 'cam-123');
          return _FakeHttpClientResponse(200, '{"status":"ok"}');
        }
        if (req.method == 'GET' && req.uri.path.contains('/kits/demo/camera/snapshot.json')) {
          if (requestSeen && capturedReqId != null) {
            return _FakeHttpClientResponse(
              200,
              jsonEncode({
                'version': 1,
                'device_id': 'cam-123',
                'request_id': capturedReqId,
                'jpeg_b64': b64,
              }),
            );
          }
          return _FakeHttpClientResponse(200, 'null');
        }
        return _FakeHttpClientResponse(404, 'Not found');
      }),
    );

    final result = await client.requestSnapshot(expectedCameraId: 'cam-123');
    expect(result, rawJpeg);
  });
}
