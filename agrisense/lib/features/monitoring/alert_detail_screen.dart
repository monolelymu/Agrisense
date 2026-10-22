import 'package:flutter/material.dart';
import '../../core/app_issue.dart';
import '../../core/hardware_controller.dart';
import '../../core/issue_card.dart';
import '../../core/widgets.dart';
import '../../data/monitoring_alert.dart';
import '../../data/models.dart';
import '../diagnosis/tomato_scan_screen.dart';

String alertStateLabel(String value) => switch (value) {
  'pending' => 'Alert recorded',
  'capturing' => 'Capturing photo',
  'analyzing' => 'Analyzing photo',
  'saving' => 'Saving result',
  'completed' => 'Diagnosis saved',
  'alert_only' => 'Alert only',
  'photo_saved' => 'Photo saved',
  'capture_failed' => 'Capture failed',
  'analysis_failed' => 'Analysis failed',
  'save_failed' => 'Result not saved',
  'photo_save_failed' => 'Photo not saved',
  'model_unavailable' => 'Model unavailable',
  'interrupted' => 'Interrupted',
  _ => 'Review alert',
};

class AlertDetailScreen extends StatefulWidget {
  const AlertDetailScreen({
    super.key,
    required this.hardware,
    required this.id,
  });
  final HardwareController hardware;
  final String id;
  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  AppIssue? issue;
  Future<void> _retry(bool capture) async {
    try {
      setState(() => issue = null);
      await widget.hardware.retryAlert(widget.id, capture: capture);
    } catch (e) {
      if (mounted) setState(() => issue = AppIssue.from(e));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.hardware,
    builder: (context, _) {
      final h = widget.hardware;
      final matches = h.alerts.where((a) => a.id == widget.id);
      if (matches.isEmpty) {
        return Scaffold(
          appBar: AppBar(title: const Text('Alert')),
          body: const PageBody(
            children: [Text('This alert has expired from recent history.')],
          ),
        );
      }
      final MonitoringAlert alert = matches.first;
      final photo = h.photoFor(alert.id);
      final scans = h.scanStore.load().where((s) => s.id == alert.resultId);
      final result = scans.isEmpty ? null : scans.first;
      final code = alert.issueCode;
      final known = AppIssue.all.where((i) => i.code == code);
      return Scaffold(
        appBar: AppBar(title: Text('${alert.crop.label} sensor alert')),
        body: PageBody(
          children: [
            Text(
              alertStateLabel(alert.state),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text('Triggered ${dateLabel(alert.timestamp)}'),
            const SizedBox(height: 12),
            Text(alert.reason),
            const SizedBox(height: 8),
            Text(
              'Preset: ${alert.settings.preset} · sustained ${alert.settings.duration}s · cooldown ${alert.settings.cooldown}s',
            ),
            const SizedBox(height: 12),
            const Text(
              'Readings describe conditions at the trigger time. Disease predictions use the photo.',
            ),
            const SizedBox(height: 20),
            if (alert.capturedAt != null)
              Text('Photo captured ${dateLabel(alert.capturedAt!)}'),
            if (photo != null)
              Image.memory(
                photo.jpeg,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Text('Photo could not be displayed.'),
              )
            else
              Text(
                alert.capturedAt != null
                    ? 'Original photo has expired or is unavailable.'
                    : 'No photo saved.',
              ),
            if (h.busy) const LinearProgressIndicator(),
            if (issue != null || known.isNotEmpty)
              IssueCard(issue: issue ?? known.first),
            if (result != null) ...[
              const SizedBox(height: 20),
              TomatoResultCard(scan: result),
            ],
            if (!h.busy &&
                !alert.unfinished &&
                (result == null || h.canRetrySaving(alert.id))) ...[
              const SizedBox(height: 20),
              if (h.canRetrySaving(alert.id))
                FilledButton(
                  onPressed: () => _retry(false),
                  child: const Text('Retry saving'),
                )
              else if (result == null &&
                  photo != null &&
                  alert.settings.analyzePhoto &&
                  h.classifier.supports(alert.crop))
                FilledButton(
                  onPressed: () => _retry(false),
                  child: const Text('Retry analysis'),
                ),
              if (result == null &&
                  photo == null &&
                  alert.capturedAt != null &&
                  !h.canRetrySaving(alert.id))
                const Text(
                  'Retry analysis is unavailable because the original photo has expired or could not be loaded. Capture or upload a new photo to make a new prediction.',
                ),
              if (result == null &&
                  photo != null &&
                  alert.settings.analyzePhoto &&
                  !h.classifier.supports(alert.crop) &&
                  !h.canRetrySaving(alert.id))
                const Text(
                  'This crop has no available analysis model. The saved photo and alert remain available; sensor monitoring works independently.',
                ),
              if (result == null &&
                  alert.settings.capturePhoto &&
                  (photo == null || alert.state == 'capture_failed'))
                OutlinedButton(
                  onPressed: () => _retry(true),
                  child: Text(
                    alert.capturedAt == null
                        ? 'Retry capture'
                        : 'Capture a new photo',
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}
