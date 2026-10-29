import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:image/image.dart' as img;
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/core/camera_live_controller.dart';
import 'package:agrisense/core/app_issue.dart';
import 'package:agrisense/core/theme.dart';
import 'package:agrisense/data/board_discovery.dart';
import 'package:agrisense/data/camera_stream.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/camera_gamepad.dart';

Uint8List jpeg() =>
    Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));
List<int> part(List<int> frame) => [
  ...ascii.encode(
    '\r\n--boundary\r\nContent-Type: image/jpeg\r\nContent-Length: ${frame.length}\r\n\r\n',
  ),
  ...frame,
];

class _Connection extends CameraFrameConnection {
  _Connection() : super(Uri.parse('http://192.168.8.21:81/stream'));
  final controller = StreamController<Uint8List>();
  bool closed = false;
  @override
  Stream<Uint8List> get frames => controller.stream;
  @override
  void close() {
    closed = true;
    super.close();
    if (!controller.isClosed) unawaited(controller.close());
  }
}

class _Boards extends HardwareClient {
  bool servo = false, wrong = false, failMove = false;
  int commands = 0, photos = 0, identityCalls = 0;
  final requests = <String>[];
  final connections = <_Connection>[];
  @override
  Future<BoardIdentity> identity(String address) async {
    identityCalls++;
    final sensor = address.endsWith('.20');
    return BoardIdentity(
      kitId: demoKitId,
      deviceId: wrong && sensor
          ? 'ffffffffffff'
          : sensor
          ? 'aabbccddeeff'
          : '112233445566',
      role: sensor ? 'sensor' : 'camera',
      ready: true,
      capabilities: sensor
          ? ['readings', if (servo) 'pan_tilt_v1']
          : ['capture', 'stream'],
      sensorCrop: sensor ? Crop.tomato : null,
    );
  }

  @override
  Future<void> panTilt(
    String address, {
    required String deviceId,
    required String requestId,
    required String action,
  }) async {
    commands++;
    requests.add(requestId);
    if (failMove) throw TimeoutException('test timeout');
  }

  @override
  CameraFrameConnection cameraStream(String address) {
    final next = _Connection();
    connections.add(next);
    return next;
  }

  @override
  Future<Uint8List> capture(String address) async {
    expect(connections.every((c) => c.closed), isTrue);
    photos++;
    return jpeg();
  }
}

class _RealNetwork extends HttpOverrides {}

class _LoopbackClient implements HttpClient {
  _LoopbackClient(this.port);
  final int port;
  final HttpClient inner = _RealNetwork().createHttpClient(null);
  @override
  set connectionTimeout(Duration? value) {
    inner.connectionTimeout = value;
  }

  @override
  set findProxy(String Function(Uri)? value) {
    inner.findProxy = value;
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => inner.openUrl(
    method,
    Uri.parse('http://127.0.0.1:$port').replace(path: url.path),
  );
  @override
  void close({bool force = false}) => inner.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> waitFor(bool Function() condition) async {
  final until = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(until)) {
      throw TimeoutException('Condition not reached');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'multipart parser handles fragmented headers/images and multiple frames',
    () {
      final parser = MjpegParser(), frame = jpeg();
      final data = [...part(frame), ...part(frame)];
      final result = <Uint8List>[];
      for (var i = 0; i < data.length; i += 7) {
        result.addAll(
          parser.add(data.sublist(i, (i + 7).clamp(0, data.length))),
        );
      }
      expect(result, hasLength(2));
      expect(result[0], frame);
      expect(result[1], frame);
    },
  );
  test('multipart parser rejects unbounded or incompatible parts', () {
    expect(
      () => MjpegParser().add(List.filled(8193, 65)),
      throwsFormatException,
    );
    expect(
      () => MjpegParser().add(
        ascii.encode(
          '--b\r\nContent-Type: text/html\r\nContent-Length: 20\r\n\r\n',
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => MjpegParser().add(
        ascii.encode(
          '--b\r\nContent-Type: image/jpeg\r\nContent-Length: 9999999\r\n\r\n',
        ),
      ),
      throwsFormatException,
    );
    expect(() => MjpegParser().add(part([0, 1, 2, 3])), throwsFormatException);
  });
  test(
    'stream URL uses camera port plus one, disallows external addresses',
    () {
      final client = HardwareClient();
      final connection = client.cameraStream('http://192.168.8.21:8080');
      expect(connection.uri.toString(), 'http://192.168.8.21:8081/stream');
      connection.close();
      expect(
        () => client.cameraStream('http://8.8.8.8'),
        throwsFormatException,
      );
    },
  );
  test(
    'real HTTP multipart stream delivers a frame and releases on close',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final frame = jpeg();
      server.listen((request) async {
        request.response.bufferOutput = false;
        request.response.headers.chunkedTransferEncoding = true;
        request.response.done.ignore();
        request.response.headers.contentType = ContentType(
          'multipart',
          'x-mixed-replace',
          parameters: {'boundary': 'boundary'},
        );
        request.response.add(part(frame));
        try {
          await request.response.flush();
        } catch (_) {}
      });
      final connection = CameraFrameConnection(
        Uri.parse('http://127.0.0.1:${server.port}/stream'),
        factory: () => _RealNetwork().createHttpClient(null),
      );
      final received = Completer<Uint8List>(), ended = Completer<void>();
      final subscription = connection.frames.listen(
        (bytes) {
          if (!received.isCompleted) received.complete(bytes);
        },
        onError: (Object error, StackTrace stack) {
          if (!received.isCompleted) received.completeError(error, stack);
          if (!ended.isCompleted) ended.complete();
        },
        onDone: () {
          if (!ended.isCompleted) ended.complete();
        },
      );
      try {
        expect(
          await received.future.timeout(const Duration(seconds: 5)),
          frame,
        );
        connection.close();
        await ended.future.timeout(const Duration(seconds: 5));
      } finally {
        connection.close();
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
  test(
    'movement HTTP uses form POST and rejects mismatched acknowledgements',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final bodies = <Map<String, String>>[];
      var wrong = false;
      server.listen((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/pan-tilt');
        expect(
          request.headers.contentType?.mimeType,
          'application/x-www-form-urlencoded',
        );
        final body = Uri.splitQueryString(
          await utf8.decoder.bind(request).join(),
        );
        bodies.add(body);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'version': 1,
            'device_id': body['device_id'],
            'request_id': wrong ? 'other-request' : body['request_id'],
            'ready': true,
            'pan': 90,
            'tilt': 90,
          }),
        );
        await request.response.close();
      });
      final client = HardwareClient(
        httpClientFactory: () => _LoopbackClient(server.port),
      );
      try {
        await client.panTilt(
          'http://192.168.8.20',
          deviceId: 'aabbccddeeff',
          requestId: 'session-1',
          action: 'up',
        );
        expect(bodies.single, {
          'version': '1',
          'device_id': 'aabbccddeeff',
          'request_id': 'session-1',
          'action': 'up',
        });
        wrong = true;
        await expectLater(
          client.panTilt(
            'http://192.168.8.20',
            deviceId: 'aabbccddeeff',
            requestId: 'session-2',
            action: 'left',
          ),
          throwsFormatException,
        );
      } finally {
        await server.close(force: true);
      }
    },
  );
  test(
    'live view releases socket on capture, background, tab exit and access opt-out',
    () async {
      final connections = <_Connection>[];
      final live = CameraLiveController(
        open: (_) {
          final c = _Connection();
          connections.add(c);
          return c;
        },
      );
      void configure({
        bool visible = true,
        bool foreground = true,
        bool allowed = true,
      }) => live.configure(
        address: 'http://192.168.8.21',
        visible: visible,
        foreground: foreground,
        allowed: allowed,
      );
      configure();
      await waitFor(() => connections.length == 1);
      connections.last.controller.add(jpeg());
      await waitFor(() => live.status == 'Live');
      expect(live.fresh, isTrue);
      await live.withPaused(() async {
        expect(connections.last.closed, isTrue);
        expect(live.status, contains('paused'));
      });
      await waitFor(() => connections.length == 2);
      configure(foreground: false);
      expect(connections.last.closed, isTrue);
      configure();
      await waitFor(() => connections.length == 3);
      configure(visible: false);
      expect(connections.last.closed, isTrue);
      configure();
      await waitFor(() => connections.length == 4);
      configure(allowed: false);
      expect(connections.last.closed, isTrue);
      live.dispose();
    },
  );
  test('late opening cannot revive a live stream after tab exit', () async {
    final opening = Completer<CameraFrameConnection>(),
        connection = _Connection();
    final live = CameraLiveController(open: (_) => opening.future);
    live.configure(
      address: 'http://192.168.8.21',
      visible: true,
      foreground: true,
      allowed: true,
    );
    live.configure(
      address: 'http://192.168.8.21',
      visible: false,
      foreground: true,
      allowed: true,
    );
    opening.complete(connection);
    await waitFor(() => connection.closed);
    expect(live.status, 'Live view off');
    live.dispose();
  });
  test('stream loss retries without duplicating still captures', () async {
    final connections = <_Connection>[];
    final live = CameraLiveController(
      open: (_) {
        final c = _Connection();
        connections.add(c);
        return c;
      },
    );
    live.configure(
      address: 'http://192.168.8.21',
      visible: true,
      foreground: true,
      allowed: true,
    );
    await waitFor(() => connections.isNotEmpty);
    connections.last.controller.addError(
      const SocketException('stream offline'),
    );
    await waitFor(() => live.status.startsWith('Reconnecting'));
    live.retry();
    await waitFor(() => connections.length == 2);
    connections.last.controller.add(jpeg());
    await waitFor(() => live.status == 'Live');
    live.dispose();
  });

  group('verified kit controls', () {
    late Directory directory;
    late Box<dynamic> box;
    late HardwareController h;
    late _Boards boards;
    setUp(() async {
      directory = await Directory('test').createTemp('camera-controls-');
      Hive.init(directory.path);
      box = await Hive.openBox<dynamic>('controls');
      boards = _Boards();
      h = HardwareController(box, client: boards)..load();
      h.assignments[Crop.tomato] = {
        'sensor': 'http://192.168.8.20',
        'camera': 'http://192.168.8.21',
      };
      await h.connectKit(Crop.tomato);
    });
    tearDown(() async {
      h.dispose();
      await box.close();
      await directory.delete(recursive: true);
    });
    test('old sensor firmware cannot receive movement commands', () async {
      expect(h.canStream, isTrue);
      expect(h.canMoveCamera, isFalse);
      await expectLater(
        h.moveCameraDirection(Crop.tomato, 'up'),
        throwsA(AppIssue.unsupported),
      );
      expect(boards.commands, 0);
    });
    test(
      'movement reuses verified identity and rechecks after failure without auto-repeat',
      () async {
        boards.servo = true;
        await h.connectKit(Crop.tomato);
        final connectedIdentityCalls = boards.identityCalls;
        for (final action in ['up', 'down', 'left', 'right', 'center']) {
          await h.moveCameraDirection(Crop.tomato, action);
        }
        expect(boards.commands, 5);
        expect(boards.identityCalls, connectedIdentityCalls);
        expect(boards.requests.toSet(), hasLength(5));
        boards.failMove = true;
        await expectLater(
          h.moveCameraDirection(Crop.tomato, 'left'),
          throwsA(isA<TimeoutException>()),
        );
        expect(boards.commands, 6);
        expect(h.movementStatus, contains('not confirmed'));
        boards.wrong = true;
        await expectLater(
          h.moveCameraDirection(Crop.tomato, 'right'),
          throwsA(AppIssue.identity),
        );
        expect(boards.commands, 6);
        expect(boards.identityCalls, connectedIdentityCalls + 1);
      },
    );
    test(
      'still capture pauses a live connection and resumes only while visible',
      () async {
        final owner = Object();
        h.cameraView(owner, true);
        await waitFor(() => boards.connections.isNotEmpty);
        boards.connections.last.controller.add(jpeg());
        await waitFor(() => h.live.status == 'Live');
        await h.capture(Crop.tomato);
        expect(boards.photos, 1);
        await waitFor(() => boards.connections.length == 2);
        h.cameraView(owner, false);
        expect(boards.connections.last.closed, isTrue);
      },
    );
    testWidgets('holding repeats, releasing stops, and Center stays one tap', (
      tester,
    ) async {
      boards.servo = true;
      await tester.runAsync(() => h.connectKit(Crop.tomato));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraGamepad(hardware: h, crop: Crop.tomato),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byTooltip('Move camera left')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(boards.commands, inInclusiveRange(2, 3));
      final held = boards.commands;
      expect(h.cameraControlActive, isTrue);
      expect(find.text('Moving camera…'), findsOneWidget);
      expect(find.text('Camera movement confirmed.'), findsNothing);
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pump();
      expect(boards.commands, greaterThan(held));
      await gesture.up();
      await tester.pump();
      final released = boards.commands;
      expect(h.cameraControlActive, isFalse);
      expect(find.text('Camera movement confirmed.'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(boards.commands, released);
      await tester.tap(find.byTooltip('Center camera'));
      await tester.pump();
      expect(boards.commands, released + 1);
      await tester.pump(const Duration(seconds: 1));
      expect(boards.commands, released + 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('a failed hold command is never repeated', (tester) async {
      boards.servo = true;
      boards.failMove = true;
      await tester.runAsync(() => h.connectKit(Crop.tomato));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraGamepad(hardware: h, crop: Crop.tomato),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byTooltip('Move camera up')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(boards.commands, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(boards.commands, 1);
      await gesture.up();
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets(
      'backgrounding cancels holding and does not restart on resume',
      (tester) async {
        boards.servo = true;
        await tester.runAsync(() => h.connectKit(Crop.tomato));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CameraGamepad(hardware: h, crop: Crop.tomato),
            ),
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byTooltip('Move camera down')),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        final beforeBackground = boards.commands;
        expect(beforeBackground, inInclusiveRange(2, 3));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(boards.commands, beforeBackground);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(boards.commands, beforeBackground);
        await gesture.up();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'all five controls are visible, disabled on old firmware, and fit a narrow phone',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
                child: Center(
                  child: CameraGamepad(hardware: h, crop: Crop.tomato),
                ),
              ),
            ),
          ),
        );
        for (final label in [
          'Move camera up',
          'Move camera down',
          'Move camera left',
          'Move camera right',
          'Center camera',
        ]) {
          final button = find.byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == label,
          );
          expect(button, findsOneWidget);
          expect(tester.widget<IconButton>(button).onPressed, isNull);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}
