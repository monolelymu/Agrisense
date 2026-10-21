import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrisense/features/diagnosis/tomato_knowledge.dart';

void main() {
  test('all installed labels have complete sourced offline entries', () {
    final labels =
        (jsonDecode(File('assets/models/tomato_labels.json').readAsStringSync())
                as List)
            .cast<String>();
    expect(tomatoKnowledge.keys.toSet(), labels.toSet());
    expect(tomatoKnowledge.length, 17);
    for (final entry in tomatoKnowledge.entries) {
      final k = entry.value;
      expect(k.label, entry.key);
      for (final text in [
        k.category,
        k.explanation,
        k.symptoms,
        k.inspect,
        k.prevention,
        k.environment,
        k.limitation,
      ]) {
        expect(text.trim(), isNotEmpty, reason: entry.key);
      }
      expect(k.sources, isNotEmpty);
      for (final source in k.sources) {
        expect(source.title, isNotEmpty);
        expect(Uri.parse(source.url).scheme, 'https');
      }
    }
  });
  test('rules retain source distinctions rather than invented thresholds', () {
    expect(tomatoKnowledge['late_blight']!.rule!.humidityExclusive, isTrue);
    expect(
      tomatoKnowledge['late_blight']!.rule!.duration,
      const Duration(hours: 10),
    );
    expect(tomatoKnowledge['target_spot']!.rule!.requiresLeafWetness, isTrue);
    expect(tomatoKnowledge['bacterial_spot']!.rule!.minimumHumidity, isNull);
    expect(
      tomatoKnowledge['septoria_leaf_spot']!.rule!.minimumHumidity,
      isNull,
    );
    for (final label in [
      'healthy',
      'mosaic_virus',
      'spotted_wilt_virus',
      'yellow_leaf_curl_virus',
      'magnesium_deficiency',
      'nitrogen_deficiency',
      'potassium_deficiency',
      'leaf_miner',
      'spider_mites',
      'whitefly',
      'powdery_mildew',
    ]) {
      expect(tomatoKnowledge[label]!.rule, isNull, reason: label);
    }
  });
}
