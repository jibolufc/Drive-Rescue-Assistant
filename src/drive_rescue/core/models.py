from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class DriveInfo:
    name: str
    mount_path: Path | None
    device_id: str | None = None
    filesystem: str | None = None
    size_bytes: int | None = None
    free_bytes: int | None = None
    is_external: bool | None = None
    is_removable: bool | None = None
    is_writable: bool | None = None
    is_time_machine: bool = False
    is_encrypted: bool | None = None
    warnings: tuple[str, ...] = field(default_factory=tuple)


@dataclass(frozen=True)
class ExtractionOptions:
    source: Path
    destination: Path
    dry_run: bool = False
    include_hidden: bool = True
    overwrite: bool = False
    scope: str = "all"
    compress: bool = False
    selected_paths: frozenset[Path] | None = None


@dataclass
class ExtractionReport:
    source: Path
    destination: Path
    dry_run: bool
    scope: str = "all"
    compressed: bool = False
    archive_path: Path | None = None
    files_seen: int = 0
    files_matched: int = 0
    files_filtered: int = 0
    files_copied: int = 0
    files_skipped: int = 0
    files_failed: int = 0
    bytes_planned: int = 0
    bytes_copied: int = 0
    failures: list[str] = field(default_factory=list)
