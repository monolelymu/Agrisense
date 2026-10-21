import 'package:flutter/material.dart';
import '../../core/hardware_controller.dart';
import '../../core/widgets.dart';
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
                  'Monitoring runs while the app is active. It pauses on settings screens and resumes when you return.',
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Monitor sensors every 10 seconds'),
                  value: hardware.polling,
                  onChanged:
                      hardware.busy ||
                          (!hardware.polling &&
                              (!hardware.allowLocalHttp ||
                                  hardware.address(crop, 'sensor').isEmpty))
                      ? null
                      : (value) {
                          setState(() {
                            if (value) {
                              hardware.startPolling(crop);
                            } else {
                              hardware.stopPolling();
                            }
                          });
                        },
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
                  onPressed: hardware.busy
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
                  'Limits are saved on this phone. Warning photos are saved under History → Alerts; they are not analyzed for disease yet.',
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
