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
  final clearedKinds = <String>[];
  @override
  Future<void> clearSavedAddress(Crop crop, String kind) async {
    requestedCrop = crop;
    clearedKinds.add(kind);
    assignments[crop]?.remove(kind);
  }

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

class AddressChangeStub extends SensorStub {
  String reachable = 'http://192.168.1.50';
  final contacted = <String>[];
  int automationWrites = 0;
  bool rejectStop = false, wrongAutomationIdentity = false;
  AutomaticCapture automation = const AutomaticCapture(
    deviceId: testId,
    crop: Crop.tomato,
    enabled: false,
  );

  void checkAddress(String address) {
    contacted.add(address);
    if (address != reachable) throw const SocketException('Old IP is offline');
  }

  @override
  Future<SensorConfiguration> configuration(String address) {
    checkAddress(address);
    return super.configuration(address);
  }

  @override
  Future<SensorConfiguration> setCrop(
    String address,
    Crop next,
    String deviceId,
    String code,
  ) {
    checkAddress(address);
    return super.setCrop(address, next, deviceId, code);
  }

  @override
  Future<AutomaticCapture?> automaticConfiguration(
    String address,
    String code,
  ) async {
    checkAddress(address);
    if (code != testCode) {
      throw const FormatException('Pairing code was rejected.');
    }
    return wrongAutomationIdentity
        ? const AutomaticCapture(deviceId: '112233445566', crop: Crop.tomato)
        : automation;
  }

  @override
  Future<AutomaticCapture> setAutomatic(
    String address,
    String sensorCode,
    AutomaticCapture requested, {
    String cameraCode = '',
  }) async {
    checkAddress(address);
    if (sensorCode != testCode) {
      throw const FormatException('Pairing code was rejected.');
    }
    automationWrites++;
    if (!rejectStop) automation = requested;
    return automation;
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

  test(
    'same sensor can recover its changed IP before changing camera IP',
    () async {
      final moved = AddressChangeStub();
      final recovery = HardwareController(box, client: moved)..load();
      addTearDown(recovery.dispose);
      await recovery.setHttpAllowed(true);
      await recovery.configureSensor(Crop.tomato, '192.168.1.50', testCode);
      moved.automation = const AutomaticCapture(
        deviceId: testId,
        crop: Crop.tomato,
        enabled: true,
      );
      moved.reachable = 'http://192.168.1.60';
      moved.contacted.clear();
      await recovery.configureSensor(Crop.tomato, '192.168.1.60', '');
      expect(moved.contacted, everyElement('http://192.168.1.60'));
      expect(moved.automationWrites, 1);
      expect(moved.automation.enabled, isFalse);
      expect(recovery.address(Crop.tomato, 'sensor'), moved.reachable);
      expect(recovery.assignments[Crop.tomato]?['sensorId'], testId);
      await recovery.moveCamera(Crop.tomato, '192.168.1.61');
      expect(recovery.address(Crop.tomato, 'camera'), 'http://192.168.1.61');
      final restored = HardwareController(box, client: moved)..load();
      addTearDown(restored.dispose);
      expect(restored.address(Crop.tomato, 'sensor'), moved.reachable);
      expect(restored.address(Crop.tomato, 'camera'), 'http://192.168.1.61');
    },
  );

  test('new IP cannot reuse a saved code for another sensor', () async {
    final moved = AddressChangeStub();
    final recovery = HardwareController(box, client: moved)..load();
    addTearDown(recovery.dispose);
    await recovery.setHttpAllowed(true);
    await recovery.configureSensor(Crop.tomato, '192.168.1.50', testCode);
    moved.reachable = 'http://192.168.1.60';
    moved.id = '112233445566';
    final writesBefore = moved.calls;
    await expectLater(
      recovery.configureSensor(Crop.tomato, '192.168.1.60', ''),
      throwsFormatException,
    );
    expect(moved.calls, writesBefore + 1); // Identity read only; no code sent.
    expect(moved.automationWrites, 0);
    expect(recovery.address(Crop.tomato, 'sensor'), 'http://192.168.1.50');
  });

  test(
    'recovery rejects wrong automation identity and unconfirmed stop',
    () async {
      final moved = AddressChangeStub();
      final recovery = HardwareController(box, client: moved)..load();
      addTearDown(recovery.dispose);
      await recovery.setHttpAllowed(true);
      await recovery.configureSensor(Crop.tomato, '192.168.1.50', testCode);
      moved.reachable = 'http://192.168.1.60';
      moved.wrongAutomationIdentity = true;
      await expectLater(
        recovery.configureSensor(Crop.tomato, '192.168.1.60', ''),
        throwsFormatException,
      );
      expect(moved.automationWrites, 0);
      moved.wrongAutomationIdentity = false;
      moved.rejectStop = true;
      moved.automation = const AutomaticCapture(
        deviceId: testId,
        crop: Crop.tomato,
        enabled: true,
      );
      await expectLater(
        recovery.configureSensor(Crop.tomato, '192.168.1.60', ''),
        throwsFormatException,
      );
      expect(recovery.address(Crop.tomato, 'sensor'), 'http://192.168.1.50');
      expect(moved.automation.enabled, isTrue);
      expect(recovery.busy, isFalse);
    },
  );

  test(
    'replacement and camera moves retain the old-board stop requirement',
    () async {
      final moved = AddressChangeStub();
      final recovery = HardwareController(box, client: moved)..load();
      addTearDown(recovery.dispose);
      await recovery.setHttpAllowed(true);
      await recovery.configureSensor(Crop.tomato, '192.168.1.50', testCode);
      moved.reachable = 'http://192.168.1.60';
      await expectLater(
        recovery.moveCamera(Crop.tomato, '192.168.1.61'),
        throwsA(isA<SocketException>()),
      );
      moved.id = '112233445566';
      await expectLater(
        recovery.configureSensor(Crop.tomato, '192.168.1.60', testCode),
        throwsFormatException,
      );
      expect(recovery.address(Crop.tomato, 'sensor'), 'http://192.168.1.50');
      expect(recovery.address(Crop.tomato, 'camera'), isEmpty);
    },
  );

  test(
    'clear saved IP works offline, preserves pairing/history and stays cleared',
    () async {
      final moved = AddressChangeStub();
      final recovery = HardwareController(box, client: moved)..load();
      addTearDown(recovery.dispose);
      await recovery.setHttpAllowed(true);
      await recovery.configureSensor(Crop.tomato, '192.168.1.50', testCode);
      await recovery.refresh(Crop.tomato);
      await recovery.moveCamera(Crop.tomato, '192.168.1.51');
      recovery.assignments[Crop.chili] = {'camera': 'http://192.168.1.99'};
      await TomatoScanStore(box).save(
        TomatoScan(
          id: 'kept-scan',
          timestamp: DateTime(2026, 10, 23),
          label: 'healthy',
          score: .8,
          preview: Uint8List(0),
          modelVersion: 'test-model',
        ),
      );
      final historyBefore = box.toMap()..remove('hardware-nodes-v1');
      moved.reachable = 'http://192.168.1.60';
      moved.contacted.clear();
      recovery.allowLocalHttp = false;
      for (final kind in ['sensor', 'camera']) {
        await recovery.clearSavedAddress(Crop.tomato, kind);
        expect(recovery.address(Crop.tomato, kind), isEmpty);
        expect(recovery.assignments[Crop.tomato]!.containsKey(kind), isFalse);
      }
      expect(moved.contacted, isEmpty);
      expect(moved.automationWrites, 0);
      expect(recovery.assignments[Crop.tomato]?['sensorId'], testId);
      expect(recovery.assignments[Crop.tomato]?['pairingCode'], testCode);
      expect(recovery.address(Crop.chili, 'camera'), 'http://192.168.1.99');
      expect(box.toMap()..remove('hardware-nodes-v1'), historyBefore);
      final restored = HardwareController(box, client: moved)..load();
      addTearDown(restored.dispose);
      expect(restored.address(Crop.tomato, 'sensor'), isEmpty);
      expect(restored.address(Crop.tomato, 'camera'), isEmpty);
      expect(restored.readings(Crop.tomato).length, 1);
      expect(TomatoScanStore(box).load().single.id, 'kept-scan');
      await restored.setHttpAllowed(true);
      await restored.moveCamera(Crop.tomato, '192.168.1.61');
      expect(restored.address(Crop.tomato, 'camera'), 'http://192.168.1.61');
      expect(moved.contacted, isEmpty);
      await restored.configureSensor(Crop.tomato, '192.168.1.60', '');
      expect(restored.address(Crop.tomato, 'sensor'), 'http://192.168.1.60');
    },
  );

  test(
    'explicitly clearing the old IP permits pairing a replacement with its own code',
    () async {
      final moved = AddressChangeStub();
      final recovery = HardwareController(box, client: moved)..load();
      addTearDown(recovery.dispose);
      await recovery.setHttpAllowed(true);
      await recovery.configureSensor(Crop.tomato, '192.168.1.50', testCode);
      await recovery.clearSavedAddress(Crop.tomato, 'sensor');
      moved.reachable = 'http://192.168.1.60';
      moved.id = '112233445566';
      moved.contacted.clear();
      await expectLater(
        recovery.configureSensor(Crop.tomato, '192.168.1.60', ''),
        throwsFormatException,
      );
      await recovery.configureSensor(Crop.tomato, '192.168.1.60', testCode);
      expect(recovery.address(Crop.tomato, 'sensor'), moved.reachable);
      expect(recovery.assignments[Crop.tomato]?['sensorId'], moved.id);
      expect(moved.contacted, everyElement(moved.reachable));
    },
  );

  test('failed clear storage write preserves the saved address', () async {
    h.assignments[Crop.tomato] = {'camera': 'http://192.168.1.51'};
    await box.close();
    await expectLater(
      h.clearSavedAddress(Crop.tomato, 'camera'),
      throwsA(anything),
    );
    expect(h.address(Crop.tomato, 'camera'), 'http://192.168.1.51');
  });

  testWidgets(
    'Devices can clear either IP without board contact or valid form input',
    (tester) async {
      final controller = AssignmentUiController(box)..load();
      controller.allowLocalHttp = false;
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      controller.assignments[Crop.tomato] = {
        'sensor': 'http://192.168.1.50',
        'camera': 'http://192.168.1.51',
        'sensorId': testId,
        'pairingCode': testCode,
      };
      await tester.pumpWidget(
        HardwareApp(
          hardware: controller,
          scans: TomatoScanStore(box),
          showTutorial: false,
        ),
      );
      await tester.tap(find.text('Devices').last);
      await tester.pumpAndSettle();
      for (final kind in ['Sensor', 'Camera']) {
        final node = find.text('$kind node');
        await tester.ensureVisible(node);
        await tester.tap(node);
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            'This works offline and does not stop automatic capture',
          ),
          findsOneWidget,
        );
        await tester.enterText(find.byType(TextField).first, 'invalid-address');
        if (kind == 'Sensor') {
          await tester.enterText(find.byType(TextField).at(1), 'invalid-code');
        }
        final clear = find.byKey(const ValueKey('clear-saved-ip'));
        await tester.ensureVisible(clear);
        await tester.tap(clear);
        await tester.pumpAndSettle();
        expect(controller.address(Crop.tomato, kind.toLowerCase()), isEmpty);
      }
      expect(client.calls, 0);
      expect(controller.clearedKinds, ['sensor', 'camera']);
      expect(controller.requestedAddress, isNull);
      expect(controller.assignments[Crop.tomato]?['pairingCode'], testCode);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
      await tester.tap(find.widgetWithText(OutlinedButton, 'Eggplant'));
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
