# Tomato knowledge reference table

Research gathered 2026-10-21. This is an advisory knowledge base, not locally
validated diagnosis or a probability model. Full offline entries and source URLs
are bundled in `lib/features/diagnosis/tomato_knowledge.dart`.

## Growing references

- Established tomato: approximately 21–29 C day and 18–21 C night, rounded from
  the [UGA production handbook](https://fieldreport.caes.uga.edu/publications/B1312/commercial-tomato-production-handbook/).
- RH 65–75% is a **controlled/protected-growing reference**, not a universal
  outdoor requirement: [controlled-environment guidance](https://pmc.ncbi.nlm.nih.gov/articles/PMC4235429/).
- No generic soil-moisture percentage or raw gas threshold is adopted.

## Environmental evidence

| Label | Published reference retained | Assessment limitation |
|---|---|---|
| bacterial_spot | 23.9–30 C, high humidity and rain/overhead irrigation ([UMN](https://extension.umn.edu/agriculture/specialty-crops/vegetable-farming/disease-management/bacterial-spot-of-tomato-and-pepper)) | No numerical RH or exposure threshold; temperature is partial evidence |
| early_blight | Optimum 27.8–30 C; wet weather/dew or RH >=90% ([UMN](https://extension.umn.edu/agriculture/specialty-crops/vegetable-farming/disease-management/early-blight-in-tomato-and-potato)) | Optimum is not the full disease range; no universal duration |
| late_blight | Average 15.6–25.6 C, RH >90%, infection in about 10 h ([UC IPM](https://ipm.ucanr.edu/agriculture/tomato/late-blight/)) | Matching history describes conducive conditions, not infection; no pathogen measurement |
| leaf_mold | RH >=85%; optimum about 21.7–23.9 C ([UMN](https://extension.umn.edu/agriculture/specialty-crops/vegetable-farming/disease-management/tomato-leaf-mold)) | Passalora reference; broad model label does not prove species; no invented duration |
| septoria_leaf_spot | 20–25 C and high humidity ([UMN](https://apps.extension.umn.edu/garden/diagnose/plant/vegetable/tomato/leavesspots.html)) | No numerical RH cutoff; temperature is partial evidence |
| target_spot | 28.3–32.2 C, high humidity, 16–44 h continuous leaf wetness ([UF/IFAS](https://ask.ifas.ufl.edu/publication/PP351)) | Air RH is not measured leaf wetness; duration cannot be established by current sensors |
| powdery_mildew | Mild temperatures and humidity, pathogen-dependent ([UC IPM](https://ipm.ucanr.edu/agriculture/tomato/powdery-mildew-on-field-grown-tomatoes/)) | Generic label; no universal numerical rule |
| spider_mites | Hot/dusty conditions and water stress favor damage ([UC IPM](https://ipm.ucanr.edu/home-and-landscape/spider-mites/)) | Qualitative only; visual pest inspection required |
| leaf_miner, whitefly | Pest and damage inspection ([leafminers](https://ipm.ucanr.edu/agriculture/tomato/leafminers/), [whiteflies](https://ipm.ucanr.edu/agriculture/tomato/whiteflies/)) | No species-specific sensor threshold assigned |
| mosaic_virus, spotted_wilt_virus, yellow_leaf_curl_virus | Symptoms and exposure/vector information ([UMN](https://extension.umn.edu/disease-management/tomato-viruses), [spotted wilt](https://ipm.ucanr.edu/agriculture/tomato/tomato-spotted-wilt/), [yellow leaf curl](https://ipm.ucanr.edu/agriculture/tomato/tomato-yellow-leaf-curl/)) | Sensors cannot establish infection; exact virus needs confirmation |
| magnesium_deficiency, nitrogen_deficiency, potassium_deficiency | Symptom patterns and soil/tissue assessment ([Maryland](https://extension.umd.edu/resource/key-common-problems-tomatoes)) | Installed sensors do not measure nutrients |
| healthy | No supported visible condition predicted | Does not exclude hidden infection or conditions outside model coverage |

For local context, Philippine [DOST-PCAARRD](https://www.pcaarrd.dost.gov.ph/index.php/quick-information-dispatch-qid-articles/a-natural-way-to-control-tomato-and-eggplant-disease)
describes black leaf mold (Pseudocercospora fuligena), which must not be silently
equated with Passalora leaf mold. Do not infer pathogen identity from a generic
training label. Entries include that limitation.

Favorable ranges are not likelihood ratios. Bayesian fusion would require paired
confirmed cases, appropriate priors and calibration; it is excluded here.
Phase 2's 10-second Sensitive trigger is not a biological infection period.
