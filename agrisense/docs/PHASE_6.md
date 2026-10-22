# Phase 6 — presentation and review APK

The dark-green design, navigation, stored records and installed models are retained.
Shared layouts use smaller phone headings, 16-pixel phone card padding, consistent
spacing, wrapping controls and minimum 48-pixel button/icon targets. Larger screens
retain wider layouts; text scaling is not disabled or reduced to force a fit.

## What to review
- Diagnosis: selected crop is prominent above upload/capture actions. “Analyzing as”
  is a user selection, not automatic crop verification. Unavailable crop analysis
  remains disabled; no confidence-based crop rejection was added.
- Results: photo, condition, score and uncertainty are easy to distinguish. Ranked
  labels wrap or stack without colliding with scores. Experimental notices stay
  visible; Explanation & care and Details expand for more information. Historical
  records retain their original model/context. No input bytes or scores changed.
- Dashboard: one crop selector, connection/monitoring status grouped separately,
  explicit stale/missing/uncalibrated readings, raw gas marked as not ppm.
- History: separate Scans/Alerts/Readings, previews and consistent timestamps;
  sensor alerts are distinct from older unlinked warning photos. Expired originals
  and failed stages remain understandable and recoverable through Phase 5 actions.
- Devices/settings: assignments, tests, monitoring and disabled reasons are clearer.
  Advanced board SD controls stay collapsed and separate from phone monitoring.
  Help uses the same card spacing while preserving tutorial/navigation behavior.

## Checks
Focused tests cover phone widths 360/430 and tablet width 800 at 1×/1.5× text,
long labels, busy/error states, unavailable models, stale/missing readings,
history/expired photos and disabled advanced controls. The notification checkbox
test now centers and hit-tests controls and asserts actual toggles; it no longer
silently taps off-screen. No warnings are suppressed.

Final regression ran once: all 144 Flutter tests pass, with no off-screen warning.
Static analysis reports no issues. Progress/build/hash details are recorded in
PHASE_6_PROGRESS.md. No dependencies, firmware, model preprocessing, scores,
thresholds, monitoring rules, services or storage formats changed.

## Review boundary
The debug APK combines Phases 5 and 6. Its previous build is preserved separately.
Review file: `agrisense/build/review/agrisense-phase6-debug-a6327e5d4841.apk`.
SHA-256: `a6327e5d484108aca9c1a5a3ae76eabaae4fc01e5b721b5e5d81cb8981a3c6e3`.
It is not automatically installed or launched. Review it manually on an emulator
or phone; model reliability and real phone/ESP32/background acceptance remain
separate Phase 7 work. These UI tests do not establish diagnostic accuracy.
