import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/automatic_capture.dart';
import 'package:agrisense/data/models.dart';
import 'package:agrisense/features/diagnosis/tomato_scan.dart';
import 'package:agrisense/features/monitoring/hardware_dashboard.dart';

const testCode =
    '0123456789abcdef0123456789abcdef'; // Test fixture, not a device secret.
const testId = 'aabbccddeeff';

class AssignmentUiController extends HardwareController {
  AssignmentUiController(super.box) {
    allowLocalHttp = true;
  }
  Crop? requestedCrop;
  String? requestedAddress, requestedCode;
  @override
  Future<void> configureSensor(Crop crop, String input, String code) async {
    requestedCrop = crop;
    requestedAddress = input;
    requestedCode = code;
  }
}

class SensorStub extends HardwareClient {
  @override
  Future<AutomaticCapture?> automaticConfiguration(
    String address,
    String code,
  ) async => null;
  Crop crop = Crop.tomato;
  String id = testId;
  int calls = 0;
  bool rejectCode = false, loseReply = false, wrongConfirmation = false;
  Completer<void>? pause;
  @override
  Future<SensorConfiguration> configuration(String address) async {
    calls++;
    return SensorConfiguration(
      deviceId: id,
      crop: wrongConfirmation ? Crop.chili : crop,
    );
  }

  @override
  Future<SensorConfiguration> setCrop(
    String address,
    Crop next,
    String deviceId,
    String code,
  ) async {
    calls++;
    if (pause != null) await pause!.future;
    if (rejectCode || code != testCode) {
      throw const FormatException('Pairing code was rejected.');
    }
    crop = next;
    if (loseReply) throw TimeoutException('Reply lost');
    return SensorConfiguration(deviceId: id, crop: next);
  }

  @override
  Future<HardwareSample> read(String address, Crop selected) async {
    calls++;
    return HardwareSample.fromDevice({
      'version': 1,
      'device_id': id,
      'crop': crop.name,
      'sample_id': '$id-${crop.name}',
      'age_ms': 100,
      'temp_c': 24,
      'humidity_pct': 55,
      'soil_raw': 2000,
      'soil_pct': null,
      'soil_calibrated': false,
      'gas_raw': 300,
    }, selected);
  }

  @override
  Future<Uint8List> capture(String address) async {
    calls++;
    if (pause != null) await pause!.future;
    return Uint8List.fromList([1, 2, 3]);
  }
}

void main() {
  late Directory directory;
  late Box<dynamic> box;
  late SensorStub client;
  late HardwareController h;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sensor-assignment-');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('sensor-assignment');
    client = SensorStub();
    h = HardwareController(box, client: client)..load();
  });
  tearDown(() async {
    h.dispose();
    await box.close();
    await directory.delete(recursive: true);
  });

  testWidgets(
    'Devices applies the selected destination crop and obscures the pairing code',
    (tester) async {
      final controller = AssignmentUiController(box);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        HardwareApp(
          hardware: controller,
          scans: TomatoScanStore(box),
          showTutorial: false,
        ),
      );
      await tester.tap(find.text('Devices').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Eggplant'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sensor node'));
      await tester.tap(find.text('Sensor node'));
      await tester.pumpAndSettle();
      expect(find.text('Assign sensor to Eggplant'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '192.168.1.50');
      await tester.enterText(find.byType(TextField).at(1), testCode);
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
        isTrue,
      );
      await tester.tap(find.text('Apply assignment'));
      await tester.pumpAndSettle();
      expect(controller.requestedCrop, Crop.eggplant);
      expect(controller.requestedAddress, '192.168.1.50');
      expect(controller.requestedCode, testCode);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('HTTP-off and invalid pairing input never contact the board', () async {
    await expectLater(
      h.configureSensor(Crop.tomato, '192.168.1.50', testCode),
      throwsFormatException,
    );
    await h.setHttpAllowed(true);
    await expectLater(
      h.configureSensor(Crop.tomato, '192.168.1.50', 'bad'),
      throwsFormatException,
    );
    expect(client.calls, 0);
  });
  test(
    'move commits only after confirmation and preserves old history',
    () async {
      await h.setHttpAllowed(true);
      await h.configureSensor(Crop.tomato, '192.168.1.50', testCode);
      await h.refresh(Crop.tomato);
      await h.configureSensor(Crop.eggplant, '192.168.1.50', '');
      expect(h.address(Crop.tomato, 'sensor'), isEmpty);
      expect(h.address(Crop.eggplant, 'sensor'), 'http://192.168.1.50');
      expect(h.readings(Crop.tomato).length, 1);
      expect(h.readings(Crop.eggplant), isEmpty);
      await h.refresh(Crop.eggplant);
      expect(h.readings(Crop.eggplant).length, 1);
      final restored = HardwareController(box, client: client)..load();
      await restored.configureSensor(Crop.chili, '192.168.1.50', '');
      expect(restored.address(Crop.eggplant, 'sensor'), isEmpty);
      expect(restored.readings(Crop.tomato).length, 1);
      restored.dispose();
    },
  );
  test(
    'rejected code or mismatched confirmation cannot commit an assignment',
    () async {
      await h.setHttpAllowed(true);
      client.rejectCode = true;
      await expectLater(
        h.configureSensor(Crop.tomato, '192.168.1.50', testCode),
        throwsFormatException,
      );
      expect(h.address(Crop.tomato, 'sensor'), isEmpty);
      client.rejectCode = false;
      client.wrongConfirmation = true;
      await expectLater(
        h.configureSensor(Crop.tomato, '192.168.1.50', testCode),
        throwsFormatException,
      );
      expect(h.address(Crop.tomato, 'sensor'), isEmpty);
    },
  );
  test(
    'lost reply keeps old mapping, rejects mismatched telemetry, and supports retry',
    () async {
      await h.setHttpAllowed(true);
      await h.configureSensor(Crop.tomato, '192.168.1.50', testCode);
      client.loseReply = true;
      await expectLater(
        h.configureSensor(Crop.eggplant, '192.168.1.50', ''),
        throwsFormatException,
      );
      expect(client.crop, Crop.eggplant);
      expect(h.address(Crop.tomato, 'sensor'), isNotEmpty);
      await h.refresh(Crop.tomato);
      expect(h.samples, isEmpty);
      client.loseReply = false;
      await h.configureSensor(Crop.eggplant, '192.168.1.50', '');
      expect(h.address(Crop.tomato, 'sensor'), isEmpty);
    },
  );
  test(
    'changed device identity blocks writes and readings at a reused IP',
    () async {
      await h.setHttpAllowed(true);
      await h.configureSensor(Crop.tomato, '192.168.1.50', testCode);
      client.id = '112233445566';
      await expectLater(
        h.configureSensor(Crop.eggplant, '192.168.1.50', ''),
        throwsFormatException,
      );
      await h.refresh(Crop.tomato);
      expect(h.samples, isEmpty);
    },
  );
  test(
    'concurrent capture prevents reassignment and HTTP changes until finished',
    () async {
      await h.setHttpAllowed(true);
      await h.moveCamera(Crop.tomato, '192.168.1.51');
      client.pause = Completer<void>();
      final capture = h.capture(Crop.tomato);
      expect(h.busy, isTrue);
      await expectLater(
        h.moveCamera(Crop.eggplant, '192.168.1.51'),
        throwsFormatException,
      );
      await expectLater(h.setHttpAllowed(false), throwsStateError);
      client.pause!.complete();
      await capture;
      expect(h.busy, isFalse);
      await h.moveCamera(Crop.eggplant, '192.168.1.51');
      expect(h.address(Crop.tomato, 'camera'), isEmpty);
    },
  );
  test(
    'storage failure after the command leaves local mapping unchanged',
    () async {
      await h.setHttpAllowed(true);
      await h.configureSensor(Crop.tomato, '192.168.1.50', testCode);
      await box.close();
      await expectLater(
        h.configureSensor(Crop.eggplant, '192.168.1.50', ''),
        throwsFormatException,
      );
      expect(h.address(Crop.tomato, 'sensor'), isNotEmpty);
    },
  );
}
