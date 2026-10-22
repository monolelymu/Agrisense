import 'package:flutter/material.dart';
import '../diagnosis/model_catalog.dart';
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
  bool dirty = false,
      showNotifications = true,
      analyzePhoto = false,
      repeat = false;
  bool applyingPreset = false;
  String preset = 'custom';
  Map<String, dynamic>? baseline;
  String get baselineTime {
    final at = DateTime.tryParse('${baseline?['received_at']}');
    return at == null ? 'Saved reading' : dateLabel(at.toLocal());
  }

  @override
  void initState() {
    super.initState();
    final saved =
        widget.hardware.notificationSettings[widget.crop] ??
        const SensorAlertSettings();
    enabled = saved.enabled;
    capturePhoto = saved.capturePhoto;
    showNotifications = saved.showNotifications;
    analyzePhoto = saved.analyzePhoto;
    repeat = saved.repeat;
    preset = saved.preset;
    baseline = saved.baseline;
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
              widget.hardware.notificationStatus ??
              'Settings saved.',
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
          showNotifications: showNotifications,
          analyzePhoto: analyzePhoto,
          repeat: repeat,
          preset: preset,
          baseline: baseline,
          duration: int.parse(duration.text.trim()),
          cooldown: int.parse(cooldown.text.trim()),
          rules: rules,
        ),
      );
      dirty = false;
    });
  }

  void _preset(String name) {
    try {
      SensorAlertSettings? proposal;
      if (name == 'sensitive') {
        if (!widget.hardware.fresh(widget.crop)) throw AppIssue.stale;
        proposal = SensorAlertSettings.sensitive(
          widget.hardware.latest(widget.crop)!,
          DateTime.now(),
        );
      }
      setState(() {
        applyingPreset = true;
        if (proposal != null) {
          baseline = proposal.baseline;
          for (var i = 0; i < 3; i++) {
            selected[i] = proposal.rules[i].enabled;
            minimum[i].text = '${proposal.rules[i].minimum}';
            maximum[i].text = '${proposal.rules[i].maximum}';
          }
          duration.text = '10';
          cooldown.text = '30';
          repeat = true;
        } else if (name == 'standard') {
          duration.text = '30';
          cooldown.text = '300';
          repeat = false;
          baseline = null;
        }
        preset = name;
        dirty = true;
        applyingPreset = false;
      });
    } catch (e) {
      setState(() => issue = AppIssue.from(e, fallback: AppIssue.settings));
    }
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
            return validateSeconds(text, minimum: 30, maximum: 86400);
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
                  preset = 'custom';
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
    appBar: AppBar(title: Text('${widget.crop.label} monitoring rules')),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: formKey,
            onChanged: () {
              if (!applyingPreset) {
                setState(() {
                  dirty = true;
                  preset = 'custom';
                });
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
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
                    title: const Text('Enable sensor alerts'),
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
                      'Use this crop’s camera when a sensor alert is recorded. Save changes to apply.',
                    ),
                    value: capturePhoto,
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            capturePhoto = v;
                            if (!v) analyzePhoto = false;
                            dirty = true;
                          }),
                  ),
                ),
                const SizedBox(height: 16),
                Panel(
                  padding: 16,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Android notifications'),
                    value: showNotifications,
                    subtitle: const Text(
                      'Capture and analysis still work if notifications are blocked.',
                    ),
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            showNotifications = v;
                            dirty = true;
                          }),
                  ),
                ),
                const SizedBox(height: 16),
                Panel(
                  padding: 16,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    key: const ValueKey('auto-analyze'),
                    title: const Text('Analyze warning photos automatically'),
                    subtitle: Text(
                      widget.hardware.classifier.supports(widget.crop)
                          ? cropModels[widget.crop]?.testingNotice ??
                                'Runs the installed ${widget.crop.label} model on each captured original. Experimental.'
                          : modelStatus(widget.crop),
                    ),
                    value: analyzePhoto,
                    onChanged:
                        busy ||
                            !widget.hardware.classifier.supports(widget.crop)
                        ? null
                        : (v) => setState(() {
                            analyzePhoto = v;
                            if (v) capturePhoto = true;
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
                    'Alerts and linked photos appear in History. The latest 20 originals are kept, up to 30 MB total. Test notifications do not take photos.',
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Monitoring preset',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in const [
                      'standard',
                      'sensitive',
                      'custom',
                    ])
                      ChoiceChip(
                        label: Text(name[0].toUpperCase() + name.substring(1)),
                        selected: preset == name,
                        onSelected: busy ? null : (_) => _preset(name),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sensitive proposes fixed limits from a fresh sample: ±1 °C and ±5 percentage points. Review the limits below, then Save. These are change-detection limits, not disease thresholds.',
                ),
                if (baseline != null) Text('Fixed baseline: $baselineTime'),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => _action(
                          () async {
                            await widget.hardware.refresh(widget.crop);
                            if (widget.hardware.error != null) {
                              throw widget.hardware.issue ??
                                  AppIssue.connection;
                            }
                          },
                          success:
                              'Fresh sample received. Choose Sensitive to preview its limits.',
                        ),
                  child: const Text('Read baseline sample'),
                ),
                const SizedBox(height: 20),
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
                      const SizedBox(height: 8),
                      const Text(
                        'Reading must stay outside its limits for 10–3600 seconds.',
                      ),
                      const SizedBox(height: 24),
                      _number(cooldown, 'Cooldown (seconds)'),
                      const SizedBox(height: 8),
                      const Text(
                        'Wait 30–86400 seconds between accepted alerts, including failed captures.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeat while outside limits'),
                  subtitle: const Text(
                    'After cooldown, a fresh abnormal sample may trigger again.',
                  ),
                  value: repeat,
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                          repeat = v;
                          preset = 'custom';
                          dirty = true;
                        }),
                ),
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
                      'Phone limits are separate from board SD capture rules. Background monitoring must be enabled separately. Missing readings restart the duration. Android settings control sound and banners. Sensor alerts trigger photos; disease analysis uses the image model.',
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
