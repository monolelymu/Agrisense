import 'package:flutter/material.dart';
import '../../core/hardware_controller.dart';
import '../../core/theme.dart';
import '../../data/models.dart';

class CameraGamepad extends StatelessWidget {
  const CameraGamepad({
    super.key,
    required this.hardware,
    required this.crop,
    this.blocked = false,
  });
  final HardwareController hardware;
  final Crop crop;
  final bool blocked;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: hardware,
    builder: (context, _) {
      final enabled = hardware.canMoveCamera && !hardware.userBusy && !blocked;
      Widget button(String action, IconData icon) => IconButton.filledTonal(
        tooltip: action == 'center' ? 'Center camera' : 'Move camera $action',
        onPressed: !enabled
            ? null
            : () async {
                try {
                  await hardware.moveCameraDirection(crop, action);
                } catch (_) {
                  /* The controller presents the bounded movement outcome below. */
                }
              },
        iconSize: action == 'center' ? 28 : 34,
        style: IconButton.styleFrom(
          minimumSize: const Size(56, 56),
          maximumSize: const Size(56, 56),
          shape: action == 'center'
              ? const CircleBorder()
              : BeveledRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon),
      );
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: muted.withValues(alpha: .35), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                button('up', Icons.keyboard_arrow_up_rounded),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    button('left', Icons.chevron_left_rounded),
                    const SizedBox(width: 8),
                    button('center', Icons.my_location),
                    const SizedBox(width: 8),
                    button('right', Icons.chevron_right_rounded),
                  ],
                ),
                const SizedBox(height: 8),
                button('down', Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hardware.canMoveCamera
                ? hardware.movementStatus ??
                      'Tap a direction to move the camera.'
                : 'Camera movement unavailable.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    },
  );
}
