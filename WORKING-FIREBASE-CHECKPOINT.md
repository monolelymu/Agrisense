# Working Firebase prototype

Checkpoint requested 2026-10-30 before the next app/firmware update.

- App source: `1.0.16-a+23`, corresponding to local `AgriSense-v1.0.16a-cloud.apk`.
- Firmware source: `AgriSense-Firmware-v1.0.16b-cloud.zip`, included in Git because working firmware is ignored.
- User verified Firebase servo control using a phone hotspot; delay remains noticeable. Full physical acceptance of every cloud feature is not claimed.
- App SHA-256: `5681afdef9bcf9eb3e516b582a5576a8cbf13d365a6d5644ee211d1c53b0cf87`.
- Firmware SHA-256: `9cb57df49a1c525870af46dcf70802d120613ba4e935cea56a486011c145d4f7`.
- Prior read-only verification: valid sensor JSON/root upload timestamp, six host suites passed, status checks/token invalidation inspected, package/source match and earlier archive hashes verified.
- No completed secrets.h, downloaded google-services.json, administrator credentials, APKs or unrelated experiments are committed. Public Firebase Web API configuration is intentional.
- APKs remain local due to their size. Rebuild with the same signing identity and a higher version code when installing over a newer release; do not uninstall to roll back if history is needed.

The next requested update includes app Wi-Fi provisioning/recovery for both boards, explicit Local/Remote selection, local/remote live preview, crop/warning settings, SD downloads, private cloud backup/linking, server-driven closed-app alerts and controller coordination, plus finalized product wording. Preserve RTC/SD and power sequencing. User requested servo targets 0..180 with PAN_SIGN=-1 and TILT_SIGN=-1 for that next revision; physical clearance still needs testing. These future features are not claimed by this checkpoint.
