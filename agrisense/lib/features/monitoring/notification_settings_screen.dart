import 'package:flutter/material.dart';
import '../../core/hardware_controller.dart';
import '../../core/sensor_notifications.dart';
import '../../data/automatic_capture.dart';
import '../../data/models.dart';
import '../../core/widgets.dart';
import '../../core/app_issue.dart';
import '../../core/issue_card.dart';
import '../../core/limit_validation.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    required this.hardware,
    required this.crop,
    super.key,
  });
  final HardwareController hardware;
  final Crop crop;
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final minimum = List.generate(3, (_) => TextEditingController());
  final maximum = List.generate(3, (_) => TextEditingController());
  final duration = TextEditingController(), cooldown = TextEditingController();
  final selected = [false, false, false];
  bool enabled = false, busy = false, capturePhoto = false;
  String? message;
  AppIssue? issue;
  final formKey = GlobalKey<FormState>();
  bool dirty = false;
  @override
  void initState() {
    super.initState();
    final saved =
        widget.hardware.notificationSettings[widget.crop] ??
        const SensorAlertSettings();
    enabled = saved.enabled;
    capturePhoto = saved.capturePhoto;
    duration.text = '${saved.duration}';
    cooldown.text = '${saved.cooldown}';
    for (var i = 0; i < 3; i++) {
      selected[i] = saved.rules[i].enabled;
      minimum[i].text = '${saved.rules[i].minimum}';
      maximum[i].text = '${saved.rules[i].maximum}';
    }
  }

  @override
  void dispose() {
    for (final controller in [...minimum, ...maximum, duration, cooldown]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _action(
    Future<void> Function() action, {
    String? success,
  }) async {
    setState(() {
      busy = true;
      message = null;
      issue = null;
    });
    try {
      await action();
      if (mounted) {
        setState(
          () => message =
              success ??
              (widget.hardware.polling
                  ? 'Saved. Monitoring resumes automatically when you return.'
                  : 'Saved. Turn on monitoring for sensor alerts.'),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => issue = AppIssue.from(e, fallback: AppIssue.settings));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    await _action(() async {
      final previous =
          widget.hardware.notificationSettings[widget.crop] ??
          const SensorAlertSettings();
      final rules = [
        for (var i = 0; i < 3; i++)
          CaptureRule(
            selected[i],
            selected[i]
                ? double.parse(minimum[i].text.trim())
                : previous.rules[i].minimum,
            selected[i]
                ? double.parse(maximum[i].text.trim())
                : previous.rules[i].maximum,
          ),
      ];
      await widget.hardware.saveNotificationSettings(
        widget.crop,
        SensorAlertSettings(
          enabled: enabled,
          capturePhoto: capturePhoto,
          duration: int.parse(duration.text.trim()),
          cooldown: int.parse(cooldown.text.trim()),
          rules: rules,
        ),
      );
      dirty = false;
    });
  }

  Widget _number(TextEditingController controller, String label) =>
      TextFormField(
        key: ValueKey('notification-$label'),
        controller: controller,
        validator: (text) {
          if (controller == duration) {
            return validateSeconds(text, minimum: 10, maximum: 3600);
          }
          if (controller == cooldown) {
            return validateSeconds(text, minimum: 60, maximum: 86400);
          }
          final i = minimum.contains(controller)
              ? minimum.indexOf(controller)
              : maximum.indexOf(controller);
          final error = validateLimit(
            text,
            minimum: i == 0 ? -40 : 0,
            maximum: i == 0 ? 80 : 100,
          );
          if (error != null) return error;
          if (maximum.contains(controller) &&
              double.parse(text!.trim()) <=
                  (double.tryParse(minimum[i].text.trim()) ??
                      double.negativeInfinity)) {
            return 'Maximum must be higher than minimum.';
          }
          return null;
        },
        enabled: !busy,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
      );

  Widget _measurement(int i) => Panel(
    padding: 16,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          key: ValueKey('notification-metric-$i'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            ['Temperature (°C)', 'Humidity (%)', 'Soil moisture (%)'][i],
            style: Theme.of(context).textTheme.titleMedium,
          ),
          value: selected[i],
          onChanged: busy
              ? null
              : (v) => setState(() {
                  selected[i] = v!;
                  dirty = true;
                }),
        ),
        if (i == 2)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Requires calibrated soil readings.'),
          ),
        if (selected[i]) ...[
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final low = _number(minimum[i], 'Minimum'),
                  high = _number(maximum[i], 'Maximum');
              if (constraints.maxWidth < 320 ||
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
          const SizedBox(height: 4),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.crop.label} notifications')),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: formKey,
            onChanged: () => setState(() => dirty = true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Text(
                  'Sensor alerts',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose which readings should warn you while monitoring is on.',
                ),
                const SizedBox(height: 20),
                Panel(
                  padding: 16,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable notifications'),
                    subtitle: const Text('Changes take effect after saving.'),
                    value: enabled,
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            enabled = v;
                            dirty = true;
                          }),
                  ),
                ),
                const SizedBox(height: 16),
                Panel(
                  padding: 16,
                  child: SwitchListTile(
                    key: const ValueKey('capture-on-alert'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Take a photo on warning'),
                    subtitle: const Text(
                      'Use this crop’s camera after a real sensor notification. Save changes to apply.',
                    ),
                    value: capturePhoto,
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            capturePhoto = v;
                            dirty = true;
                          }),
                  ),
                ),
                if (capturePhoto) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.hardware.address(widget.crop, 'camera').isEmpty
                        ? 'Assign a camera to this crop in Devices first.'
                        : 'Camera: ${widget.hardware.address(widget.crop, 'camera')}',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Photos appear in History. The latest 20 snapshots are kept, up to 30 MB total. Test notifications do not take photos.',
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Measurements and limits',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter suitable growing limits. Initial values are sensor bounds.',
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < 3; i++) ...[
                  _measurement(i),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 8),
                Text(
                  'Alert timing',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Panel(
                  padding: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _number(duration, 'Duration (seconds)'),
                      const SizedBox(height: 10),
                      const Text(
                        'Reading must stay outside its limits for 10–3600 seconds.',
                      ),
                      const SizedBox(height: 28),
                      _number(cooldown, 'Cooldown (seconds)'),
                      const SizedBox(height: 10),
                      const Text(
                        'Wait 60–86400 seconds between alerts. Each measurement alerts once until it recovers.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (busy) const LinearProgressIndicator(),
                if (dirty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Unsaved changes · saved on this phone after Save.',
                    ),
                  ),
                if (issue != null) IssueCard(issue: issue!),
                if (message != null) ...[
                  Text(message!),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  onPressed: busy ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Save notification settings'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => _action(
                          () => widget.hardware.testNotification(widget.crop),
                          success:
                              'Test notification posted. Check the Android notification shade.',
                        ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Send test notification'),
                ),
                const SizedBox(height: 20),
                const ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('How alerts work'),
                  childrenPadding: EdgeInsets.only(bottom: 20),
                  children: [
                    Text(
                      'Limits are saved on this phone, separately from automatic camera rules. Monitoring pauses outside the app and resumes on return. Missing readings restart the duration. Android settings control sound and banners. Sensor alerts are not disease diagnoses.',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
