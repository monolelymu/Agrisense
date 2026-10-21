import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/data/automatic_capture.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/monitoring/automatic_capture_screen.dart';
import 'hardware_transport_test.dart' as transport;

const sensorId = 'aabbccddeeff', cameraId = '112233445566';
const code = '0123456789abcdef0123456789abcdef'; // Test-only fixture.
const rules = [
  CaptureRule(true, 20, 30),
  CaptureRule(false, 0, 100),
  CaptureRule(false, 0, 100),
];
AutomaticCapture settings({bool enabled = true, Crop crop = Crop.tomato}) =>
    AutomaticCapture(
      deviceId: sensorId,
      crop: crop,
      enabled: enabled,
      camera: '192.168.8.103',
      cameraId: cameraId,
      rules: rules,
      duration: 30,
      cooldown: 60,
    );
Map<String, dynamic> packet(AutomaticCapture a) => {
  'version': 1,
  'device_id': a.deviceId,
  'crop': a.crop.name,
  'enabled': a.enabled,
  'camera': a.camera,
  'camera_id': a.cameraId,
  'duration': a.duration,
  'cooldown': a.cooldown,
  'soil_calibrated': a.soilCalibrated,
  'status': a.status,
  for (var i = 0; i < 3; i++) ...{
    '${automaticMetrics[i]}_enabled': a.rules[i].enabled,
    '${automaticMetrics[i]}_min': a.rules[i].minimum,
    '${automaticMetrics[i]}_max': a.rules[i].maximum,
  },
};

class AutoStub extends HardwareClient {
  AutomaticCapture state = settings(enabled: false);
  int writes = 0, cameraChecks = 0;
  bool sdReady = true, failRead = false, wrongReadback = false;
  @override
  Future<AutomaticCapture?> automaticConfiguration(
    String address,
    String code,
  ) async {
    if (failRead) throw const SocketException('offline');
    return wrongReadback && writes > 0 ? settings(crop: Crop.chili) : state;
  }

  @override
  Future<String> cameraAutomationIdentity(String address, String code) async {
    cameraChecks++;
    if (!sdReady) throw const FormatException('SD not ready');
    return cameraId;
  }

  @override
  Future<AutomaticCapture> setAutomatic(
    String address,
    String sensorCode,
    AutomaticCapture requested, {
    String cameraCode = '',
  }) async {
    requested.validate();
    writes++;
    state = requested;
    return state;
  }
}

void main() {
  test(
    'rules reject malformed ranges, timing, uncalibrated soil and wrong protocol',
    () {
      final valid = packet(settings());
      expect(AutomaticCapture.fromJson(valid).enabled, isTrue);
      for (final change in <Map<String, dynamic>>[
        {'version': 2},
        {'temp_min': 30},
        {'temp_max': double.nan},
        {'duration': 0},
        {'cooldown': 59},
        {'soil_enabled': true},
        {'temp_enabled': false},
        {'enabled': 'true'},
      ]) {
        expect(
          () => AutomaticCapture.fromJson({...valid, ...change}),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'settings use authenticated fixed-length form, with no key in URL',
    () async {
      final http = transport.TestClient(
        transport.TestResponse([utf8.encode(jsonEncode(packet(settings())))]),
      );
      final client = HardwareClient(httpClientFactory: () => http);
      await client.setAutomatic(
        '192.168.8.102',
        code,
        settings(),
        cameraCode: code,
      );
      expect(http.request!.uri.path, '/automation');
      expect(http.request!.uri.query, isEmpty);
      expect(http.request!.headers.values['X-AgriSense-Key'], code);
      final form = Uri.splitQueryString(http.request!.body.toString());
      expect(form.length, 17);
      expect(form['camera_key'], code);
      expect(form['camera'], '192.168.8.103');
      expect(http.request!.followRedirects, isFalse);
    },
  );
  test(
    'legacy firmware is distinguishable from authentication failure',
    () async {
      final legacy = HardwareClient(
        httpClientFactory: () =>
            transport.TestClient(transport.TestResponse([], statusCode: 404)),
      );
      expect(
        await legacy.automaticConfiguration('192.168.8.102', code),
        isNull,
      );
      final rejected = HardwareClient(
        httpClientFactory: () =>
            transport.TestClient(transport.TestResponse([], statusCode: 401)),
      );
      await expectLater(
        rejected.automaticConfiguration('192.168.8.102', code),
        throwsFormatException,
      );
    },
  );
  test('camera must authenticate and report ready SD', () async {
    final client = HardwareClient(
      httpClientFactory: () => transport.TestClient(
        transport.TestResponse([
          utf8.encode(
            jsonEncode({
              'version': 1,
              'device_id': cameraId,
              'sd_ready': false,
            }),
          ),
        ]),
      ),
    );
    await expectLater(
      client.cameraAutomationIdentity('192.168.8.103', code),
      throwsFormatException,
    );
    await expectLater(
      client.cameraAutomationIdentity('8.8.8.8', code),
      throwsFormatException,
    );
  });

  group('controller', () {
    late Directory directory;
    late Box<dynamic> box;
    late AutoStub client;
    late HardwareController h;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('automatic-capture-');
      Hive.init(directory.path);
      box = await Hive.openBox<dynamic>('automatic');
      client = AutoStub();
      h = HardwareController(box, client: client)..load();
      h.assignments[Crop.tomato] = {
        'sensor': 'http://192.168.8.102',
        'sensorId': sensorId,
        'pairingCode': code,
        'camera': 'http://192.168.8.103',
      };
    });
    tearDown(() async {
      h.dispose();
      await box.close();
      await directory.delete(recursive: true);
    });
    Future<AutomaticCapture> save({bool enabled = true}) => h.saveAutomatic(
      Crop.tomato,
      enabled: enabled,
      rules: rules,
      duration: 30,
      cooldown: 60,
      cameraCode: code,
    );

    test(
      'HTTP opt-in and ready camera required; disable works without camera',
      () async {
        await expectLater(save(), throwsFormatException);
        expect(client.writes, 0);
        await h.setHttpAllowed(true);
        client.sdReady = false;
        await expectLater(save(), throwsFormatException);
        expect(client.writes, 0);
        client.sdReady = true;
        expect((await save()).enabled, isTrue);
        client.sdReady = false;
        expect((await save(enabled: false)).enabled, isFalse);
      },
    );
    test(
      'independent readback must match and failures release busy lock',
      () async {
        await h.setHttpAllowed(true);
        client.wrongReadback = true;
        await expectLater(save(), throwsFormatException);
        expect(h.busy, isFalse);
      },
    );
    test(
      'camera move disables old rules; offline sensor blocks move',
      () async {
        await h.setHttpAllowed(true);
        client.state = settings();
        client.failRead = true;
        await expectLater(
          h.moveCamera(Crop.chili, '192.168.8.103'),
          throwsA(isA<SocketException>()),
        );
        expect(h.address(Crop.tomato, 'camera'), isNotEmpty);
        client.failRead = false;
        await h.moveCamera(Crop.chili, '192.168.8.103');
        expect(client.state.enabled, isFalse);
        expect(h.address(Crop.tomato, 'camera'), isEmpty);
        expect(h.address(Crop.chili, 'camera'), 'http://192.168.8.103');
      },
    );
    testWidgets(
      'settings show board truth, obscure key and explain offline storage',
      (tester) async {
        h.allowLocalHttp = true;
        await tester.pumpWidget(
          MaterialApp(
            home: AutomaticCaptureScreen(hardware: h, crop: Crop.tomato),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Confirmed on board: Off'), findsOneWidget);
        expect(
          find.textContaining('not automatically imported'),
          findsOneWidget,
        );
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        final keyField = tester
            .widgetList<TextField>(find.byType(TextField))
            .first;
        expect(keyField.obscureText, isTrue);
        expect(client.writes, 0); // Editing is not applying.
      },
    );
  });
}
