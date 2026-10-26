import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/camera_stream.dart';
import '../features/diagnosis/photo_processing.dart';

/// Foreground-only live view; still captures acquire a pause lease first.
class CameraLiveController extends ChangeNotifier {
  CameraLiveController({required this.open, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final FutureOr<CameraFrameConnection> Function(String) open;
  final DateTime Function() _clock;
  CameraFrameConnection? _connection;
  Timer? _retry;
  Future<void>? _reader;
  String? _address;
  int _generation = 0, _pauses = 0, _attempt = 0;
  bool _visible = false,
      _foreground = true,
      _allowed = false,
      _disposed = false;
  bool enabled = true;
  String status = 'Live view off';
  Uint8List? frame;
  DateTime? receivedAt;
  bool get fresh =>
      status == 'Live' &&
      receivedAt != null &&
      !_clock().isBefore(receivedAt!) &&
      _clock().difference(receivedAt!).inSeconds < 8;
  bool get _wanted =>
      !_disposed &&
      enabled &&
      _visible &&
      _foreground &&
      _allowed &&
      _address != null &&
      _pauses == 0;
  void configure({
    required String? address,
    required bool visible,
    required bool foreground,
    required bool allowed,
  }) {
    if (_address == address &&
        _visible == visible &&
        _foreground == foreground &&
        _allowed == allowed) {
      return;
    }
    final changedAddress = _address != address;
    _address = address;
    _visible = visible;
    _foreground = foreground;
    _allowed = allowed;
    _stop();
    if (changedAddress) {
      frame = null;
      receivedAt = null;
      _attempt = 0;
    }
    if (_wanted) {
      _start();
    } else {
      status = 'Live view off';
    }
    if (!_disposed) notifyListeners();
  }

  void setEnabled(bool value) {
    enabled = value;
    _stop();
    _attempt = 0;
    if (_wanted) {
      _start();
    } else {
      status = 'Live view off';
    }
    if (!_disposed) notifyListeners();
  }

  void retry() {
    _stop();
    _attempt = 0;
    if (_wanted) _start();
    if (!_disposed) notifyListeners();
  }

  void _stop() {
    _generation++;
    _retry?.cancel();
    _retry = null;
    _connection?.close();
    _connection = null;
  }

  void _start() {
    if (!_wanted) return;
    status = _attempt == 0
        ? 'Connecting live view…'
        : 'Reconnecting live view…';
    final generation = _generation;
    _reader = _read(generation, _address!);
  }

  Future<void> _read(int generation, String address) async {
    CameraFrameConnection? connection;
    int? drawn;
    final redrawClock = Stopwatch()..start();
    try {
      connection = await open(address);
      if (_disposed || generation != _generation || !_wanted) return;
      _connection = connection;
      await for (final image in connection.frames) {
        if (_disposed || generation != _generation || !_wanted) break;
        final now = redrawClock.elapsedMilliseconds;
        // Drain the socket, but redraw at most four times per second.
        if (drawn != null && now - drawn < 250) {
          continue;
        }
        drawn = now;
        await compute(validateCameraFrame, image);
        if (_disposed || generation != _generation || !_wanted) break;
        receivedAt = _clock();
        _attempt = 0;
        frame = image;
        status = 'Live';
        notifyListeners();
      }
    } catch (_) {
      /* A stream failure must not label still capture disconnected. */
    } finally {
      connection?.close();
      if (identical(_connection, connection)) _connection = null;
      if (!_disposed && generation == _generation && _wanted) {
        status = 'Reconnecting live view…';
        final delay = [2, 5, 10, 30][_attempt.clamp(0, 3)];
        _attempt++;
        _retry = Timer(Duration(seconds: delay), () {
          _retry = null;
          _start();
        });
        notifyListeners();
      }
    }
  }

  Future<T> withPaused<T>(Future<T> Function() action) async {
    _pauses++;
    _stop();
    final reader = _reader;
    if (!_disposed) {
      status = 'Live view paused for photo';
      notifyListeners();
    }
    try {
      if (reader != null) {
        try {
          await reader.timeout(const Duration(seconds: 2));
        } catch (_) {
          /* Socket has already been closed. */
        }
      }
      return await action();
    } finally {
      _pauses--;
      if (_wanted && _connection == null && _retry == null) {
        _start();
      } else if (!_wanted) {
        status = 'Live view off';
      }
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stop();
    super.dispose();
  }
}
