import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Bounded multipart parser for the ESP32 CameraWebServer's JPEG parts.
class MjpegParser {
  static const maxFrame = 2 * 1024 * 1024;
  final List<int> _buffer = [];
  int? _length;
  List<Uint8List> add(List<int> chunk) {
    if (chunk.length > maxFrame + 8192) {
      throw const FormatException('Live-feed chunk too large.');
    }
    _buffer.addAll(chunk);
    final frames = <Uint8List>[];
    while (true) {
      if (_length == null) {
        var end = -1;
        for (var i = 0; i + 3 < _buffer.length; i++) {
          if (_buffer[i] == 13 &&
              _buffer[i + 1] == 10 &&
              _buffer[i + 2] == 13 &&
              _buffer[i + 3] == 10) {
            end = i;
            break;
          }
        }
        if (end < 0) {
          if (_buffer.length > 8192) {
            throw const FormatException('Invalid live-feed header.');
          }
          break;
        }
        if (end > 8192) {
          throw const FormatException('Live-feed header too large.');
        }
        final header = latin1.decode(_buffer.sublist(0, end));
        final length = RegExp(
          r'(?:^|\r\n)Content-Length:\s*(\d+)\s*(?:\r\n|$)',
          caseSensitive: false,
        ).firstMatch(header);
        final count = int.tryParse(length?.group(1) ?? '');
        if (count == null ||
            count < 4 ||
            count > maxFrame ||
            !RegExp(
              r'Content-Type:\s*image/jpeg\s*(?:\r\n|$)',
              caseSensitive: false,
            ).hasMatch(header)) {
          throw const FormatException('Unsupported live-feed part.');
        }
        _buffer.removeRange(0, end + 4);
        _length = count;
      }
      if (_buffer.length < _length!) break;
      final frame = Uint8List.fromList(_buffer.sublist(0, _length!));
      _buffer.removeRange(0, _length!);
      _length = null;
      if (frame[0] != 0xff ||
          frame[1] != 0xd8 ||
          frame[frame.length - 2] != 0xff ||
          frame.last != 0xd9) {
        throw const FormatException('Incomplete live photo.');
      }
      frames.add(frame);
    }
    if (_buffer.length > maxFrame + 8192) {
      throw const FormatException('Live-feed buffer too large.');
    }
    return frames;
  }
}

class CameraFrameConnection {
  CameraFrameConnection(this.uri, {HttpClient Function()? factory})
    : _client = (factory ?? HttpClient.new)() {
    _client.connectionTimeout = const Duration(seconds: 5);
    _client.findProxy = (_) => 'DIRECT';
  }
  final Uri uri;
  final HttpClient _client;
  bool _closed = false;
  void close() {
    _closed = true;
    _client.close(force: true);
  }

  Stream<Uint8List> get frames async* {
    Timer? deadline;
    try {
      if (_closed) return;
      final request = await _client
          .getUrl(uri)
          .timeout(const Duration(seconds: 5));
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.acceptHeader,
        'multipart/x-mixed-replace',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != 200 ||
          response.headers.contentType?.mimeType !=
              'multipart/x-mixed-replace') {
        throw const FormatException('Live feed is unavailable.');
      }
      final parser = MjpegParser();
      void armDeadline() {
        deadline?.cancel();
        deadline = Timer(const Duration(seconds: 8), close);
      }

      armDeadline();
      await for (final chunk in response.timeout(const Duration(seconds: 8))) {
        if (_closed) break;
        for (final frame in parser.add(chunk)) {
          armDeadline();
          yield frame;
        }
      }
    } finally {
      deadline?.cancel();
      close();
    }
  }
}
