# Drive Rescue Assistant

Drive Rescue Assistant is a local-first, cross-platform external drive rescue tool. It helps inspect removable drives, explain likely read/write problems, and extract readable files into a normal folder without modifying the source drive.

The first version is intentionally conservative:

- Scan mounted drives.
- Inspect one drive or mount path.
- Detect common read-only and backup-drive conditions.
- Copy readable files out to another destination.
- Support dry-run extraction previews.
- Produce local reports.
- Avoid delete, format, repair, repartition, force-mount, or permission-bypass operations.

## Supported Platforms

- macOS: `diskutil`, `mount`, and Time Machine hints.
- Windows: PowerShell `Get-Volume`/`Get-Disk` where available.
- Linux: `lsblk`, `findmnt`, and common mount metadata.

Each platform has its own adapter under `src/drive_rescue/platforms/`.

## Quick Start

Requires Python 3.10 or newer.

```bash
python3 -m drive_rescue scan
python3 -m drive_rescue inspect /Volumes/MyBackup
python3 -m drive_rescue extract /Volumes/MyBackup --to ./recovered --dry-run
python3 -m drive_rescue extract /Volumes/MyBackup --to ./recovered
```

For local development from the repo root:

```bash
python3 -m pip install -e .
drive-rescue scan
```

Run tests without extra dependencies:

```bash
PYTHONPATH=src python3 -m unittest discover -s tests
```

## Mac App

The repo includes a first SwiftUI macOS interface with both SwiftPM and Xcode entrypoints.

```bash
swift build
xcodebuild -project DriveRescueAssistant.xcodeproj -scheme DriveRescueAssistant -destination "platform=macOS,arch=arm64" build
./script/build_and_run.sh
```

The app keeps the same safety model as the CLI: scan, inspect, preview extraction, and extract readable files. It does not delete, repair, format, or force-mount drives.

Preview and extraction can be limited to all files, documents, photos, videos, audio, or archives. The app can also write matched files into a ZIP archive to save destination space.

The Mac app also includes a "Move From This Mac" workflow for copying a user-selected internal folder to an external destination with the same preview, file-type filter, and ZIP options.

Use `DriveRescueAssistant.xcodeproj` for signing, Archive, asset catalog work, and future App Store preparation.

For a Developer ID-signed direct-download package and Apple's notarization
workflow, see `docs/MACOS_SIGNING_NOTARIZATION.md` and run:

```bash
./script/package_macos_release.sh
```

## Friend Testing

To create a Mac package that can be uploaded to a GitHub Release:

```bash
./script/package_friend_test.sh
```

The package is written to `dist/friend-test/DriveRescueAssistant-mac-friend-test.zip`. Include `docs/FRIEND_TEST_GUIDE.md` and `docs/GITHUB_RELEASE_TESTING.md` when preparing a test release.

Windows and Linux friend-test packages are built automatically by `.github/workflows/desktop-release.yml`. Push a version tag such as `v0.2.0` to create a GitHub Release containing:

- `DriveRescueAssistant-windows-x64.zip`
- `DriveRescueAssistant-linux-x64.tar.gz`

Both desktop packages are self-contained and do not require Python. Their shared GUI supports detected-drive selection, source/destination folder pickers, file-type filters, individual preview selection, and optional ZIP extraction.

The same workflow also produces a private GitHub Actions artifact named `MicrosoftStorePackage`. Its `.msixupload` file uses the reserved Partner Center identity and is intended for Store submission, not public direct installation. See `docs/WINDOWS_STORE_SUBMISSION.md`.

## Safety Promise

Drive Rescue Assistant is extraction-first. It does not erase, format, repartition, force-mount, or delete files in V1. If a drive looks damaged or read-only, the tool recommends copying readable data out before any repair attempt.

Recovered personal files and real scan logs should not be committed to GitHub.

## Repo Layout

```text
src/drive_rescue/
  cli.py
  core/
  platforms/
docs/
  DESIGN_SPEC.md
  SAFETY.md
  PLATFORM_SUPPORT.md
  store/
tests/
```

## Store Readiness

The GitHub CLI can be more technical, but any Apple App Store or Google Play version should use a stricter permission model, system file pickers, clear privacy wording, and no destructive disk operations by default. See `docs/store/`.

For the full Apple/Google store and cross-platform release plan, see `docs/STORE_AND_PLATFORM_PLAN.md`.

## Mac App Direction

The preferred interface is simple, functional, and minimalist: a native macOS app with a connected-drive sidebar, a clear drive summary, one primary extraction path, and plain safety notes. See `docs/MAC_APP_UI.md`.

## Troubleshooting Direction

Drive diagnosis should explain older Mac backup disks calmly. Apple Partition Map and tiny legacy Apple driver partitions can be normal on old WD drives; failed HFS+ verification with `Invalid extent entry` points to filesystem corruption. See `docs/TROUBLESHOOTING.md`.
