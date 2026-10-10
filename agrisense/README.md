# AgriSense

**AgriSense — Smart Crop Stress Monitoring System**

AgriSense is a Flutter-based application prototype designed to demonstrate crop stress monitoring for **Tomato, Chili, and Eggplant** plants.

The application provides a simulated environment for monitoring sensor readings, detecting potential plant stress, reviewing alerts, and visualizing historical data.

The current implementation uses mock sensor readings and simulated device connections. No physical sensors, external datasets, cloud backend, or trained AI model are required to run the demo.

## 1. Project Requirements

Before getting started, ensure your development environment has:

- Flutter SDK installed and configured
- Visual Studio Code with the Flutter and Dart extensions
- Git for version control
- A modern web browser
- Android SDK and emulator (optional, for Android testing)

Verify your Flutter installation using `flutter doctor`.

## 2. Getting Started

**Step 1: Open the repository**

Clone the repository or download the project, then open its folder in Visual Studio Code.

**Step 2: Navigate to the Flutter application**

The repository contains a nested Flutter package. From the repository root, run:

`cd agrisense`

You should now be inside the folder containing `pubspec.yaml`.

**Step 3: Install dependencies**

Run:

`flutter pub get`

This downloads the packages required by the application.

## 3. Running the Application

### Web browser (recommended)

Run the following command from the Flutter project directory:

`flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8081`

Then open:

http://127.0.0.1:8081

Keep the terminal running while testing.

**Flutter terminal shortcuts:**

- `r` — Hot reload supported changes
- `R` — Hot restart the application
- `q` — Quit the running application

Using the same browser, address, and port helps preserve browser-local demo history between sessions.

### Android emulator (optional)

If an Android emulator is already installed:

1. Launch your emulator.
2. Run `flutter devices` to confirm Flutter detects it.
3. Run `flutter run` and select the Android device, or specify its device ID.

The repository may also provide optional Windows setup scripts:

- `tools/setup_android.ps1` — Sets up an Android development environment
- `tools/run_android.ps1` — Starts the configured emulator and application

These scripts should only be used if they are included in your checkout and are compatible with your Windows environment. Initial SDK installation can require several gigabytes of downloads.

## 4. Application Demonstration

Follow these steps to explore the application.

**Step 1: Device setup**

1. Open the **Devices** screen.
2. Select Tomato, Chili, or Eggplant.
3. Select **Scan simulated nodes**.
4. Connect the Sensor Node and Vision Node.

**Step 2: Dashboard monitoring**

1. Return to the **Dashboard**.
2. Select the same crop.
3. Review the displayed sensor readings.
4. Choose **Normal sample** to simulate healthy conditions.
5. Select **Simulate stress** to generate a stressed reading.

**Step 3: Alerts and diagnosis**

1. Open the notification bell.
2. Review the generated stress alert.
3. Select **View mock diagnosis**.
4. Review the simulated diagnosis details.

**Step 4: Historical data and trends**

1. Open **History** to review readings, scans, and alerts.
2. Open **Trends** to explore sensor charts and historical patterns.
3. Open **Settings** to try the available demo ranges and units.

**Additional test scenarios**

- Disconnect the Vision Node to simulate an unavailable camera.
- Record a normal reading before generating another stress alert.
- Switch between Tomato, Chili, and Eggplant to observe separate crop histories and connections.
- Reset the demo to restore the application's sample data after confirmation.

## 5. Current Project Scope

**Implemented demonstration features**

- Dashboard for crop monitoring
- Simulated sensor and vision node connections
- Crop selection for Tomato, Chili, and Eggplant
- Mock sensor readings
- Demo stress score calculation
- Stress alerts and notifications
- Simulated diagnosis interface
- Reading and alert history
- Trend visualization
- Application settings

**Features reserved for future development**

- Integration with physical sensors
- Real-time hardware communication
- Collection and preparation of datasets
- Training and integration of an AI model
- Actual image-based plant stress classification
- Integration with backend services if required

All stress scores, diagnoses, and confidence values are currently demonstration outputs and should not be treated as validated crop assessments.

## 6. Development and Testing

Run these commands from the Flutter project directory:

- `dart format .` — Format Dart source files
- `flutter analyze` — Check for static analysis issues
- `flutter test` — Execute automated tests
- `flutter build web` — Verify the web application builds

Note that `dart format .` may modify source files. Review these changes before committing.

For additional implementation details, refer to `docs/IMPLEMENTATION.md`.

## 7. Team Development Guidelines

To maintain a consistent development environment:

1. Pull the latest changes before beginning development.
2. Use a separate feature branch when working on substantial changes.
3. Make descriptive Git commits.
4. Run analysis and relevant tests before merging.
5. Do not commit local SDK installations, generated build files, or personal IDE configurations.
6. Never commit passwords, access tokens, signing keys, or private configuration files.
7. Inform other members when introducing new packages or major project changes.

The project's `.gitignore` is intended to keep temporary and machine-specific files out of version control.

## 8. Important Notes

- The application is currently a **functional UI prototype**.
- Hardware connections and diagnoses are simulated.
- Installing dependencies may require internet access, but the current demo does not depend on a live backend service.
- Browser-local demo data is not automatically synchronized between members or devices.
- Demo history may be lost when browser site data is cleared or when the application is reset.

**AgriSense is under active development.** Additional functionality will be integrated as the project progresses.
