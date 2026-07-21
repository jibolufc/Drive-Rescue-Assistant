# Drive Rescue Assistant Design Spec

## Purpose

Drive Rescue Assistant helps users inspect external/removable drives and extract readable data when the drive is visible but difficult to write to. The original target problem is a MacBook Pro seeing a Time Machine-style drive that cannot be written to normally.

The product direction is extraction-first, destructive-actions-last.

## Core Goals

- Detect mounted drives across macOS, Windows, and Linux.
- Explain common reasons a drive is read-only or restricted.
- Extract readable files to a user-chosen destination.
- Copy selected internal folders to an external destination.
- Preserve folder structure where possible.
- Resume-friendly behavior by skipping existing files unless overwrite is requested.
- Generate local reports for each extraction.
- Keep the GitHub repo free of recovered private data.

## Non-Goals for V1

- No deletion.
- No formatting.
- No repartitioning.
- No force mounting.
- No bypassing permissions.
- No deep forensic recovery.
- No cloud upload.

## Architecture

```text
src/drive_rescue/
  cli.py
  core/
    extractor.py
    models.py
    reporter.py
    safety.py
  platforms/
    macos.py
    windows.py
    linux.py
```

The core package handles shared extraction, safety diagnosis, models, and reporting. The platform adapters handle OS-specific drive discovery.

## Mac App Interface Direction

The preferred product surface is a simple, functional, minimalist Mac app. The CLI remains the reusable engine and cross-platform foundation, but the main user experience should be a calm native macOS interface for selecting a drive, previewing extraction, copying files, and reading a short report.

See `docs/MAC_APP_UI.md`.

## Commands

```bash
drive-rescue scan
drive-rescue inspect <mount-path-or-device>
drive-rescue extract <source> --to <destination> --dry-run
drive-rescue extract <source> --to <destination>
```

## V1 User Flow

1. Connect external drive.
2. Run `drive-rescue scan`.
3. Run `drive-rescue inspect <drive>`.
4. Review safety notes.
5. Run extraction dry-run.
6. Run real extraction if the preview looks right.
7. Review generated report.

## Version Roadmap

The original V1/V2/V3 outline has been replaced by a release-based roadmap that separates consumer rescue, advanced deleted-file recovery, and forensic workflows.

- `0.x`: finish usability, reliability, signing, and Store-safe architecture.
- `1.x`: stable Safe Rescue and mounted-backup browsing.
- `2.x`: image-first acquisition, deleted-file recovery, and deep carving.
- `3.x`: separate forensic edition with evidence hashes, audit records, and validated workflows.

See `docs/PRODUCT_ROADMAP.md` for scope, platform availability, safety boundaries, and release gates.

For the Apple Mac App Store, Google Play, and broader cross-platform release path, see `docs/STORE_AND_PLATFORM_PLAN.md`.

## Diagnostic Knowledge Base

The Mac app should include a small local troubleshooting layer for common drive states, especially old WD Time Machine disks, Apple Partition Map layouts, unmounted HFS+ volumes, and HFS+ `Invalid extent entry` failures.

See `docs/TROUBLESHOOTING.md`.
