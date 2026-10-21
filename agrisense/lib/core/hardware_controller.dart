import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import '../data/hardware_client.dart';
import '../data/models.dart';
import '../data/automatic_capture.dart';
import 'sensor_notifications.dart';
import 'app_issue.dart';
import '../data/alert_photo.dart';
import '../features/diagnosis/photo_processing.dart';

class HardwareController extends ChangeNotifier {
  HardwareController(
    this.box, {
    HardwareClient? client,
    SensorNotifications? notifications,
    DateTime Function()? clock,
  }) : client = client ?? HardwareClient(),
       notifications = notifications ?? SensorNotifications(),
       _clock = clock ?? DateTime.now;
  final Box<dynamic> box;
  final HardwareClient client;
  final SensorNotifications notifications;
  final DateTime Function() _clock;
  final Map<Crop, SensorAlertSettings> notificationSettings = {};
  final Map<Crop, SensorAlertTracker> _alertTrackers = {};
  String? notificationStatus;
  AppIssue? notificationIssue;
  Crop? _pollingCrop;
  Crop? _requestedPollingCrop;
  bool _foreground = true;
  int _pollingPauses = 0;
  final Map<Crop, Map<String, String>> assignments = {};
  final List<HardwareSample> samples = [];
  final List<AlertPhoto> alertPhotos = [];
  final Map<Crop, String> status = {};
  bool busy = false;
  bool allowLocalHttp = false;
  String? error;
  AppIssue? issue;
  Timer? _timer;
  bool _disposed = false;
  static const _historyKey = 'hardware-readings-v1';

  void load() {
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
        notificationSettings[crop] = alerts[crop.name] is Map
            ? SensorAlertSettings.fromJson(alerts[crop.name] as Map)
            : const SensorAlertSettings();
      } catch (_) {
        notificationSettings[crop] = const SensorAlertSettings();
        notificationStatus =
            'Saved notification rules were invalid; configure them again.';
      }
    }
    allowLocalHttp =
        box.get('allow-local-hardware-http', defaultValue: false) == true;
    final raw =
        box.get('hardware-nodes-v1', defaultValue: <String, dynamic>{}) as Map;
    for (final crop in Crop.values) {
      assignments[crop] = Map<String, String>.from(
        raw[crop.name] as Map? ?? {},
      );
    }
    samples.addAll(
      (box.get(_historyKey, defaultValue: []) as List).map(
        (e) => HardwareSample.fromSaved(e as Map),
      ),
    );
    samples.sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
  }

  String address(Crop crop, String kind) => assignments[crop]?[kind] ?? '';
  List<HardwareSample> readings(Crop crop) =>
      samples.where((r) => r.crop == crop).toList();
  HardwareSample? latest(Crop crop) {
    final items = readings(crop);
    return items.isEmpty ? null : items.last;
  }

  bool fresh(Crop crop) {
    final sample = latest(crop);
    return status[crop] == 'Received' &&
        sample != null &&
        DateTime.now().difference(sample.receivedAt).inSeconds < 35;
  }

  Future<void> assign(
    Crop crop,
    String kind,
    String input,
  ) => withPollingPaused(() async {
    _requireIdle();
    if (kind != 'camera' && kind != 'sensor') {
      throw const FormatException('Unknown device type.');
    }
    final value = input.trim().isEmpty ? '' : hardwareAddress(input).toString();
    if (value != address(crop, kind)) await _stopAutomaticFor({crop});
    if (value.isNotEmpty &&
        assignments.entries.any(
          (entry) => entry.key != crop && entry.value.values.contains(value),
        )) {
      throw const FormatException(
        'This board is assigned to another crop. Clear that assignment first.',
      );
    }
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
    status.remove(crop);
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
    final key = code.trim().isEmpty
        ? old['pairingCode'] ?? ''
        : code.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(key)) {
      throw const FormatException(
        'Enter the 32-character pairing code printed by the sensor.',
      );
    }
    if (endpoint != address(crop, 'sensor')) await _stopAutomaticFor({crop});
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
      status.clear();
      status[crop] = 'Crop confirmed: ${crop.label}';
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
      notifyListeners();
    },
  );

  Future<void> refresh(Crop crop) async {
    if (busy || _disposed || !allowLocalHttp) return;
    final endpoint = address(crop, 'sensor');
    if (endpoint.isEmpty) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final reading = await client.read(endpoint, crop);
      final expectedId = assignments[crop]?['sensorId'];
      if (expectedId != null && reading.deviceId != expectedId) {
        throw const FormatException(
          'A different sensor answered. Check the IP and pair the intended board.',
        );
      }
      if (_disposed) return;
      if (!samples.any((r) => r.crop == crop && r.id == reading.id)) {
        final next = [...samples, reading];
        // Bound storage, keeping the most recent 5,000 samples per crop.
        while (next.where((r) => r.crop == crop).length > 5000) {
          next.removeAt(next.indexWhere((r) => r.crop == crop));
        }
        try {
          await box.put(_historyKey, next.map((r) => r.toJson()).toList());
        } catch (_) {
          throw AppIssue.write;
        }
        samples
          ..clear()
          ..addAll(next);
      }
      status[crop] = 'Received';
      await _notifyReading(crop, reading);
    } catch (e) {
      status[crop] = 'Unavailable';
      _alertTrackers[crop]?.reset();
      issue = AppIssue.from(e, fallback: AppIssue.connection);
      error = e is FormatException
          ? e.message
          : 'Could not read or save ${crop.label} sensor data. Check Wi-Fi, IP, and device storage.';
    } finally {
      busy = false;
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
    for (final crop in crops) {
      if (assignments[crop]?['sensorId'] == null) continue;
      await _automaticRequest(() async {
        final sensor = address(crop, 'sensor');
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
      });
    }
  }

  Future<Uint8List> capture(Crop crop) {
    _requireIdle();
    _requireHttp();
    final endpoint = address(crop, 'camera');
    if (endpoint.isEmpty) {
      throw const FormatException('Assign a camera IP in Devices first.');
    }
    return withPollingPaused(() => _capture(endpoint));
  }

  Future<Uint8List> _capture(String endpoint) async {
    busy = true;
    notifyListeners();
    try {
      return await client.capture(endpoint);
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  // Foreground opt-in polling only; no background service or discovery scans.
  void startPolling(Crop crop) {
    stopPolling();
    if (!allowLocalHttp) return;
    _requestedPollingCrop = crop;
    _resumePolling();
    if (pollingActive) unawaited(refresh(crop));
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
        !_foreground ||
        _pollingPauses > 0 ||
        !allowLocalHttp ||
        crop == null ||
        address(crop, 'sensor').isEmpty ||
        _timer != null) {
      return;
    }
    _pollingCrop = crop;
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => refresh(crop));
  }

  void stopPolling() {
    _requestedPollingCrop = null;
    _pausePolling(resetDuration: true);
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
    if (active) {
      _resumePolling();
    } else {
      _pausePolling(resetDuration: resetDuration);
    }
    if (!_disposed) notifyListeners();
  }

  bool get polling => _requestedPollingCrop != null;
  bool get pollingActive =>
      _timer != null && _foreground && _pollingPauses == 0;
  String get monitoringStatus => !polling
      ? 'Monitoring off'
      : !_foreground
      ? 'Paused while the app is not active; resumes when you return.'
      : _pollingPauses > 0
      ? 'Paused during settings or analysis; resumes automatically.'
      : _timer == null
      ? 'Waiting for a sensor assignment.'
      : 'Monitoring every 10 seconds';

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
      if (settings.enabled && !await notifications.requestPermission()) {
        throw const FormatException(
          'Notifications are blocked. Allow AgriSense notifications in Android settings, then retry.',
        );
      }
      final next = {...notificationSettings, crop: settings};
      await box.put('foreground-notification-rules-v1', {
        for (final e in next.entries) e.key.name: e.value.toJson(),
      });
      notificationSettings[crop] = settings;
      _alertTrackers.remove(crop);
      notificationStatus = settings.enabled
          ? 'Notifications enabled. ${polling ? 'Monitoring resumes automatically.' : 'Turn on sensor monitoring in Devices.'}'
          : 'Notifications off for ${crop.label}.';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  });

  Future<void> testNotification(Crop crop) async {
    if (notificationSettings[crop]?.enabled != true) {
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

  Future<void> _notifyReading(Crop crop, HardwareSample sample) async {
    final settings = notificationSettings[crop];
    if (_disposed ||
        _pollingCrop != crop ||
        !pollingActive ||
        settings?.enabled != true) {
      return;
    }
    try {
      final tracker = _alertTrackers.putIfAbsent(crop, SensorAlertTracker.new);
      final now = _clock();
      final ready = tracker.evaluate(sample, settings!, now);
      if (ready.isEmpty) return;
      final values = [sample.temperature, sample.humidity, sample.soil];
      final names = ['Temperature', 'Humidity', 'Soil moisture'];
      final units = ['°C', '%', '%'];
      final text = ready
          .map(
            (i) =>
                '${names[i]} ${values[i]!.toStringAsFixed(1)}${units[i]} (range ${settings.rules[i].minimum}–${settings.rules[i].maximum}${units[i]})',
          )
          .join('; ');
      if (_disposed || _pollingCrop != crop) return;
      final posted = await notifications.show(
        5000 + crop.index,
        '${crop.label}: sensor limit exceeded',
        '$text. Outside range for at least ${settings.duration}s. Check growing conditions.',
      );
      if (posted) {
        notificationIssue = null;
        tracker.delivered(ready, now);
        notificationStatus = 'Sent ${crop.label} sensor alert.';
        if (settings.capturePhoto) await _captureAlertPhoto(crop, sample, text);
      } else {
        notificationIssue = AppIssue.permission;
        tracker.reset();
        notificationStatus =
            'Notifications blocked or app not active. Check Android notification settings.';
      }
    } catch (e) {
      _alertTrackers[crop]?.reset();
      notificationIssue = AppIssue.from(e, fallback: AppIssue.permission);
      notificationStatus =
          'Could not post notification. Sensor reading was still saved.';
    }
  }

  Future<void> _captureAlertPhoto(
    Crop crop,
    HardwareSample sample,
    String reason,
  ) async {
    if (_disposed ||
        !allowLocalHttp ||
        !pollingActive ||
        _pollingCrop != crop) {
      notificationStatus =
          'Alert sent. Photo skipped because monitoring was paused.';
      return;
    }
    final camera = address(crop, 'camera');
    if (camera.isEmpty) {
      notificationIssue = AppIssue.assignment;
      notificationStatus =
          'Alert sent. Photo skipped: no camera assigned to ${crop.label}.';
      return;
    }
    if (alertPhotos.any((p) => p.crop == crop && p.sampleId == sample.id)) {
      return;
    }
    try {
      // refresh() already owns the busy lock; avoid calling the public capture()
      // method, which intentionally rejects concurrent hardware requests.
      final jpeg = await compute(alertSnapshot, await client.capture(camera));
      if (_disposed) return;
      final photo = AlertPhoto(
        sampleId: sample.id,
        crop: crop,
        timestamp: _clock(),
        reason: reason,
        jpeg: jpeg,
      );
      final next = [...alertPhotos, photo];
      // A bounded, separate snapshot history; diagnosis records are untouched.
      while (next.length > 20 ||
          next.fold<int>(0, (sum, p) => sum + p.jpeg.length) >
              30 * 1024 * 1024) {
        next.removeAt(0);
      }
      try {
        await box.put(
          'notification-photos-v1',
          next.map((p) => p.toJson()).toList(),
        );
      } catch (_) {
        throw AppIssue.write;
      }
      alertPhotos
        ..clear()
        ..addAll(next);
      notificationStatus =
          'Alert sent. ${crop.label} camera photo saved in History.';
    } catch (e) {
      notificationIssue = AppIssue.from(e, fallback: AppIssue.camera);
      notificationStatus =
          'Alert sent, but the camera photo could not be captured or saved. Check its IP, Wi-Fi and phone storage.';
      // Keep the alert acknowledged so camera errors cannot cause repeated alerts.
    }
  }

  Future<void> setHttpAllowed(bool value) async {
    if (busy) throw StateError('Wait for the current request to finish.');
    await box.put('allow-local-hardware-http', value);
    allowLocalHttp = value;
    if (!value) {
      stopPolling();
      status.clear();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
