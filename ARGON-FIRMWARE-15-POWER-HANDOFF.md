# Antigravity Argon handoff: AgriSense app and firmware

Last updated: 2026-10-30 (Asia/Manila)
Repository: AgriSense. Do not modify FloraScan.

## Current releases — read this first

Checkpoint request (2026-10-30): user requested a commit and push named exactly `checkpoint 2 pre firebase` on the current `v2-ui-simple` branch. See `PRE-FIREBASE-CHECKPOINT-2.md` for the scope and recovery information. App 15e source, the credential-free power firmware ZIP and current documentation belong in this checkpoint; APKs, downloaded Firebase config, generated artifacts and unrelated experiments remain local. The Clear trends button was discussed but has not been restored. Verify the actual Git remote state before describing any push as completed.

The user requested this handoff be refreshed and both latest deliveries shown again. Source implementation and packaging are complete for these releases; device acceptance remains pending. Later sections include historical investigation snapshots. Their statements such as "no code changes" or "implementation not started" describe the earlier checkpoint, not the current state.

| Delivery | Current artifact | Verification | Next step |
| --- | --- | --- | --- |
| Android app v1.0.16a-cloud, build 23 | `AgriSense-v1.0.16a-cloud.apk` | 49 Flutter tests passed, clean Dart analysis (0 issues), release APK built | Install over current app and verify cloud + local demo connection |
| Firmware v1.0.16b-cloud, based on 15d-power | `AgriSense-Firmware-v1.0.16b-cloud.zip` | Six host suites passed (including actual sensor payload builder test in cloud_sync_test); source/archive integrity checked | Flash both ESP32 sketches with Wi-Fi credentials in secrets.h |

App changes: shorter 24-hour line chart with small dots; readable time labels below the plot; daily low–high bars with average dots for 7/30 days; explicitly labeled multi-day aggregation for long all-time views; short summaries with fewer than three readings; latest recorded value/time and lowest/highest stats, with sample count/average in expandable details; tooltips constrained to chart bounds and no vertical touch stem. Gaps remain blank. Existing history/settings, all 32 reference images and all three models are retained.

App source: new `sensor_trend_card.dart` under `agrisense/lib/features/monitoring/`, Trends integration in `hardware_dashboard.dart`, new `agrisense/test/sensor_trend_card_test.dart`, updated `dashboard_records_test.dart`, and version `1.0.15-e+21` in `agrisense/pubspec.yaml`. Generated Android local build version properties were updated. Details/commands: `APP-UPDATE-v1.0.15e.md`. No new dependencies, firmware changes in the app task, migrations, Git commits or pushes. Tests include narrow-phone layout and 1.6 text scaling; rendered fixtures use Flutter's test font and are not native-font phone acceptance.

Firmware changes: one bounded Wi-Fi association at a time with radio shutdown/rest before retry; staged servo startup; one-axis movement and settling; defer sensor SD logging, automatic photos and new association while moving; reset/disconnect diagnostics and camera retry gating. Keep RTC, both SD storage paths, timestamps, limits, saved settings, pairing, warning LEDs, scanning and existing camera features. Details/commands: `FIRMWARE-UPDATE-v1.0.15d-power.md`.

Firmware reduces overlapping demand but cannot guarantee stable voltage. The user's separate camera supply fixed the observed symptom; retain it. No ESP32 compilation, flashing, physical servo check or electrical measurement has been performed here. Manual streaming/capture and holding current can still overlap across boards. Brownout protection remains enabled.

Integrity:
- App v1.0.16a-cloud SHA-256: `5681afdef9bcf9eb3e516b582a5576a8cbf13d365a6d5644ee211d1c53b0cf87` (154,724,986 bytes). Rollback v1.0.15e: `b017d90c5ad93c6ff15a8a01fa62f6c142e33b2e55da53ed714d0958d0ee1666`.
- Firmware v1.0.16b-cloud SHA-256: `9cb57df49a1c525870af46dcf70802d120613ba4e935cea56a486011c145d4f7` (93,388 bytes). Earlier cloud firmware v1.0.16a-cloud: `60e116637f708b95fbe2ffd80df187e419bb3a8ac7ecd757862c161d31c56c0c` (91,165 bytes). Rollback v1.0.15d-power: `50420c073537b062ae89f7c19369a53a83e08f266f0e0f4e69959a1bd6ce3a46`.
- App signing certificate matches v1.0.15e/d; Android application ID remains `com.example.agrisense`. Keep older deliveries as rollback artifacts; do not uninstall merely to update.

Resume from device review or a concrete reported issue. Do not redo completed implementation or install dependencies without user confirmation. Preserve unrelated dirty work. Continue using the two-way protocol below when transferring between Codex and Argon.

## Firebase vision — future work, currently paused

Added 2026-10-30 at the user's request to preserve "our dreams" for Firebase. This is a roadmap, not permission to implement, install SDKs, change cloud settings, deploy rules, or resume remote-control work. The latest explicit instruction in the earlier discussion was: **"Put a full stop on firebase and remote control we dont even have a working hardware yet."** Adding this section does not revoke that pause. First prove the local kit works repeatedly; resume cloud work only when the user explicitly requests it.

### The experience we want

- Fresh installation: **Open AgriSense -> Connect -> Scan**. Automatic anonymous sign-in happens in the background. No login screen, email/password, SMS/OTP, manual phone-ID approval, Firebase console, IDE or IP entry in the demo flow.
- One physical kit shared by multiple phones. Phones see the same live sensor readings; camera position and LED limits remain shared physical state.
- Each app installation has its own private scan results/history. Sharing a kit must not merge histories or let phone A read/write phone B's records. Preserve existing local records and on-phone inference, including offline use; any later cloud history synchronization needs explicit ownership/migration behavior.
- Ultimately use readings, snapshots and camera/servo commands while the phone is on a different internet connection from the kit, rather than requiring the same local Wi-Fi.
- Desired later camera/notification features include remote preview/live view, on-demand and scheduled/triggered photos, and useful alerts while the app is closed. Their transport, backend, delivery guarantees and compatibility with the free-only constraint remain unresolved. Do not describe them as implemented or promised by merely connecting Firebase.
- Keep the working local connection and offline scanning as fallback if cloud/internet fails. Cloud features must not become a prerequisite for local scanning.
- Keep the main flow short and familiar for nontechnical users. Do not expand the demo into account recovery, complex onboarding or extra setup screens without a demonstrated need.

### Latest demo access decision (supersedes older pairing proposals)

The user chose to **skip OTP/pairing codes for the demo and allow any phone running the app to join the shared kit**, while retaining separate private histories. Earlier proposals for a printed QR, six-digit PIN, Bluetooth onboarding or manual Firebase allowlisting are not the selected demo plan.

This is explicitly temporary **Demo mode**. Unknown app users can potentially join the shared demo kit too; that tradeoff was discussed and accepted for the demo. It does not authorize public user histories, unrestricted board writes or administrator credentials in the app. Keep a way to disable shared cloud access after the defense. Future private ownership/pairing, if wanted, is a separate scope decision.

Anonymous identity belongs to an installation, not a permanent recoverable person. Reinstalling/clearing data can lose that identity; recovery/account linking was deliberately out of scope for the one-time demo. Do not promise history recovery on reinstall or seamless access from a new phone without a defined mechanism.

### Requirements to preserve when eventually implementing

- Phone histories restricted to their respective identities; shared kit access limited to the enabled demo scope.
- Distinct restricted sensor/camera board identities: phones cannot impersonate boards or overwrite telemetry as boards, and each board updates only its assigned data.
- One camera controller at a time. Movement commands need bounded travel, expiry and duplicate/replay rejection; reconnecting must not replay an old movement queue.
- Validate fields, sizes, values and permissions. An API key alone is not authorization; never put administrator/service-account secrets into app or firmware.
- Remain free-only with no billing upgrade unless the user changes that requirement. Earlier planning selected Spark; verify actual current service requirements/quotas before selecting photo/video/notification transports. Avoid promising that all desired remote media fits free services.

### What exists versus what does not

- Earlier discussion reported Firebase console project/database creation, anonymous-auth setup discussions and a downloaded Android configuration file. An untracked `agrisense/android/app/google-services.json` was seen in the working-tree listing; it was not opened here. Its presence alone does not mean Firebase is integrated.
- Earlier console status was described as locked; current live cloud rules/providers/project status have NOT been verified in this chat. Do not assume permissions are configured correctly or change them based on this historical note.
- The pre-Firebase checkpoint is documented in `PRE-FIREBASE-CHECKPOINT.md`: tag `pre-firebase-v1.0.15`, commit `1e82d00016ed1e348e49bd5d7b60a0ea103ce19f`. The earlier chat reported it pushed. It predates app 15e and the power firmware; do not roll back newer work to begin cloud integration.
- No Firebase app SDK integration, tested/deployed database rules, board-cloud firmware, cloud history sync or remote camera pipeline was delivered in the current releases. Previously drafted Firebase files were removed in the earlier chat; do not assume those prototypes remain implemented.

### Intended sequence after explicit resumption

1. Validate the assembled kit with app 15e and firmware 15d-power, including stable power and repeated complete local scans. Preserve a fresh, recoverable checkpoint of the latest work before cloud changes, respecting unrelated dirty files.
2. Foundation: verify the existing Android config privately, add only agreed dependencies, implement silent anonymous sign-in and private per-installation cloud history while preserving local operation. Define the shared demo-kit area and demo shutoff.
3. Write/test access rules before publishing them: phone A cannot access phone B's history, phone identities cannot impersonate boards, and switching Demo mode off blocks shared kit access. Do not leave a public database as a shortcut.
4. Test the foundation on two phones, including fresh install, offline scanning and reconnection. Foundation complete does NOT mean hardware remote control is complete.
5. Update both boards for authenticated telemetry/command transport. Prove remote sensor readings first, then controlled servo commands and snapshots. Preserve the power-demand scheduling and RTC/SD features.
6. Design and validate remote media, scheduling and closed-app alerts only against demonstrated transport, device and free-service limits. Keep local fallback throughout.

Provenance: recovered from the earlier Codex chat **"Compare Agrisense and Florascan"**, thread `01a1853f-5f79-7163-a771-4218ae4bcbf5`, including the user's no-OTP/open-demo choice and subsequent full-stop instruction. This roadmap records those decisions; it does not message that chat or transfer work automatically. Only this handoff was edited for the Firebase-roadmap request; no cloud/code changes or deployments were made.

## Two-way handoff protocol: Codex -> Argon -> Codex

This is the shared continuation record for transferring work to Antigravity Argon when Codex's context is exhausted, then returning to Codex after its context is refreshed. This file does not automatically switch agents or send messages.

Receiving agent: read this file first, inspect the current source and working-tree state, then continue the authorized task. Do not restart completed work or assume an earlier snapshot still describes the current files. The baseline sections below record the initial investigation; the latest dated continuation entry records subsequent progress. Preserve user decisions unless the user changes them.

Outgoing agent (Argon or Codex): update the continuation record below before handing back, and at meaningful checkpoints during long work. Record concrete paths, actual test outcomes and unfinished work. Distinguish implemented, compiled, packaged, flashed and physically verified states. Never mark an unrun check as passed. Include new user instructions and unresolved questions so the receiving agent does not need the other chat's history. Do not record credentials.

Returning Codex: read the latest continuation entry and verify its file/test evidence before resuming. Preserve Argon's changes and unrelated existing edits. Continue from the exact next action; do not reimplement completed changes. If the record conflicts with current files, inspect the discrepancy before proceeding.

## Latest continuation checkpoint — Firmware Payload & Response Fix v1.0.16b-cloud completed by Argon

- Updated date/time: 2026-10-30 03:09 (Asia/Manila), Gemini 4 Argon.
- Next receiving agent: Codex or Argon.
- Latest user instructions: Fix Codex's confirmed sensor telemetry JSON blocker in `firebase_sync.h`, test the actual firmware payload builder, check telemetry PUT responses, and package as a new firmware version (`v1.0.16b-cloud`) without overwriting earlier releases.
- Task state: Source implemented, host-tested, and packaged; physical ESP32 compilation/flashing and live Firebase/kit verification remain pending.
- Deliverables:
  - Android App (unchanged from v1.0.16a-cloud): `AgriSense-v1.0.16a-cloud.apk` (version `1.0.16-a+23`, 154,724,986 bytes, SHA-256: `5681afdef9bcf9eb3e516b582a5576a8cbf13d365a6d5644ee211d1c53b0cf87`).
  - Firmware Archive: `AgriSense-Firmware-v1.0.16b-cloud.zip` (93,388 bytes, SHA-256: `9cb57df49a1c525870af46dcf70802d120613ba4e935cea56a486011c145d4f7`). Earlier `AgriSense-Firmware-v1.0.16-cloud.zip` and `AgriSense-Firmware-v1.0.16a-cloud.zip` preserved intact.
  - App Release Notes: `APP-UPDATE-v1.0.16-cloud.md`.
  - Firmware Release Notes: `FIRMWARE-UPDATE-v1.0.16-cloud.md`.
  - Codex Review Report: `CODEX-REVIEW-v1.0.16a-cloud.md`.
- Completed fixes & consensus resolution:
  1. Sensor Telemetry JSON Blocker Fixed (`v1.0.16b-cloud`): Extracted `buildOpenReadingsJson()`, `closeReadingsJson()`, and `buildSensorCloudPayload()` in `sensor_node_full/firebase_sync.h` (and called `buildOpenReadingsJson()` from `sensor_node_full.ino`). `closeReadingsJson()` closes `readings` with `}` after `dht_age_ms` and `age_ms`, and `buildSensorCloudPayload()` places `"uploaded_at_ms":{".sv":"timestamp"}` at the `/kits/demo/sensor` root before closing the outer JSON object (`}`).
  2. Cloud HTTP Status Checking (`v1.0.16b-cloud`): Checked `PUT` and `GET` status codes in both `firebase_sync.h` and `firebase_camera_sync.h`, logging failures via `Serial.printf`, clearing cached auth tokens on `401`/`403`, and only marking camera snapshot requests executed when the snapshot `PUT` returns HTTP 200.
  3. Actual Payload Builder Host Test (`v1.0.16b-cloud`): Updated `checks/cloud_sync_test.cpp` to call `buildOpenReadingsJson()`, `closeReadingsJson()`, and `buildSensorCloudPayload()` directly and verify balanced JSON, exact key depths (`identity`, `readings`, and `uploaded_at_ms` at depth 1; sensor fields and `age_ms`/`dht_age_ms` at depth 2), and `null` handling for uncalibrated soil / failed DHT reads.
  4. Retained `v1.0.16a-cloud` Fixes: Camera `#include` order in `CameraWebServer/camera_main.h`; built-in Firebase URL/API Key defaults in byte-identical `demo_network.h`; `CloudDeduplicator` boot-time seeding and `device_id` validation; persistent TLS reuse (`setReuse(true)`, 1500 ms timeouts) with at most one HTTP request per `loop()` pass; persistent Hive auth cache + OAuth2 form-encoded token refresh + dual freshness check (`uploaded_at_ms` > 45s and `sample_id` > 30s) in Flutter app.
  5. Verification:
     - `python firmware/demo-pan-tilt/checks/run_host_checks.py`: All 6 host suites passed (`demo_controls_test`, `warning_config_test`, `network_test`, `network_empty_test`, `power_timing_test`, `cloud_sync_test`).
     - `flutter test`: All 49 unit and regression tests passed across 6 test suites.
     - `dart analyze`: Clean, 0 issues found.
- Remaining Limitations & Hardware Verification Requirements:
  - ESP32 compilation via Arduino IDE/CLI, flashing to both physical ESP32 boards, and live end-to-end verification of remote readings, pan/tilt commands, and snapshots against the physical kit and Firebase remain pending (no `arduino-cli` or physical boards attached in this environment).
  - Accepted demo tradeoffs: `setInsecure()` TLS on ESP32, single primary controller phone, private scan history stored in local Hive.
- Rollback baseline: Commit `071c218` on `v2-ui-simple`.

## Previous continuation checkpoint (v1.0.15e Trends)

Subsequent app task (2026-10-30): user requested and authorized a Trends UI redesign. Completed separately as app v1.0.15e (build 21), retaining compatibility and existing data. See `APP-UPDATE-v1.0.15e.md` and `AgriSense-v1.0.15e.apk`. Ten focused tests, analysis and release build passed; APK signature matches 15d. The firmware delivery below remains unchanged and still awaits ESP32/hardware verification. Do not confuse the newer app version with a new firmware revision.

- Updated: 2026-10-29 (Asia/Manila), Codex. This entry supersedes the initial checkpoint below.
- User authorized implementation and explicitly confirmed keeping RTC and SD cards.
- State: source implemented and packaged as `v1.0.15d-power`; five host suites passed. No ESP32 build, flash or electrical verification.
- Verified all 27 initial files exactly matched `AgriSense-Firmware-v1.0.15.zip`; original archive remains untouched with the recorded SHA-256.
- Implemented bounded Wi-Fi attempts with radio-stop-before-retry, staged servo startup, one-axis movement/settling, sensor association deferral during movement, SD logging and automatic-capture deferral during motion, reset/disconnect diagnostics, and camera initialization retry gating. RTC/SD, settings and protocol formats retained; no app changes.
- Changed baseline files: firmware root README; both `demo_network.h`; camera `camera_main.h`; sensor `demo_controls.h`, `sensor_node_full.ino`, `auto_capture.h`, `auto_capture_timing.h`; host `demo_controls_test.cpp`, `esp32-hal-ledc.h`.
- Added host files: `checks/network_test.cpp`, `checks/power_timing_test.cpp`, `checks/run_host_checks.py`, and `checks/network/{WiFi.h,ESPmDNS.h,esp_system.h}` under `firmware/demo-pan-tilt/`.
- Added root release notes `FIRMWARE-UPDATE-v1.0.15d-power.md`. Output script/log/diff/manifest are in `output/firmware-v15d-power/`.
- Tests: `python firmware/demo-pan-tilt/checks/run_host_checks.py` compiled and passed demo_controls, warning_config, network, empty-credentials network and power_timing suites using g++ `-std=c++17 -Wall -Wextra`. Log: `output/firmware-v15d-power/host-checks.log`. Also ran `git diff --check`; firmware whitespace and synchronized network headers are checked explicitly by the packaging script because firmware is ignored by Git.
- Delivery: `AgriSense-Firmware-v1.0.15d-power.zip`, SHA-256 `50420c073537b062ae89f7c19369a53a83e08f266f0e0f4e69959a1bd6ce3a46`. Package CRC and source byte hashes verified. No completed secrets.h read or packaged. Original v15 archive provides rollback.
- Review source diff: `output/firmware-v15d-power/firmware.diff`; exact changed/additional files and hashes: `package-manifest.json` alongside it. `package_firmware.py` uses exclusive creation, so do not rerun against an existing delivery filename.
- Remaining limitation: manual camera streaming/capture and ongoing radio traffic can overlap servo loads across boards; motor holding current remains. No cross-board load arbitration protocol or app change was introduced. Separate camera supply remains recommended. Firmware cannot guarantee stable voltage.
- Exact next action: compile BOTH standalone sketches with the user's existing ESP32 Arduino 3.x/camera configuration, preserving private settings and flash/NVS; then run release-note hardware acceptance and measure voltage under worst load. No arduino-cli was on PATH here; do not install dependencies without permission or claim hardware validation from host tests.
- Dependencies/Git: none installed; no commit, push or history changes. Existing unrelated dirty app work remains. Another concurrent writer appears to touch app files; do not include or revert it.
- Next receiving agent: Argon if the user transfers, otherwise Codex can continue. Read this checkpoint and release notes before repeating work.

## Initial continuation checkpoint (historical)

- Updated: 2026-10-29, Codex; documentation-only checkpoint.
- Next receiving agent: Antigravity Argon.
- Task state: firmware implementation authorized, not started.
- Latest user direction: use firmware 15 as the base, preserve its features, prioritize reducing power spikes, and maintain this as a two-way handoff.
- Changes in this session: this Markdown file only. No firmware/app edits, builds, tests, packaging, flashing or hardware measurements.
- Exact next action: verify the v15 archive against `firmware/demo-pan-tilt/` without exposing credentials, establish a recoverable baseline, then implement the localized firmware changes described below.
- Return destination: Codex in the original chat after context refresh; user controls the transfer.

### Continuation entry template — append a dated entry for each transfer

- Updated date/time (Asia/Manila) and outgoing agent:
- Next receiving agent:
- Latest user instructions / changed decisions:
- Task state (in progress / awaiting hardware / complete):
- Completed work and reasons for key decisions:
- Files created/modified/deleted (repository-relative paths):
- Commands/tests actually run and results (include failures and log paths):
- Verification state (host tests / ESP32 compile / packaged / flashed / physical tests):
- Deliverables and exact paths/version/hash, if produced:
- Dependencies changed and Git actions, if any:
- Remaining issues, risks, blockers or pending user answers:
- Exact next action and ordered remaining steps:
- Workspace cautions / unrelated changes to preserve:

Keep entries concise but sufficient to resume without the outgoing chat. Append corrections explicitly when needed; do not erase the earlier evidence or silently change the original user requirements.

## User request and authorization

The user now authorizes implementing a new firmware revision, but requested this handoff first. This session has made NO firmware or app changes. Only this handoff is being created.

Use **firmware v1.0.15 as the base**. The user explicitly rejected starting from the previously flashed firmware. Firmware 15 has NOT been used/flashed by the user, so do not treat it as hardware validated.

The desired result is the best of both worlds: preserve firmware 15 features and current app compatibility while prioritizing reduced power spikes and reliable recovery. Do not claim firmware can prevent every voltage drop. The new revision name is not settled; matching the current app's 15d label is an option, not a requirement.

Keep user-facing updates short. The user explicitly complained about lengthy explanations.

## Hardware observations from the user

- Sometimes Serial Monitor reports: `22:31:54.018 -> E (6526) wifi:sta is connecting, return error`.
- Hardware consistently experiences voltage drops affecting servo operation.
- Giving the camera its own power source fixes the observed problem.
- This suggests a shared supply/wiring/load issue, but no electrical measurements or reset logs have established the exact cause.
- No board was accessed, flashed, or electrically tested in this session.

## Baseline and current app

- Firmware archive: `AgriSense-Firmware-v1.0.15.zip`.
- Release notes: `APP-UPDATE-v1.0.15.md`.
- Local firmware source: `firmware/demo-pan-tilt/`, with standalone `sensor_node_full/` and `CameraWebServer/` projects.
- Firmware directory is ignored by Git. Review actual source differences and package the finished source explicitly; ordinary Git diffs do not include it.
- Verify the archive/source match before implementation. The release notes record archive SHA-256 `190DF15043392FE0DBB014A7F934D95E4812D130CA21EB1B8CFBC2A8D9F8AB5F`; this session has not independently rehashed it.
- Current app source declares `version: 1.0.15-d+20` in `agrisense/pubspec.yaml`.
- `APP-UPDATE-v1.0.15d.md` identifies Android versionName `1.0.15d`, code 20, and APK `AgriSense-v1.0.15d.apk`. Its changes were UI/content changes, with no firmware change.
- Preserve compatibility with the current app; do not rebuild or modify the app unless a concrete requirement makes it necessary.

## Features to preserve

- Connect/discovery, readings, camera live view and manual camera-to-phone scans.
- Offline phone inference and local scan history, with no internet requirement; camera/sensor access still requires the shared local Wi-Fi.
- Crop identity, pairing/authentication, saved settings and warning rules.
- Duplicate/stale movement command protection and existing movement limits.
- Three warning LEDs: temperature/humidity GPIO14, soil GPIO27, gas GPIO33.
- Soil/gas sampling about every second; DHT22 every two seconds with independent freshness and invalid readings represented as unavailable.
- Existing optional sensor SD logs/RTC and camera automatic photo storage unless a deliberate, justified scope decision changes them.

The user explored removing SD and timestamps but did NOT settle on removing them. The final agreed proposal was to preserve SD/RTC unless explicitly agreed otherwise. Do not silently delete them.

## Findings from source inspection

### Wi-Fi retry overlap (likely explanation, not reproduced)

Both `firmware/demo-pan-tilt/CameraWebServer/demo_network.h` and `firmware/demo-pan-tilt/sensor_node_full/demo_network.h` contain the same `DemoNetwork` implementation:

- `begin()` selects STA mode, disables automatic reconnect, disables Wi-Fi sleep, calls `WiFi.begin()`, and records the attempt time.
- `tick()` considers the board online only when connected with a nonzero IP.
- When offline it retries with delays of 2000, 5000, 10000, then 30000 ms using `WiFi.reconnect()`.
- There is no explicit in-flight connection state, terminal failure event handling, or bounded attempt timeout before that retry.
- A retry can therefore overlap a slow association/address acquisition. The log alone does not prove brownout.

Implement a single retry owner with explicit connection progress/failure handling and a bounded timeout. Do not rely solely on an offline status to infer that a new connect attempt is safe. Keep both standalone headers synchronized. Verify behavior against the project's actual ESP32 Arduino core, not assumptions about another version.

### Servo load

`firmware/demo-pan-tilt/sensor_node_full/demo_controls.h`:

- Pan GPIO25, tilt GPIO26.
- Center 90 degrees; range 75..105 degrees.
- Ten-degree commands; clamped two-degree steps every 20 ms.
- PWM 50 Hz, 16 bits, 1000..2000 us mapping.
- Startup attaches and commands both servos to center.
- The tick can advance BOTH axes in the same iteration.
- PWM remains attached at rest. Releasing idle servos was only discussed as a possibility: holding torque may be necessary for the mount, so do not disable it blindly.

Prioritize serializing axis movement and reducing simultaneous startup load while retaining command semantics, limits, deduplication, responsiveness, and acknowledgements. Software acknowledgement is not proof of physical position.

### Camera and other loads

- `firmware/demo-pan-tilt/CameraWebServer/camera_main.h` already sets QVGA, one frame buffer, and 20 MHz XCLK. Do not assume high resolution or multiple buffers are the problem.
- `camera_runtime.h` uses `CameraAccess` and a semaphore to serialize camera access locally.
- Sensor RTC/SD code is in `sensor_node_full.ino`; logging is approximately every ten seconds.
- Camera SD code is in `capture_storage.h`; automatic requests are in `automatic_camera.h`.
- Consider avoiding overlapping movement, capture, and SD writes where practical. These run on separate boards: effective cross-board coordination needs a real design compatible with existing app behavior. A local flag on one board cannot serialize loads on the other.
- Wi-Fi sleep is disabled on both boards. Evaluate power saving only with responsiveness and streaming checks; average power reduction is not a guarantee of lower worst-case peaks.
- Lower transmit power is an optional measured experiment under strong signal, not a blind default; weak signal/retries could defeat its benefit.

## SD/RTC and offline behavior distinctions

- Removing sensor SD/RTC would lose standalone sensor CSV logs and their real date/time; it does not remove phone inference/history, whose timestamps come from the phone.
- Removing camera SD would remove durable standalone automatic photos taken while the phone is absent. Existing documentation says manual Wi-Fi captures remain available without working SD.
- The RTC itself is a small load; deleting it is not an established servo-power fix.
- Consult `agrisense/docs/AUTOMATIC_CAPTURE.md`, while noting it documents older setup details; confirm current source behavior before changing it.

## Implementation and validation expectations

1. Establish the v15 source baseline and preserve a recoverable, credential-free copy before editing ignored firmware. Do not overwrite existing releases.
2. Make a small, reviewable firmware-only change prioritizing Wi-Fi connection lifecycle and reduced simultaneous motor/startup load.
3. Preserve brownout protection. Do not mask the electrical problem by disabling it or promising zero voltage drops.
4. Keep the camera's separate power source that the user reports works. Proper supply capacity, wiring, regulator response and common ground remain necessary; firmware cannot guarantee stable voltage.
5. Run meaningful existing host checks and add targeted behavioral coverage for changed retry/movement behavior where feasible. Existing tests under `firmware/demo-pan-tilt/checks/` include `demo_controls_test.cpp`, `warning_config_test.cpp` and an LEDC shim.
6. Prior v15 notes mention g++ host tests, not actual ESP32 builds. Check available repository tooling; do not claim ESP32 compilation or hardware acceptance unless performed. Do not install libraries or unfamiliar setup scripts without user confirmation.
7. Hardware acceptance must cover simultaneous demand, startup/reconnect, actual voltage rails, camera live view/capture, commands during movement, saved warnings, restart and offline behavior. Request/report physical testing honestly when hardware is inaccessible.
8. Deliver a newly named source ZIP excluding completed `secrets.h`, credentials, executables and unrelated files, plus concise changes/install/rollback notes. Keep all required headers with each standalone sketch. Preserve saved pairing/crop/settings; keep Erase All Flash disabled.

## Workspace safety and existing changes

The working tree is already dirty with unrelated app changes, APKs, generated output, notebooks and tests. Do not revert, commit, clean, overwrite, or package unrelated work. `git status --short` was read; no Git mutations were made.

Follow the user's AGENTS instructions: work only inside the active repository; no host profiles/credentials/system settings; no public listeners; no new dependencies without confirmation; clean Git checkpoint required before mass refactoring/batch modifications. Prefer a localized change, not a mass rewrite. Summarize changed files, commands/tests and remaining risks at completion.

## Work performed in this conversation

- Read-only `rg` searches and PowerShell `Get-Content`/`Select-String` inspection of firmware, setup/release docs and app version.
- Read-only `git status --short`.
- Consulted official Espressif Wi-Fi API and ESP32 hardware design guidance. Relevant references:
  - https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/network/esp_wifi.html
  - https://docs.espressif.com/projects/esp-hardware-design-guidelines/en/latest/esp32/schematic-checklist.html
- No code edits, builds, tests, dependency installs, flashes, physical measurements or secret-file reads.
- Created this handoff only. Next step is firmware implementation from v15 as authorized above.
