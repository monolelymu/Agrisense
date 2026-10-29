/// Offline references, not a diagnostic model or Bayesian probabilities.
const tomatoReferenceVersion = 'tomato-reference-2026-10-21-v1';

class KnowledgeSource {
  const KnowledgeSource(this.title, this.url, {this.id = ''});
  final String title, url;
  final String id;
}

const growingTemperatureSource = KnowledgeSource(
  'UGA: Commercial Tomato Production Handbook',
  'https://fieldreport.caes.uga.edu/publications/B1312/commercial-tomato-production-handbook/',
  id: 'TM-01',
);
const growingHumiditySource = KnowledgeSource(
  'Controlled-environment tomato research guidance',
  'https://pmc.ncbi.nlm.nih.gov/articles/PMC4235429/',
  id: 'TM-02',
);
const _bacterial = KnowledgeSource(
  'UMN: Bacterial spot of tomato and pepper',
  'https://extension.umn.edu/agriculture/specialty-crops/vegetable-farming/disease-management/bacterial-spot-of-tomato-and-pepper',
  id: 'TM-03',
);
const _early = KnowledgeSource(
  'UMN: Early blight',
  'https://extension.umn.edu/agriculture/specialty-crops/vegetable-farming/disease-management/early-blight-in-tomato-and-potato',
  id: 'TM-04',
);
const _late = KnowledgeSource(
  'UC IPM: Late blight',
  'https://ipm.ucanr.edu/agriculture/tomato/late-blight/',
  id: 'TM-05',
);
const _mold = KnowledgeSource(
  'UMN: Tomato leaf mold',
  'https://extension.umn.edu/agriculture/specialty-crops/vegetable-farming/disease-management/tomato-leaf-mold',
  id: 'TM-06',
);
const _septoria = KnowledgeSource(
  'UMN: Tomato leaf spots',
  'https://apps.extension.umn.edu/garden/diagnose/plant/vegetable/tomato/leavesspots.html',
  id: 'TM-07',
);
const _target = KnowledgeSource(
  'UF/IFAS: Target spot of tomato',
  'https://ask.ifas.ufl.edu/publication/PP351',
  id: 'TM-08',
);
const _powdery = KnowledgeSource(
  'UC IPM: Powdery mildew on tomatoes',
  'https://ipm.ucanr.edu/agriculture/tomato/powdery-mildew-on-field-grown-tomatoes/',
  id: 'TM-09',
);
const _viruses = KnowledgeSource(
  'UMN: Tomato viruses',
  'https://extension.umn.edu/disease-management/tomato-viruses',
  id: 'TM-10',
);
const _nutrients = KnowledgeSource(
  'University of Maryland: Common tomato problems',
  'https://extension.umd.edu/resource/key-common-problems-tomatoes',
  id: 'TM-11',
);
const _miners = KnowledgeSource(
  'UC IPM: Tomato leafminers',
  'https://ipm.ucanr.edu/agriculture/tomato/leafminers/',
  id: 'TM-12',
);
const _mites = KnowledgeSource(
  'UC IPM: Spider mites',
  'https://ipm.ucanr.edu/home-and-landscape/spider-mites/',
  id: 'TM-13',
);
const _whiteflies = KnowledgeSource(
  'UC IPM: Tomato whiteflies',
  'https://ipm.ucanr.edu/agriculture/tomato/whiteflies/',
  id: 'TM-14',
);
const _spotted = KnowledgeSource(
  'UC IPM: Tomato spotted wilt',
  'https://ipm.ucanr.edu/agriculture/tomato/tomato-spotted-wilt/',
  id: 'TM-15',
);
const _curl = KnowledgeSource(
  'UC IPM: Tomato yellow leaf curl',
  'https://ipm.ucanr.edu/agriculture/tomato/tomato-yellow-leaf-curl/',
  id: 'TM-16',
);

class TomatoEnvironmentRule {
  const TomatoEnvironmentRule({
    this.minimumTemperature,
    this.maximumTemperature,
    this.minimumHumidity,
    this.humidityExclusive = false,
    this.duration,
    this.requiresLeafWetness = false,
    this.qualitativeRequirement,
  });
  final double? minimumTemperature, maximumTemperature, minimumHumidity;
  final bool humidityExclusive, requiresLeafWetness;
  final Duration? duration;
  final String? qualitativeRequirement;
}

class TomatoKnowledge {
  const TomatoKnowledge({
    required this.label,
    required this.category,
    required this.explanation,
    required this.symptoms,
    required this.inspect,
    required this.prevention,
    required this.environment,
    required this.limitation,
    required this.sources,
    this.rule,
  });
  final String label,
      category,
      explanation,
      symptoms,
      inspect,
      prevention,
      environment,
      limitation;
  final List<KnowledgeSource> sources;
  final TomatoEnvironmentRule? rule;
}

const tomatoKnowledge = <String, TomatoKnowledge>{
  'bacterial_spot': TomatoKnowledge(
    label: 'bacterial_spot',
    category: 'Bacterial disease',
    explanation: 'Bacterial spotting can affect leaves, stems and fruit.',
    symptoms:
        'Small brown spots, sometimes with yellow halos; rough fruit spots.',
    inspect:
        'Check both leaf surfaces and fruit. Similar spots have other causes.',
    prevention:
        'Use healthy young plants, water at the base and avoid handling wet plants.',
    environment:
        'Warm conditions around 23.9–30 °C, high humidity and rain or overhead watering favor disease.',
    limitation:
        'The source gives no numerical humidity cutoff or universal exposure time. Temperature alone is partial evidence.',
    sources: [_bacterial],
    rule: TomatoEnvironmentRule(
      minimumTemperature: 23.9,
      maximumTemperature: 30,
      qualitativeRequirement:
          'High humidity and rain or overhead watering are also relevant; no numerical humidity cutoff is established.',
    ),
  ),
  'early_blight': TomatoKnowledge(
    label: 'early_blight',
    category: 'Fungal disease',
    explanation: 'Early blight damages leaves and may affect stems and fruit.',
    symptoms:
        'Look first at older, lower leaves for brown spots with rings like a target. Yellow tissue may surround the spots, and badly affected leaves can dry and fall.',
    inspect:
        'Compare the rings and yellow margins with other leaf spots. Yellowing alone does not identify early blight; inspect several leaves and the rest of the plant.',
    prevention:
        'Reduce soil splash with mulch, water at the base and remove crop debris.',
    environment:
        'The guide reports an optimum around 27.8–30 °C; wet weather, heavy dew or RH of at least 90% favors spread.',
    limitation:
        'This is an optimum reference, not the full possible temperature range. No universal exposure time is assigned.',
    sources: [_early],
    rule: TomatoEnvironmentRule(
      minimumTemperature: 27.8,
      maximumTemperature: 30,
      minimumHumidity: 90,
    ),
  ),
  'healthy': TomatoKnowledge(
    label: 'healthy',
    category: 'No visible condition predicted',
    explanation:
        'The model did not identify one of its other supported conditions in this image.',
    symptoms:
        'Look for normal leaf color and shape, without unusual spots, holes or curling.',
    inspect:
        'Continue checking new growth, leaf undersides and the whole plant.',
    prevention:
        'Maintain suitable growing conditions, clean tools and regular inspection.',
    environment:
        'Suitable environmental readings do not prove that a plant is disease-free.',
    limitation:
        'Hidden infection, pests outside the photo and nutrient problems may still be present.',
    sources: [growingTemperatureSource, _nutrients],
  ),
  'late_blight': TomatoKnowledge(
    label: 'late_blight',
    category: 'Oomycete disease',
    explanation: 'Late blight can spread rapidly through leaves and fruit.',
    symptoms:
        'Small wet-looking patches can quickly become large purple-brown blotches with an oily appearance. Gray-white growth may occur around patches underneath leaves. Stems and firm brown fruit can also be affected.',
    inspect:
        'Check the undersides and nearby plants. Seek local agricultural advice promptly if symptoms spread rapidly.',
    prevention:
        'Use healthy planting material, improve airflow and avoid prolonged wet leaves.',
    environment:
        'UC IPM reports infection in about 10 hours when average temperature is 15.6–25.6 °C and RH is above 90%.',
    limitation:
        'Favorable conditions require a susceptible host and pathogen exposure. Current weather cannot confirm or exclude an existing infection.',
    sources: [_late],
    rule: TomatoEnvironmentRule(
      minimumTemperature: 15.6,
      maximumTemperature: 25.6,
      minimumHumidity: 90,
      humidityExclusive: true,
      duration: Duration(hours: 10),
    ),
  ),
  'leaf_miner': TomatoKnowledge(
    label: 'leaf_miner',
    category: 'Pest damage',
    explanation: 'Leaf-mining larvae feed inside leaf tissue.',
    symptoms:
        'Look for pale winding trails or wider blotches inside the leaf tissue. Inspect a fresh trail closely for a larva; the generic label does not establish which insect made it.',
    inspect:
        'Look for active larvae in fresh mines; the generic label does not identify a pest species.',
    prevention:
        'Inspect young plants and preserve helpful insects; remove heavily affected material when appropriate.',
    environment:
        'The installed environmental sensors do not detect larvae or establish pest identity.',
    limitation:
        'No species-specific temperature rule is assigned to this broad classifier label.',
    sources: [_miners],
  ),
  'leaf_mold': TomatoKnowledge(
    label: 'leaf_mold',
    category: 'Fungal disease',
    explanation:
        'Tomato leaf molds affect leaves, particularly in humid protected growing areas.',
    symptoms:
        'Compare yellow patches on the upper leaf surface with olive-brown, velvety growth underneath the same area. Inspect both surfaces; a yellow patch alone is not enough to identify common tomato leaf mold.',
    inspect:
        'Inspect both surfaces. Different leaf molds can look similar; the model label does not confirm a pathogen species.',
    prevention:
        'Improve airflow, reduce prolonged canopy humidity and remove crop debris.',
    environment:
        'For the common tomato leaf mold described by UMN, RH of at least 85% favors severe outbreaks; optimum temperature is about 21.7–23.9 °C.',
    limitation:
        'This source concerns Passalora leaf mold. Black leaf mold is a different disease; humidity alone cannot distinguish them. No universal exposure duration is assigned.',
    sources: [_mold],
    rule: TomatoEnvironmentRule(
      minimumHumidity: 85,
      qualitativeRequirement:
          'This humidity reference concerns common Passalora leaf mold; the broad image label does not confirm its pathogen.',
    ),
  ),
  'magnesium_deficiency': TomatoKnowledge(
    label: 'magnesium_deficiency',
    category: 'Possible nutrient disorder',
    explanation:
        'The image resembles a nutrient-related problem; magnesium deficiency requires further assessment.',
    symptoms: 'Yellowing between veins can resemble several nutrient problems.',
    inspect:
        'Check which leaves are affected and arrange soil or tissue testing before selecting a nutrient correction.',
    prevention:
        'Use a balanced, soil-test-based nutrition program and consistent irrigation.',
    environment:
        'Temperature, RH and soil moisture do not measure magnesium concentration.',
    limitation:
        'The sensors cannot confirm this deficiency. Similar symptoms may come from other nutrients or root problems.',
    sources: [_nutrients],
  ),
  'mosaic_virus': TomatoKnowledge(
    label: 'mosaic_virus',
    category: 'Possible viral disease',
    explanation:
        'Several tomato viruses can produce mosaic-like leaf patterns.',
    symptoms:
        'Mottled light and dark green areas, distorted leaves or reduced growth.',
    inspect:
        'Check new growth and nearby plants. Laboratory testing is needed to identify a virus.',
    prevention:
        'Use healthy planting material, clean tools and avoid spreading sap between plants.',
    environment:
        'Environmental readings cannot identify a virus or show whether a plant was exposed.',
    limitation:
        'The generic mosaic label does not establish a specific virus or transmission route.',
    sources: [_viruses],
  ),
  'nitrogen_deficiency': TomatoKnowledge(
    label: 'nitrogen_deficiency',
    category: 'Possible nutrient disorder',
    explanation: 'The image resembles a nutrient-related yellowing problem.',
    symptoms:
        'Yellowing beginning on older leaves may be associated with nitrogen shortage.',
    inspect:
        'Check the whole plant, roots and watering; confirm nutrient status with testing.',
    prevention:
        'Base fertilizer decisions on soil or tissue advice rather than adding nitrogen solely from an image.',
    environment: 'Moisture readings do not measure nitrogen availability.',
    limitation:
        'Yellowing has many causes. These sensors cannot confirm nitrogen deficiency.',
    sources: [_nutrients],
  ),
  'potassium_deficiency': TomatoKnowledge(
    label: 'potassium_deficiency',
    category: 'Possible nutrient disorder',
    explanation:
        'The image resembles a nutrient disorder that needs confirmation.',
    symptoms:
        'Leaf discoloration can overlap with other nutrient and environmental problems.',
    inspect:
        'Review affected leaf age, roots and irrigation, and obtain soil or tissue assessment.',
    prevention:
        'Use balanced nutrition and consistent irrigation guided by testing.',
    environment:
        'The installed sensors do not measure potassium concentration or uptake.',
    limitation:
        'No temperature, RH or soil-moisture percentage can establish potassium deficiency.',
    sources: [_nutrients],
  ),
  'powdery_mildew': TomatoKnowledge(
    label: 'powdery_mildew',
    category: 'Fungal disease',
    explanation: 'Powdery mildew affects living leaves and may weaken plants.',
    symptoms:
        'Yellow patches and sometimes white powdery growth on leaf surfaces.',
    inspect:
        'Examine both leaf surfaces and compare with other causes of yellowing.',
    prevention:
        'Maintain airflow and suitable watering; inspect surrounding plants.',
    environment:
        'Mild temperatures and humidity can favor development, but responses depend on the powdery mildew pathogen.',
    limitation:
        'No universal numerical humidity range is assigned to this generic model label. Air humidity is not leaf wetness.',
    sources: [_powdery],
  ),
  'septoria_leaf_spot': TomatoKnowledge(
    label: 'septoria_leaf_spot',
    category: 'Fungal disease',
    explanation: 'Septoria leaf spot can cause spotting and loss of leaves.',
    symptoms:
        'Small spots with dark margins, pale centers and sometimes tiny black dots.',
    inspect:
        'Inspect lower leaves and spot centers; bacterial spots and other fungi can look similar.',
    prevention:
        'Reduce leaf wetness and soil splash, improve airflow and remove crop debris.',
    environment:
        'UMN lists high humidity and temperatures around 20–25 °C as common favorable conditions.',
    limitation:
        'The source does not specify an exact RH threshold or universal exposure duration.',
    sources: [_septoria],
    rule: TomatoEnvironmentRule(
      minimumTemperature: 20,
      maximumTemperature: 25,
      qualitativeRequirement:
          'High humidity is also relevant, but the source gives no numerical RH cutoff.',
    ),
  ),
  'spider_mites': TomatoKnowledge(
    label: 'spider_mites',
    category: 'Pest damage',
    explanation: 'Tiny mites feed on leaf cells and may cause visible damage.',
    symptoms:
        'Fine pale stippling, bronzing and sometimes webbing beneath leaves.',
    inspect:
        'Use a hand lens to look for mites, eggs and webbing before taking control action.',
    prevention:
        'Avoid water stress and dusty conditions; preserve natural predators.',
    environment:
        'Damage is often worse in hot, dusty conditions and on water-stressed plants.',
    limitation:
        'No numerical temperature or RH cutoff is assigned. Sensors cannot detect mites.',
    sources: [_mites],
  ),
  'spotted_wilt_virus': TomatoKnowledge(
    label: 'spotted_wilt_virus',
    category: 'Possible viral disease',
    explanation:
        'Tomato spotted wilt is a virus disease associated with thrips transmission.',
    symptoms:
        'Leaf or fruit discoloration, spots or rings and stunted growth may occur.',
    inspect:
        'Inspect for thrips and symptoms on the whole plant; obtain confirmation when practical.',
    prevention:
        'Use healthy young plants, inspect for thrips and manage nearby infected host plants with local advice.',
    environment:
        'Temperature and humidity cannot establish that thrips carry the virus.',
    limitation:
        'The image is a suspicion, not laboratory confirmation. No sensor-derived infection probability is assigned.',
    sources: [_spotted, _viruses],
  ),
  'target_spot': TomatoKnowledge(
    label: 'target_spot',
    category: 'Fungal disease',
    explanation: 'Target spot can damage leaves, stems and fruit.',
    symptoms:
        'Brown spots may enlarge with pale centers and rings inside the spots; fruit can develop sunken damaged spots.',
    inspect:
        'Compare with early blight and bacterial spots, and inspect fruit as well as leaves.',
    prevention:
        'Improve airflow, reduce prolonged wet leaves and inspect plants regularly.',
    environment:
        'UF/IFAS reports favorable temperatures around 28.3–32.2 °C, high humidity and 16–44 hours of continuous leaf wetness.',
    limitation:
        'The app does not measure leaf wetness. Air RH cannot establish the published wetness duration.',
    sources: [_target],
    rule: TomatoEnvironmentRule(
      minimumTemperature: 28.3,
      maximumTemperature: 32.2,
      duration: Duration(hours: 16),
      requiresLeafWetness: true,
      qualitativeRequirement:
          'High humidity and measured leaf wetness are also required to assess the published conditions.',
    ),
  ),
  'whitefly': TomatoKnowledge(
    label: 'whitefly',
    category: 'Pest damage',
    explanation:
        'Whiteflies feed on plants; some species can transmit plant viruses.',
    symptoms:
        'Tiny white-winged insects, yellowing or curling, and sticky honeydew or sooty mold.',
    inspect:
        'Look beneath leaves for adults and immature stages. Whitefly presence does not prove virus infection.',
    prevention:
        'Inspect young plants, monitor leaf undersides and preserve helpful insects.',
    environment:
        'Sensors cannot identify whitefly species, abundance or whether they carry a virus.',
    limitation:
        'No species-specific numerical environmental rule is assigned to this broad label.',
    sources: [_whiteflies],
  ),
  'yellow_leaf_curl_virus': TomatoKnowledge(
    label: 'yellow_leaf_curl_virus',
    category: 'Possible viral disease',
    explanation:
        'Tomato yellow leaf curl is a virus disease spread by certain whiteflies.',
    symptoms:
        'Yellowed, curled leaves and stunted growth may indicate infection.',
    inspect:
        'Inspect new growth and whiteflies; arrange confirmation if symptoms persist or spread.',
    prevention:
        'Start with healthy young plants, inspect for whiteflies and follow local advice on affected plants.',
    environment:
        'Suitable weather does not establish infection or identify a virus-carrying whitefly.',
    limitation:
        'No numerical temperature or humidity rule can confirm this disease.',
    sources: [_curl, _viruses],
  ),
};
