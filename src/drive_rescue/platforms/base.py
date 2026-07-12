from __future__ import annotations

from pathlib import Path
from shutil import disk_usage

from drive_rescue.core.models import DriveInfo
from drive_rescue.core.safety import looks_like_time_machine


def inspect_path(path: Path) -> DriveInfo:
    resolved = path.expanduser().resolve()
    usage = disk_usage(resolved)
    return DriveInfo(
        name=resolved.name or str(resolved),
        mount_path=resolved,
        size_bytes=usage.total,
        free_bytes=usage.free,
        is_external=None,
        is_removable=None,
        is_writable=_is_writable(resolved),
        is_time_machine=looks_like_time_machine(resolved),
    )


def _is_writable(path: Path) -> bool:
    try:
        return path.exists() and path.is_dir() and __import__("os").access(path, __import__("os").W_OK)
    except OSError:
        return False

