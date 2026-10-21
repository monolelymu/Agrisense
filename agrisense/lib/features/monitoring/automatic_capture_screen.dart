import 'package:flutter/material.dart';
import '../../core/hardware_controller.dart';
import '../../data/automatic_capture.dart';
import '../../data/models.dart';
import '../../core/app_issue.dart';
import '../../core/issue_card.dart';
import '../../core/limit_validation.dart';
import '../../core/widgets.dart';

class AutomaticCaptureScreen extends StatefulWidget {
  const AutomaticCaptureScreen({
    required this.hardware,
    required this.crop,
    super.key,
  });
  final HardwareController hardware;
  final Crop crop;
  @override
  State<AutomaticCaptureScreen> createState() => _AutomaticCaptureScreenState();
}

class _AutomaticCaptureScreenState extends State<AutomaticCaptureScreen> {
  final minimum = List.generate(3, (_) => TextEditingController());
  final maximum = List.generate(3, (_) => TextEditingController());
  final duration = TextEditingController(), cooldown = TextEditingController();
  final cameraCode = TextEditingController();
  final selected = [false, false, false];
  AutomaticCapture? saved;
  bool enabled = false, busy = true;
  String? message;
  AppIssue? issue;
  bool dirty = false;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [...minimum, ...maximum, duration, cooldown, cameraCode]) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply(AutomaticCapture value) {
    saved = value;
    enabled = value.enabled;
    duration.text = '${value.duration}';
    cooldown.text = '${value.cooldown}';
    for (var i = 0; i < 3; i++) {
      selected[i] = value.rules[i].enabled;
      minimum[i].text = '${value.rules[i].minimum}';
      maximum[i].text = '${value.rules[i].maximum}';
    }
    dirty = false;
  }

  Future<void> _load() async {
    setState(() {
      busy = true;
      message = null;
      issue = null;
    });
    try {
      final value = await widget.hardware.loadAutomatic(widget.crop);
      if (mounted) setState(() => _apply(value));
    } catch (e) {
      if (mounted) {
        setState(() => issue = AppIssue.from(e, fallback: AppIssue.settings));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    if (enabled && !formKey.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
      issue = null;
    });
    try {
      final rules = enabled
          ? [
              for (var i = 0; i < 3; i++)
                CaptureRule(
                  selected[i],
                  selected[i]
                      ? double.parse(minimum[i].text.trim())
                      : saved!.rules[i].minimum,
                  selected[i]
                      ? double.parse(maximum[i].text.trim())
                      : saved!.rules[i].maximum,
                ),
            ]
          : saved!.rules;
      final value = await widget.hardware.saveAutomatic(
        widget.crop,
        enabled: enabled,
        rules: rules,
        duration: enabled ? int.parse(duration.text.trim()) : saved!.duration,
        cooldown: enabled ? int.parse(cooldown.text.trim()) : saved!.cooldown,
        cameraCode: cameraCode.text,
      );
      if (mounted) {
        setState(() {
          _apply(value);
          cameraCode.clear();
          message =
              'Settings confirmed on sensor. Automatic capture is ${value.enabled ? 'on' : 'off'}.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => issue = AppIssue.from(e, fallback: AppIssue.settings));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String get _status => switch (saved?.status) {
    'saved' => 'Photo saved on camera SD card',
    'wifi_unavailable' => 'Sensor Wi-Fi unavailable',
    'camera_pairing_rejected' => 'Camera rejected pairing code',
    'camera_identity_mismatch' => 'A different camera answered at this IP',
    'camera_sd_unavailable' => 'Check camera SD card or camera capture error',
    'camera_cooldown' => 'Camera is waiting for its cooldown',
    'camera_unavailable' =>
      'Camera request failed or timed out; a photo may still have been saved',
    _ => 'No trigger attempt since restart/settings change',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.crop.label} board SD capture')),
    body: Form(
      key: formKey,
      onChanged: () => setState(() => dirty = true),
      child: PageBody(
        children: [
          const Text(
            'The sensor triggers the camera over local Wi-Fi, even with the app closed. Photos stay on the camera SD card; they are not automatically imported or diagnosed in the app.',
          ),
          if (busy) const LinearProgressIndicator(),
          if (dirty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Unsaved changes · save to the sensor to apply.'),
            ),
          if (issue != null)
            IssueCard(
              issue: issue!,
              onRetry: busy ? null : _load,
              retryLabel: 'Reload board settings',
            ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(message!),
            ),
          OutlinedButton(
            onPressed: busy ? null : _load,
            child: const Text('Reload settings and status'),
          ),
          if (saved != null) ...[
            Text('Confirmed on board: ${saved!.enabled ? 'On' : 'Off'}'),
            Text('Last trigger status: $_status'),
            if (saved!.enabled) Text('Board’s saved camera: ${saved!.camera}'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Independent SD capture'),
              subtitle: const Text(
                'Changes take effect only after saving to the sensor.',
              ),
              value: enabled,
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      enabled = v;
                      dirty = true;
                    }),
            ),
            if (enabled) ...[
              Text(
                'Camera: ${widget.hardware.address(widget.crop, 'camera').isEmpty ? 'Assign a camera in Devices first' : widget.hardware.address(widget.crop, 'camera')}',
              ),
              const Text(
                'This uses the camera assigned to this crop. Change that assignment in Devices to choose another camera.',
              ),
              TextFormField(
                controller: cameraCode,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !busy,
                validator: (value) =>
                    RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Enter the 32-character camera pairing code.',
                decoration: const InputDecoration(
                  labelText: 'Camera pairing code',
                  helperText:
                      'From camera Serial Monitor; enter when saving enabled settings.',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Capture when ANY selected measurement remains outside its range. These starting values are sensor bounds, not recommended growing limits. Enter your own limits.',
              ),
              for (var i = 0; i < 3; i++) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    [
                      'Temperature (°C)',
                      'Humidity (%)',
                      'Soil moisture (%)',
                    ][i],
                  ),
                  subtitle: i == 2 && !saved!.soilCalibrated
                      ? const Text('Requires calibration in sensor firmware.')
                      : null,
                  value: selected[i],
                  onChanged: busy || (i == 2 && !saved!.soilCalibrated)
                      ? null
                      : (v) => setState(() {
                          selected[i] = v!;
                          dirty = true;
                        }),
                ),
                if (selected[i])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final low = _limit(i, false), high = _limit(i, true);
                        if (constraints.maxWidth < 400 ||
                            MediaQuery.textScalerOf(context).scale(1) > 1.25) {
                          return Column(
                            children: [low, const SizedBox(height: 20), high],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: low),
                            const SizedBox(width: 16),
                            Expanded(child: high),
                          ],
                        );
                      },
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              TextFormField(
                controller: duration,
                validator: (text) =>
                    validateSeconds(text, minimum: 10, maximum: 3600),
                enabled: !busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Outside range for (seconds)',
                  helperText: '10–3600; readings are checked every 10 seconds.',
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: cooldown,
                validator: (text) =>
                    validateSeconds(text, minimum: 60, maximum: 86400),
                enabled: !busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cooldown (seconds)',
                  helperText:
                      '60–86400; applies after attempts and on restart.',
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : _save,
              child: const Text('Save to sensor'),
            ),
            const Text(
              'To stop board automation, turn it off here and save while connected. Closing the app or disabling the app’s local HTTP toggle does not stop rules already saved on the sensor.',
            ),
          ],
        ],
      ),
    ),
  );

  Widget _limit(int i, bool upper) => TextFormField(
    controller: upper ? maximum[i] : minimum[i],
    enabled: !busy,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    decoration: InputDecoration(labelText: upper ? 'Maximum' : 'Minimum'),
    validator: (text) {
      final error = validateLimit(
        text,
        minimum: i == 0 ? -40 : 0,
        maximum: i == 0 ? 80 : 100,
      );
      if (error != null) return error;
      if (upper &&
          double.parse(text!.trim()) <=
              (double.tryParse(minimum[i].text.trim()) ??
                  double.negativeInfinity)) {
        return 'Maximum must be higher than minimum.';
      }
      return null;
    },
  );
}
