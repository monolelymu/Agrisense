import 'package:flutter/material.dart';
import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({
    required this.controller,
    required this.onResult,
    required this.onDevices,
    super.key,
  });
  final AppController controller;
  final ValueChanged<DiseaseResult> onResult;
  final VoidCallback onDevices;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final alerts = c.alerts
        .where((a) => a.crop == c.selectedCrop)
        .toList()
        .reversed;
    return PageBody(
      children: [
        SectionTitle('Alerts', '${c.selectedCrop.label} • threshold events'),
        CropPicker(value: c.selectedCrop, onChanged: c.selectCrop),
        const SizedBox(height: 22),
        if (alerts.isEmpty)
          const EmptyState(
            'All quiet here',
            'Connect a simulated Sensor Node and tap Simulate stress to create an alert.',
            icon: Icons.notifications_none,
          ),
        for (final a in alerts)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      Tag(
                        a.resolved ? 'RESOLVED' : 'ATTENTION',
                        color: a.resolved ? accent : warning,
                      ),
                      const Tag('SIMULATED EVENT'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Stress threshold crossed • ${a.score}/100',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    dateLabel(a.timestamp),
                    style: const TextStyle(color: muted),
                  ),
                  const SizedBox(height: 12),
                  if (a.diagnosisId != null)
                    FilledButton.tonal(
                      onPressed: () {
                        final result = c.resultById(a.diagnosisId);
                        if (result != null) onResult(result);
                      },
                      child: const Text('View mock diagnosis'),
                    )
                  else ...[
                    const Text(
                      'No diagnosis saved. Both simulated nodes must be connected to try the image flow.',
                      style: TextStyle(color: muted),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: onDevices,
                          child: const Text('Connect nodes'),
                        ),
                        FilledButton.tonal(
                          onPressed:
                              c.busy ||
                                  !c.connected(a.crop, NodeKind.sensor) ||
                                  !c.connected(a.crop, NodeKind.vision)
                              ? null
                              : () => c.retryDiagnosis(a),
                          child: const Text('Retry mock diagnosis'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
