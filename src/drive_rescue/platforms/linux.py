from __future__ import annotations

import json
import subprocess
from pathlib import Path

from drive_rescue.core.models import DriveInfo
from drive_rescue.core.safety import looks_like_time_machine
from .base import inspect_path


def scan_drives() -> list[DriveInfo]:
    try:
        raw = subprocess.check_output(["lsblk", "-J", "-o", "NAME,PATH,MOUNTPOINT,FSTYPE,SIZE,RM,RO,TYPE"], text=True)
        payload = json.loads(raw)
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError):
        return []

    drives: list[DriveInfo] = []
    for device in payload.get("blockdevices", []):
        for item in _flatten(device):
            mountpoint = item.get("mountpoint")
            if not mountpoint:
                continue
            path = Path(mountpoint)
            drives.append(
                DriveInfo(
                    name=item.get("name") or str(path),
                    mount_path=path,
                    device_id=item.get("path"),
                    filesystem=item.get("fstype"),
                    is_external=bool(item.get("rm")),
                    is_removable=bool(item.get("rm")),
                    is_writable=not bool(item.get("ro")),
                    is_time_machine=looks_like_time_machine(path),
                )
            )
    return drives


def inspect_drive(target: str) -> DriveInfo:
    path = Path(target)
    if path.exists():
        return inspect_path(path)
    raise FileNotFoundError(f"Drive or mount path not found: {target}")


def _flatten(device: dict):
    yield device
    for child in device.get("children", []) or []:
        yield from _flatten(child)

