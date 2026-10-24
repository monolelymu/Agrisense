import 'package:flutter/material.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import 'eggplant_knowledge.dart';
import 'chili_knowledge.dart';
import 'tomato_knowledge.dart';
import 'tomato_context_widgets.dart';

/// Offline reference access also works while a crop's classifier is unavailable.
class CropKnowledgeScreen extends StatelessWidget {
  const CropKnowledgeScreen({required this.crop, super.key});
  final Crop crop;

  @override
  Widget build(BuildContext context) {
    final entries = switch (crop) {
      Crop.tomato => tomatoKnowledge,
      Crop.eggplant => eggplantKnowledge,
      Crop.chili => chiliKnowledge,
    };
    return Scaffold(
      appBar: AppBar(title: Text('${crop.label} knowledge & care')),
      body: PageBody(
        children: [
          const Text(
            'Research references for inspection and care. These entries do not confirm a diagnosis.',
          ),
          if (entries.isEmpty)
            const Text('Crop references are not available yet.'),
          for (final entry in entries.values)
            ExpansionTile(
              key: ValueKey(entry.label),
              title: Text(entry.label.replaceAll('_', ' ')),
              subtitle: Text(entry.category),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.explanation),
                      const SizedBox(height: 12),
                      Text('Symptoms: ${entry.symptoms}'),
                      const SizedBox(height: 12),
                      Text('Inspect: ${entry.inspect}'),
                      const SizedBox(height: 12),
                      Text('Prevention & care: ${entry.prevention}'),
                      const SizedBox(height: 12),
                      Text('Environment: ${entry.environment}'),
                      const SizedBox(height: 12),
                      Text(entry.limitation),
                      ReferenceSources(sources: entry.sources),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
