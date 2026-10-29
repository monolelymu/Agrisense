import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import 'tomato_scan.dart';
import 'tomato_knowledge.dart';
import 'eggplant_knowledge.dart';
import 'chili_knowledge.dart';
import 'disease_example.dart';
import 'scan_guidance.dart';

class SimpleResultCard extends StatelessWidget {
  const SimpleResultCard({required this.scan, super.key});
  final TomatoScan scan;
  static const _links = MethodChannel('agrisense/external_links');

  Future<void> _sources(
    BuildContext context,
    List<KnowledgeSource> sources,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Learn more',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text('Plant care websites. Internet needed.'),
            const SizedBox(height: 12),
            for (final source in sources)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: Text(source.title),
                  onPressed: () async {
                    var opened = false;
                    try {
                      opened =
                          await _links.invokeMethod<bool>('open', {
                            'url': source.url,
                          }) ??
                          false;
                    } catch (_) {
                      /* Show a readable failure below. */
                    }
                    if (!opened && sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Cannot open the website. Check your internet connection.',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final predictions = [...scan.rankedPredictions]
      ..sort((a, b) => b.score.compareTo(a.score));
    final entry = switch (scan.crop) {
      Crop.tomato => tomatoKnowledge[scan.label],
      Crop.eggplant => eggplantKnowledge[scan.label],
      Crop.chili => chiliKnowledge[scan.label],
    };
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.memory(
            scan.preview,
            height: 220,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Text('Photo unavailable.'),
          ),
          const SizedBox(height: 16),
          Text(
            scan.uncertain
                ? 'Not sure yet'
                : scan.label == 'healthy'
                ? 'Looks healthy in this photo'
                : 'Possible ${scan.displayLabel}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '${scan.crop.label} • ${dateLabel(scan.timestamp)}',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 12),
          Text(
            scan.uncertain
                ? 'Try a closer view of one leaf in good light.'
                : scan.label == 'healthy'
                ? 'Keep checking new leaves and nearby plants.'
                : entry?.explanation ??
                      'Check the leaf and take another clear photo.',
          ),
          const SizedBox(height: 12),
          Text(scanSensorSummary(scan)),
          for (final measurement in scanSensorMeasurements(scan))
            Text(measurement),
          DiseaseExampleButton(scan: scan),
          if (entry != null)
            ExpansionTile(
              key: ValueKey('symptoms-${scan.crop.name}-${scan.label}'),
              tilePadding: EdgeInsets.zero,
              title: const Text('What to look for'),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scan.label == 'healthy'
                            ? 'Healthy appearance'
                            : 'Typical signs',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(entry.symptoms),
                      const SizedBox(height: 12),
                      const Text(
                        'Care tips',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(entry.prevention),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Photo scores'),
            children: [
              for (final prediction in predictions.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(prediction.displayLabel)),
                      const SizedBox(width: 12),
                      Text('${(prediction.score * 100).toStringAsFixed(1)}%'),
                    ],
                  ),
                ),
              const Text('A high score does not prove disease.'),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'What to do next',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            scan.uncertain
                ? scanRetakeGuidance(scan)
                : entry?.inspect ??
                      'Check this leaf and nearby leaves for changes.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Check the plant before treating it.',
            style: TextStyle(color: muted),
          ),
          if (!scan.uncertain && entry != null && entry.sources.isNotEmpty) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _sources(context, entry.sources),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Learn more'),
            ),
          ],
        ],
      ),
    );
  }
}
