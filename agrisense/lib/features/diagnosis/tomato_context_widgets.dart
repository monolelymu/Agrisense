import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets.dart';
import '../../data/hardware_client.dart';
import 'tomato_assessment.dart';
import 'tomato_knowledge.dart';
import 'tomato_scan.dart';
import 'eggplant_knowledge.dart';
import 'chili_knowledge.dart';
import '../../data/models.dart';

class ReferenceSources extends StatelessWidget {
  const ReferenceSources({required this.sources, super.key});
  final List<KnowledgeSource> sources;

  Future<void> _copy(BuildContext context, String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Source link copied.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not copy the link. Select the address below to copy it.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: const Text('Research sources'),
    children: [
      for (final source in sources)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${source.id.isEmpty ? '' : '[${source.id}] '}${source.title}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SelectableText(source.url),
              TextButton.icon(
                onPressed: () => _copy(context, source.url),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy source link'),
              ),
            ],
          ),
        ),
    ],
  );
}

class GrowingConditionsView extends StatelessWidget {
  const GrowingConditionsView({required this.conditions, super.key});
  final GrowingConditions conditions;
  @override
  Widget build(BuildContext context) {
    final c = conditions;
    String value(double? n, String unit) =>
        n == null ? 'Unavailable' : '${n.toStringAsFixed(1)}$unit';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Air temperature: ${value(c.temperature, ' °C')} · ${referencePositionLabel(c.temperaturePosition)}',
        ),
        const SizedBox(height: 8),
        Text(
          '${c.crop != Crop.tomato
              ? 'General growing'
              : c.daytime
              ? 'Day'
              : 'Night'} reference: ${c.minimumTemperature.toStringAsFixed(c.crop != Crop.tomato ? 1 : 0)}–${c.maximumTemperature.toStringAsFixed(c.crop != Crop.tomato ? 1 : 0)} °C',
        ),
        const SizedBox(height: 12),
        Text(
          'Humidity: ${value(c.humidity, '% RH')} · ${c.crop != Crop.tomato ? 'No numerical reference assigned' : referencePositionLabel(c.humidityPosition)}',
        ),
        const SizedBox(height: 8),
        Text(
          c.crop != Crop.tomato
              ? 'No universal ${c.crop.label} humidity range is assigned. Air humidity does not measure leaf wetness.'
              : '65–75% RH is a protected-growing reference. It is not a universal outdoor requirement.',
        ),
        const SizedBox(height: 12),
        Text(
          c.soil == null
              ? 'Soil moisture: unavailable; recent device-calibrated readings are required.'
              : 'Soil moisture: ${c.soil!.toStringAsFixed(1)}% (device-calibrated). No universal suitable percentage is assigned.',
        ),
        const SizedBox(height: 12),
        Text(
          c.crop != Crop.tomato
              ? 'General ${c.crop.label} growth reference, without a day/night schedule. References describe the environment, not confirmed plant health.'
              : 'For established tomatoes. Assumed daytime: 06:00–18:00, phone local time. References describe the environment, not confirmed plant health.',
        ),
        if (c.crop == Crop.chili)
          const Text(
            'This regional pepper reference is advisory; cultivar and local growing conditions may differ.',
          ),
        if (c.sampleAt != null) ...[
          const SizedBox(height: 8),
          Text('Reading received ${dateLabel(c.sampleAt!.toLocal())}'),
        ],
      ],
    );
  }
}

/// Display-only expiry timer; no network requests, monitoring owner or poller.
class GrowingConditionsPanel extends StatefulWidget {
  const GrowingConditionsPanel({
    required this.sample,
    this.clock,
    this.crop = Crop.tomato,
    super.key,
  });
  final Crop crop;
  final HardwareSample? sample;
  final DateTime Function()? clock;
  @override
  State<GrowingConditionsPanel> createState() => _GrowingConditionsPanelState();
}

class _GrowingConditionsPanelState extends State<GrowingConditionsPanel> {
  Timer? expiry;
  DateTime get now => widget.clock?.call() ?? DateTime.now();
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant GrowingConditionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    expiry?.cancel();
    final at = now;
    final sample = widget.sample;
    if (!recentCropSample(sample, at, widget.crop)) return;
    final local = at.toLocal();
    final boundary = local.hour < 6
        ? DateTime(local.year, local.month, local.day, 6)
        : local.hour < 18
        ? DateTime(local.year, local.month, local.day, 18)
        : DateTime(local.year, local.month, local.day + 1, 6);
    final staleAt = sample!.receivedAt.add(
      const Duration(seconds: 30, milliseconds: 1),
    );
    final next = staleAt.isBefore(boundary) ? staleAt : boundary;
    expiry = Timer(next.difference(at), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  void dispose() {
    expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Growing conditions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        GrowingConditionsView(
          conditions: GrowingConditions.assess(
            widget.sample,
            now,
            crop: widget.crop,
          ),
        ),
        ReferenceSources(
          sources: switch (widget.crop) {
            Crop.tomato => [growingTemperatureSource, growingHumiditySource],
            Crop.eggplant => [eggplantGrowingSource],
            Crop.chili => [chiliGrowingSource],
          },
        ),
      ],
    ),
  );
}

class TomatoExplanation extends StatelessWidget {
  const TomatoExplanation({required this.scan, super.key});
  final TomatoScan scan;
  @override
  Widget build(BuildContext context) {
    final knowledge = switch (scan.crop) {
      Crop.tomato => tomatoKnowledge,
      Crop.eggplant => eggplantKnowledge,
      Crop.chili => chiliKnowledge,
    };
    final entry = knowledge[scan.label];
    final assessment = TomatoAssessment.tryFromJson(scan.assessment);
    if (entry == null) {
      return const Text(
        'No reference entry is available for this model label.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'About this prediction',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(diseaseDisplayName(entry.category)),
        const SizedBox(height: 12),
        Text(entry.explanation),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Symptoms & next steps'),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Typical symptoms',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(entry.symptoms),
                  const SizedBox(height: 12),
                  Text(
                    'What to inspect',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(entry.inspect),
                  const SizedBox(height: 12),
                  Text(
                    'Prevention & care',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(entry.prevention),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Environmental context',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(entry.environment),
        const SizedBox(height: 8),
        Text(entry.limitation),
        const SizedBox(height: 16),
        if (assessment == null)
          Text(
            scan.source == 'upload'
                ? 'No linked sensor data. The capture time and plant of an uploaded photo are unknown.'
                : 'No saved sensor assessment. Historical scans are not assessed using today’s readings.',
          )
        else ...[
          Text(
            assessment.context,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(assessment.evidence.message),
          if (assessment.evidence.requiredSeconds != null)
            Text(
              'Continuous observations: ${(assessment.evidence.observedSeconds / 3600).toStringAsFixed(1)} h of about ${(assessment.evidence.requiredSeconds! / 3600).toStringAsFixed(0)} h required.',
            ),
          if (assessment.evidence.averageTemperature != null)
            Text(
              'Recorded average temperature: ${assessment.evidence.averageTemperature!.toStringAsFixed(1)} °C',
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Saved growing context'),
            children: [
              GrowingConditionsView(conditions: assessment.conditions),
              Text(
                'Assessed ${dateLabel(assessment.conditions.at.toLocal())} · Reference ${assessment.referenceVersion}',
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Sensor context does not change the image prediction or model score.',
        ),
        ReferenceSources(
          sources: [
            ...entry.sources,
            if (assessment != null && scan.crop == Crop.eggplant)
              eggplantGrowingSource,
            if (assessment != null &&
                scan.crop == Crop.chili &&
                !entry.sources.contains(chiliGrowingSource))
              chiliGrowingSource,
            if (assessment != null && scan.crop == Crop.tomato)
              growingTemperatureSource,
            if (assessment != null && scan.crop == Crop.tomato)
              growingHumiditySource,
          ],
        ),
      ],
    );
  }
}
