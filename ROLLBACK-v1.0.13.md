# AgriSense rollback checkpoint — v1.0.13

Created 2026-10-29 before adding optional disease example photos and clearer
sensor/retake explanations.

- Current Android build: version name `1.0.13`, version code `14`, as recorded in
  Android build properties and the versioned APK.
- `pubspec.yaml` still declares `1.0.0+1`; Android release versions have been
  supplied as build overrides. Use `--build-name=1.0.13 --build-number=14` when
  reproducing this checkpoint.
- This commit preserves the current tracked application source, including the
  existing movement/control changes, and the v1.0.11–v1.0.13 update notes.
- Existing rollback installer: `AgriSense-v1.0.13.apk` in the repository folder
  on this computer. APKs, firmware archives, temporary outputs and unrelated ML
  work are not part of this source checkpoint.
- Firmware and FloraScan are unchanged.

To restore source, create a separate branch/check-out from the commit containing
this note. Avoid resetting or deleting local work. Reverting subsequent app
commits on the working branch is another option that preserves history.

Android may reject installation of an older version code over a newer build.
For a data-preserving rollback, rebuild this source with a version code higher
than the installed build, using the same application ID and signing key. Do not
uninstall the app unless loss of its local history is acceptable.
