import 'package:flutter/material.dart';
import '../../core/hardware_controller.dart';
import '../../core/widgets.dart';
import '../../data/app_alert_event.dart';
import '../../data/models.dart';
import '../diagnosis/simple_result_card.dart';
import 'alert_detail_screen.dart';

class AppAlertsScreen extends StatefulWidget {
  const AppAlertsScreen({
    super.key,
    required this.hardware,
    this.initialTarget,
  });
  final HardwareController hardware;
  final AlertTarget? initialTarget;
  @override
  State<AppAlertsScreen> createState() => _AppAlertsScreenState();
}

class _AppAlertsScreenState extends State<AppAlertsScreen> {
  HardwareController get h => widget.hardware;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = widget.initialTarget;
      if (mounted && target != null) _open(target.type, target.target);
    });
  }

  Future<void> _open(String type, String target) async {
    Widget? screen;
    if (type == 'sensor' && h.alerts.any((a) => a.id == target)) {
      screen = AlertDetailScreen(hardware: h, id: target);
    } else if (type == 'scheduled') {
      final results = h.scanStore.load().where((scan) => scan.id == target);
      if (results.isNotEmpty) {
        final scan = results.first;
        screen = Scaffold(
          appBar: AppBar(title: const Text('Scheduled photo')),
          body: PageBody(children: [SimpleResultCard(scan: scan)]),
        );
      }
    }
    if (screen == null) {
      final events = h.events.where(
        (event) => event.type == type && event.target == target,
      );
      if (events.isEmpty) return; // Deleted/expired target: stay in Alerts.
      final event = events.first;
      screen = Scaffold(
        appBar: AppBar(title: Text(event.title)),
        body: PageBody(
          children: [
            Text(dateLabel(event.at)),
            const SizedBox(height: 16),
            Text(event.body, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen!));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: h,
    builder: (context, _) {
      final entries = <AppAlertEvent>[...h.events];
      // Old sensor records remain visible without rewriting their saved data.
      for (final alert in h.alerts) {
        if (!entries.any(
          (event) => event.type == 'sensor' && event.target == alert.id,
        )) {
          entries.add(
            AppAlertEvent(
              id: alert.id,
              type: 'sensor',
              title: '${alert.crop.label}: sensor warning',
              body: alert.reason,
              at: alert.timestamp,
              target: alert.id,
            ),
          );
        }
      }
      entries.sort((a, b) => b.at.compareTo(a.at));
      return Scaffold(
        appBar: AppBar(title: const Text('Alerts')),
        body: PageBody(
          children: [
            if (h.remindersIssue != null) Text(h.remindersIssue!),
            if (entries.isEmpty)
              const EmptyState(
                'No alerts yet',
                'Sensor warnings, scheduled photos and watering reminders appear here.',
              ),
            for (final event in entries) ...[
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  leading: Icon(switch (event.type) {
                    'watering' => Icons.water_drop_outlined,
                    'scheduled' => Icons.schedule,
                    _ => Icons.notifications_outlined,
                  }),
                  title: Text(event.title),
                  subtitle: Text('${dateLabel(event.at)}\n${event.body}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(event.type, event.target),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      );
    },
  );
}
