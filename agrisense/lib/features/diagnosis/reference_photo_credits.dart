// Photo credits are display-only. These assets never enter model inference.
const referencePhotoCredits = <String, String>{
  "chili_bacterial_spot.jpg":
      "FloraScan supplied training example; original author unverified\nCopied with project owner permission; original image rights unverified\nFloraScan/mobile/assets/pathology_reference/chili_bacterial_spot.jpg",
  "chili_cercospora_leaf_spot.jpg":
      "FloraScan supplied training example; original author unverified\nCopied with project owner permission; original image rights unverified\nFloraScan/mobile/assets/pathology_reference/chili_cercospora_leaf_spot.jpg",
  "chili_curl_virus.jpg":
      "FloraScan supplied training example; original author unverified\nCopied with project owner permission; original image rights unverified\nFloraScan/mobile/assets/pathology_reference/chili_curl_virus.jpg",
  "chili_healthy.jpg":
      "FloraScan supplied training example; original author unverified\nCopied with project owner permission; original image rights unverified\nFloraScan/mobile/assets/pathology_reference/chili_healthy.jpg",
  "chili_nutrition_deficiency.jpg":
      "FloraScan supplied training example; original author unverified\nCopied with project owner permission; original image rights unverified\nFloraScan/mobile/assets/pathology_reference/chili_nutrition_deficiency.jpg",
  "chili_powdery_mildew.jpg":
      "Scot Nelson\nCC0\nhttps://www.flickr.com/photos/scotnelson/5836333879\nhttps://creativecommons.org/publicdomain/zero/1.0/",
  "eggplant_alternaria_leaf_spot.jpg":
      "Hasnain Ahmad, Gargy Roy and Md. Umaid Hasan\nCC BY 4.0\nhttps://data.mendeley.com/datasets/6k94t3fydy/1\nhttps://creativecommons.org/licenses/by/4.0/",
  "eggplant_downy_mildew.jpg":
      "Hasnain Ahmad, Gargy Roy and Md. Umaid Hasan\nCC BY 4.0\nhttps://data.mendeley.com/datasets/6k94t3fydy/1\nhttps://creativecommons.org/licenses/by/4.0/",
  "eggplant_healthy.jpg":
      "FloraScan supplied training example; original author unverified\nCopied with project owner permission; original image rights unverified\nFloraScan/mobile/assets/pathology_reference/eggplant_healthy.jpg",
  "eggplant_insect_pest.jpg":
      "FloraScan supplied training example; original author unverified\nCopied with project owner permission; original image rights unverified\nFloraScan/mobile/assets/pathology_reference/eggplant_insect_pest.jpg",
  "eggplant_leaf_spot.jpg":
      "FloraScan supplied training example; original author unverified\nCopied with project owner permission; original image rights unverified\nFloraScan/mobile/assets/pathology_reference/eggplant_leaf_spot.jpg",
  "eggplant_mosaic_virus.jpg":
      "FloraScan supplied training example; original author unverified\nCopied with project owner permission; original image rights unverified\nFloraScan/mobile/assets/pathology_reference/eggplant_mosaic_virus.jpg",
  "eggplant_phomopsis_blight.jpg":
      "Hasnain Ahmad, Gargy Roy and Md. Umaid Hasan\nCC BY 4.0\nhttps://data.mendeley.com/datasets/6k94t3fydy/1\nhttps://creativecommons.org/licenses/by/4.0/",
  "eggplant_powdery_mildew.jpg":
      "Scot Nelson\nCC0\nhttps://www.flickr.com/photos/scotnelson/15886189885\nhttps://creativecommons.org/publicdomain/zero/1.0/",
  "eggplant_wilt.jpg":
      "FloraScan supplied training example; original author unverified\nCopied with project owner permission; original image rights unverified\nFloraScan/mobile/assets/pathology_reference/eggplant_wilt.jpg",
  "tomato_bacterial_spot.jpg":
      "PlantVillage — Hughes, Salathé and Mohanty\nCC BY-SA 3.0\nhttps://github.com/spMohanty/PlantVillage-Dataset/blob/master/raw/color/Tomato___Bacterial_spot/00416648-be6e-4bd4-bc8d-82f43f8a7240___GCREC_Bact.Sp%203110.JPG\nhttps://creativecommons.org/licenses/by-sa/3.0/",
  "tomato_early_blight.jpg":
      "FloraScan supplied training example; original author unverified\nCopied with project owner permission; original image rights unverified\nFloraScan/mobile/assets/pathology_reference/tomato_early_blight.jpg",
  "tomato_healthy.jpg":
      "FloraScan supplied training example; original author unverified\nCopied with project owner permission; original image rights unverified\nFloraScan/mobile/assets/pathology_reference/tomato_healthy.jpg",
  "tomato_late_blight.jpg":
      "FloraScan supplied training example; original author unverified\nCopied with project owner permission; original image rights unverified\nFloraScan/mobile/assets/pathology_reference/tomato_late_blight.jpg",
  "tomato_leaf_miner.jpg":
      "Goldlocki\nCC BY-SA 3.0\nhttps://commons.wikimedia.org/wiki/File:Tomate_Blatt_Minierfliegenschaden.jpg\nhttp://creativecommons.org/licenses/by-sa/3.0/",
  "tomato_magnesium_deficiency.jpg":
      "Goldlocki\nCC BY-SA 3.0\nhttps://commons.wikimedia.org/wiki/File:TomateBlattMgMangel.jpg\nhttp://creativecommons.org/licenses/by-sa/3.0/",
  "tomato_mold_leaf.jpg":
      "FloraScan supplied training example; original author unverified\nCopied with project owner permission; original image rights unverified\nFloraScan/mobile/assets/pathology_reference/tomato_mold_leaf.jpg",
  "tomato_mosaic_virus.jpg":
      "PlantVillage — Hughes, Salathé and Mohanty\nCC BY-SA 3.0\nhttps://github.com/spMohanty/PlantVillage-Dataset/blob/master/raw/color/Tomato___Tomato_mosaic_virus/000ec6ea-9063-4c33-8abe-d58ca8a88878___PSU_CG%202169.JPG\nhttps://creativecommons.org/licenses/by-sa/3.0/",
  "tomato_nitrogen_deficiency.jpg":
      "Mamta Gehlot, Raj Kumar Saxena and G. C. Gandhi — Tomato-Village\nPublic research dataset; standalone image license not specified\nhttps://github.com/mamta-joshi-gehlot/Tomato-Village/blob/main/Variant-a(Multiclass%20Classification)/test/Nitrogen%20Deficiency/IMG20220323180110_1.jpg\nhttps://github.com/mamta-joshi-gehlot/Tomato-Village",
  "tomato_potassium_deficiency.jpg":
      "Goldlocki\nCC BY-SA 3.0\nhttps://commons.wikimedia.org/wiki/File:Tomate_Blatt_Kalimangel.jpg\nhttp://creativecommons.org/licenses/by-sa/3.0/",
  "tomato_powdery_mildew.jpg":
      "Goldlocki\nCC BY-SA 3.0\nhttps://commons.wikimedia.org/wiki/File:Tomate_Mehltau_Blatt.jpg\nhttp://creativecommons.org/licenses/by-sa/3.0/",
  "tomato_septoria_leaf_spot.jpg":
      "FloraScan supplied training example; original author unverified\nCopied with project owner permission; original image rights unverified\nFloraScan/mobile/assets/pathology_reference/tomato_septoria_leaf_spot.jpg",
  "tomato_spider_mites.jpg":
      "PlantVillage — Hughes, Salathé and Mohanty\nCC BY-SA 3.0\nhttps://github.com/spMohanty/PlantVillage-Dataset/blob/master/raw/color/Tomato___Spider_mites%20Two-spotted_spider_mite/002835d1-c18e-4471-aa6e-8d8c29585e9b___Com.G_SpM_FL%208584.JPG\nhttps://creativecommons.org/licenses/by-sa/3.0/",
  "tomato_spotted_wilt_virus.jpg":
      "Downtowngal\nCC0\nhttps://commons.wikimedia.org/wiki/File:Tomato_with_Tomato_Spotted_Wilt_Virus.jpg\nhttp://creativecommons.org/publicdomain/zero/1.0/deed.en",
  "tomato_target_spot.jpg":
      "PlantVillage — Hughes, Salathé and Mohanty\nCC BY-SA 3.0\nhttps://github.com/spMohanty/PlantVillage-Dataset/blob/master/raw/color/Tomato___Target_Spot/002213fb-b620-4593-b9ac-6a6cc119b100___Com.G_TgS_FL%208360.JPG\nhttps://creativecommons.org/licenses/by-sa/3.0/",
  "tomato_whitefly.jpg":
      "Goldlocki\nCC BY-SA 3.0\nhttps://commons.wikimedia.org/wiki/File:Tomate_Blatt_Eier_Wei%C3%9Fe_Fliege_parasitiert.jpg\nhttp://creativecommons.org/licenses/by-sa/3.0/",
  "tomato_yellow_leaf_curl.jpg":
      "FloraScan supplied training example; original author unverified\nCopied with project owner permission; original image rights unverified\nFloraScan/mobile/assets/pathology_reference/tomato_yellow_leaf_curl.jpg",
};

const referencePhotoNotes = <String, String>{
  "chili_powdery_mildew.jpg":
      "Powdery mildew on pepper. Appearance varies between pepper varieties.",
  "eggplant_alternaria_leaf_spot.jpg":
      "Dataset-labelled eggplant example; not independently laboratory-confirmed.",
  "eggplant_downy_mildew.jpg":
      "Dataset label: Downy mildew. The disease identity on eggplant is unverified; compare symptoms and seek expert confirmation.",
  "eggplant_phomopsis_blight.jpg":
      "Dataset-labelled eggplant example; not independently laboratory-confirmed.",
  "tomato_bacterial_spot.jpg":
      "Dataset-labelled example; not independently laboratory-confirmed.",
  "tomato_mosaic_virus.jpg":
      "Dataset-labelled example; not independently laboratory-confirmed.",
  "tomato_nitrogen_deficiency.jpg":
      "Dataset-labelled nitrogen-deficiency example. Similar yellowing can have other causes.",
  "tomato_spider_mites.jpg":
      "Dataset-labelled example; not independently laboratory-confirmed.",
  "tomato_spotted_wilt_virus.jpg":
      "Spotted wilt symptoms on tomato fruit. Leaf symptoms can look different.",
  "tomato_target_spot.jpg":
      "Dataset-labelled example; not independently laboratory-confirmed.",
  "tomato_whitefly.jpg":
      "Whitefly immature stages on a tomato leaf, including stages parasitized by a beneficial wasp.",
  "eggplant_powdery_mildew.jpg":
      "Powdery mildew on eggplant. Inspect both sides of the leaf.",
};
