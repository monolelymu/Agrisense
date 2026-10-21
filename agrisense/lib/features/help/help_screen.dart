import 'package:flutter/material.dart';
import '../../core/app_issue.dart';
import '../../core/widgets.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, this.issue, this.onReplay});
  final AppIssue? issue;
  final VoidCallback? onReplay;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help & troubleshooting')),
    body: PageBody(
      children: [
        const Text('Help is available offline.'),
        const SizedBox(height: 16),
        if (onReplay != null) ...[
          OutlinedButton.icon(
            onPressed: onReplay,
            icon: const Icon(Icons.school_outlined),
            label: const Text('Replay tutorial'),
          ),
          const SizedBox(height: 20),
        ],
        const ExpansionTile(
          title: Text('Connect your devices'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Use the same trusted Wi-Fi for your phone and boards. Select a crop in Devices, enable local hardware access, and enter each board’s IP. Pair the sensor using its private code. Test the sensor and camera before starting monitoring.',
              ),
            ),
          ],
        ),
        const ExpansionTile(
          title: Text('Monitoring and automatic photos'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Phone monitoring checks the selected crop every ten seconds. Enable warning photos and automatic analysis in Monitoring & Auto Scan. Background operation requires the separate Continue in background switch and an explicit start while the app is visible. Settings and manual analysis pause monitoring. Force-stop, reboot or process termination ends it. Android can delay checks. Advanced SD capture runs independently; stop it by connecting and saving Off to the sensor.',
              ),
            ),
          ],
        ),
        const ExpansionTile(
          title: Text('Get a useful leaf photo'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Use an evenly lit, sharp leaf photo with the leaf filling the frame. Retake blurry, very dark or purple-tinted images. Only Tomato analysis is currently installed. Image scores are model outputs, not a guarantee of disease or accuracy.',
              ),
            ),
          ],
        ),
        const ExpansionTile(
          title: Text('History and local storage'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'History separates disease scans, sensor Alerts with linked photos/results, and readings. Alerts show failures and manual recovery actions. The latest 500 alerts and 20 warning originals (up to 30 MB) are retained. Board SD photos are not imported automatically. Clearing app data or uninstalling removes local records.',
              ),
            ),
          ],
        ),
        const ExpansionTile(
          title: Text('Tomato growing conditions and scan explanations'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Growing references describe the environment, not confirmed plant health. Daytime is assumed to be 06:00–18:00 on this phone. Humidity guidance is qualified for protected growing; soil moisture needs calibration. Readings expire after 30 seconds. Tomato results explain all 17 labels and show saved sensor evidence when available. Uploads and older scans do not acquire current readings. Sources can be copied, and sensor context never changes the image model score.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Error codes', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final item in [
          ?issue,
          ...AppIssue.all.where((e) => e.code != issue?.code),
        ])
          ExpansionTile(
            key: ValueKey(item.code),
            initiallyExpanded: item.code == issue?.code,
            title: Text('${item.code} · ${item.title}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(item.recovery),
              ),
            ],
          ),
      ],
    ),
  );
}

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.onDone});
  final Future<void> Function() onDone;
  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  bool busy = false;
  Future<void> _finish() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.onDone();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Welcome to AgriSense'),
      actions: [
        TextButton(onPressed: busy ? null : _finish, child: const Text('Skip')),
      ],
    ),
    body: PageBody(
      children: [
        const SectionTitle(
          'Start with your crop',
          'You can use photo diagnosis without hardware.',
        ),
        for (final step in const [
          (
            '1. Choose a crop',
            'Tomato and Eggplant have experimental photo analysis, offline knowledge and growing references. Eggplant photo preparation is provisional for testing. Chili supports sensor monitoring while its model is prepared.',
          ),
          (
            '2. Connect, if you have boards',
            'In Devices, enable local hardware access on trusted Wi-Fi. Assign and test the sensor and camera.',
          ),
          (
            '3. Monitor or scan',
            'Scan a leaf photo, or configure sensor alerts and automatic analysis in Monitoring & Auto Scan. Enable background operation separately to continue while minimized.',
          ),
          (
            '4. Review your records',
            'History separates Scans, Alerts and Readings by crop. Help explains error codes and setup. You can replay this tutorial there.',
          ),
        ]) ...[
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.$1, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(step.$2),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: busy ? null : _finish,
          child: const Text('Get started'),
        ),
        TextButton(
          onPressed: busy ? null : _finish,
          child: const Text('Skip tutorial'),
        ),
      ],
    ),
  );
}
