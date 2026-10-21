# Phase 3: Tomato growing conditions and explanations

## Using the app

Tomato Dashboard now includes Growing conditions. Current readings from the
assigned sensor are compared with advisory references for established tomatoes:
21–29 C by day, 18–21 C by night. Daytime is assumed to be 06:00–18:00 in the phone's
local time. The 65–75% humidity reference is for protected growing; it is not a
universal outdoor requirement. A value outside a reference is not a diagnosis.

Measurements expire after 30 seconds, even if monitoring is stopped. Calibrated
soil moisture is shown without a universal suitable percentage. Gas readings do
not influence the assessment. Presets and automatic scan triggers are unchanged.

Every supported Tomato prediction has an About this prediction section. Expand
Symptoms & next steps for inspection and nonchemical care guidance. Research
sources contains selectable HTTPS addresses and a Copy source link button. The
information is available offline; opening a copied website requires a browser.

## Sensor context

Automatic results use their saved alert-trigger readings, clearly identified by
time. Manual camera results may attach the latest same-device Tomato reading
preceding capture if it is no more than 30 seconds old. Uploaded photographs do
not receive sensor context because their capture time and plant are unknown.

Supported environmental rules describe favorable conditions only. Some require
more evidence than these sensors provide. Target spot's leaf-wetness requirement
cannot be satisfied with air humidity. Late blight's reference needs about ten
hours of uninterrupted high-RH observations and suitable average temperature.
Duplicates do not extend exposure; gaps over 30 seconds or device changes break
continuity. Insufficient history is reported as Duration not established.

Saved growing context and assessment reference versions are frozen with new
results. Old scans remain readable and receive label information, but never
acquire today's readings. Image labels, scores and rankings are unchanged.

## Boundaries and acceptance

The 17 labels include diseases, pests, possible nutrient disorders and Healthy.
The generic image labels do not confirm a pathogen species. Healthy does not
exclude hidden infection; environmental sensors do not measure nutrients or
identify viruses and insects. See PHASE_3_REFERENCES.md for source distinctions.

Chili and Eggplant keep their monitoring, alerts, photos and History. Their
models, crop-specific knowledge and validation remain later work. No dependencies,
firmware, model files or Android service changes were introduced in Phase 3.

On the physical phone, confirm the sensor is shaded/representative of the crop,
calibration is appropriate, and the assumed schedule suits the growing setup.
Check Dashboard expiry, automatic/manual context and saved results alongside the
Phase 2 physical checklist. Horticultural ranges need validation for local variety,
growth stage and environment. Physical acceptance remains pending.
