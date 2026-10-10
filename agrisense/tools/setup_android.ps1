param([switch]$AcceptLicenses)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $projectRoot
$toolRoot = Join-Path $repoRoot '.tools'
$sdkRoot = Join-Path $toolRoot 'android-sdk'
$bootstrap = Join-Path $toolRoot 'android-bootstrap'
$archive = Join-Path $toolRoot 'commandlinetools.zip'
New-Item -ItemType Directory -Force -Path $toolRoot,$sdkRoot,$bootstrap | Out-Null
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21'
if (!(Test-Path "$env:JAVA_HOME\bin\java.exe")) { throw 'JDK 21 is required. Set JAVA_HOME in this script to your JDK installation.' }
$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot
$env:ANDROID_USER_HOME = Join-Path $toolRoot 'android-user'
$env:ANDROID_AVD_HOME = Join-Path $toolRoot 'avd'
$env:GRADLE_USER_HOME = Join-Path $toolRoot 'gradle'
New-Item -ItemType Directory -Force -Path $env:ANDROID_USER_HOME,$env:ANDROID_AVD_HOME | Out-Null
$manager = Join-Path $bootstrap 'cmdline-tools\bin\sdkmanager.bat'
if (!(Test-Path $manager)) {
  Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip' -OutFile $archive
  $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne '90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a') { throw 'Android command-line tools checksum mismatch.' }
  Expand-Archive -LiteralPath $archive -DestinationPath $bootstrap -Force
}
if ($AcceptLicenses) {
  1..20 | ForEach-Object { 'y' } | & $manager "--sdk_root=$sdkRoot" --licenses
} else {
  & $manager "--sdk_root=$sdkRoot" --licenses
}
if ($LASTEXITCODE -ne 0) { throw 'SDK license step failed.' }
& $manager "--sdk_root=$sdkRoot" 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0' 'emulator' 'system-images;android-36;google_apis;x86_64' 'ndk;28.2.13676358' 'cmdline-tools;latest'
if ($LASTEXITCODE -ne 0) { throw 'SDK package installation failed.' }
$avdmanager = Join-Path $sdkRoot 'cmdline-tools\latest\bin\avdmanager.bat'
if (!(Test-Path (Join-Path $env:ANDROID_AVD_HOME 'AgriSense_API_36.ini'))) {
  'no' | & $avdmanager create avd --name AgriSense_API_36 --package 'system-images;android-36;google_apis;x86_64' --device pixel_6
  if ($LASTEXITCODE -ne 0) { throw 'Emulator creation failed.' }
}
& (Join-Path $sdkRoot 'emulator\emulator.exe') -accel-check
Write-Output 'SDK prepared in .tools. Run tools/run_android.ps1 to build and launch.'
