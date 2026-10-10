import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

class DiagnosisScreen extends StatelessWidget {
  const DiagnosisScreen({this.result, super.key});
  final DiseaseResult? result;
  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r == null) {
      return const PageBody(
        children: [
          SectionTitle('Diagnosis results', 'A closer look at the leaf'),
          EmptyState(
            'No mock diagnosis yet',
            'Connect both simulated nodes and simulate stress, then open the resulting alert.',
            icon: Icons.document_scanner_outlined,
          ),
        ],
      );
    }
    return PageBody(
      children: [
        SectionTitle(
          'A closer look',
          '${r.crop.label} • ${dateLabel(r.timestamp)}',
        ),
        const Tag('MOCK DIAGNOSIS', color: warning),
        const SizedBox(height: 18),
        MetricGrid(
          minWidth: 340,
          children: [
            Panel(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: r.imageAsset == null
                        ? const _ImagePlaceholder()
                        : Image.asset(
                            r.imageAsset!,
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const _ImagePlaceholder(),
                          ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Reference image only • not captured or analyzed',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ILLUSTRATIVE RESULT',
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    r.label,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${(r.confidence * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 44,
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Mock confidence • predetermined value',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'No AI inference was performed. This result tests the app workflow, not diagnosis accuracy.',
                    style: TextStyle(color: warning),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Care information preview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(r.treatment, style: const TextStyle(color: muted)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Dataset images and real model testing are deferred. This preview uses mock results only.',
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();
  @override
  Widget build(BuildContext context) => Container(
    height: 250,
    width: double.infinity,
    color: background,
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.eco_outlined, size: 80, color: accent),
        SizedBox(height: 14),
        Text('Leaf image preview', style: TextStyle(color: muted)),
        Text(
          'No camera image captured',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    ),
  );
}
