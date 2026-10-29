import 'tomato_knowledge.dart';

const eggplantReferenceVersion = 'eggplant-reference-2026-10-21-v1';
const eggplantGrowingSource = KnowledgeSource(
  'Virginia Cooperative Extension: Eggplant',
  'https://www.pubs.ext.vt.edu/content/pubs_ext_vt_edu/en/SPES/SPES-686/SPES-686.html',
  id: 'EG-GROW-01',
);
const _alternaria = KnowledgeSource(
  'TNAU: Brinjal Alternaria leaf spot',
  'https://agritech.tnau.ac.in/crop_protection/brinjal_diseases_3.html',
  id: 'EG-ALT-01',
);
const _leafSpot = KnowledgeSource(
  'TNAU: Brinjal Cercospora leaf spot (one possible cause)',
  'https://agritech.tnau.ac.in/crop_protection/brinjal_diseases_2.html',
  id: 'EG-SPOT-01',
);
const _phomopsis = KnowledgeSource(
  'TNAU: Brinjal Phomopsis fruit rot',
  'https://agritech.tnau.ac.in/crop_protection/brinjal_phdiseases_2.html',
  id: 'EG-PHOM-01',
);
const _powdery = KnowledgeSource(
  'UC IPM: Powdery mildew on vegetables',
  'https://ipm.ucanr.edu/home-and-landscape/powdery-mildew-on-vegetables/',
  id: 'EG-POW-01',
);
const _downy = KnowledgeSource(
  'UC IPM: Downy mildew (general background)',
  'https://ipm.ucanr.edu/home-and-landscape/downy-mildew/',
  id: 'EG-DOWN-01',
);
const _mosaic = KnowledgeSource(
  'UC IPM: Eggplant mosaic diseases caused by potyviruses',
  'https://ipm.ucanr.edu/agriculture/eggplant/mosaic-diseases-caused-by-potyviruses/',
  id: 'EG-MOS-01',
);
const _wilt = KnowledgeSource(
  'UC IPM: Eggplant Verticillium wilt (one possible cause)',
  'https://ipm.ucanr.edu/agriculture/eggplant/verticillium-wilt/',
  id: 'EG-WILT-01',
);
const _bacterialWilt = KnowledgeSource(
  'TNAU: Brinjal bacterial wilt (one possible cause)',
  'https://agritech.tnau.ac.in/crop_protection/brinjal_diseases_1.html',
  id: 'EG-WILT-02',
);
const _pests = KnowledgeSource(
  'UC IPM: Eggplant pest management guidelines',
  'https://ipm.ucanr.edu/agriculture/eggplant/',
  id: 'EG-PEST-01',
);

// Shared entry structure retained to avoid migrating existing Tomato records.
const eggplantKnowledge = <String, TomatoKnowledge>{
  'alternaria_leaf_spot': TomatoKnowledge(
    label: 'alternaria_leaf_spot',
    category: 'Fungal disease',
    explanation:
        'Alternaria-type spotting can damage Eggplant leaves and fruit.',
    symptoms:
        'Look for irregular brown spots with rings inside them. Spots may crack or merge into larger damaged areas, and badly affected leaves can fall. Some Alternaria diseases also cause deep fruit spots.',
    inspect:
        'Check rings, both leaf surfaces and fruit. Similar spots need expert confirmation.',
    prevention:
        'Use basic care: avoid splashing leaves and clean up damaged crop material.',
    environment:
        'The selected Eggplant source does not establish a numerical temperature, humidity or exposure rule.',
    limitation:
        'The image label does not establish an Alternaria species. No sensor rule is assigned.',
    sources: [_alternaria, _downy],
  ),
  'downy_mildew': TomatoKnowledge(
    label: 'downy_mildew',
    category: 'Possible leaf disease',
    explanation:
        'Downy-mildew-like symptoms need expert confirmation on Eggplant. Use this general information to guide inspection.',
    symptoms:
        'General signs include pale patches above and soft gray or purplish growth underneath leaves.',
    inspect:
        'Inspect leaf undersides and ask a plant expert to confirm the cause; compare with other leaf diseases.',
    prevention:
        'General guidance is to improve airflow and water at soil level rather than wetting leaves.',
    environment:
        'General guidance discusses damp foliage and humidity; no Eggplant-specific sensor range is established here.',
    limitation:
        'The cited general source does not establish this disease on Eggplant or identify the training images. No pathogen or numerical rule is assigned.',
    sources: [_downy],
  ),
  'healthy': TomatoKnowledge(
    label: 'healthy',
    category: 'No visible condition predicted',
    explanation: 'The image resembles the model’s healthy class.',
    symptoms:
        'Look for normal leaf color and shape, without unusual spots, holes or curling.',
    inspect:
        'Inspect new growth, undersides, stems and fruit; continue checking for pests and changes.',
    prevention:
        'Maintain drainage, adequate light and regular observation. Base fertilizer decisions on soil testing.',
    environment:
        'A general warm-season reference is 70–85 °F, approximately 21.1–29.4 °C.',
    limitation:
        'Healthy is not proof of plant health; hidden infection and untrained conditions can be missed.',
    sources: [eggplantGrowingSource, _pests],
  ),
  'insect_pest': TomatoKnowledge(
    label: 'insect_pest',
    category: 'Broad pest category',
    explanation:
        'The model indicates possible pest damage without identifying a species.',
    symptoms:
        'Damage varies; look for holes, curled growth, insects and feeding marks.',
    inspect:
        'Check both leaf surfaces and young shoots; photograph the pest itself for identification.',
    prevention:
        'Monitor regularly and identify the pest before choosing control. Preserve beneficial insects.',
    environment:
        'Different pests respond differently to weather; a shared sensor threshold is not justified.',
    limitation:
        'Air and soil sensors cannot identify an insect or distinguish pest feeding from similar damage.',
    sources: [_pests, eggplantGrowingSource],
  ),
  'leaf_spot': TomatoKnowledge(
    label: 'leaf_spot',
    category: 'Broad symptom category',
    explanation:
        'Leaf spot describes damage with several possible causes; Cercospora is only one example.',
    symptoms:
        'Pale, brown or gray damaged spots may enlarge; severely affected leaves can drop.',
    inspect:
        'Record spot shape, leaf underside appearance and progression; seek identification before disease-specific treatment.',
    prevention:
        'Use healthy plants, limit leaves splash and remove badly affected material with clean tools.',
    environment:
        'No common numerical environmental rule is assigned to this broad label.',
    limitation:
        'Do not interpret this class as confirmed Cercospora, Alternaria or bacterial infection.',
    sources: [_leafSpot, _downy],
  ),
  'mosaic_virus': TomatoKnowledge(
    label: 'mosaic_virus',
    category: 'Possible viral disease',
    explanation:
        'Mosaic-like patterns can be associated with several Eggplant viruses.',
    symptoms:
        'Compare younger leaves for alternating light and dark green patches rather than a uniform color. Leaves may curl; fruit can become distorted or mottled. These signs do not identify a particular virus.',
    inspect:
        'Check younger leaves, nearby plants and possible insects that spread disease. Confirm the virus with professional testing where available.',
    prevention:
        'Use healthy young plants and discuss control of insects and weeds with local farming advice.',
    environment:
        'Transmission involves infected hosts and vectors; these sensors cannot establish infection.',
    limitation:
        'The source covers potyviruses as examples; the model label does not identify a virus or its transmission route.',
    sources: [_mosaic],
  ),
  'phomopsis_blight': TomatoKnowledge(
    label: 'phomopsis_blight',
    category: 'Possible fungal disease',
    explanation:
        'Phomopsis-type disease can affect seedlings, leaves, stems and fruit.',
    symptoms:
        'Brown leaf damaged spots, stem damage and soft decaying fruit may occur.',
    inspect:
        'Inspect stems and fruit as well as the leaf. Ask for confirmation when rot or seedling collapse is present.',
    prevention:
        'Use healthy planting material, clean tools and remove infected crop debris; reduce splash onto leaves.',
    environment:
        'Spread can involve rain splash and infected debris. A reported laboratory growth temperature is not an infection threshold.',
    limitation:
        'The source includes post-harvest fruit rot; storage conditions must not become leaf-disease sensor rules.',
    sources: [_phomopsis],
  ),
  'powdery_mildew': TomatoKnowledge(
    label: 'powdery_mildew',
    category: 'Possible fungal disease',
    explanation: 'Powdery mildew fungi can affect Eggplant leaves.',
    symptoms:
        'White patches or yellowing can occur; inspect both surfaces because appearance varies.',
    inspect:
        'Check whether growth is on the leaf rather than dust or residue. Confirm uncertain cases.',
    prevention: 'Provide light and airflow and avoid excessive fertilization.',
    environment:
        'Moist leaf surfaces are not required. General vegetable guidance is not a validated Eggplant exposure rule.',
    limitation:
        'The broad label does not identify a species; no universal humidity cutoff or duration is assigned.',
    sources: [_powdery],
  ),
  'wilt': TomatoKnowledge(
    label: 'wilt',
    category: 'Broad symptom category',
    explanation:
        'Wilting may reflect water stress, root problems or vascular diseases; this label does not identify the cause.',
    symptoms:
        'Look for leaves or branches that droop and may turn yellow, sometimes followed by wilting of the whole plant. Check watering and drainage; this appearance can have several causes.',
    inspect:
        'Check drainage, watering, roots and progression. Seek diagnosis for persistent wilt or plant collapse.',
    prevention:
        'Maintain drainage and use healthy young plants. Get the cause identified before changing disease management.',
    environment:
        'Air readings and calibrated soil moisture provide context but cannot distinguish bacterial, fungal or physical causes.',
    limitation:
        'Do not equate wilt with Verticillium or bacterial wilt. No disease-specific threshold is assigned.',
    sources: [_wilt, _bacterialWilt, eggplantGrowingSource],
  ),
};
