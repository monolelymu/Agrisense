import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/hardware_controller.dart';
import '../../core/theme.dart';
import '../../data/models.dart';

class CameraGamepad extends StatefulWidget {
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
  State<CameraGamepad> createState() => _CameraGamepadState();
}

class _CameraGamepadState extends State<CameraGamepad>
    with WidgetsBindingObserver {
  Timer? _repeat;
  Timer? _tapReset;
  int? _pointer;
  bool _suppressTap = false;
  int _generation = 0;
  bool _sending = false;
  bool _foreground = true;
  HardwareController get hardware => widget.hardware;
  bool get _allowed =>
      mounted &&
      _foreground &&
      !widget.blocked &&
      hardware.canMoveCamera &&
      !hardware.userBusy &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  void _stop() {
    _generation++;
    _repeat?.cancel();
    _repeat = null;
    _pointer = null;
    if (!_sending) hardware.setCameraControlActive(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _stop();
      _suppressTap = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) _stop();
  }

  @override
  void didUpdateWidget(covariant CameraGamepad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.crop != widget.crop ||
        oldWidget.hardware != hardware ||
        widget.blocked) {
      _stop();
    }
  }

  Future<void> _step(
    String action,
    int generation, {
    bool repeat = false,
  }) async {
    if (generation != _generation || _sending || !_allowed) {
      if (!_sending) hardware.setCameraControlActive(false);
      return;
    }
    final watch = Stopwatch()..start();
    _sending = true;
    try {
      await hardware.moveCameraDirection(widget.crop, action);
    } catch (_) {
      _stop(); // Never repeat an unconfirmed physical command.
      return;
    } finally {
      _sending = false;
      if (!repeat || generation != _generation) {
        hardware.setCameraControlActive(false);
      }
    }
    if (!repeat || generation != _generation || !_allowed) return;
    final remaining = 300 - watch.elapsedMilliseconds;
    _repeat = Timer(Duration(milliseconds: remaining > 0 ? remaining : 0), () {
      unawaited(_step(action, generation, repeat: true));
    });
  }

  void _start(String action, {bool repeat = false}) {
    _stop();
    hardware.setCameraControlActive(true);
    unawaited(_step(action, _generation, repeat: repeat));
  }

  @override
  void dispose() {
    _stop();
    _tapReset?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: hardware,
    builder: (context, _) {
      final enabled =
          _foreground &&
          hardware.canMoveCamera &&
          (!hardware.userBusy || _sending) &&
          !widget.blocked;
      if (!enabled) _stop();
      Widget button(String action, IconData icon) {
        final control = IconButton.filledTonal(
          tooltip: action == 'center' ? 'Center camera' : 'Move camera $action',
          onPressed: enabled
              ? () {
                  if (!_suppressTap) _start(action);
                }
              : null,
          iconSize: action == 'center' ? 28 : 34,
          style: IconButton.styleFrom(
            minimumSize: const Size(56, 56),
            maximumSize: const Size(56, 56),
            shape: action == 'center'
                ? const CircleBorder()
                : BeveledRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
          ),
          icon: Icon(icon),
        );
        if (action == 'center') return control;
        return Listener(
          onPointerDown: !enabled
              ? null
              : (event) {
                  if (_pointer != null || _sending) return;
                  _tapReset?.cancel();
                  _suppressTap = true;
                  _start(action, repeat: true);
                  _pointer = event.pointer;
                },
          onPointerUp: (event) {
            if (_pointer != null && _pointer != event.pointer) return;
            _stop();
            // The button's tap callback follows pointer-up; avoid a second step.
            _tapReset = Timer(Duration.zero, () => _suppressTap = false);
          },
          onPointerCancel: (event) {
            if (_pointer == null || _pointer == event.pointer) {
              _stop();
              _suppressTap = false;
            }
          },
          onPointerMove: (event) {
            if (_pointer == event.pointer &&
                !(Offset.zero & const Size(56, 56)).contains(
                  event.localPosition,
                )) {
              _stop();
            }
          },
          child: control,
        );
      }

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
                ? hardware.cameraControlActive
                      ? 'Moving camera…'
                      : hardware.movementStatus?.contains('not confirmed') ==
                            true
                      ? hardware.movementStatus!
                      : 'Hold a direction to move. Tap Center to return.'
                : 'Camera movement unavailable.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    },
  );
}
