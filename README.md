# AgriSense

A dark Flutter mock app for **Tomato and Chili**, intended for browser and Android.
No hardware, internet service, dataset, or trained AI model is needed for the UI.

## 1. Open the Flutter package

The Git repository contains a nested Flutter package. In PowerShell:

```powershell
cd C:\Users\Samuel\Desktop\agrisenseAppDev\Agrisense\agrisense
flutter pub get
```

## 2. Run in your browser

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8081
```

Keep the terminal open, then open http://127.0.0.1:8081 in your browser.
Use the same address and port each time to retain browser-local history.
Press `r` to reload supported changes, `R` to restart, or `q` to stop.

## 3. Try the guided demo

1. Open **Devices**, select Tomato or Chili, and **Scan simulated nodes**.
2. Connect the Sensor Node and Vision Node.
3. Return to **Dashboard** and select the same crop.
4. Scroll down and choose **Normal sample**, then **Simulate stress**.
5. Open the bell icon, then **View mock diagnosis**.
6. Open **History** to find scans, readings, and alerts.
7. Try the charts in **Trends** and demo ranges/units in **Settings**.

To test a missing camera, disconnect the Vision Node before introducing stress.
The alert offers a connection/retry path. To trigger another alert, record a
normal sample before another stressed sample. Selecting the other crop keeps
its connections and events separate.

All device connections and diagnoses are simulated. The stress calculation and
confidence values are demo values. Dataset work is deferred; leaf previews use
placeholders. Resetting the demo requires confirmation and restores sample data.

## 4. Android emulator

If your Android SDK is already installed, use your normal emulator and `flutter run`.
For this machine, the optional PowerShell scripts use the existing JDK 21 and
keep downloaded SDK/emulator files in the repository's ignored `.tools` folder:

```powershell
powershell -ExecutionPolicy Bypass -File tools/setup_android.ps1
powershell -ExecutionPolicy Bypass -File tools/run_android.ps1
```

The first script downloads several GB and prompts for Google's SDK licenses.
Hardware virtualization and a supported Windows hypervisor are required for a
usable emulator. These scripts do not change global environment variables.
Do not run setup twice concurrently.

## 5. Checks

```powershell
dart format .
flutter analyze
flutter test
flutter build web
```

Read `docs/IMPLEMENTATION.md` for architecture, implemented behavior, and deferred work.
