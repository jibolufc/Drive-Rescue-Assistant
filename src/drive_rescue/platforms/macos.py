from __future__ import annotations

import plistlib
import subprocess
from pathlib import Path

from drive_rescue.core.models import DriveInfo
from drive_rescue.core.safety import looks_like_time_machine
from .base import inspect_path


def scan_drives() -> list[DriveInfo]:
    try:
        raw = subprocess.check_output(["diskutil", "list", "-plist"], stderr=subprocess.DEVNULL)
        listing = plistlib.loads(raw)
    except (OSError, subprocess.CalledProcessError, plistlib.InvalidFileException):
        return _scan_mount_fallback()

    drives: list[DriveInfo] = []
    for disk in listing.get("AllDisksAndPartitions", []):
        for partition in disk.get("Partitions", []):
            _append_diskutil_drive(drives, partition.get("DeviceIdentifier"), partition.get("VolumeName"))
            for apfs_volume in partition.get("APFSVolumes", []) or []:
                _append_diskutil_drive(drives, apfs_volume.get("DeviceIdentifier"), apfs_volume.get("VolumeName"))
    return drives


def inspect_drive(target: str) -> DriveInfo:
    path = Path(target)
    if path.exists():
        base = inspect_path(path)
        return base

    identifier = target.removeprefix("/dev/")
    info = _diskutil_info(identifier)
    mount_point = info.get("MountPoint")
    if mount_point:
        return inspect_path(Path(mount_point))
    if info:
        return _drive_from_diskutil_info(identifier, info, None)
    raise FileNotFoundError(f"Drive or mount path not found: {target}")


def _diskutil_info(identifier: str) -> dict:
    try:
        raw = subprocess.check_output(["diskutil", "info", "-plist", identifier], stderr=subprocess.DEVNULL)
        return plistlib.loads(raw)
    except (OSError, subprocess.CalledProcessError, plistlib.InvalidFileException):
        return {}


def _append_diskutil_drive(drives: list[DriveInfo], identifier: str | None, fallback_name: str | None) -> None:
    if not identifier:
        return
    info = _diskutil_info(identifier)
    if not info:
        return
    if not _is_user_visible_volume(info, fallback_name):
        return
    drives.append(_drive_from_diskutil_info(identifier, info, fallback_name))


def _drive_from_diskutil_info(identifier: str, info: dict, fallback_name: str | None) -> DriveInfo:
    mount_point = info.get("MountPoint")
    path = Path(mount_point) if mount_point else None
    external = info.get("Ejectable") or info.get("Removable") or info.get("BusProtocol") in {"USB", "Thunderbolt"}
    warnings: tuple[str, ...] = ()
    if path is None:
        warnings = ("Drive is visible but not mounted; extraction is unavailable until it is mounted.",)
    writable = bool(info.get("Writable")) if "Writable" in info else None
    if path is None:
        writable = None

    return DriveInfo(
        name=info.get("VolumeName") or fallback_name or identifier,
        mount_path=path,
        device_id=f"/dev/{identifier}",
        filesystem=info.get("FilesystemType") or info.get("TypeBundle"),
        size_bytes=info.get("TotalSize"),
        free_bytes=info.get("FreeSpace"),
        is_external=bool(external),
        is_removable=bool(info.get("Removable") or info.get("Ejectable")),
        is_writable=writable,
        is_time_machine=looks_like_time_machine(path),
        is_encrypted=info.get("Encryption") not in (None, "None"),
        warnings=warnings,
    )


def _is_user_visible_volume(info: dict, fallback_name: str | None) -> bool:
    if info.get("MountPoint"):
        return True
    if info.get("VolumeName") or fallback_name:
        return True
    if info.get("FilesystemType") or info.get("TypeBundle"):
        return True
    return False


def _scan_mount_fallback() -> list[DriveInfo]:
    try:
        output = subprocess.check_output(["mount"], text=True, stderr=subprocess.DEVNULL)
    except (OSError, subprocess.CalledProcessError):
        return []

    drives: list[DriveInfo] = []
    for line in output.splitlines():
        if " on " not in line or " (" not in line:
            continue
        device, rest = line.split(" on ", 1)
        mount_text, details = rest.rsplit(" (", 1)
        if not mount_text.startswith("/Volumes/"):
            continue
        detail_parts = {part.strip() for part in details.rstrip(")").split(",")}
        path = Path(mount_text)
        drives.append(
            DriveInfo(
                name=path.name,
                mount_path=path,
                device_id=device,
                filesystem=next((part for part in detail_parts if part in {"apfs", "hfs", "msdos", "exfat", "ntfs"}), None),
                is_external=True,
                is_removable=None,
                is_writable="read-only" not in detail_parts and "ro" not in detail_parts,
                is_time_machine=looks_like_time_machine(path),
                warnings=("diskutil unavailable; using mount fallback with limited details.",),
            )
        )
    return drives
