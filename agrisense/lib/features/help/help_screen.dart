import 'package:flutter/material.dart';
import '../../core/app_issue.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../diagnosis/model_catalog.dart';

enum HelpDestination { scan, devices, monitoring, alerts, tutorial }

String _availability(Crop? crop) =>
    (crop == null ? Crop.values : [crop]).map(modelStatus).join('\n');

class HelpScreen extends StatelessWidget {
  const HelpScreen({
    super.key,
    this.issue,
    this.onReplay,
    this.crop,
    this.showShortcuts = false,
  });
  final AppIssue? issue;
  final VoidCallback? onReplay;
  final Crop? crop;
  final bool showShortcuts;

  Widget _error(AppIssue item, {bool expanded = false}) => ExpansionTile(
    key: ValueKey(item.code),
    initiallyExpanded: expanded,
    title: Text('${item.code} · ${item.title}'),
    children: [
      Padding(padding: const EdgeInsets.all(16), child: Text(item.recovery)),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help & troubleshooting')),
    body: PageBody(
      children: [
        const Text('Help is available offline.'),
        const SizedBox(height: 12),
        if (crop != null) ...[
          Text(
            'Selected crop: ${crop!.label}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
        ],
        Panel(child: Text(_availability(crop))),
        const SizedBox(height: 16),
        if (issue != null) ...[
          const SizedBox(height: 12),
          _error(issue!, expanded: true),
        ],
        if (onReplay != null)
          OutlinedButton.icon(
            onPressed: onReplay,
            icon: const Icon(Icons.school_outlined),
            label: const Text('Replay tutorial'),
          ),
        if (showShortcuts) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in const [
                (HelpDestination.scan, 'Scan leaf'),
                (HelpDestination.devices, 'Devices'),
                (HelpDestination.monitoring, 'Monitoring & Auto Scan'),
                (HelpDestination.alerts, 'History → Alerts'),
              ])
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(action.$1),
                  child: Text(action.$2),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        for (final topic in const [
          (
            'Scan a useful leaf photo',
            'You can upload a photo without connecting boards. Choose the crop before scanning; the app cannot reliably check that a leaf belongs to that crop. Use a sharp, evenly lit photo with the leaf filling most of the frame. Avoid clutter, deep shadows and glare. Retake blurry, dark or purple-tinted photos. Choose JPEG or PNG, up to 15 MB, 24 megapixels and 12,000 pixels per side.',
          ),
          (
            'Understand your prediction',
            'The top result is an image prediction. Confirm the cause by inspecting the plant. Model scores are not measured accuracy or validated disease probabilities. Check the other predictions, symptoms and sources; another clear photo can help compare results but cannot guarantee a correct answer. Growing references and saved sensor evidence describe conditions, not confirmed plant health, and never change the image score. Humidity is not measured leaf wetness; soil percentage requires calibration. Uploaded photos and older scans do not acquire current sensor readings.',
          ),
          (
            'Connect your devices',
            'Use the same trusted Wi-Fi for your phone and boards. In Devices, select the crop, enable local hardware access and enter each board’s IP address. Pair the sensor using its private code. Assign and test the sensor and camera before monitoring. Hardware is not required for uploaded-photo analysis.',
          ),
          (
            'Monitoring and background operation',
            'Monitoring & Auto Scan has separate controls for monitoring, notifications, warning photos, automatic analysis and background operation. A saved alert does not necessarily have a photo or diagnosis. Standard uses your limits, a 30-second duration and 300-second cooldown; each measurement must recover before triggering again. Sensitive proposes fixed limits from one fresh sample: ±1 °C and ±5 percentage points for humidity and calibrated soil, with a 10-second duration and 30-second cooldown and repeat alerts. Review before saving. Editing switches to Custom. These are change-detection limits, not disease thresholds. Checks are requested every ten seconds; Android may delay them. Denied notifications do not prevent saving or analysis. Start background monitoring while the app is visible; force-stop, reboot or process termination ends it. Settings, Help and manual analysis pause monitoring. Advanced board SD capture is independent, uses a minimum 60-second cooldown and must be stopped by connecting and saving Off to the sensor. Its SD photos are not imported automatically.',
          ),
          (
            'History and local storage',
            'History is filtered by crop. Scans contains saved predictions, Alerts contains sensor events and linked photos/results, and Readings contains sensor samples. The latest 500 alerts and 20 warning originals (up to 30 MB) are retained. An alert can remain after its original photo expires. Saved diagnoses retain their existing history. Clearing app data or uninstalling removes local records; do not use those actions as routine troubleshooting.',
          ),
          (
            'Recover a failed action',
            'Retry saving keeps the existing prediction; it does not capture or analyze again. Keep the result screen open if saving failed. Retry analysis uses the saved original photo and an installed crop model. These local actions do not need a board connection. Retry capture needs the assigned camera, power and trusted Wi-Fi; a new capture records the plant as it looks now. If the original has expired, it cannot be analyzed again; capture or upload a new photo. Recovery is manual, not an automatic retry loop. If saving settings was uncertain, reload before changing them again.',
          ),
        ])
          ExpansionTile(
            title: Text(topic.$1),
            children: [
              Padding(padding: const EdgeInsets.all(16), child: Text(topic.$2)),
            ],
          ),
        const SizedBox(height: 24),
        Text('Error codes', style: Theme.of(context).textTheme.titleLarge),
        for (final item in AppIssue.all.where((e) => e.code != issue?.code))
          _error(item),
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
        Text(
          'No More Guessplant',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        const SectionTitle(
          'Start with your crop',
          'You can use photo diagnosis without hardware.',
        ),
        for (final step in [
          (
            '1. Choose a crop',
            'Select the crop that matches your leaf. Photo analysis works without hardware.\n${_availability(null)}',
          ),
          (
            '2. Connect, if you have boards',
            'In Devices, enable local hardware access on trusted Wi-Fi. Assign and test the sensor and camera.',
          ),
          (
            '3. Monitor or scan',
            'Use a sharp, evenly lit leaf photo. Predictions and model scores are not confirmed diagnoses. For connected boards, configure Monitoring & Auto Scan; enable background operation separately.',
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
