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

## Linux

Adapter: `src/drive_rescue/platforms/linux.py`

Uses:

- `lsblk -J`

Special handling planned:

- `findmnt` details.
- `blkid` filesystem details.
- Better permission and read-only diagnosis.

## Capability Model

The tool should report what is supported on the current OS instead of pretending every OS can perform every recovery task.
