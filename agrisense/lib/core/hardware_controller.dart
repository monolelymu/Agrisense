import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import '../data/hardware_client.dart';
import '../data/firebase_cloud_client.dart';
import '../data/soil_calibration.dart';
import '../data/board_discovery.dart';
import '../data/app_alert_event.dart';
import 'app_alerts_bridge.dart';
import 'camera_live_controller.dart';
import 'dart:io';
import '../data/models.dart';
import '../data/automatic_capture.dart';
import '../data/kit_warning.dart';
import '../data/daily_photo_schedule.dart';
import 'sensor_notifications.dart';
import 'app_issue.dart';
import '../data/alert_photo.dart';
import '../features/diagnosis/photo_processing.dart';
import '../features/diagnosis/tomato_classifier.dart';
import '../features/diagnosis/tomato_scan.dart';
import '../data/monitoring_alert.dart';
import 'monitoring_service.dart';
import '../features/diagnosis/tomato_assessment.dart';

class HardwareController extends ChangeNotifier {
  HardwareController(
    this.box, {
    HardwareClient? client,
    SensorNotifications? notifications,
    DateTime Function()? clock,
    TomatoClassifier? classifier,
    TomatoScanStore? scanStore,
    MonitoringAlertStore? alertStore,
    MonitoringServiceBridge? service,
    BoardDiscovery? discovery,
    AppAlertsBridge? appAlerts,
  }) : client = client ??
           HardwareClient(
             cloud: FirebaseCloudClient(
               box: box,
               clock: clock ?? DateTime.now,
             ),
           ),
       notifications = notifications ?? SensorNotifications(),
       _clock = clock ?? DateTime.now,
       classifier = classifier ?? TomatoClassifier(),
       scanStore = scanStore ?? TomatoScanStore(box),
       alertStore = alertStore ?? MonitoringAlertStore(box),
       service = service ?? MonitoringServiceBridge(),
       discovery = discovery ?? BoardDiscovery(),
       appAlerts = appAlerts ?? AppAlertsBridge();
  final AppAlertsBridge appAlerts;
  WateringReminder watering = const WateringReminder();
  final List<AppAlertEvent> events = [];
  AlertTarget? alertTarget;
  String? remindersIssue;
  Future<void>? _alertSync;
  (Uint8List, DateTime)? lastCameraPhoto;
  Uint8List? lastCameraOriginal;
  CameraLiveController? _live;
  CameraLiveController get live => _live ??= CameraLiveController(
    open: (endpoint) async {
      final expected = _verified['camera'];
      if (expected == null) throw AppIssue.identity;
      final identity = await client.identity(endpoint);
      if (identity.kitId != demoKitId ||
          identity.role != 'camera' ||
          identity.deviceId != expected.deviceId ||
          !identity.ready ||
          !identity.capabilities.contains('stream')) {
        throw AppIssue.camera;
      }
      return client.cameraStream(endpoint);
    },
    clock: _clock,
  );
  final Set<Object> _cameraViews = {};
  final Map<String, BoardIdentity> _verified = {};
  DateTime? _cameraVerifiedAt;
  DateTime? _lastAppHeartbeat;
  bool _monitorTickActive = false;
  final Map<Crop, HardwareSample> _liveReadings = {};
  final Map<Crop, DateTime> _lastHistoryWrite = {};
  final Map<Crop, String> warningSyncStatus = {};
  String? _warningConfirmed;
  DateTime? _warningCheckAt;

  String warningStatus(Crop crop) =>
      warningSyncStatus[crop] ?? 'Waiting to sync';

  Future<void> _syncWarnings(Crop crop) async {
    if (!allowLocalHttp || cameraControlActive || _disposed) return;
    final nodes = assignments[crop];
    final endpoint = address(crop, 'sensor');
    final device = nodes?['sensorId'];
    if (endpoint.isEmpty || device == null) return;
    final settings = notificationSettings[crop] ?? SensorAlertSettings.initial;
    final rules = [
      for (var i = 0; i < 3; i++)
        CaptureRule(
          settings.enabled &&
              settings.rules[i].enabled &&
              (!settings.autoBaseline ||
                  settings.baseline?['metric_$i'] != null ||
                  settings.baseline?['manual_$i'] == true),
          settings.rules[i].minimum,
          settings.rules[i].maximum,
        ),
      CaptureRule(
        settings.enabled && settings.gasRule.enabled,
        settings.gasRule.minimum,
        settings.gasRule.maximum,
      ),
    ];
    final desired = KitWarning(
      deviceId: device,
      crop: _sensorCrop ?? crop,
      soilRaw: settings.soilRaw,
      rules: rules,
    );
    final fingerprint = '$endpoint:${desired.form()}';
    if (_warningConfirmed != fingerprint) {
      for (final key in warningSyncStatus.keys.toList()) {
        if (key != crop && warningSyncStatus[key] == 'Saved to kit') {
          warningSyncStatus[key] = 'Waiting to sync';
        }
      }
      warningSyncStatus[crop] = 'Waiting to sync';
    }
    if (_warningCheckAt != null && _clock().isBefore(_warningCheckAt!)) return;
    _warningCheckAt = _clock().add(const Duration(seconds: 10));
    try {
      final identity = _verified['sensor'] ?? await client.identity(endpoint);
      if (identity.deviceId != device ||
          identity.kitId != demoKitId ||
          identity.role != 'sensor') {
        throw const FormatException('Sensor identity changed.');
      }
      if (!identity.capabilities.contains('warning_leds_v1')) {
        warningSyncStatus[crop] = 'Update sensor firmware to sync warning LEDs';
        return;
      }
      final code = nodes?['pairingCode'] ?? '';
      if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(code)) {
        warningSyncStatus[crop] =
            'Waiting to sync · pair the sensor in Device setup';
        return;
      }
      final actual = await client.warningConfiguration(endpoint, code);
      if (actual == null || !desired.matches(actual)) {
        await client.setWarnings(endpoint, code, desired);
      }
      _warningConfirmed = fingerprint;
      warningSyncStatus[crop] = 'Saved to kit';
      _warningCheckAt = _clock().add(const Duration(seconds: 30));
    } catch (_) {
      _warningConfirmed = null;
      warningSyncStatus[crop] = 'Waiting to sync';
    }
  }

  String? movementStatus;
  String? _movementVerifiedAddress;
  bool cameraControlActive = false;
  void setCameraControlActive(bool active) {
    if (_disposed || cameraControlActive == active) return;
    cameraControlActive = active;
    // A hold can end during a widget rebuild; notify after that build completes.
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  int _moveSequence = 0;
  final String _controlSession = DateTime.now().microsecondsSinceEpoch
      .toRadixString(16);
  bool get canStream =>
      allowLocalHttp &&
      address(_sensorCrop ?? Crop.tomato, 'camera') != 'cloud://camera' &&
      _verified['camera']?.ready == true &&
      _verified['camera']!.capabilities.contains('stream');
  bool get canMoveCamera =>
      allowLocalHttp &&
      _verified['sensor']?.ready == true &&
      _verified['sensor']!.capabilities.contains('pan_tilt_v1');
  void cameraView(Object owner, bool visible) {
    if (_disposed) return;
    if (visible) {
      _cameraViews.add(owner);
    } else {
      _cameraViews.remove(owner);
    }
    _syncLive();
  }

  void _syncLive() {
    if (_live == null && _cameraViews.isEmpty) return;
    final nodes = assignments.values.where(
      (nodes) => nodes['camera']?.isNotEmpty == true,
    );
    live.configure(
      address: canStream && nodes.isNotEmpty ? nodes.first['camera'] : null,
      visible: _cameraViews.isNotEmpty,
      foreground: _foreground,
      allowed: allowLocalHttp && canStream,
    );
  }

  Future<void> moveCameraDirection(Crop crop, String action) =>
      withPollingPaused(() async {
        await waitForIdle();
        _requireIdle();
        _requireHttp();
        if (!canMoveCamera ||
            !['up', 'down', 'left', 'right', 'center'].contains(action)) {
          throw AppIssue.unsupported;
        }
        final expected = assignments[crop]?['sensorId'];
        if (expected == null) throw AppIssue.identity;
        busy = true;
        movementStatus = 'Moving camera…';
        _idle = Completer<void>();
        notifyListeners();
        try {
          final endpoint = address(crop, 'sensor');
          final identity = _movementVerifiedAddress == endpoint
              ? _verified['sensor']
              : await client.identity(endpoint);
          if (identity == null ||
              identity.kitId != demoKitId ||
              identity.deviceId != expected ||
              identity.role != 'sensor' ||
              !identity.ready ||
              !identity.capabilities.contains('pan_tilt_v1')) {
            throw AppIssue.identity;
          }
          _movementVerifiedAddress = endpoint;
          final request = '$_controlSession-${++_moveSequence}';
          await client.panTilt(
            endpoint,
            deviceId: expected,
            requestId: request,
            action: action,
          );
          movementStatus = action == 'center'
              ? 'Camera returned to center.'
              : 'Camera movement confirmed.';
        } catch (_) {
          _movementVerifiedAddress =
              null; // Reverify before the next deliberate command.
          movementStatus =
              'Movement not confirmed. Check the board before trying again.';
          rethrow; // Never automatically repeat a physical movement.
        } finally {
          busy = false;
          _idle?.complete();
          _idle = null;
          if (!_disposed) notifyListeners();
        }
      });
  Future<void> _sendAppStatus(Crop crop) async {
    final sensorEndpoint = address(crop, 'sensor');
    if (sensorEndpoint.startsWith('cloud://')) return;
    final identity = _verified['sensor'];
    if (identity == null ||
        !identity.capabilities.contains('app_status_v1') ||
        !fresh(crop)) {
      return;
    }
    final at = _clock();
    bool recent(DateTime? date) =>
        date != null &&
        !at.isBefore(date) &&
        at.difference(date).inSeconds < 30;
    final ready =
        _live?.fresh == true ||
        recent(lastCameraPhoto?.$2) ||
        recent(_cameraVerifiedAt);
    try {
      await client.appStatus(
        address(crop, 'sensor'),
        deviceId: identity.deviceId,
        sessionId: _controlSession,
        cameraReady: ready,
        cameraId: assignments[crop]?['cameraId'] ?? '',
      );
    } catch (_) {
      /* A missed heartbeat expires naturally; never interrupt monitoring. */
    }
  }

  Future<void> initializeAppAlerts() async {
    appAlerts.listen(syncAppAlerts);
    try {
      await appAlerts.restore();
      await syncAppAlerts();
    } catch (_) {
      remindersIssue = 'Reminder scheduling is unavailable. Please retry.';
    }
  }

  Future<void> syncAppAlerts() =>
      _alertSync ??= _syncAppAlerts().whenComplete(() => _alertSync = null);
  Future<void> _syncAppAlerts() async {
    if (!appAlerts.supported || _disposed) return;
    try {
      final value = await appAlerts.snapshot();
      watering = WateringReminder.fromJson(value);
      for (final item in value['events'] as List? ?? []) {
        final event = AppAlertEvent.fromJson(item as Map);
        await _storeEvent(event);
      }
      final tap = value['tap'];
      if (tap is Map &&
          ['sensor', 'scheduled', 'watering'].contains(tap['type']) &&
          tap['target'] is String &&
          tap['token'] is String) {
        alertTarget = AlertTarget(tap['type'], tap['target'], tap['token']);
      }
      remindersIssue = null;
    } catch (_) {
      remindersIssue = 'Reminders could not be refreshed. Please retry.';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> saveWatering(int? minute, bool enabled) async {
    if (minute != null && (minute < 0 || minute > 1439) ||
        enabled && minute == null) {
      throw const FormatException('Choose a daily reminder time.');
    }
    if (!appAlerts.supported) throw AppIssue.unsupported;
    if (enabled) await notifications.requestPermission();
    watering = WateringReminder.fromJson(
      await appAlerts.configure(minute, enabled),
    );
    remindersIssue = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> allowPreciseReminders() => appAlerts.requestPrecise();
  Future<void> acknowledgeAlertTarget(String token) async {
    if (alertTarget?.token == token) alertTarget = null;
    try {
      await appAlerts.acknowledge(token);
    } catch (_) {
      remindersIssue = 'This alert could not be marked as opened.';
    }
  }

  Future<void> _storeEvent(AppAlertEvent event) async {
    if (events.any((e) => e.id == event.id)) return;
    await box.put('app-alert-v1/${event.id}', event.toJson());
    events.add(event);
    events.sort((a, b) => b.at.compareTo(a.at));
    while (events.length > 500) {
      await box.delete('app-alert-v1/${events.last.id}');
      events.removeLast();
    }
  }

  Future<void> _announce(AppAlertEvent event, {bool post = true}) async {
    await _storeEvent(event);
    if (post) {
      final posted = appAlerts.supported
          ? await appAlerts.post(event.toJson())
          : await notifications.show(5000, event.title, event.body);
      if (!posted) notificationIssue = AppIssue.permission;
    }
    if (!_disposed) notifyListeners();
  }

  final Box<dynamic> box;
  final HardwareClient client;
  final TomatoClassifier classifier;
  final TomatoScanStore scanStore;
  final MonitoringAlertStore alertStore;
  final MonitoringServiceBridge service;
  final BoardDiscovery discovery;
  Future<void>? _connecting;
  bool _autoDiscovery = false;
  DateTime? _nextDiscovery;
  final Set<String> _blockedRoles = {};
  String? connectionStatus;

  Future<void> connectKit(Crop crop, {bool quietly = false}) {
    return _connecting ??= _connectKit(
      crop,
      quietly: quietly,
    ).whenComplete(() => _connecting = null);
  }

  Future<void> _connectKit(Crop crop, {required bool quietly}) async {
    await waitForIdle();
    if (_disposed) return;
    _requireHttp();
    _autoDiscovery = true;
    _nextDiscovery = _clock().add(const Duration(seconds: 30));
    busy = true;
    backgroundWork = quietly;
    _idle = Completer<void>();
    if (!quietly) connectionStatus = 'Looking for your AgriSense kit…';
    notifyListeners();
    final found = <String, (String, BoardIdentity)>{};
    final legacy = <String>{};
    final conflicts = <String>{};
    final checked = <String>{};
    final candidates = <String, Map<String, (String, BoardIdentity)>>{};
    try {
      for (final role in ['sensor', 'camera']) {
        final saved = address(crop, role);
        if (saved.isEmpty) continue;
        try {
          final identity = await client.identity(saved);
          checked.add(saved);
          final expected = assignments[crop]?['${role}Id'];
          if (identity.kitId == demoKitId &&
              identity.role == role &&
              (expected == null || expected == identity.deviceId)) {
            found[role] = (saved, identity);
          }
        } on HardwareHttpException catch (error) {
          // Existing manually configured firmware remains usable, but is never
          // automatically assigned from an unverified discovery advertisement.
          if (error.status == 404 || error.status == 405) legacy.add(role);
        } catch (_) {
          /* Discovery can recover an address changed by DHCP. */
        }
      }
      var discoveryFailed = false;
      if (found.length < 2 && discovery.supported) {
        try {
          final addresses = await discovery.discover();
          for (final candidate in addresses.toSet()) {
            if (_disposed || !allowLocalHttp) return;
            String normalized;
            try {
              normalized = hardwareAddress(candidate).toString();
            } catch (_) {
              continue;
            }
            if (checked.contains(normalized)) continue;
            try {
              final identity = await client.identity(normalized);
              if (identity.kitId != demoKitId) continue;
              final expected = assignments[crop]?['${identity.role}Id'];
              if (expected != null && expected != identity.deviceId) {
                if (!found.containsKey(identity.role)) {
                  conflicts.add(identity.role);
                }
                continue;
              }
              candidates.putIfAbsent(
                identity.role,
                () => {},
              )[identity.deviceId] = (
                normalized,
                identity,
              );
            } catch (_) {
              /* Reject unreachable or malformed candidates. */
            }
          }
          for (final role in ['sensor', 'camera']) {
            final matches = candidates[role];
            if (matches == null || matches.isEmpty) continue;
            if (matches.length > 1 ||
                (found[role] != null &&
                    !matches.containsKey(found[role]!.$2.deviceId))) {
              conflicts.add(role);
              found.remove(role);
            } else {
              found[role] = matches.values.single;
              conflicts.remove(role);
            }
          }
        } catch (_) {
          discoveryFailed = true;
        }
      }
      if (found.length < 2 && allowLocalHttp && !_disposed) {
        for (final role in ['sensor', 'camera']) {
          if (!found.containsKey(role)) {
            final cloudAddr = 'cloud://$role';
            try {
              final identity = await client.identity(cloudAddr);
              if (identity.kitId == demoKitId && identity.role == role) {
                found[role] = (cloudAddr, identity);
                conflicts.remove(role);
              }
            } catch (_) {}
          }
        }
      }
      if (_disposed || !allowLocalHttp) return;
      final next = Map<String, String>.of(assignments[crop] ?? {});
      var sensorCrop = _sensorCrop ?? crop;
      for (final entry in found.entries) {
        next[entry.key] = entry.value.$1;
        next['${entry.key}Id'] = entry.value.$2.deviceId;
        if (entry.key == 'sensor') sensorCrop = entry.value.$2.sensorCrop!;
      }
      if (found.isNotEmpty) {
        await box.put('shared-kit-v1', {
          'sensorCrop': sensorCrop.name,
          'nodes': next,
        });
        _sensorCrop = sensorCrop;
        for (final value in Crop.values) {
          assignments[value] = Map.of(next);
        }
      }
      for (final role in ['sensor', 'camera']) {
        if (found.containsKey(role)) {
          _verified[role] = found[role]!.$2;
        } else {
          _verified.remove(role);
        }
      }
      _movementVerifiedAddress = found['sensor']?.$1;
      _warningCheckAt = null;
      _warningConfirmed = null;
      _cameraVerifiedAt = _verified['camera']?.ready == true ? _clock() : null;
      for (final role in ['sensor', 'camera']) {
        final identity = found[role]?.$2;
        if (identity != null && identity.ready ||
            legacy.contains(role) && !conflicts.contains(role)) {
          _blockedRoles.remove(role);
        } else {
          _blockedRoles.add(role);
        }
        if (role == 'camera') {
          cameraStatus[crop] = identity?.ready == true
              ? 'Received'
              : identity != null
              ? 'Camera unavailable'
              : 'Unavailable';
        } else if (identity == null || !identity.ready) {
          status[crop] = 'Unavailable';
        }
      }
      connectionStatus = conflicts.isNotEmpty
          ? 'Conflicting ${conflicts.join(' and ')} identities. Keep only your intended kit powered and retry.'
          : found.isEmpty && legacy.isEmpty
          ? discoveryFailed
                ? 'Cannot find the kit. Check Wi-Fi and app permissions, then retry.'
                : 'No kit found. Turn on the kit and use the same Wi-Fi, then retry.'
          : found.length == 2 && _blockedRoles.isEmpty
          ? (found.values.any((e) => e.$1.startsWith('cloud://'))
                ? 'Kit connected via Cloud. Readings will update automatically.'
                : 'Kit connected. Readings will update automatically.')
          : legacy.isNotEmpty
          ? 'Using the saved kit connection.'
          : 'Kit partly connected. Retrying the missing device…';
    } finally {
      busy = false;
      backgroundWork = false;
      _idle?.complete();
      _idle = null;
      _syncLive();
      if (!_disposed) notifyListeners();
    }
  }

  Future<Uint8List> _cameraBytes(Crop crop) =>
      live.withPaused(() => _stillBytes(crop));
  Future<Uint8List> _stillBytes(Crop crop) async {
    if (_blockedRoles.contains('camera')) throw AppIssue.camera;
    final cameraAddress = address(crop, 'camera');
    if (cameraAddress.startsWith('cloud://')) {
      final expected = assignments[crop]?['cameraId'] ?? '';
      if (expected.isNotEmpty) {
        client.cloud.lastVerifiedCameraId = expected;
      }
      return client.capture(cameraAddress);
    }
    final expected = assignments[crop]?['cameraId'];
    if (expected != null) {
      final identity = await client.identity(address(crop, 'camera'));
      if (identity.deviceId != expected ||
          identity.kitId != demoKitId ||
          identity.role != 'camera' ||
          !identity.ready) {
        throw AppIssue.camera;
      }
    }
    return client.capture(address(crop, 'camera'));
  }

  final List<MonitoringAlert> alerts = [];
  final Map<String, TomatoScan> _pendingResults = {};
  int _run = 0;
  int revision = 0;
  final SensorNotifications notifications;
  final DateTime Function() _clock;
  final Map<Crop, SensorAlertSettings> notificationSettings = {};
  final Map<Crop, SensorAlertTracker> _alertTrackers = {};
  String? notificationStatus;
  AppIssue? notificationIssue;
  Crop? _pollingCrop;
  Crop? _requestedPollingCrop;
  bool _foreground = true;
  bool backgroundActive = false;
  bool backgroundEnabled = false;
  int _pollingPauses = 0;
  final Map<Crop, Map<String, String>> assignments = {};
  Crop? _sensorCrop;
  DailyPhotoSchedule? _sharedSchedule;
  final List<HardwareSample> samples = [];
  final List<AlertPhoto> alertPhotos = [];
  final Map<Crop, String> status = {};
  bool busy = false;
  bool backgroundWork = false;
  bool get userBusy => busy && !backgroundWork;
  Completer<void>? _idle;
  Future<void> waitForIdle() async {
    await _idle?.future;
  }

  final Map<Crop, DailyPhotoSchedule> photoSchedules = {};
  final Map<Crop, String> cameraStatus = {};
  final Map<Crop, DateTime> _cameraRetryAt = {};
  String? _lastKitCaptureSlot;
  final Set<String> _scheduleAttempts = {};
  String? automaticStatus;
  bool allowLocalHttp = false;
  String? error;
  AppIssue? issue;
  Timer? _timer;
  bool _disposed = false;
  static const _historyKey = 'hardware-readings-v1';

  void load() {
    for (final key in box.keys.whereType<String>().where(
      (key) => key.startsWith('app-alert-v1/'),
    )) {
      try {
        events.add(AppAlertEvent.fromJson(box.get(key) as Map));
      } catch (_) {
        /* Retain unreadable records unchanged. */
      }
    }
    events.sort((a, b) => b.at.compareTo(a.at));
    backgroundEnabled =
        box.get(
          'background-monitoring-enabled-v1',
          defaultValue: service.supported,
        ) ==
        true;
    this.alerts.addAll(alertStore.load());
    for (final item
        in box.get('notification-photos-v1', defaultValue: []) as List) {
      try {
        alertPhotos.add(AlertPhoto.fromJson(item as Map));
      } catch (_) {
        notificationStatus = 'A saved alert photo could not be loaded.';
      }
    }
    final alerts =
        box.get('foreground-notification-rules-v1', defaultValue: {}) as Map;
    for (final crop in Crop.values) {
      try {
        photoSchedules[crop] = DailyPhotoSchedule.fromJson(
          box.get(
                'daily-photos-v1-${crop.name}',
                defaultValue: <String, dynamic>{},
              )
              as Map,
        );
      } catch (_) {
        photoSchedules[crop] = const DailyPhotoSchedule();
      }
      try {
        final saved = alerts[crop.name];
        final unconfigured =
            saved is Map &&
            saved['enabled'] == true &&
            saved['rules'] is List &&
            !(saved['rules'] as List).any(
              (r) => r is Map && r['enabled'] == true,
            );
        notificationSettings[crop] = saved is Map && !unconfigured
            ? SensorAlertSettings.fromJson(saved)
            : SensorAlertSettings.initial;
      } catch (_) {
        notificationSettings[crop] = const SensorAlertSettings();
        notificationStatus =
            'Saved notification rules were invalid; configure them again.';
      }
    }
    allowLocalHttp =
        box.get('allow-local-hardware-http', defaultValue: true) == true;
    _scheduleAttempts.addAll(
      (box.get('daily-photo-attempts-v1', defaultValue: []) as List)
          .whereType<String>()
          .map(
            (key) =>
                key.replaceFirst(RegExp(r'^(tomato|chili|eggplant)-'), 'kit-'),
          ),
    );
    final raw =
        box.get('hardware-nodes-v1', defaultValue: <String, dynamic>{}) as Map;
    for (final crop in Crop.values) {
      assignments[crop] = Map<String, String>.from(
        raw[crop.name] as Map? ?? {},
      );
    }
    final shared = box.get('shared-kit-v1');
    if (shared is Map) {
      _sensorCrop = Crop.values.byName(shared['sensorCrop'] as String);
      final nodes = Map<String, String>.from(shared['nodes'] as Map);
      for (final crop in Crop.values) {
        assignments[crop] = Map.of(nodes);
      }
    } else {
      // Preserve legacy entries on disk; use one kit consistently from now on.
      final owner = Crop.values.firstWhere(
        (c) => assignments[c]?['sensor']?.isNotEmpty == true,
        orElse: () => Crop.tomato,
      );
      _sensorCrop = assignments[owner]?['sensor']?.isNotEmpty == true
          ? owner
          : null;
      final nodes = Map<String, String>.of(assignments[owner] ?? {});
      for (final entry in assignments.values) {
        if (nodes['camera']?.isNotEmpty != true &&
            entry['camera']?.isNotEmpty == true) {
          nodes['camera'] = entry['camera']!;
        }
      }
      for (final crop in Crop.values) {
        assignments[crop] = Map.of(nodes);
      }
    }
    final savedSchedule = box.get('shared-daily-photos-v1');
    if (savedSchedule is Map) {
      try {
        _sharedSchedule = DailyPhotoSchedule.fromJson(savedSchedule);
      } catch (_) {
        _sharedSchedule = const DailyPhotoSchedule();
        automaticStatus = 'Photo times could not be loaded. Please edit times.';
      }
    } else {
      final candidates = photoSchedules.values
          .where((s) => s.minutes.isNotEmpty)
          .toList();
      _sharedSchedule = candidates.isEmpty
          ? const DailyPhotoSchedule()
          : candidates.first;
      if (candidates.any(
        (s) =>
            s.enabled != _sharedSchedule!.enabled ||
            !listEquals(
              s.minutes.toList()..sort(),
              _sharedSchedule!.minutes.toList()..sort(),
            ),
      )) {
        _sharedSchedule = DailyPhotoSchedule(minutes: candidates.first.minutes);
        automaticStatus =
            'Different photo times were saved for each crop. Edit times to confirm one shared schedule.';
      }
    }
    samples.addAll(
      (box.get(_historyKey, defaultValue: []) as List).map(
        (e) => HardwareSample.fromSaved(e as Map),
      ),
    );
    samples.sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
  }

  String address(Crop crop, String kind) => assignments[crop]?[kind] ?? '';
  Future<void> _saveSharedKit(Crop crop) async {
    final nodes = Map<String, String>.of(assignments[crop] ?? {});
    final sensorCrop = _sensorCrop ?? crop;
    await box.put('shared-kit-v1', {
      'sensorCrop': sensorCrop.name,
      'nodes': nodes,
    });
    _sensorCrop = sensorCrop;
    for (final item in Crop.values) {
      assignments[item] = Map.of(nodes);
    }
  }

  List<HardwareSample> readings(Crop crop) =>
      samples.where((r) => r.crop == crop).toList();

  DateTime? trendStart(Crop crop) => DateTime.tryParse(
    box.get('trend-start-v1-${crop.name}', defaultValue: '') as String,
  );

  Future<void> resetTrendView(Crop crop) async {
    await box.put('trend-start-v1-${crop.name}', _clock().toIso8601String());
    notifyListeners();
  }

  Future<void> restoreTrendView(Crop crop) async {
    await box.delete('trend-start-v1-${crop.name}');
    notifyListeners();
  }

  HardwareSample? latest(Crop crop) {
    final live = _liveReadings[crop];
    if (live != null &&
        (assignments[crop]?['sensorId'] == null ||
            live.deviceId == assignments[crop]?['sensorId'])) {
      return live;
    }
    final items = samples
        .where((s) => s.deviceId == assignments[crop]?['sensorId'])
        .toList();
    if (items.isEmpty) return readings(crop).lastOrNull;
    items.sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
    return items.isEmpty ? null : items.last;
  }

  String? _soilCalibrationKey(Crop crop, [HardwareSample? sample]) {
    final endpoint = address(crop, 'sensor');
    if (endpoint.isEmpty) return null;
    sample ??= latest(crop);
    final assignedId = assignments[crop]?['sensorId'] ?? '';
    if (assignedId.isNotEmpty &&
        sample != null &&
        sample.deviceId != assignedId) {
      return null;
    }
    final id = assignedId.isNotEmpty ? assignedId : sample?.deviceId ?? '';
    return 'soil-display-calibration-v1/${id.isNotEmpty ? 'id:$id' : 'address:$endpoint'}';
  }

  SoilCalibration? soilCalibration(Crop crop, [HardwareSample? sample]) {
    final key = _soilCalibrationKey(crop, sample);
    return key == null ? null : SoilCalibration.tryFromJson(box.get(key));
  }

  double? soilPercentage(HardwareSample sample) => sample.soilCalibrated
      ? sample.soil
      : soilCalibration(sample.crop, sample)?.percentage(sample.soilRaw);

  Future<void> saveSoilCalibration(Crop crop, SoilCalibration? value) async {
    final key = _soilCalibrationKey(crop);
    if (key == null) throw const FormatException('Connect your sensor first.');
    if (value == null) {
      await box.delete(key);
    } else {
      await box.put(key, value.toJson());
    }
    if (!_disposed) notifyListeners();
  }

  bool fresh(Crop crop) {
    final sample = latest(crop);
    return status[crop] == 'Received' &&
        sample != null &&
        !_clock().isBefore(sample.receivedAt) &&
        _clock().difference(sample.receivedAt).inSeconds <= 30;
  }

  /// Freeze context at capture/trigger time, never at a later history-view time.
  TomatoScan attachScanContext(
    TomatoScan scan, {
    required DateTime at,
    HardwareSample? trigger,
  }) {
    if (scan.source == 'upload') return scan;
    HardwareSample? sample;
    if (scan.source == 'auto') {
      sample = trigger;
    } else if (scan.source == 'camera') {
      final device = assignments[scan.crop]?['sensorId'];
      if (device != null && device.isNotEmpty) {
        final candidates =
            [
                  ...samples,
                  if (_liveReadings[scan.crop] != null)
                    _liveReadings[scan.crop]!,
                ]
                .where(
                  (s) =>
                      s.crop == scan.crop &&
                      s.deviceId == device &&
                      !s.receivedAt.isAfter(at),
                )
                .toList()
              ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
        if (candidates.isNotEmpty) sample = candidates.first;
      }
    }
    if (!recentCropSample(sample, at, scan.crop)) return scan;
    final assessment = TomatoAssessment.assess(
      crop: scan.crop,
      label: scan.label,
      context: scan.source == 'auto'
          ? 'Alert trigger readings'
          : 'Readings preceding camera capture',
      sample: sample!,
      history: samples,
      at: at,
    );
    return TomatoScan.fromJson({
      ...scan.toJson(),
      'sensor_context': {
        ...sample.toJson(),
        if (!sample.soilCalibrated &&
            soilCalibration(scan.crop, sample) != null)
          'soil_display_calibration': soilCalibration(
            scan.crop,
            sample,
          )!.toJson(),
      },
      'assessment': assessment.toJson(),
    });
  }

  Future<void> assign(Crop crop, String kind, String input) =>
      withPollingPaused(() async {
        _requireIdle();
        if (kind != 'camera' && kind != 'sensor') {
          throw const FormatException('Unknown device type.');
        }
        final value = input.trim().isEmpty
            ? ''
            : hardwareAddress(input).toString();
        if (value != address(crop, kind)) await _stopAutomaticFor({crop});
        final next = {
          for (final entry in assignments.entries)
            entry.key: Map<String, String>.of(entry.value),
        };
        next.putIfAbsent(crop, () => {})[kind] = value;
        if (kind == 'sensor' && value != address(crop, kind)) {
          next[crop]!.remove('sensorId');
          next[crop]!.remove('pairingCode');
        }
        await box.put('hardware-nodes-v1', {
          for (final e in next.entries) e.key.name: e.value,
        });
        assignments
          ..clear()
          ..addAll(next);
        if (kind == 'sensor') _sensorCrop = crop;
        await _saveSharedKit(crop);
        status.remove(crop);
        notifyListeners();
      });

  /// Forget only this phone's endpoint, even when the board is unreachable.
  /// Retain identity/pairing for re-adding the same sensor; no board command.
  Future<void> clearSavedAddress(Crop crop, String kind) =>
      withPollingPaused(() async {
        _requireIdle();
        if (kind != 'camera' && kind != 'sensor') {
          throw const FormatException('Unknown device type.');
        }
        final next = {
          for (final entry in assignments.entries)
            entry.key: Map<String, String>.of(entry.value),
        };
        next[crop]?.remove(kind);
        await box.put('hardware-nodes-v1', {
          for (final entry in next.entries) entry.key.name: entry.value,
        });
        assignments
          ..clear()
          ..addAll(next);
        await _saveSharedKit(crop);
        status.remove(crop);
        if (kind == 'sensor') _alertTrackers[crop]?.reset();
        error = null;
        issue = null;
        notifyListeners();
      });

  void _requireIdle() {
    if (_disposed || busy) {
      throw const FormatException(
        'Wait for the current hardware request to finish.',
      );
    }
  }

  void _requireHttp() {
    if (!allowLocalHttp) {
      throw const FormatException(
        'Enable local hardware HTTP in Devices first.',
      );
    }
  }

  /// The board confirms persistent configuration before local mappings move.
  /// On an interrupted reply, the old mapping remains and wrong-crop readings
  /// are rejected. Retrying this operation is safe and idempotent.
  Future<void> configureSensor(
    Crop crop,
    String input,
    String code,
  ) => withPollingPaused(() async {
    _requireIdle();
    _requireHttp();
    final endpoint = hardwareAddress(input).toString();
    if (assignments.values.any((a) => a['camera'] == endpoint)) {
      throw const FormatException(
        'This address is assigned as a camera. Check the sensor IP.',
      );
    }
    final existing = assignments.values.where((a) => a['sensor'] == endpoint);
    final old = existing.isEmpty ? <String, String>{} : existing.first;
    final selected = assignments[crop] ?? <String, String>{};
    final reuseMovedSensor =
        code.trim().isEmpty && old.isEmpty && selected['sensorId'] != null;
    final key = code.trim().isEmpty
        ? (reuseMovedSensor ? selected['pairingCode'] : old['pairingCode']) ??
              ''
        : code.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(key)) {
      throw const FormatException(
        'Enter the 32-character pairing code printed by the sensor.',
      );
    }
    busy = true;
    error = null;
    notifyListeners();
    var commandSent = false;
    try {
      final before = await client.configuration(endpoint);
      if (old['sensorId'] != null && old['sensorId'] != before.deviceId) {
        throw const FormatException(
          'A different sensor is using this IP. Remove the old assignment before pairing a replacement.',
        );
      }
      if (reuseMovedSensor && selected['sensorId'] != before.deviceId) {
        throw const FormatException(
          'A different sensor is using this IP. Supply its own code to pair a replacement.',
        );
      }
      if (endpoint != address(crop, 'sensor') &&
          selected['sensorId'] != null &&
          (selected['sensorId'] == before.deviceId ||
              address(crop, 'sensor').isNotEmpty)) {
        // DHCP may have moved this same board. Verify its identity first, then
        // stop automation at its reachable address rather than the stale IP.
        await _stopAutomaticAt(
          crop,
          selected['sensorId'] == before.deviceId
              ? endpoint
              : address(crop, 'sensor'),
        );
      }
      commandSent = true;
      await client.setCrop(endpoint, crop, before.deviceId, key);
      final confirmed = await client.configuration(endpoint);
      if (confirmed.crop != crop || confirmed.deviceId != before.deviceId) {
        throw const FormatException(
          'Sensor verification failed. Retry the same assignment.',
        );
      }
      final next = {
        for (final e in assignments.entries)
          e.key: Map<String, String>.of(e.value),
      };
      for (final entry in next.values) {
        if (entry['sensor'] == endpoint ||
            entry['sensorId'] == confirmed.deviceId) {
          entry.remove('sensor');
          entry.remove('sensorId');
          entry.remove('pairingCode');
        }
      }
      next.putIfAbsent(crop, () => {}).addAll({
        'sensor': endpoint,
        'sensorId': confirmed.deviceId,
        'pairingCode': key,
      });
      await box.put('hardware-nodes-v1', {
        for (final e in next.entries) e.key.name: e.value,
      });
      assignments
        ..clear()
        ..addAll(next);
      _sensorCrop = crop;
      _warningCheckAt = null;
      _warningConfirmed = null;
      await _saveSharedKit(crop);
      status.clear();
      status[crop] = 'Crop confirmed: ${crop.label}';
      await _syncWarnings(crop);
    } catch (e) {
      status.clear();
      if (e is FormatException) rethrow;
      throw FormatException(
        commandSent
            ? 'Could not confirm or save the assignment. The sensor may already have changed. Retry the same crop; existing history is unchanged.'
            : 'Cannot reach the sensor. Check Wi-Fi, its IP, and the updated firmware.',
      );
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  });

  Future<void> moveCamera(Crop crop, String input) => withPollingPaused(
    () async {
      _requireIdle();
      final endpoint = hardwareAddress(input).toString();
      if (assignments.values.any((a) => a['sensor'] == endpoint)) {
        throw const FormatException(
          'This address is assigned as a sensor. Check the camera IP.',
        );
      }
      await _stopAutomaticFor({
        if (address(crop, 'camera') != endpoint) crop,
        for (final entry in assignments.entries)
          if (entry.key != crop && entry.value['camera'] == endpoint) entry.key,
      });
      final next = {
        for (final e in assignments.entries)
          e.key: Map<String, String>.of(e.value),
      };
      for (final entry in next.values) {
        if (entry['camera'] == endpoint) entry.remove('camera');
      }
      next.putIfAbsent(crop, () => {})['camera'] = endpoint;
      await box.put('hardware-nodes-v1', {
        for (final e in next.entries) e.key.name: e.value,
      });
      assignments
        ..clear()
        ..addAll(next);
      await _saveSharedKit(crop);
      notifyListeners();
    },
  );

  Future<void> refresh(Crop crop) async {
    if (busy || _disposed || !allowLocalHttp) return;
    final endpoint = address(crop, 'sensor');
    if (endpoint.isEmpty) return;
    if (_blockedRoles.contains('sensor')) {
      status[crop] = 'Unavailable';
      return;
    }
    busy = true;
    backgroundWork = true;
    _idle = Completer<void>();
    error = null;
    notifyListeners();
    try {
      final measured = await client.read(endpoint, _sensorCrop ?? crop);
      // Validate the firmware protocol above, then tag new app records with
      // the crop selected when this request started. Old records stay intact.
      final reading = HardwareSample.fromSaved({
        ...measured.toJson(),
        'crop': crop.name,
      });
      final expectedId = assignments[crop]?['sensorId'];
      if (expectedId != null && reading.deviceId != expectedId) {
        throw const FormatException(
          'A different sensor answered. Check the IP and pair the intended board.',
        );
      }
      if (_disposed) return;
      final saved = readings(crop).lastOrNull;
      final previous = _liveReadings[crop] ?? saved;
      final duplicate =
          previous?.deviceId == reading.deviceId && previous?.id == reading.id;
      final saveDue =
          saved == null ||
          saved.deviceId != reading.deviceId ||
          _clock().difference(_lastHistoryWrite[crop] ?? saved.receivedAt) >=
              const Duration(seconds: 10);
      if (!duplicate) _liveReadings[crop] = reading;
      if (saveDue &&
          !samples.any((r) => r.crop == reading.crop && r.id == reading.id)) {
        final next = [...samples, reading];
        // Bound storage, keeping the most recent 5,000 samples per crop.
        while (next.where((r) => r.crop == reading.crop).length > 5000) {
          next.removeAt(next.indexWhere((r) => r.crop == reading.crop));
        }
        try {
          await box.put(_historyKey, next.map((r) => r.toJson()).toList());
        } catch (_) {
          throw AppIssue.write;
        }
        samples
          ..clear()
          ..addAll(next);
        _lastHistoryWrite[crop] = _clock();
      }
      status[crop] = 'Received';
      final currentRules = notificationSettings[crop];
      if (currentRules?.autoBaseline == true) {
        final initialized = currentRules!.initializeFrom(reading);
        if (!identical(initialized, currentRules)) {
          await box.put('foreground-notification-rules-v1', {
            ...box.get('foreground-notification-rules-v1', defaultValue: {})
                as Map,
            crop.name: initialized.toJson(),
          });
          notificationSettings[crop] = initialized;
          _warningCheckAt = null;
          _warningConfirmed = null;
        }
      }
      try {
        if (!duplicate) await _notifyReading(crop, reading);
      } catch (_) {
        notificationIssue = AppIssue.write;
        notificationStatus =
            'Sensor reading saved, but the alert outcome could not be saved.';
      }
      if (_pollingPauses == 0) await _syncWarnings(crop);
    } catch (e) {
      status[crop] = 'Unavailable';
      _alertTrackers[crop]?.reset();
      issue = AppIssue.from(e, fallback: AppIssue.connection);
      error = e is FormatException
          ? e.message
          : 'Could not read or save ${crop.label} sensor data. Check Wi-Fi, IP, and device storage.';
    } finally {
      busy = false;
      backgroundWork = false;
      _idle?.complete();
      _idle = null;
      if (!_disposed) notifyListeners();
    }
  }

  void _checkAutomaticIdentity(Crop crop, AutomaticCapture settings) {
    if (settings.crop != crop ||
        settings.deviceId != assignments[crop]?['sensorId']) {
      throw const FormatException(
        'Sensor identity or crop changed. Check its assignment first.',
      );
    }
  }

  Future<T> _automaticRequest<T>(Future<T> Function() action) =>
      withPollingPaused(() async {
        _requireIdle();
        _requireHttp();
        busy = true;
        notifyListeners();
        try {
          return await action();
        } finally {
          busy = false;
          if (!_disposed) notifyListeners();
        }
      });

  Future<AutomaticCapture> loadAutomatic(Crop crop) =>
      _automaticRequest(() async {
        if (address(crop, 'sensor').isEmpty ||
            assignments[crop]?['sensorId'] == null) {
          throw const FormatException('Pair a sensor for this crop first.');
        }
        final result = await client.automaticConfiguration(
          address(crop, 'sensor'),
          assignments[crop]!['pairingCode']!,
        );
        if (result == null) {
          throw const FormatException(
            'Upload the updated sensor firmware to use automatic capture.',
          );
        }
        _checkAutomaticIdentity(crop, result);
        return result;
      });

  Future<AutomaticCapture> saveAutomatic(
    Crop crop, {
    required bool enabled,
    required List<CaptureRule> rules,
    required int duration,
    required int cooldown,
    required String cameraCode,
  }) => _automaticRequest(() async {
    final sensor = address(crop, 'sensor');
    final code = assignments[crop]?['pairingCode'] ?? '';
    final current = await client.automaticConfiguration(sensor, code);
    if (current == null) {
      throw const FormatException('Upload the updated sensor firmware first.');
    }
    _checkAutomaticIdentity(crop, current);
    String camera = '', cameraId = '';
    final key = cameraCode.trim().toLowerCase();
    if (enabled) {
      if (address(crop, 'camera').isEmpty) {
        throw const FormatException(
          'Assign this crop’s camera in Devices first.',
        );
      }
      final uri = hardwareAddress(address(crop, 'camera'));
      if (uri.port != 80) {
        throw const FormatException(
          'Automatic capture requires camera port 80.',
        );
      }
      camera = uri.host;
      cameraId = await client.cameraAutomationIdentity(camera, key);
    }
    final requested = AutomaticCapture(
      deviceId: current.deviceId,
      crop: crop,
      enabled: enabled,
      camera: camera,
      cameraId: cameraId,
      duration: duration,
      cooldown: cooldown,
      rules: rules,
      soilCalibrated: current.soilCalibrated,
    );
    await client.setAutomatic(sensor, code, requested, cameraCode: key);
    final confirmed = await client.automaticConfiguration(sensor, code);
    if (confirmed == null) {
      throw const FormatException(
        'Could not verify settings. Reload them before retrying.',
      );
    }
    client.verifyAutomatic(requested, confirmed);
    return confirmed;
  });

  // An old board must stop triggering before its local mapping is removed/moved.
  Future<void> _stopAutomaticFor(Set<Crop> crops) async {
    for (final crop in {if (crops.isNotEmpty) _sensorCrop ?? crops.first}) {
      if (assignments[crop]?['sensorId'] == null ||
          address(crop, 'sensor').isEmpty) {
        continue;
      }
      await _automaticRequest(
        () => _stopAutomaticAt(crop, address(crop, 'sensor')),
      );
    }
  }

  // Caller owns the request lock. Overrides are used only after matching the
  // saved sensor identity at its new address.
  Future<void> _stopAutomaticAt(Crop crop, String sensor) async {
    crop = _sensorCrop ?? crop;
    final code = assignments[crop]?['pairingCode'] ?? '';
    final current = await client.automaticConfiguration(sensor, code);
    if (current == null) return;
    _checkAutomaticIdentity(crop, current);
    if (!current.enabled) return;
    final off = AutomaticCapture(deviceId: current.deviceId, crop: crop);
    await client.setAutomatic(sensor, code, off);
    final check = await client.automaticConfiguration(sensor, code);
    if (check == null) {
      throw const FormatException(
        'Could not confirm automatic capture is off. Retry before moving devices.',
      );
    }
    client.verifyAutomatic(off, check);
  }

  Future<Uint8List> capture(Crop crop) {
    return withPollingPaused(() async {
      await waitForIdle();
      _requireIdle();
      _requireHttp();
      final endpoint = address(crop, 'camera');
      if (endpoint.isEmpty) throw AppIssue.assignment;
      _lastKitCaptureSlot = _slot(crop, _clock());
      try {
        final bytes = await _capture(crop);
        cameraStatus[crop] = 'Received';
        return bytes;
      } catch (error) {
        _cameraFailed(crop, error);
        rethrow;
      }
    });
  }

  Future<Uint8List> _capture(Crop crop) async {
    busy = true;
    notifyListeners();
    try {
      final bytes = await _cameraBytes(crop);
      lastCameraOriginal = bytes;
      await compute(previewPhoto, bytes);
      lastCameraPhoto = (bytes, _clock());
      return bytes;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void bindService() => service.listen((event) {
    if (event == 'stopRequested' ||
        (event == 'serviceStopped' && backgroundActive)) {
      backgroundActive = false;
      stopPolling(stopService: false);
      if (!_disposed) notifyListeners();
    } else if (event == 'activityResumed') {
      setForeground(true);
    } else if (event == 'activityPaused') {
      setForeground(false, resetDuration: !backgroundActive);
    }
  });

  Future<void> setBackgroundEnabled(bool value) async {
    _requireIdle();
    if (!_foreground) throw AppIssue.background;
    if (value && !service.supported) throw AppIssue.background;
    await box.put('background-monitoring-enabled-v1', value);
    backgroundEnabled = value;
    if (polling && value) {
      try {
        await _startService(_requestedPollingCrop!);
      } catch (_) {
        stopPolling();
        rethrow;
      }
    } else if (!value) {
      backgroundActive = false;
      await service.stop();
      if (!_foreground) _pausePolling(resetDuration: true);
    }
    notifyListeners();
  }

  Future<void> _startService(Crop crop) async {
    if (!_foreground || !service.supported) throw AppIssue.background;
    if (!await service.start(crop.label)) throw AppIssue.background;
    backgroundActive = true;
  }

  Future<void> startMonitoring(Crop crop) async {
    await waitForIdle();
    _requireIdle();
    _requireHttp();
    if (!_autoDiscovery &&
        address(crop, 'sensor').isEmpty &&
        address(crop, 'camera').isEmpty) {
      throw AppIssue.assignment;
    }
    await _saveSharedKit(crop);
    await box.put('shared-daily-photos-v1', schedule(crop).toJson());
    if (backgroundEnabled) await _startService(crop);
    startPolling(crop);
    notifyListeners();
  }

  // One controller owns all requests, whether or not an Activity is attached.
  void startPolling(Crop crop) {
    stopPolling(stopService: false);
    if (!allowLocalHttp) return;
    _requestedPollingCrop = crop;
    _resumePolling();
    if (pollingActive) unawaited(monitorTick(crop));
  }

  void _pausePolling({bool resetDuration = false}) {
    _timer?.cancel();
    _timer = null;
    _pollingCrop = null;
    if (resetDuration) {
      for (final tracker in _alertTrackers.values) {
        tracker.reset();
      }
    }
  }

  void _resumePolling() {
    final crop = _requestedPollingCrop;
    if (_disposed ||
        (!_foreground && !backgroundActive) ||
        _pollingPauses > 0 ||
        !allowLocalHttp ||
        crop == null ||
        (!_autoDiscovery &&
            address(crop, 'sensor').isEmpty &&
            address(crop, 'camera').isEmpty) ||
        _timer != null) {
      return;
    }
    _pollingCrop = crop;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final selected = _requestedPollingCrop;
      if (selected != null) unawaited(monitorTick(selected));
    });
  }

  /// Crop selection changes the model for future checks, not the kit connection.
  void selectMonitoringCrop(Crop crop) {
    if (_disposed || !polling) return;
    if (_requestedPollingCrop != crop) _alertTrackers.clear();
    if (_requestedPollingCrop != crop) {
      _warningCheckAt = null;
      _warningConfirmed = null;
    }
    _requestedPollingCrop = crop;
    if (_timer != null) _pollingCrop = crop;
    notifyListeners();
  }

  void stopPolling({bool stopService = true}) {
    _run++;
    _requestedPollingCrop = null;
    _pausePolling(resetDuration: true);
    if (stopService && backgroundActive) {
      backgroundActive = false;
      unawaited(
        service.stop().catchError((Object _) {
          notificationIssue = AppIssue.background;
        }),
      );
    }
  }

  /// Settings/diagnosis can pause requests without changing the user's ON switch.
  Future<T> withPollingPaused<T>(Future<T> Function() action) async {
    _pollingPauses++;
    _pausePolling();
    try {
      return await action();
    } finally {
      _pollingPauses--;
      _resumePolling();
      if (!_disposed) notifyListeners();
    }
  }

  void setForeground(bool active, {bool resetDuration = false}) {
    _foreground = active;
    _syncLive();
    if (active || backgroundActive) {
      _resumePolling();
    } else {
      _pausePolling(resetDuration: resetDuration);
    }
    if (!_disposed) notifyListeners();
  }

  bool get polling => _requestedPollingCrop != null;
  bool get pollingActive =>
      _timer != null &&
      (_foreground || backgroundActive) &&
      _pollingPauses == 0;
  String get monitoringStatus => !polling
      ? 'Monitoring off'
      : !_foreground && !backgroundActive
      ? 'Paused while the app is not active; resumes when you return.'
      : _pollingPauses > 0
      ? 'Paused during settings or analysis; resumes automatically.'
      : _timer == null
      ? 'Waiting for a sensor assignment.'
      : backgroundActive
      ? 'Checking sensors every second · background enabled'
      : 'Checking sensors every second';

  Future<void> saveNotificationSettings(
    Crop crop,
    SensorAlertSettings settings,
  ) => withPollingPaused(() async {
    _requireIdle();
    settings.validate();
    if (settings.enabled &&
        settings.capturePhoto &&
        address(crop, 'camera').isEmpty) {
      throw const FormatException(
        'Assign a camera to this crop in Devices before enabling alert photos.',
      );
    }
    busy = true;
    notifyListeners();
    try {
      final permission =
          !settings.enabled ||
          !settings.showNotifications ||
          await notifications.requestPermission();
      if (settings.analyzePhoto && !classifier.supports(crop)) {
        throw AppIssue.unsupported;
      }
      await box.put('foreground-notification-rules-v1', {
        ...box.get('foreground-notification-rules-v1', defaultValue: {}) as Map,
        crop.name: settings.toJson(),
      });
      notificationSettings[crop] = settings;
      _warningCheckAt = null;
      _warningConfirmed = null;
      await _syncWarnings(crop);
      _alertTrackers.remove(crop);
      notificationIssue = permission ? null : AppIssue.permission;
      notificationStatus = permission
          ? 'Monitoring settings saved.'
          : 'Settings saved. Android notifications blocked; capture and analysis can still run.';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  });

  Future<void> testNotification(Crop crop) async {
    if (notificationSettings[crop]?.enabled != true ||
        notificationSettings[crop]?.showNotifications != true) {
      throw const FormatException(
        'Enable and save notifications for this crop first.',
      );
    }
    if (!await notifications.show(
      5100 + crop.index,
      'AgriSense notification test',
      '${crop.label}: notifications are working. This is a test, not a sensor alert.',
    )) {
      throw const FormatException(
        'Notification not posted. Check Android notification settings and keep the app open.',
      );
    }
  }

  AlertPhoto? photoFor(String id) {
    final matches = alertPhotos.where((p) => p.alertId == id);
    return matches.isEmpty ? null : matches.last;
  }

  Future<void> _saveAlert(MonitoringAlert alert) async {
    await alertStore.save(alert);
    alerts
      ..clear()
      ..addAll(alertStore.load());
    if (!_disposed) notifyListeners();
  }

  Future<void> reconcileAlerts() async {
    final results = {for (final scan in scanStore.load()) scan.id: scan};
    for (final alert in List<MonitoringAlert>.of(alerts)) {
      if (!alert.unfinished &&
          alert.state != 'save_failed' &&
          alert.state != 'interrupted') {
        continue;
      }
      await _saveAlert(
        alert.change(
          results.containsKey(alert.resultId) ? 'completed' : 'interrupted',
        ),
      );
    }
  }

  DailyPhotoSchedule schedule(Crop crop) =>
      _sharedSchedule ?? photoSchedules[crop] ?? const DailyPhotoSchedule();

  Future<void> saveSchedule(Crop crop, DailyPhotoSchedule value) async {
    value.validate();
    await box.put('shared-daily-photos-v1', value.toJson());
    _sharedSchedule = value;
    for (final item in Crop.values) {
      photoSchedules[item] = value;
    }
    notifyListeners();
  }

  String _slot(Crop crop, DateTime at) =>
      'kit-${at.year}-${at.month}-${at.day}-${at.hour * 60 + at.minute}';

  void _cameraFailed(Crop crop, [Object? error]) {
    cameraStatus[crop] = error is TimeoutException
        ? 'Timed out'
        : error is SocketException
        ? 'Unreachable'
        : error is HardwareHttpException && error.status == 503 ||
              error == AppIssue.camera
        ? 'Camera unavailable'
        : 'Capture failed';
    _cameraRetryAt[crop] = _clock().add(const Duration(seconds: 30));
  }

  String cameraMessage(Crop crop) => switch (cameraStatus[crop]) {
    'Received' => 'Camera ready',
    'Camera unavailable' => 'Camera is not ready',
    'Capture failed' => 'Photo capture failed. Try again.',
    'Timed out' => 'Camera took too long. Retrying…',
    'Unreachable' || 'Unavailable' => 'Camera did not respond. Retrying…',
    _ => 'Not checked. Tap Connect.',
  };

  Future<void> checkCamera(Crop crop, {bool quietly = false}) async {
    if (busy ||
        _disposed ||
        !allowLocalHttp ||
        address(crop, 'camera').isEmpty) {
      return;
    }
    busy = true;
    backgroundWork = quietly;
    _idle = Completer<void>();
    if (!_disposed) notifyListeners();
    try {
      await compute(previewPhoto, await _cameraBytes(crop));
      cameraStatus[crop] = 'Received';
      if (automaticStatus?.startsWith('Camera reconnecting') == true) {
        automaticStatus = 'Camera reconnected. Scheduled checks will continue.';
      }
    } catch (error) {
      _cameraFailed(crop, error);
    } finally {
      busy = false;
      backgroundWork = false;
      _idle?.complete();
      _idle = null;
      if (!_disposed) notifyListeners();
    }
  }

  /// Check only the current local minute; never replay missed slots.
  Future<void> monitorTick(Crop crop) async {
    if (_monitorTickActive || cameraControlActive) return;
    _monitorTickActive = true;
    try {
      await _monitorTick(crop);
    } finally {
      _monitorTickActive = false;
    }
  }

  Future<void> _monitorTick(Crop crop) async {
    if (_disposed || !pollingActive || _requestedPollingCrop != crop || busy) {
      return;
    }
    if (_autoDiscovery &&
        !(_clock().isBefore(_nextDiscovery ?? _clock())) &&
        (address(crop, 'sensor').isEmpty ||
            address(crop, 'camera').isEmpty ||
            status[crop] == 'Unavailable' ||
            const [
              'Unavailable',
              'Unreachable',
              'Timed out',
            ].contains(cameraStatus[crop]) ||
            _blockedRoles.isNotEmpty)) {
      await connectKit(crop, quietly: true);
      if (_disposed || !pollingActive || _requestedPollingCrop != crop) return;
    }
    final now = _clock();
    final key = _slot(crop, now);
    final settings = schedule(crop);
    final due =
        settings.enabled &&
        settings.minutes.contains(now.hour * 60 + now.minute) &&
        !_scheduleAttempts.contains(key);
    if (due) {
      _scheduleAttempts.add(key);
      try {
        await box.put('daily-photo-attempts-v1', _scheduleAttempts.toList());
      } catch (_) {
        automaticStatus =
            'A scheduled check could not be saved. Please check phone storage.';
        return;
      }
    }
    await refresh(crop);
    if (_disposed ||
        !pollingActive ||
        _requestedPollingCrop != crop ||
        busy ||
        cameraControlActive) {
      return;
    }
    if (due && _slot(crop, _clock()) == key && _lastKitCaptureSlot != key) {
      await _scheduledPhoto(crop, key);
    } else if (const [
          'Unavailable',
          'Unreachable',
          'Timed out',
          'Camera unavailable',
          'Capture failed',
        ].contains(cameraStatus[crop]) &&
        !_clock().isBefore(_cameraRetryAt[crop] ?? now)) {
      await checkCamera(crop, quietly: true);
    }
    if (!_disposed &&
        pollingActive &&
        _requestedPollingCrop == crop &&
        !busy &&
        (_lastAppHeartbeat == null ||
            _clock().difference(_lastAppHeartbeat!) >=
                const Duration(seconds: 10)) &&
        _verified['sensor']?.capabilities.contains('app_status_v1') == true) {
      // Use the same operation lock as sampling/capture for the status heartbeat.
      busy = true;
      backgroundWork = true;
      _idle = Completer<void>();
      try {
        _lastAppHeartbeat = _clock();
        await _sendAppStatus(crop);
      } finally {
        busy = false;
        backgroundWork = false;
        _idle?.complete();
        _idle = null;
      }
    }
  }

  Future<void> _scheduledPhoto(Crop crop, String id) async {
    final endpoint = address(crop, 'camera');
    if (endpoint.isEmpty || busy || !allowLocalHttp) return;
    busy = true;
    backgroundWork = true;
    _idle = Completer<void>();
    automaticStatus = 'Checking your plant…';
    _lastKitCaptureSlot = id;
    notifyListeners();
    var stage = 'capture';
    final rawKey = 'scheduled-original-v1/$id';
    try {
      final bytes = await _cameraBytes(crop);
      final capturedAt = _clock();
      await compute(previewPhoto, bytes);
      cameraStatus[crop] = 'Received';
      stage = 'save';
      await box.put(rawKey, {
        'crop': crop.name,
        'at': capturedAt.toIso8601String(),
        'jpeg': bytes,
        'state': 'photo_saved',
      });
      if (_disposed || !pollingActive || _requestedPollingCrop != crop) return;
      stage = 'analysis';
      if (!classifier.supports(crop)) throw AppIssue.unsupported;
      final prediction = await classifier.classifyCrop(crop, bytes);
      final contextual = attachScanContext(
        TomatoScan.fromJson({
          ...prediction.toJson(),
          'id': 'scheduled-$id',
          'crop': crop.name,
          'timestamp': capturedAt.toIso8601String(),
          'source': 'camera',
        }),
        at: capturedAt,
      );
      stage = 'save';
      await scanStore.save(
        TomatoScan.fromJson({...contextual.toJson(), 'source': 'scheduled'}),
      );
      await box.put(rawKey, {
        ...Map<String, dynamic>.from(box.get(rawKey) as Map),
        'state': 'completed',
      });
      revision++;
      automaticStatus = '${crop.label} check saved.';
      try {
        await _announce(
          AppAlertEvent(
            id: 'scheduled-$id',
            type: 'scheduled',
            title: 'Scheduled photo',
            body: '${crop.label}: photo checked and result saved.',
            at: capturedAt,
            target: 'scheduled-$id',
          ),
        );
      } catch (_) {
        notificationIssue = AppIssue.permission;
      }
    } catch (error) {
      if (stage == 'capture') _cameraFailed(crop, error);
      automaticStatus = stage == 'capture'
          ? 'Photo capture failed. The next scheduled check will be attempted.'
          : stage == 'analysis'
          ? 'Photo saved. Analysis could not finish.'
          : 'Could not save this check. Please check phone storage.';
      try {
        await _announce(
          AppAlertEvent(
            id: 'scheduled-$id',
            type: 'scheduled',
            title: 'Scheduled photo',
            body: automaticStatus!,
            at: _clock(),
            target: 'scheduled-$id',
          ),
        );
      } catch (_) {
        notificationIssue = AppIssue.write;
      }
    } finally {
      busy = false;
      backgroundWork = false;
      _idle?.complete();
      _idle = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _notifyReading(Crop crop, HardwareSample sample) async {
    final settings = notificationSettings[crop];
    if (settings?.awaitingLimits == true) return;
    if (_disposed ||
        _pollingCrop != crop ||
        !pollingActive ||
        settings?.enabled != true) {
      return;
    }
    final tracker = _alertTrackers.putIfAbsent(crop, SensorAlertTracker.new);
    final now = _clock();
    final ready = tracker.evaluate(sample, settings!, now);
    if (ready.isEmpty) return;
    final alert = MonitoringAlert(
      id: '${crop.name}-${now.microsecondsSinceEpoch}-${alerts.length}',
      sample: sample,
      settings: settings,
      metrics: ready,
      timestamp: now,
      camera: address(crop, 'camera'),
    );
    try {
      await _saveAlert(alert);
    } catch (_) {
      notificationIssue = AppIssue.write;
      notificationStatus = 'Alert could not be saved; capture was not started.';
      return;
    }
    tracker.delivered(
      ready,
      now,
    ); // Acceptance, independent of notification delivery.
    notificationIssue = null;
    try {
      await _announce(
        AppAlertEvent(
          id: alert.id,
          type: 'sensor',
          title: '${crop.label}: sensor warning',
          body: alert.reason,
          at: now,
          target: alert.id,
        ),
        post: settings.showNotifications,
      );
    } catch (e) {
      notificationIssue = AppIssue.from(e, fallback: AppIssue.permission);
    }
    notificationStatus = '${crop.label} sensor alert saved.';
    if (!settings.capturePhoto) {
      await _saveAlert(alert.change('alert_only'));
      return;
    }
    if (_scheduleAttempts.contains(_slot(crop, now)) &&
        _lastKitCaptureSlot == _slot(crop, now)) {
      await _saveAlert(alert.change('alert_only'));
      return;
    }
    await _processAlert(alert, capture: true, manual: false);
  }

  bool _canProcess(
    MonitoringAlert alert,
    int run,
    bool manual, {
    required bool capture,
  }) =>
      !_disposed &&
      (allowLocalHttp || (manual && !capture)) &&
      (_foreground || backgroundActive) &&
      _run == run &&
      (manual || _requestedPollingCrop == alert.crop);

  Future<void> _processAlert(
    MonitoringAlert initial, {
    required bool capture,
    required bool manual,
  }) async {
    var alert = initial;
    final run = _run;
    var stage = capture ? 'capture_failed' : 'analysis_failed';
    try {
      final existing = scanStore.load().where((s) => s.id == alert.resultId);
      if (existing.isNotEmpty) {
        await _saveAlert(alert.change('completed'));
        revision++;
        return;
      }
      if (!_canProcess(alert, run, manual, capture: capture)) {
        await _saveAlert(alert.change('interrupted'));
        return;
      }
      Uint8List bytes;
      if (capture) {
        if (alert.camera.isEmpty ||
            address(alert.crop, 'camera') != alert.camera) {
          throw AppIssue.assignment;
        }
        await _saveAlert(alert.change('capturing'));
        if (!_canProcess(alert, run, manual, capture: capture)) {
          await _saveAlert(alert.change('interrupted'));
          return;
        }
        _lastKitCaptureSlot = _slot(alert.crop, _clock());
        bytes = await _cameraBytes(alert.crop);
        // Validate originals before storage and inference. Do not resize model input here.
        await compute(previewPhoto, bytes);
        cameraStatus[alert.crop] = 'Received';
        alert = alert.change('photo_saved', capturedAt: _clock());
        final photo = AlertPhoto(
          sampleId: alert.sample.id,
          crop: alert.crop,
          timestamp: alert.capturedAt!,
          reason: alert.reason,
          jpeg: bytes,
          alertId: alert.id,
        );
        final next = [
          ...alertPhotos.where((p) => p.alertId != alert.id),
          photo,
        ];
        while (next.length > 20 ||
            next.fold<int>(0, (n, p) => n + p.jpeg.length) > 30 * 1024 * 1024) {
          next.removeAt(0);
        }
        stage = 'photo_save_failed';
        await box.put(
          'notification-photos-v1',
          next.map((p) => p.toJson()).toList(),
        );
        alertPhotos
          ..clear()
          ..addAll(next);
        await _saveAlert(alert);
      } else {
        final photo = photoFor(alert.id);
        if (photo == null) throw AppIssue.photo;
        bytes = photo.jpeg;
      }
      if (!alert.settings.analyzePhoto) {
        await _saveAlert(alert.change('photo_saved'));
        return;
      }
      if (!classifier.supports(alert.crop)) {
        await _saveAlert(
          alert.change(
            'model_unavailable',
            issueCode: AppIssue.unsupported.code,
          ),
        );
        return;
      }
      if (!_canProcess(alert, run, manual, capture: capture)) {
        await _saveAlert(alert.change('interrupted'));
        return;
      }
      stage = 'analysis_failed';
      await _saveAlert(alert.change('analyzing'));
      if (!_canProcess(alert, run, manual, capture: capture)) {
        await _saveAlert(alert.change('interrupted'));
        return;
      }
      final prediction = await classifier.classifyCrop(alert.crop, bytes);
      final scan = attachScanContext(
        TomatoScan.fromJson({
          ...prediction.toJson(),
          'id': alert.resultId,
          'timestamp': (alert.capturedAt ?? alert.timestamp).toIso8601String(),
          'crop': alert.crop.name,
          'source': 'auto',
          'alert_id': alert.id,
          'sensor_context': alert.sample.toJson(),
        }),
        at: alert.timestamp,
        trigger: alert.sample,
      );
      _pendingResults[alert.id] = scan;
      while (_pendingResults.length > 20) {
        _pendingResults.remove(_pendingResults.keys.first);
      }
      stage = 'save_failed';
      await _saveAlert(alert.change('saving'));
      await scanStore.save(scan);
      revision++;
      await _saveAlert(alert.change('completed'));
      _pendingResults.remove(alert.id);
      notificationStatus = '${alert.crop.label} automatic scan saved.';
    } catch (e) {
      if (stage == 'capture_failed') _cameraFailed(alert.crop, e);
      final issue = stage == 'capture_failed'
          ? AppIssue.fromCamera(e)
          : AppIssue.from(
              e,
              fallback: switch (stage) {
                'save_failed' || 'photo_save_failed' => AppIssue.write,
                'analysis_failed' => AppIssue.model,
                _ => AppIssue.camera,
              },
            );
      notificationIssue = issue;
      notificationStatus =
          'Alert saved. Open History to review or retry the failed step.';
      try {
        await _saveAlert(alert.change(stage, issueCode: issue.code));
      } catch (_) {
        notificationIssue = AppIssue.write;
      }
    }
  }

  bool canRetrySaving(String id) => _pendingResults.containsKey(id);

  Future<void> retryAlert(String id, {required bool capture}) =>
      withPollingPaused(() async {
        _requireIdle();
        if (capture) _requireHttp();
        if (!_foreground) throw AppIssue.busy;
        final alert = alerts.firstWhere((a) => a.id == id);
        busy = true;
        notifyListeners();
        try {
          final pending = _pendingResults[id];
          if (pending != null && !capture) {
            try {
              await scanStore.save(pending);
              revision++;
              await _saveAlert(alert.change('completed'));
              _pendingResults.remove(id);
            } catch (_) {
              await _saveAlert(
                alert.change('save_failed', issueCode: AppIssue.write.code),
              );
            }
          } else {
            await _processAlert(alert, capture: capture, manual: true);
          }
        } finally {
          busy = false;
          if (!_disposed) notifyListeners();
        }
      });

  Future<void> setHttpAllowed(bool value) async {
    if (busy) throw StateError('Wait for the current request to finish.');
    await box.put('allow-local-hardware-http', value);
    allowLocalHttp = value;
    _syncLive();
    if (!value) {
      unawaited(discovery.cancel());
      stopPolling();
      status.clear();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _live?.dispose();
    _cameraViews.clear();
    unawaited(discovery.cancel());
    stopPolling();
    super.dispose();
  }
}
