# Phase 5 — user guidance and recovery

## Guidance
Help remains offline. Six topics cover photo scanning, prediction interpretation,
device connections, monitoring/background operation, history and recovery. Crop
availability comes from the installed model catalog, including Eggplant's experimental
notice and Chili's unavailable diagnosis. Scores are not measured accuracy; sensor
context does not change image predictions. Phone and advanced board cooldown limits
are explained separately without changing validation.

The existing four-step tutorial remains skippable and replayable. Its
`tutorial-complete-v1` preference is unchanged. Existing users do not receive a forced
replay. Diagnosis now has a Help icon. Dashboard Help has crop-preserving shortcuts
to Scan, Devices, Monitoring & Auto Scan and History → Alerts.

## Navigation interface
`HelpScreen` accepts optional crop context and shortcut visibility. The typed
`HelpDestination` result is consumed by the owning dashboard inside its existing
polling pause. Error-card Help still focuses the relevant code and does not offer
shortcuts without an owning handler. No additional controller, poller or service.

## Recovery
Explicit local Retry saving uses the pending prediction without hardware, capture
or inference. Retry analysis uses a retained original and available crop model
without a board connection. Both remain foreground-only and guarded against
overlap. Capture retries retain HTTP opt-in and matching camera assignment checks.
Automatic processing still requires hardware access and existing lifecycle/run
guards. Stable IDs and saved-result reconciliation prevent duplicate scans.

Alert detail explains expired originals and unavailable models. A pending-save
retry remains accessible if the scan was saved but alert completion failed.
No automatic failure retries; no clearing app data as routine recovery.

## Compatibility and acceptance
No models, preprocessing, thresholds, firmware, dependencies, permissions or storage
formats changed. Existing data and unrelated notebook work are preserved. Widget
tests and fake-hardware tests cover the new behavior; physical phone/ESP32 checks,
an APK build and extended Android lifecycle verification remain release work.

On a release device, verify Help and tutorial layout, navigate every shortcut for
each crop, test photo guidance from Diagnosis, and manually recover saved-photo
analysis with local hardware access off. Verify capture still requires a connection.
Do not infer diagnostic accuracy from these usability/recovery checks.
