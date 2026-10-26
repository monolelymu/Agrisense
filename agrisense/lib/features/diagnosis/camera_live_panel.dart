import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/hardware_controller.dart';
import '../../core/theme.dart';
import 'camera_photo_preview.dart';

class CameraLivePanel extends StatefulWidget {
  const CameraLivePanel({super.key, required this.hardware});
  final HardwareController hardware;
  @override
  State<CameraLivePanel> createState() => _CameraLivePanelState();
}

class _CameraLivePanelState extends State<CameraLivePanel> {
  HardwareController get h => widget.hardware;
  bool? _visible;
  late final Listenable updates = Listenable.merge([h, h.live]);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (_visible == current) return;
    _visible = current;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) h.cameraView(this, current);
    });
  }

  @override
  void dispose() {
    unawaited(Future<void>.microtask(() => h.cameraView(this, false)));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updates,
    builder: (context, _) {
      final live = h.live;
      final showFrame = live.frame != null && live.enabled && h.canStream;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Live view'),
            value: h.canStream && live.enabled,
            onChanged: h.canStream ? live.setEnabled : null,
          ),
          if (showFrame) ...[
            Image.memory(
              live.frame!,
              height: 220,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const Text(
                'Live photo could not be displayed. Refresh a still photo.',
              ),
            ),
            const SizedBox(height: 8),
          ] else if (h.lastCameraPhoto != null)
            CameraPhotoPreview(
              bytes: h.lastCameraPhoto!.$1,
              at: h.lastCameraPhoto!.$2,
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.camera_alt_outlined, size: 48, color: accent),
                  SizedBox(height: 12),
                  Text('Your plant will appear here.'),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            h.canStream
                ? live.status
                : 'Connect AgriSense to start a supported live feed.',
            style: TextStyle(color: live.fresh ? accent : muted),
          ),
          if (live.status.startsWith('Reconnecting')) ...[
            const Text('Still photos remain available.'),
            TextButton(
              onPressed: live.retry,
              child: const Text('Retry live view'),
            ),
          ],
        ],
      );
    },
  );
}
