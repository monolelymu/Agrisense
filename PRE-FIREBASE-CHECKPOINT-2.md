# Checkpoint 2 pre Firebase

Date: 2026-10-30 (Asia/Manila). Commit message requested by the user: `checkpoint 2 pre firebase`. Branch: `v2-ui-simple`.

This checkpoint preserves the current local-network app and firmware source before any future Firebase implementation. Firebase/remote work remains paused pending reliable hardware and explicit resumption.

- App: v1.0.15e, Android build 21 (`1.0.15-e+21` in `agrisense/pubspec.yaml`). Includes plain-language main flow and the redesigned Trends view. Source and tests are committed; large APKs remain local.
- APK: `AgriSense-v1.0.15e.apk`; SHA-256 `b017d90c5ad93c6ff15a8a01fa62f6c142e33b2e55da53ed714d0958d0ee1666`. Signing matches v1.0.15d. Install updates over the current app to retain history.
- Firmware: `AgriSense-Firmware-v1.0.15d-power.zip`; SHA-256 `50420c073537b062ae89f7c19369a53a83e08f266f0e0f4e69959a1bd6ce3a46`. This complete source package is included because the working firmware directory is ignored by Git. RTC/SD retained, servo loads sequenced, Wi-Fi attempts controlled. Original v15 firmware archive remains the rollback baseline.
- Verification previously completed: 10 focused app tests, clean changed-file Dart analysis, successful offline Android release build and APK checks; five firmware host suites. Firmware has not been ESP32-compiled/flashed or physically power-tested here. Phone review remains pending.
- Clear trends: no visible button in the current release. Restoring a view-only reset was discussed but not implemented. Do not imply it exists or deletes stored history.
- Firebase: no SDK integration, active cloud transport, tested/deployed rules or remote firmware is included. The separately downloaded untracked `google-services.json` stays local and is excluded. Cloud console state has not been verified here.
- No new dependencies or migrations. Do not include BANTAI helpers, training/model-import work, generated test databases, output/tmp files, credentials or APKs in this checkpoint.

Release details/commands: `APP-UPDATE-v1.0.15d.md`, `APP-UPDATE-v1.0.15e.md`, `FIRMWARE-UPDATE-v1.0.15d-power.md`. Two-way continuation record and paused Firebase vision: `ARGON-FIRMWARE-15-POWER-HANDOFF.md`.

To recover, use this commit in a separate checkout. Build with the existing dependencies and same signing identity. If installing over a newer app, use a higher Android version code rather than uninstalling. Extract firmware source with all neighboring headers, restore private Wi-Fi settings locally, and keep Erase All Flash disabled to preserve pairing/settings.
