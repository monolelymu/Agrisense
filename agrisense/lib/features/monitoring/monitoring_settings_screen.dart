import 'package:flutter/material.dart';
import '../../core/hardware_controller.dart';
import '../../core/widgets.dart';
import '../../core/app_issue.dart';
import '../../core/issue_card.dart';
import '../../data/models.dart';
import 'automatic_capture_screen.dart';
import 'notification_settings_screen.dart';

class MonitoringSettingsScreen extends StatefulWidget {
  const MonitoringSettingsScreen({
    super.key,
    required this.hardware,
    required this.crop,
  });
  final HardwareController hardware;
  final Crop crop;
  @override
  State<MonitoringSettingsScreen> createState() =>
      _MonitoringSettingsScreenState();
}

class _MonitoringSettingsScreenState extends State<MonitoringSettingsScreen> {
  HardwareController get hardware => widget.hardware;
  Crop get crop => widget.crop;
  bool working = false;
  AppIssue? issue;
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      working = true;
      issue = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => issue = AppIssue.from(e, fallback: AppIssue.background));
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _open(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Monitoring & Auto Scan')),
    body: AnimatedBuilder(
      animation: hardware,
      builder: (context, _) => PageBody(
        children: [
          SectionTitle(
            '${crop.label} monitoring',
            'Choose how to monitor your crops.',
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'On this phone',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Monitoring pauses on settings screens. Enable background operation below to continue from the Dashboard when minimized or screen-locked.',
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Monitor sensors every 10 seconds'),
                  value: hardware.polling,
                  onChanged:
                      working ||
                          hardware.busy ||
                          (!hardware.polling &&
                              (!hardware.allowLocalHttp ||
                                  hardware.address(crop, 'sensor').isEmpty))
                      ? null
                      : (value) => _run(() async {
                          if (value) {
                            await hardware.startMonitoring(crop);
                          } else {
                            hardware.stopPolling();
                          }
                        }),
                ),
                if (!hardware.allowLocalHttp ||
                    hardware.address(crop, 'sensor').isEmpty)
                  const Text(
                    'Enable local hardware access and assign a sensor in Devices to start monitoring.',
                  ),
                const SizedBox(height: 12),
                Text(hardware.monitoringStatus),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: working || hardware.busy
                      ? null
                      : () => _open(
                          context,
                          NotificationSettingsScreen(
                            hardware: hardware,
                            crop: crop,
                          ),
                        ),
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('Sensor limits & warning photos'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Phone limits control alerts, warning photos and optional automatic analysis. Open History to review each alert and its linked result.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (working) const LinearProgressIndicator(),
          if (issue != null) IssueCard(issue: issue!),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Continue in background'),
                  subtitle: const Text(
                    'Uses an ongoing Android notification with Open and Stop actions. May increase battery use.',
                  ),
                  value: hardware.backgroundEnabled,
                  onChanged:
                      working || hardware.busy || !hardware.service.supported
                      ? null
                      : (value) =>
                            _run(() => hardware.setBackgroundEnabled(value)),
                ),
                const Text(
                  'Start monitoring while the app is visible. Force-stop, reboot or process termination ends monitoring; start it again manually. Android may delay checks under power restrictions.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Panel(
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Advanced: independent SD capture'),
              children: [
                const Text(
                  'These rules are saved on the sensor board. They can take photos with the app closed. Photos stay on the camera SD card and do not appear in app history or diagnosis.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Closing the app or turning off phone monitoring does not stop these rules. To stop, connect to the sensor and save Off.',
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed:
                      working ||
                          hardware.busy ||
                          !hardware.allowLocalHttp ||
                          hardware.address(crop, 'sensor').isEmpty
                      ? null
                      : () => _open(
                          context,
                          AutomaticCaptureScreen(
                            hardware: hardware,
                            crop: crop,
                          ),
                        ),
                  child: const Text('Manage board SD capture'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
