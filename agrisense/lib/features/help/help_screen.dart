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
                'Phone monitoring reads the selected crop every ten seconds while the app is active. It pauses outside the app and during analysis or settings, and resumes on return. Enable notifications and warning photos in Monitoring & Auto Scan. Warning photos are snapshots; automatic diagnosis is not available yet. Advanced SD capture runs on the boards independently, even with the app closed. Turning off phone monitoring does not stop it; connect and save Off to the sensor.',
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
                'History separates disease scans, warning photos under Alerts, and sensor readings. Select a crop to filter records. Board SD photos are not imported automatically. Records stay on this device; clearing app data or uninstalling removes them.',
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
            'Tomato has photo analysis. Chili and Eggplant support sensor monitoring while their models are prepared.',
          ),
          (
            '2. Connect, if you have boards',
            'In Devices, enable local hardware access on trusted Wi-Fi. Assign and test the sensor and camera.',
          ),
          (
            '3. Monitor or scan',
            'Scan a leaf photo, or set sensor limits in Monitoring & Auto Scan. Phone monitoring pauses when the app is not active.',
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
