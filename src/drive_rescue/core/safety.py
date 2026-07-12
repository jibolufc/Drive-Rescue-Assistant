from __future__ import annotations

from pathlib import Path

from .models import DriveInfo


TIME_MACHINE_MARKERS = (
    "Backups.backupdb",
    ".backupbundle",
    "com.apple.TimeMachine.localsnapshots",
)


def looks_like_time_machine(path: Path | None) -> bool:
    if path is None:
        return False
    try:
        if (path / "Backups.backupdb").exists():
            return True
        if any(child.name.endswith(".backupbundle") for child in path.iterdir()):
            return True
    except OSError:
        return False
    return False


def diagnose_drive(drive: DriveInfo) -> list[str]:
    messages: list[str] = []

    if drive.mount_path is None:
        messages.append("Drive is visible but not mounted; extraction is unavailable until it is mounted.")
    if drive.is_writable is False:
        messages.append("Drive appears read-only; extraction may work, but deletion or modification should be avoided.")
    if drive.filesystem and drive.filesystem.lower() == "ntfs":
        messages.append("NTFS is commonly read-only on macOS without extra drivers.")
    if drive.filesystem and drive.filesystem.lower() in {"hfs", "hfs+"} and drive.mount_path is None:
        messages.append("Unmounted HFS+ volume detected; if First Aid reports invalid extent entries, copy readable data before repair or erase.")
    if drive.is_time_machine:
        messages.append("Time Machine-style backup detected; copy readable files out instead of modifying the backup.")
    if drive.is_encrypted:
        messages.append("Drive appears encrypted; locked content may need to be unlocked outside this tool.")
    messages.extend(drive.warnings)

    if not messages:
        messages.append("No obvious safety warnings detected.")

    return list(dict.fromkeys(messages))
