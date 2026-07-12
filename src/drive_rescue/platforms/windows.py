from __future__ import annotations

import json
import subprocess
from pathlib import Path

from drive_rescue.core.models import DriveInfo
from drive_rescue.core.safety import looks_like_time_machine
from .base import inspect_path


def scan_drives() -> list[DriveInfo]:
    command = [
        "powershell",
        "-NoProfile",
        "-Command",
        "Get-Volume | Select-Object DriveLetter,FileSystemLabel,FileSystem,Size,SizeRemaining,DriveType | ConvertTo-Json",
    ]
    try:
        raw = subprocess.check_output(command, text=True, stderr=subprocess.DEVNULL)
        payload = json.loads(raw)
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError):
        return []

    if isinstance(payload, dict):
        payload = [payload]

    drives: list[DriveInfo] = []
    for item in payload:
        letter = item.get("DriveLetter")
        if not letter:
            continue
        path = Path(f"{letter}:\\")
        drive_type = item.get("DriveType")
        drives.append(
            DriveInfo(
                name=item.get("FileSystemLabel") or f"{letter}:",
                mount_path=path,
                device_id=f"{letter}:",
                filesystem=item.get("FileSystem"),
                size_bytes=item.get("Size"),
                free_bytes=item.get("SizeRemaining"),
                is_external=drive_type in ("Removable", "Fixed"),
                is_removable=drive_type == "Removable",
                is_writable=None,
                is_time_machine=looks_like_time_machine(path),
            )
        )
    return drives


def inspect_drive(target: str) -> DriveInfo:
    path = Path(target)
    if path.exists():
        return inspect_path(path)
    raise FileNotFoundError(f"Drive or mount path not found: {target}")

