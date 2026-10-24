import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:agrisense/features/diagnosis/eggplant_knowledge.dart';
import 'package:agrisense/features/diagnosis/chili_knowledge.dart';
import 'package:agrisense/features/diagnosis/tomato_knowledge.dart';

void main() {
  test('six ordered Chili entries are complete with no disease rules', () {
    expect(chiliKnowledge.keys, [
      'bacterial_spot',
      'cercospora_leaf_spot',
      'leaf_curl',
      'healthy',
      'nutrient_deficiency',
      'powdery_mildew',
    ]);
    for (final entry in chiliKnowledge.entries) {
      expect(entry.value.label, entry.key);
      for (final text in [
        entry.value.category,
        entry.value.explanation,
        entry.value.symptoms,
        entry.value.inspect,
        entry.value.prevention,
        entry.value.environment,
        entry.value.limitation,
      ]) {
        expect(text.trim(), isNotEmpty, reason: entry.key);
      }
      expect(entry.value.rule, isNull);
      expect(entry.value.sources, isNotEmpty);
    }
    expect(
      chiliKnowledge['leaf_curl']!.explanation,
      contains('does not identify a virus'),
    );
    expect(
      chiliKnowledge['nutrient_deficiency']!.environment,
      contains('do not measure'),
    );
    expect(
      chiliKnowledge['healthy']!.limitation,
      contains('not a disease threshold'),
    );
  });
  test(
    'all nine export labels have complete sourced entries without guessed rules',
    () {
      final labels =
          jsonDecode(
                File('assets/models/eggplant_labels.json').readAsStringSync(),
              )
              as List;
      expect(eggplantKnowledge.keys.toSet(), labels.toSet());
      expect(labels.length, 9);
      for (final entry in eggplantKnowledge.values) {
        for (final text in [
          entry.category,
          entry.explanation,
          entry.symptoms,
          entry.inspect,
          entry.prevention,
          entry.environment,
          entry.limitation,
        ]) {
          expect(text.trim(), isNotEmpty, reason: entry.label);
        }
        expect(
          entry.rule,
          isNull,
          reason: 'No verified numerical Eggplant disease rules',
        );
        expect(entry.sources, isNotEmpty);
      }
      expect(
        eggplantKnowledge['downy_mildew']!.limitation,
        contains('does not establish'),
      );
      expect(eggplantKnowledge['wilt']!.limitation, contains('Do not equate'));
    },
  );

  test('all app source IDs resolve to claim records and bibliography', () {
    final register =
        jsonDecode(File('docs/RESEARCH_REGISTER.json').readAsStringSync())
            as Map;
    final sources = (register['sources'] as List).cast<Map>();
    final byId = {for (final source in sources) source['id']: source};
    expect(byId.length, sources.length);
    final bibliography = File(
      'docs/RESEARCH_BIBLIOGRAPHY.md',
    ).readAsStringSync();
    for (final entry in [
      ...tomatoKnowledge.values,
      ...eggplantKnowledge.values,
      ...chiliKnowledge.values,
    ]) {
      for (final source in entry.sources) {
        expect(source.id, isNotEmpty);
        expect(byId[source.id]?['url'], source.url);
        expect(byId[source.id]?['labels'], contains(entry.label));
        if (chiliKnowledge.values.contains(entry)) {
          expect(byId[source.id]?['crops'], contains('chili'));
        }
        expect(bibliography, contains('[${source.id}]'));
        expect(Uri.parse(source.url).scheme, 'https');
      }
    }
    for (final source in sources) {
      for (final field in [
        'title',
        'authors_or_organization',
        'year',
        'url',
        'accessed',
        'locator',
        'claims',
        'verification',
      ]) {
        expect(source[field], isNotEmpty, reason: '${source['id']} $field');
      }
    }
  });
}
