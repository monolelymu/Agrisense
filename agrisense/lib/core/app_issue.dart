import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../data/hardware_client.dart';

/// Stable, user-facing diagnostics. Never include raw exceptions or pairing keys.
class AppIssue {
  const AppIssue(this.code, this.title, this.recovery);
  final String code, title, recovery;

  static const connection = AppIssue(
    'NET-001',
    'Device did not respond',
    'Check device power, the saved IP address, and that your phone and board use the same trusted Wi-Fi. Then retry.',
  );
  static const address = AppIssue(
    'NET-002',
    'Check the device address',
    'Enter the board’s private numeric IPv4 address, optionally with a port. Remove endpoint paths such as /capture.',
  );
  static const httpOff = AppIssue(
    'NET-003',
    'Local device access is off',
    'Open Settings → Device setup and enable local hardware access on your trusted Wi-Fi.',
  );
  static const pairing = AppIssue(
    'DEV-001',
    'Pairing code was not accepted',
    'Check the code printed in the intended board’s Serial Monitor. Re-enter it privately and retry.',
  );
  static const identity = AppIssue(
    'DEV-002',
    'Device or crop does not match',
    'Check the selected crop and assigned board in Settings → Device setup. Confirm the intended board before reassigning it.',
  );
  static const protocol = AppIssue(
    'DEV-003',
    'Device response is incompatible',
    'Check the board IP and device type in Settings → Device setup. Reload settings before retrying a change; the board may already have received it.',
  );
  static const stale = AppIssue(
    'SEN-001',
    'No fresh sensor reading',
    'Wait ten seconds and read again. Check sensor power and wiring if values remain unavailable.',
  );
  static const permission = AppIssue(
    'PER-001',
    'Permission is unavailable',
    'Check AgriSense permissions in Android settings, then return and retry. Manual photo scans remain available without notifications.',
  );
  static const photo = AppIssue(
    'IMG-001',
    'Photo could not be read',
    'Choose a valid JPEG or PNG up to 15 MB, 24 megapixels and 12,000 pixels per side. Try selecting the photo again.',
  );
  static const camera = AppIssue(
    'CAM-001',
    'Camera capture failed',
    'Test the camera in Settings → Device setup. Check its power, Wi-Fi and IP address, then retry capture.',
  );
  static const model = AppIssue(
    'ML-001',
    'Model could not run',
    'Restart the app and try a clear leaf photo. If this repeats, install a verified app build with matching model and labels.',
  );
  static const unsupported = AppIssue(
    'ML-002',
    'Model not available for this crop',
    'Choose a crop with an installed model. Sensor monitoring is available independently of disease analysis.',
  );
  static const storage = AppIssue(
    'STO-001',
    'Result could not be saved',
    'Free device storage and retry saving. Keep this screen open to retain the current result.',
  );
  static const history = AppIssue(
    'STO-002',
    'Saved records could not be loaded',
    'Restart the app and retry. Do not clear app data or uninstall: those actions remove local history.',
  );
  static const settings = AppIssue(
    'SET-001',
    'Settings could not be saved',
    'Review the highlighted fields and retry. For board settings, reload first to check whether the change was received.',
  );
  static const limits = AppIssue(
    'SET-002',
    'Check monitoring limits',
    'Enter numbers with minimum below maximum. Temperature: -40 to 80 °C; humidity and soil: 0–100%. Duration: 10–3600 seconds. Phone alert cooldown: 30–86400 seconds; advanced board SD capture cooldown: 60–86400 seconds.',
  );
  static const busy = AppIssue(
    'APP-001',
    'Another request is running',
    'Wait for the current request to finish, then retry.',
  );
  static const selection = AppIssue(
    'SET-003',
    'Choose a measurement',
    'Select at least one measurement before enabling alerts or board capture.',
  );
  static const calibration = AppIssue(
    'SEN-002',
    'Soil percentage is not calibrated',
    'Use temperature or humidity limits for now. Soil alerts require a calibrated percentage from the sensor.',
  );
  static const assignment = AppIssue(
    'DEV-004',
    'Device is not assigned',
    'Select the crop in Settings → Device setup, assign its sensor or camera, and test the connection before retrying.',
  );
  static const write = AppIssue(
    'STO-003',
    'Device storage write failed',
    'Free phone storage and retry. For board settings, reload first to check whether the board received the change.',
  );
  static const unknown = AppIssue(
    'APP-002',
    'Action could not be completed',
    'Retry the action. If it continues, restart the app. Your existing saved records are not removed.',
  );
  static const background = AppIssue(
    'BG-001',
    'Background monitoring could not start',
    'Open AgriSense and start monitoring while the app is visible. Check Android app and notification settings. Keep the app open if background operation is unavailable.',
  );
  static const all = [
    connection,
    address,
    httpOff,
    pairing,
    identity,
    protocol,
    stale,
    permission,
    photo,
    camera,
    model,
    unsupported,
    storage,
    history,
    settings,
    limits,
    selection,
    calibration,
    assignment,
    write,
    busy,
    unknown,
    background,
  ];

  static AppIssue from(Object error, {AppIssue fallback = unknown}) {
    if (error is AppIssue) return error;
    if (error is TimeoutException || error is SocketException) {
      return connection;
    }
    if (error is HardwareHttpException) {
      return switch (error.status) {
        401 || 403 => pairing,
        409 => identity,
        503 => stale,
        _ => protocol,
      };
    }
    if (error is PlatformException) {
      return error.code.toLowerCase().contains('denied') ||
              error.code.toLowerCase().contains('permission')
          ? permission
          : fallback;
    }
    // Legacy validators expose known local messages, never arbitrary HTTP bodies.
    final message = error is FormatException ? error.message.toLowerCase() : '';
    if ((message.contains('assign') && message.contains('first')) ||
        message.contains('pair a sensor')) {
      return assignment;
    }
    if (message.contains('at least one measurement')) return selection;
    if (message.contains('calibrat')) return calibration;
    if (message.contains('minimum') ||
        message.contains('duration') ||
        message.contains('cooldown')) {
      return limits;
    }
    if (message.contains('notifications are blocked')) return permission;
    if (message.contains('http is off') || message.contains('enable local')) {
      return httpOff;
    }
    if (message.contains('ipv4') || message.contains('lan addresses')) {
      return address;
    }
    if (message.contains('pairing code')) return pairing;
    if (message.contains('different sensor') ||
        message.contains('wrong crop') ||
        message.contains('identity') ||
        message.contains('crop changed')) {
      return identity;
    }
    if (message.contains('fresh sample') || message.contains('too old')) {
      return stale;
    }
    if (message.contains('jpeg') ||
        message.contains('png') ||
        message.contains('megapixel') ||
        message.contains('15 mb') ||
        message.contains('decoded')) {
      return photo;
    }
    if (message.contains('firmware') ||
        message.contains('sensor json') ||
        message.contains('response')) {
      return protocol;
    }
    if (error is StateError && error.message.contains('Model not available')) {
      return unsupported;
    }
    if (error is StateError && error.message.contains('request')) return busy;
    return fallback;
  }
}
