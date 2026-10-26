import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:agrisense/core/hardware_controller.dart';
import 'package:agrisense/data/board_discovery.dart';
import 'package:agrisense/data/hardware_client.dart';
import 'package:agrisense/data/models.dart';

class _Discovery extends BoardDiscovery {
  @override
  bool get supported => true;
  List<String> addresses = [];
  bool fail = false;
  int searches = 0;
  Completer<void>? gate;
  @override
  Future<List<String>> discover() async {
    searches++;
    await gate?.future;
    if (fail) throw TimeoutException('test timeout');
    return addresses;
  }

  @override
  Future<void> cancel() async {
    gate?.complete();
    gate = null;
  }
}

class _Boards extends HardwareClient {
  final identities = <String, BoardIdentity>{};
  int captures = 0, reads = 0;
  @override
  Future<BoardIdentity> identity(String address) async =>
      identities[address] ?? (throw const SocketException('offline'));
  @override
  Future<Uint8List> capture(String address) async {
    captures++;
    return Uint8List(0);
  }

  @override
  Future<HardwareSample> read(String address, Crop crop) async {
    reads++;
    return HardwareSample(
      id: '$reads',
      deviceId: identities[address]!.deviceId,
      crop: crop,
      receivedAt: DateTime(2026),
      temperature: 25,
      humidity: 60,
      soil: null,
      soilRaw: 2000,
      gasRaw: 400,
      soilCalibrated: false,
    );
  }
}

BoardIdentity identity(
  String role,
  String id, {
  String kit = demoKitId,
  bool ready = true,
}) => BoardIdentity(
  kitId: kit,
  deviceId: id,
  role: role,
  ready: ready,
  capabilities: [role == 'sensor' ? 'readings' : 'capture'],
  sensorCrop: role == 'sensor' ? Crop.tomato : null,
);

void main() {
  late Directory dir;
  late Box<dynamic> box;
  late HardwareController h;
  late _Discovery discovery;
  late _Boards boards;
  var now = DateTime(2026);
  setUp(() async {
    dir = await Directory('test').createTemp('kit-discovery-');
    Hive.init(dir.path);
    box = await Hive.openBox<dynamic>('kit');
    discovery = _Discovery();
    boards = _Boards();
    now = DateTime(2026);
    h = HardwareController(
      box,
      client: boards,
      discovery: discovery,
      clock: () => now,
    )..load();
  });
  tearDown(() async {
    h.dispose();
    await box.close();
    await dir.delete(recursive: true);
  });

  test('identity schema rejects malformed and unsupported responses', () {
    final value = <String, dynamic>{
      'version': 1,
      'kit_id': demoKitId,
      'device_id': 'aabbccddeeff',
      'role': 'sensor',
      'ready': true,
      'sensor_crop': 'tomato',
      'capabilities': ['readings'],
    };
    expect(BoardIdentity.fromJson(value).sensorCrop, Crop.tomato);
    expect(
      () => BoardIdentity.fromJson({...value, 'version': 2}),
      throwsFormatException,
    );
    expect(
      () => BoardIdentity.fromJson({...value, 'device_id': 'unknown'}),
      throwsFormatException,
    );
    expect(
      () => BoardIdentity.fromJson({...value, 'role': 'router'}),
      throwsFormatException,
    );
  });

  test(
    'first connection verifies both roles and persists shared identity without pairing codes',
    () async {
      boards.identities['http://192.168.8.20'] = identity(
        'sensor',
        'aabbccddeeff',
      );
      boards.identities['http://192.168.8.21'] = identity(
        'camera',
        '112233445566',
      );
      discovery.addresses = boards.identities.keys.toList();
      await h.connectKit(Crop.chili);
      expect(h.address(Crop.chili, 'sensor'), 'http://192.168.8.20');
      expect(h.address(Crop.eggplant, 'camera'), 'http://192.168.8.21');
      expect(h.assignments[Crop.tomato]!['pairingCode'], isNull);
      expect(boards.captures, 0);
      final restored = HardwareController(box)..load();
      expect(restored.assignments[Crop.chili]!['cameraId'], '112233445566');
      restored.dispose();
      await h.connectKit(Crop.chili);
      expect(discovery.searches, 1); // Saved identities avoid a second scan.
    },
  );

  test(
    'one camera connects even when sensor is absent and discovery times out safely',
    () async {
      boards.identities['http://192.168.8.21'] = identity(
        'camera',
        '112233445566',
      );
      discovery.addresses = boards.identities.keys.toList();
      await h.connectKit(Crop.tomato);
      expect(h.address(Crop.tomato, 'camera'), isNotEmpty);
      expect(h.address(Crop.tomato, 'sensor'), isEmpty);
      expect(h.connectionStatus, contains('partly connected'));
      discovery.fail = true;
      await h.connectKit(Crop.tomato);
      expect(h.address(Crop.tomato, 'camera'), 'http://192.168.8.21');
      expect(h.busy, isFalse);
    },
  );

  test(
    'conflicting cameras are rejected while the sensor remains usable',
    () async {
      boards.identities['http://192.168.8.20'] = identity(
        'sensor',
        'aabbccddeeff',
      );
      boards.identities['http://192.168.8.21'] = identity(
        'camera',
        '112233445566',
      );
      boards.identities['http://192.168.8.22'] = identity(
        'camera',
        '223344556677',
      );
      discovery.addresses = boards.identities.keys.toList();
      await h.connectKit(Crop.tomato);
      expect(h.address(Crop.tomato, 'sensor'), isNotEmpty);
      expect(h.address(Crop.tomato, 'camera'), isEmpty);
      expect(h.connectionStatus, contains('Conflicting camera'));
      await h.refresh(Crop.tomato);
      expect(boards.reads, 1);
    },
  );

  test('wrong kits and malformed addresses cannot be assigned', () async {
    boards.identities['http://192.168.8.21'] = identity(
      'camera',
      '112233445566',
      kit: 'other-kit',
    );
    discovery.addresses = ['http://8.8.8.8', 'http://192.168.8.21'];
    await h.connectKit(Crop.tomato);
    expect(h.address(Crop.tomato, 'camera'), isEmpty);
    expect(h.connectionStatus, contains('No kit found'));
  });

  test(
    'changed IP is rediscovered and monitoring resumes using the same identity',
    () async {
      boards.identities['http://192.168.8.20'] = identity(
        'sensor',
        'aabbccddeeff',
      );
      discovery.addresses = boards.identities.keys.toList();
      await h.connectKit(Crop.tomato);
      await h.withPollingPaused(() => h.startMonitoring(Crop.tomato));
      boards.identities.clear();
      await h.refresh(Crop.tomato);
      expect(h.status[Crop.tomato], 'Unavailable');
      boards.identities['http://192.168.8.30'] = identity(
        'sensor',
        'aabbccddeeff',
      );
      discovery.addresses = boards.identities.keys.toList();
      now = now.add(const Duration(seconds: 31));
      await h.monitorTick(Crop.tomato);
      expect(h.address(Crop.tomato, 'sensor'), 'http://192.168.8.30');
      expect(h.status[Crop.tomato], 'Received');
      expect(h.polling, isTrue);
    },
  );

  test(
    'a replacement camera cannot silently take over an already bound identity',
    () async {
      boards.identities['http://192.168.8.21'] = identity(
        'camera',
        '112233445566',
      );
      discovery.addresses = boards.identities.keys.toList();
      await h.connectKit(Crop.tomato);
      boards.identities['http://192.168.8.21'] = identity(
        'camera',
        '223344556677',
      );
      await expectLater(h.capture(Crop.tomato), throwsA(anything));
      expect(boards.captures, 0);
      await h.connectKit(Crop.tomato);
      expect(h.assignments[Crop.tomato]!['cameraId'], '112233445566');
      expect(h.cameraStatus[Crop.tomato], 'Unavailable');
    },
  );

  test(
    'parallel Connect calls share one scan and local access opt-out is respected',
    () async {
      discovery.gate = Completer<void>();
      final one = h.connectKit(Crop.tomato);
      final two = h.connectKit(Crop.tomato);
      await Future<void>.delayed(Duration.zero);
      discovery.gate!.complete();
      discovery.gate = null;
      await Future.wait([one, two]);
      expect(discovery.searches, 1);
      await h.setHttpAllowed(false);
      await expectLater(h.connectKit(Crop.tomato), throwsA(anything));
      expect(discovery.searches, 1);
    },
  );
}
