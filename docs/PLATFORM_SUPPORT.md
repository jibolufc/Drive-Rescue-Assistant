# Platform Support

## macOS

Adapter: `src/drive_rescue/platforms/macos.py`

Uses:

- `diskutil list -plist`
- `diskutil info -plist`

Special handling:

- Time Machine markers.
- APFS/HFS+/NTFS/exFAT metadata where available.
- Read-only and writable hints from `diskutil`.

## Windows

Adapter: `src/drive_rescue/platforms/windows.py`

Uses:

- PowerShell `Get-Volume`

Special handling planned:

- BitLocker detection.
- Drive letter workflows.
- Robocopy-based copy engine if needed.

Desktop test package:

- Standalone `DriveRescueAssistant.exe` built on GitHub Actions.
- Does not require the tester to install Python.
- Includes drive scanning, folder selection, individual-file preview selection, filters, and ZIP extraction.

## Linux

Adapter: `src/drive_rescue/platforms/linux.py`

Uses:

- `lsblk -J`

Special handling planned:

- `findmnt` details.
- `blkid` filesystem details.
- Better permission and read-only diagnosis.

Desktop test package:

- Standalone `DriveRescueAssistant` binary built on Ubuntu 22.04.
- Does not require the tester to install Python.
- Uses the desktop file picker and the same preview-first extraction flow as Windows.
- Targets mainstream x86-64 distributions with glibc compatible with Ubuntu 22.04.

## Capability Model

The tool should report what is supported on the current OS instead of pretending every OS can perform every recovery task.
