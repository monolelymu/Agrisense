param([switch]$Headless)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = Join-Path (Split-Path -Parent $projectRoot) '.tools'
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21'
$env:ANDROID_HOME = Join-Path $toolRoot 'android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:ANDROID_USER_HOME = Join-Path $toolRoot 'android-user'
$env:ANDROID_AVD_HOME = Join-Path $toolRoot 'avd'
$env:GRADLE_USER_HOME = Join-Path $toolRoot 'gradle'
$emulator = Join-Path $env:ANDROID_HOME 'emulator\emulator.exe'
$adb = Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
if (!(Test-Path $emulator)) { throw 'Run tools/setup_android.ps1 first.' }
$arguments = @('-avd','AgriSense_API_36','-port','5554','-no-snapshot','-no-audio')
if ($Headless) { $arguments += '-no-window' }
if (!((& $adb devices) -match 'emulator-5554\s+device')) {
  Start-Process -FilePath $emulator -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput (Join-Path $toolRoot 'emulator.log') -RedirectStandardError (Join-Path $toolRoot 'emulator-error.log') | Out-Null
}
Push-Location $projectRoot
try { flutter run -d emulator-5554 --device-timeout 120 } finally { Pop-Location }
