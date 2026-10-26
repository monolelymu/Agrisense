import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/widgets.dart';

/// Both camera surfaces display the same original, without a second JPEG encode.
class CameraPhotoPreview extends StatelessWidget {
  const CameraPhotoPreview({super.key, required this.bytes, required this.at});
  final Uint8List bytes;
  final DateTime at;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.memory(
        bytes,
        height: 220,
        fit: BoxFit.contain,
        gaplessPlayback: false,
        errorBuilder: (_, _, _) =>
            const Text('Photo could not be displayed. Try another capture.'),
      ),
      const SizedBox(height: 8),
      Text('Last photo • ${dateLabel(at)} • not live'),
    ],
  );
}
