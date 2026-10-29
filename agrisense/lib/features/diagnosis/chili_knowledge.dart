import 'tomato_knowledge.dart';

const chiliReferenceVersion = 'chili-reference-2026-10-22-v1';
const chiliGrowingSource = KnowledgeSource(
  'Virginia Cooperative Extension: Potatoes, Peppers and Eggplant',
  'https://www.pubs.ext.vt.edu/426/426-413/426-413.html',
  id: 'CH-GROW-01',
);
const _bacterialSpot = KnowledgeSource(
  'UC IPM: Peppers bacterial spot',
  'https://ipm.ucanr.edu/agriculture/peppers/bacterial-spot/',
  id: 'CH-BACT-01',
);
const _sharedBacterialSpot = KnowledgeSource(
  'UMN: Bacterial spot of tomato and pepper',
  'https://extension.umn.edu/agriculture/specialty-crops/vegetable-farming/disease-management/bacterial-spot-of-tomato-and-pepper',
  id: 'TM-03',
);
const _cercospora = KnowledgeSource(
  'TNAU: Chilli Cercospora leaf spot',
  'https://agritech.tnau.ac.in/crop_protection/chilli_diseases_5.html',
  id: 'CH-CERC-01',
);
const _leafCurl = KnowledgeSource(
  'TNAU: Chilli viral diseases, leaf curl',
  'https://agritech.tnau.ac.in/crop_protection/chilli_diseases_7.html',
  id: 'CH-CURL-01',
);
const _powdery = KnowledgeSource(
  'UC IPM: Peppers powdery mildew',
  'https://ipm.ucanr.edu/agriculture/peppers/powdery-mildew/',
  id: 'CH-POW-01',
);

// Label order follows the bundled six-class Chili export.
const chiliKnowledge = <String, TomatoKnowledge>{
  'bacterial_spot': TomatoKnowledge(
    label: 'bacterial_spot',
    category: 'Bacterial disease',
    explanation: 'Bacterial spot can affect pepper leaves, stems and fruit.',
    symptoms:
        'Look under leaves for small wet-looking spots that turn brown. Stems may have raised spots. Fruit spots can be brown, rough or cracked.',
    inspect:
        'Inspect both leaf surfaces, stems and fruit. Similar spotting needs expert confirmation.',
    prevention:
        'Start with healthy seed and young plants, reduce splashing onto leaves and avoid handling wet plants.',
    environment:
        'Moist foliage and humid conditions can favor spread. Air humidity does not measure leaf wetness.',
    limitation:
        'An image cannot confirm the bacterium. No numerical Chili disease rule is assigned; sensors cannot confirm infection.',
    sources: [_bacterialSpot, _sharedBacterialSpot],
    rule: null,
  ),
  'cercospora_leaf_spot': TomatoKnowledge(
    label: 'cercospora_leaf_spot',
    category: 'Fungal disease',
    explanation: 'Cercospora-type leaf spotting can damage Chili leaves.',
    symptoms:
        'Look for round brown leaf spots with pale gray centers and dark brown edges. They can enlarge and join together. Similar marks on stems or pods may be more oval; severe spotting can lead to leaf drop.',
    inspect:
        'Compare spot centers and margins; inspect leaf stalks, stems and pods. Ask a plant expert to distinguish similar leaf spots.',
    prevention:
        'Use basic care and avoid moving affected crop material between plants; seek local advice for confirmed disease.',
    environment:
        'The cited symptom guide does not establish a numerical temperature, humidity or exposure rule.',
    limitation:
        'The label does not confirm Cercospora capsici. General hygiene is precautionary; no sensor-based disease assessment is assigned.',
    sources: [_cercospora],
    rule: null,
  ),
  'leaf_curl': TomatoKnowledge(
    label: 'leaf_curl',
    category: 'Broad symptom / possible viral disease',
    explanation:
        'Leaf curl describes a symptom pattern; it does not identify a virus or prove infection.',
    symptoms:
        'Leaves may curl and become distorted, with small new leaves and stunted growth in viral cases.',
    inspect:
        'Inspect new growth and leaf undersides for insects, including whiteflies and thrips, and consider nonviral causes with a plant expert.',
    prevention:
        'Use healthy planting material and protect seedlings from insect exposure. Obtain local confirmation before removing plants.',
    environment:
        'Air and soil-moisture readings cannot detect insect vectors or confirm a viral infection.',
    limitation:
        'TNAU describes whitefly transmission for its leaf-curl example. Do not assume all curled leaves share that cause or that all insects transmit the same virus.',
    sources: [_leafCurl],
    rule: null,
  ),
  'healthy': TomatoKnowledge(
    label: 'healthy',
    category: 'No visible condition predicted',
    explanation:
        'This category represents leaves without a selected visible disorder; it is not proof of plant health.',
    symptoms:
        'Look for normal leaf color and shape, without unusual spots, holes or curling.',
    inspect:
        'Continue checking new growth, leaf undersides, stems and fruit for changes.',
    prevention:
        'Provide drainage and steady moisture, observe regularly and base fertilizer decisions on soil testing.',
    environment:
        'The cited pepper guide gives a general 21.1–23.9 °C growing reference, without a day/night schedule or universal humidity or soil percentage.',
    limitation:
        'This regional advisory reference is not a disease threshold or a guarantee of health. Hidden or early disorders may have no visible signs.',
    sources: [chiliGrowingSource],
    rule: null,
  ),
  'nutrient_deficiency': TomatoKnowledge(
    label: 'nutrient_deficiency',
    category: 'Broad abiotic / physiological condition',
    explanation:
        'This broad category suggests investigating nutrition and growing conditions; it does not identify a deficient nutrient.',
    symptoms:
        'Yellow leaves or slow growth can have several causes. Check watering and nutrients before changing fertilizer.',
    inspect:
        'Check old and new leaves. Review watering and fertilizer use. Ask a plant expert about soil testing before changing fertilizer.',
    prevention:
        'Maintain drainage and consistent watering. Use test results and local advice before changing fertilizer.',
    environment:
        'Air and soil-moisture sensors do not measure nitrogen, phosphorus, potassium or micronutrient concentrations.',
    limitation:
        'The growing guide supplies general pepper care, not a diagnosis for this label. No individual nutrient or numerical disease rule is assigned.',
    sources: [chiliGrowingSource],
    rule: null,
  ),
  'powdery_mildew': TomatoKnowledge(
    label: 'powdery_mildew',
    category: 'Fungal disease',
    explanation:
        'Pepper powdery mildew described by UC IPM is associated with Leveillula taurica.',
    symptoms:
        'Look underneath leaves for white powdery patches, with yellowish or brownish areas above. Leaf edges may roll upward and leaves can fall, exposing fruit to sun damage. Check that the coating is growth rather than dust or spray residue.',
    inspect:
        'Examine leaf undersides and exposed fruit. Distinguish fungal growth from dust, residues and other disorders.',
    prevention:
        'Monitor leaves regularly and inspect nearby host plants. Seek local advice early if leaves begin dropping; simple sanitation alone may not control this disease.',
    environment:
        'Disease conditions vary; this app assigns no universal temperature, humidity or exposure cutoff for Chili powdery mildew.',
    limitation:
        'A photo cannot establish the fungal species. Sensor readings do not confirm mildew or exclude infection.',
    sources: [_powdery],
    rule: null,
  ),
};
