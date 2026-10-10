import 'package:flutter/material.dart';
import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    required this.controller,
    required this.onResult,
    super.key,
  });
  final AppController controller;
  final ValueChanged<DiseaseResult> onResult;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool allCrops = false;
  String type = 'Scans';
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final results = c.results
        .where((r) => allCrops || r.crop == c.selectedCrop)
        .toList()
        .reversed
        .toList();
    final readings =
        c.readings.where((r) => allCrops || r.crop == c.selectedCrop).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final alerts = c.alerts
        .where((a) => allCrops || a.crop == c.selectedCrop)
        .toList()
        .reversed
        .toList();
    return PageBody(
      children: [
        const SectionTitle(
          'Your growing journal',
          'Saved locally on this browser or phone.',
        ),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CropPicker(value: c.selectedCrop, onChanged: c.selectCrop),
            FilterChip(
              label: const Text('All crops'),
              selected: allCrops,
              onSelected: (v) => setState(() => allCrops = v),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Scans', label: Text('Scans')),
            ButtonSegment(value: 'Readings', label: Text('Readings')),
            ButtonSegment(value: 'Alerts', label: Text('Alerts')),
          ],
          selected: {type},
          onSelectionChanged: (v) => setState(() => type = v.first),
        ),
        const SizedBox(height: 22),
        if (type == 'Scans') ...[
          if (results.isEmpty)
            const EmptyState(
              'Your first scan starts here',
              'Run the guided demo with both simulated nodes connected.',
              icon: Icons.history,
            ),
          for (final r in results)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.document_scanner_outlined,
                    color: accent,
                  ),
                  title: Text('${r.crop.label} • ${r.label}'),
                  subtitle: Text('Mock diagnosis • ${dateLabel(r.timestamp)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => widget.onResult(r),
                ),
              ),
            ),
        ],
        if (type == 'Readings') ...[
          if (readings.isEmpty)
            const EmptyState(
              'No readings saved',
              'Connect a simulated Sensor Node to record a sample.',
            ),
          for (final r in readings)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.water_drop_outlined, color: accent),
                  title: Text('${r.crop.label} • ${dateLabel(r.timestamp)}'),
                  subtitle: Text(
                    'Mock • Soil ${r.soil.toStringAsFixed(0)}% · ${c.temperature(r.temperature)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('${r.crop.label} sensor log'),
                      content: Text(
                        'Mock reading\n${dateLabel(r.timestamp)}\n\nSoil: ${r.soil}%\nTemperature: ${c.temperature(r.temperature)}\nHumidity: ${r.humidity}%\nGas / VOC: ${r.gas} raw',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
        if (type == 'Alerts') ...[
          if (alerts.isEmpty)
            const EmptyState(
              'No alerts saved',
              'Cross a demo stress threshold to record an alert.',
            ),
          for (final a in alerts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    a.resolved
                        ? Icons.check_circle_outline
                        : Icons.warning_amber,
                    color: warning,
                  ),
                  title: Text('${a.crop.label} • stress ${a.score}/100'),
                  subtitle: Text(
                    'Simulated • ${a.resolved ? 'Resolved' : 'Attention'} • ${dateLabel(a.timestamp)}',
                  ),
                  trailing: a.diagnosisId == null
                      ? null
                      : const Icon(Icons.chevron_right),
                  onTap: a.diagnosisId == null
                      ? null
                      : () {
                          final r = c.resultById(a.diagnosisId);
                          if (r != null) widget.onResult(r);
                        },
                ),
              ),
            ),
        ],
      ],
    );
  }
}
