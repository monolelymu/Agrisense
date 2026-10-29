# Pre-Firebase rollback checkpoint

- App version: **1.0.15**, Android build **16**.
- Git branch: `v2-ui-simple`.
- Rollback tag: `pre-firebase-v1.0.15`.
- This is the local-network app before Firebase integration. No Firebase SDKs, Google Services Gradle plugin, cloud authentication, remote transport or google-services.json are included.
- Includes descriptive disease results, responsive sensor polling, saved kit-warning limits and the three-LED/servo firmware package. See APP-UPDATE-v1.0.15.md for changes and verification limits.
- Firmware source archive: `AgriSense-Firmware-v1.0.15.zip`, excluding completed credentials. Local firmware directories are ignored by Git; use this archive for the matching firmware source.
- The APK is retained locally as `AgriSense-v1.0.15.apk` and is not committed because it exceeds GitHub's normal 100 MiB file limit. Its SHA-256 is `94B96E163B0353A8CADEC51855C39F7DB2A349205F9392F00310A9FAD0BFC1C5`.

To recover the source, check out the tag in a separate checkout. To install a rollback over a newer app without uninstalling, rebuild this source with the same signing identity and a higher Android version code than the installed version. Keep history by avoiding uninstall/reinstall. Preserve private Wi-Fi settings separately when restoring firmware, and leave Erase All Flash disabled.
