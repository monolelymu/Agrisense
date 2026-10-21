import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';

// In-memory HTTP doubles: these tests never open sockets or contact a board.
class TestHeaders implements HttpHeaders {
  final values = <String, Object>{};
  @override
  ContentType? contentType;
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestResponse extends Stream<List<int>> implements HttpClientResponse {
  TestResponse(
    this.body, {
    this.statusCode = 200,
    String mime = 'application/json',
    this.contentLength = -1,
  }) {
    headers.contentType = ContentType.parse(mime);
  }
  final List<List<int>> body;
  @override
  final int statusCode, contentLength;
  @override
  final TestHeaders headers = TestHeaders();
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromIterable(body).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestRequest implements HttpClientRequest {
  TestRequest(this.method, this.uri, this.response, {this.hang = false});
  @override
  final String method;
  @override
  final Uri uri;
  final TestResponse response;
  final bool hang;
  final body = StringBuffer();
  @override
  final TestHeaders headers = TestHeaders();
  @override
  bool followRedirects = true;
  @override
  int contentLength = -1;
  @override
  void add(List<int> data) {
    // Fail if the length is omitted or assigned after writing the body.
    expect(contentLength, data.length);
    body.write(utf8.decode(data));
  }

  @override
  void write(Object? obj) {
    body.write(obj);
  }

  @override
  Future<HttpClientResponse> close() =>
      hang ? Completer<HttpClientResponse>().future : Future.value(response);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestClient implements HttpClient {
  TestClient(this.response, {this.hang = false});
  final TestResponse response;
  final bool hang;
  TestRequest? request;
  bool closed = false;
  @override
  Duration? connectionTimeout;
  @override
  set findProxy(String Function(Uri)? value) {
    proxy = value;
  }

  String Function(Uri)? proxy;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri uri) async =>
      request = TestRequest(method, uri, response, hang: hang);
  @override
  void close({bool force = false}) {
    closed = force;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<List<int>> configurationBody() => [
  utf8.encode(
    jsonEncode({
      'crop_protocol': 1,
      'device_id': 'aabbccddeeff',
      'crop': 'eggplant',
    }),
  ),
];

void main() {
  test(
    'crop command uses POST, form body, header authentication and no redirects/proxy',
    () async {
      final socket = TestClient(TestResponse(configurationBody()));
      final client = HardwareClient(httpClientFactory: () => socket);
      final result = await client.setCrop(
        '192.168.1.50',
        Crop.eggplant,
        'aabbccddeeff',
        '0123456789abcdef0123456789abcdef',
      );
      expect(result.crop, Crop.eggplant);
      final request = socket.request!;
      expect(request.method, 'POST');
      expect(request.uri.path, '/crop');
      expect(request.uri.query, isEmpty);
      expect(
        request.contentLength,
        utf8.encode(request.body.toString()).length,
      );
      expect(request.followRedirects, isFalse);
      expect(
        request.headers.contentType!.mimeType,
        'application/x-www-form-urlencoded',
      );
      expect(
        request.headers.values['X-AgriSense-Key'],
        '0123456789abcdef0123456789abcdef',
      );
      expect(Uri.splitQueryString(request.body.toString()), {
        'crop': 'eggplant',
        'device_id': 'aabbccddeeff',
      });
      expect(socket.proxy!(request.uri), 'DIRECT');
      expect(socket.closed, isTrue);
    },
  );
  test(
    'assignment errors include endpoint, HTTP status and safe firmware detail',
    () async {
      final socket = TestClient(
        TestResponse([
          utf8.encode(
            '{"error":"invalid_crop_request","private":"do-not-display"}',
          ),
        ], statusCode: 400),
      );
      final client = HardwareClient(httpClientFactory: () => socket);
      await expectLater(
        client.setCrop(
          '192.168.1.50',
          Crop.tomato,
          'aabbccddeeff',
          '0123456789abcdef0123456789abcdef',
        ),
        throwsA(
          isA<FormatException>()
              .having((e) => e.message, 'status', contains('/crop: HTTP 400'))
              .having(
                (e) => e.message,
                'detail',
                contains('crop and device ID'),
              )
              .having(
                (e) => e.message,
                'privacy',
                isNot(contains('do-not-display')),
              ),
        ),
      );
    },
  );
  test('unexpected response type reports the endpoint and type', () async {
    final socket = TestClient(TestResponse([], mime: 'text/html'));
    final client = HardwareClient(httpClientFactory: () => socket);
    await expectLater(
      client.configuration('192.168.1.50'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'detail',
          contains('/config: HTTP 200, but received text/html'),
        ),
      ),
    );
  });
  test(
    'redirects, authentication failures, bad MIME and oversized bodies fail closed',
    () async {
      for (final response in [
        TestResponse(configurationBody(), statusCode: 302),
        TestResponse(configurationBody(), statusCode: 401),
        TestResponse(configurationBody(), statusCode: 409),
        TestResponse(configurationBody(), mime: 'text/html'),
        TestResponse(configurationBody(), contentLength: 4097),
        TestResponse([List.filled(4097, 65)]),
        TestResponse([utf8.encode('not json')]),
      ]) {
        final socket = TestClient(response);
        final client = HardwareClient(httpClientFactory: () => socket);
        await expectLater(
          client.configuration('192.168.1.50'),
          throwsFormatException,
        );
        expect(socket.closed, isTrue);
      }
    },
  );
  test('public addresses are rejected before creating a client', () async {
    var opened = false;
    final client = HardwareClient(
      httpClientFactory: () {
        opened = true;
        return TestClient(TestResponse(configurationBody()));
      },
    );
    await expectLater(client.configuration('8.8.8.8'), throwsFormatException);
    expect(opened, isFalse);
  });
  test('a hung response times out and force-closes its client', () async {
    final socket = TestClient(TestResponse([]), hang: true);
    final client = HardwareClient(httpClientFactory: () => socket);
    await expectLater(
      client.configuration('192.168.1.50'),
      throwsA(isA<TimeoutException>()),
    );
    expect(socket.closed, isTrue);
  });
}
