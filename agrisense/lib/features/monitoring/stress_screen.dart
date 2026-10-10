import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class StressScreen extends StatelessWidget {
  const StressScreen({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final score = controller.score(controller.selectedCrop);
    final threshold = controller.settingsFor(controller.selectedCrop).threshold;
    final high = score.value >= threshold;
    return PageBody(
      children: [
        SectionTitle(
          'Stress score',
          '${controller.selectedCrop.label} • mock sensor interpretation',
        ),
        Panel(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                const Tag('DEMO CALCULATION'),
                const SizedBox(height: 28),
                SizedBox(
                  width: 190,
                  height: 190,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: score.value / 100,
                          strokeWidth: 14,
                          backgroundColor: background,
                          color: high ? warning : accent,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${score.value}',
                            style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            'OUT OF 100',
                            style: TextStyle(
                              color: muted,
                              letterSpacing: 2,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  high ? 'Attention needed in this demo' : 'Within demo ranges',
                  style: TextStyle(
                    color: high ? warning : accent,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Alert threshold: $threshold',
                  style: const TextStyle(color: muted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'What contributes to this score?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        for (final e in score.contributions.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              child: Row(
                children: [
                  Icon(
                    e.value > 0
                        ? Icons.warning_amber
                        : Icons.check_circle_outline,
                    color: e.value > 0 ? warning : accent,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key),
                        Text(
                          e.value > 0
                              ? 'Outside the configured demo range'
                              : 'Within the configured demo range',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+${e.value}',
                    style: TextStyle(
                      color: e.value > 0 ? warning : accent,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Each reading outside its range contributes 25 points. This simple rule is for software demonstration only; it does not detect a disease or establish plant health.',
          style: TextStyle(color: muted),
        ),
      ],
    );
  }
}
