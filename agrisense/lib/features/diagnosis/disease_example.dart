import 'package:flutter/material.dart';

import '../../data/models.dart';
import 'tomato_scan.dart';
import 'reference_photo_credits.dart';

// Explicit matches only. Never substitute a different disease or crop image.
const diseaseExamples = <(Crop, String), String>{
  (Crop.tomato, 'bacterial_spot'): 'tomato_bacterial_spot.jpg',
  (Crop.tomato, 'leaf_miner'): 'tomato_leaf_miner.jpg',
  (Crop.tomato, 'magnesium_deficiency'): 'tomato_magnesium_deficiency.jpg',
  (Crop.tomato, 'mosaic_virus'): 'tomato_mosaic_virus.jpg',
  (Crop.tomato, 'nitrogen_deficiency'): 'tomato_nitrogen_deficiency.jpg',
  (Crop.tomato, 'potassium_deficiency'): 'tomato_potassium_deficiency.jpg',
  (Crop.tomato, 'powdery_mildew'): 'tomato_powdery_mildew.jpg',
  (Crop.tomato, 'spider_mites'): 'tomato_spider_mites.jpg',
  (Crop.tomato, 'spotted_wilt_virus'): 'tomato_spotted_wilt_virus.jpg',
  (Crop.tomato, 'target_spot'): 'tomato_target_spot.jpg',
  (Crop.tomato, 'whitefly'): 'tomato_whitefly.jpg',
  (Crop.tomato, 'early_blight'): 'tomato_early_blight.jpg',
  (Crop.tomato, 'late_blight'): 'tomato_late_blight.jpg',
  (Crop.tomato, 'healthy'): 'tomato_healthy.jpg',
  (Crop.tomato, 'leaf_mold'): 'tomato_mold_leaf.jpg',
  (Crop.tomato, 'septoria_leaf_spot'): 'tomato_septoria_leaf_spot.jpg',
  (Crop.tomato, 'yellow_leaf_curl_virus'): 'tomato_yellow_leaf_curl.jpg',
  (Crop.eggplant, 'healthy'): 'eggplant_healthy.jpg',
  (Crop.eggplant, 'alternaria_leaf_spot'): 'eggplant_alternaria_leaf_spot.jpg',
  (Crop.eggplant, 'downy_mildew'): 'eggplant_downy_mildew.jpg',
  (Crop.eggplant, 'phomopsis_blight'): 'eggplant_phomopsis_blight.jpg',
  (Crop.eggplant, 'powdery_mildew'): 'eggplant_powdery_mildew.jpg',
  (Crop.eggplant, 'insect_pest'): 'eggplant_insect_pest.jpg',
  (Crop.eggplant, 'leaf_spot'): 'eggplant_leaf_spot.jpg',
  (Crop.eggplant, 'mosaic_virus'): 'eggplant_mosaic_virus.jpg',
  (Crop.eggplant, 'wilt'): 'eggplant_wilt.jpg',
  (Crop.chili, 'healthy'): 'chili_healthy.jpg',
  (Crop.chili, 'bacterial_spot'): 'chili_bacterial_spot.jpg',
  (Crop.chili, 'cercospora_leaf_spot'): 'chili_cercospora_leaf_spot.jpg',
  (Crop.chili, 'leaf_curl'): 'chili_curl_virus.jpg',
  (Crop.chili, 'nutrient_deficiency'): 'chili_nutrition_deficiency.jpg',
  (Crop.chili, 'powdery_mildew'): 'chili_powdery_mildew.jpg',
};

class DiseaseExampleButton extends StatelessWidget {
  const DiseaseExampleButton({required this.scan, super.key});

  final TomatoScan scan;

  @override
  Widget build(BuildContext context) {
    final filename = diseaseExamples[(scan.crop, scan.label)];
    if (filename == null) return const SizedBox.shrink();
    return TextButton.icon(
      icon: const Icon(Icons.photo_library_outlined),
      label: const Text('See example'),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Compare photos',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text('${scan.crop.label}: ${scan.displayLabel}'),
                        const SizedBox(height: 16),
                        const Text('Your photo'),
                        const SizedBox(height: 8),
                        Image.memory(
                          scan.preview,
                          height: 180,
                          fit: BoxFit.contain,
                          semanticLabel: 'Your captured leaf photo',
                          errorBuilder: (_, _, _) =>
                              const Text('Photo unavailable.'),
                        ),
                        const SizedBox(height: 16),
                        const Text('Example photo'),
                        const SizedBox(height: 8),
                        Image.asset(
                          'assets/pathology_reference/$filename',
                          height: 200,
                          cacheWidth: 1024,
                          fit: BoxFit.contain,
                          semanticLabel:
                              '${scan.crop.label} ${scan.displayLabel} example',
                          errorBuilder: (_, _, _) =>
                              const Text('Example photo unavailable.'),
                        ),
                        if (referencePhotoNotes[filename] case final note?) ...[
                          const SizedBox(height: 8),
                          Text(note),
                        ],
                        const SizedBox(height: 16),
                        const Text(
                          'Example only. Your plant may look different.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to result'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
