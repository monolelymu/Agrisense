# AgriSense prototype status

## Implemented

- Dark responsive Flutter UI for Tomato and Chili.
- Dashboard, stress breakdown, trends, alerts, device pairing, diagnosis,
  history, and settings screens.
- Deterministic mock sensor samples and simulated node connections.
- Five shared models and repository interfaces. ChangeNotifier coordinates
  the demo; widgets do not talk to Hive or hardware plugins directly.
- Hive CE history/settings storage, scoped by crop; connections reset on launch.
- Crossing alerts, normal-sample recovery, duplicate suppression, and diagnosis retry.
- Configurable demo ranges, Celsius/Fahrenheit display, and confirmed reset.
- Loading, empty, storage-error, and retry states.

## Intentionally deferred by the user

Dataset downloads, sample dataset photos, training notebooks, model training,
and real inference are deferred. There are no dataset images in this UI version.
Leaf previews are placeholders. Disease names and confidence values are fixed
mock outputs, not predictions or accuracy measurements.

Real BLE, Wi-Fi, camera capture, ESP-NOW firmware, cloud sync, and calibrated
agricultural thresholds are not implemented.

## Architecture

`core` owns app wiring, theme, reusable UI, and the application controller.
`data` defines models, repository contracts, mock adapters, and Hive adapters.
`features` contains the monitoring, device, diagnosis, history, and settings UI.
Stress calculation is a pure function in the monitoring feature.

The initial 58 readings represent seven days of synthetic readings for two crops.
The guided demo adds new readings only while the selected Sensor Node is connected.
Each out-of-range metric adds 25 points; the default alert threshold is 50.
Temperature limits are stored/edited in Celsius. Settings changes establish a
new score baseline without creating artificial sensor events.

History and settings persist on the current installation/origin only. Use the
same browser hostname and port between sessions to see the same local history.
The Reset demo action removes both crops' data and restores the seed readings.

## Validation

Run `flutter analyze` and `flutter test` from the Flutter package directory.
Tests cover inclusive stress boundaries, disconnected sensors, alert deduplication,
crop isolation, mock diagnosis retries, storage failure/retry, restoration/reset,
and guided navigation at 390x844 and 1440x1000.

Web compilation has succeeded. Android build initially failed because no SDK was
installed. The optional tooling scripts prepare an SDK and API 36 emulator under
the repository's ignored `.tools` directory; actual Android run status must be
verified after setup completes.
