from __future__ import annotations

import shutil
import zipfile
from pathlib import Path

from .models import ExtractionOptions, ExtractionReport

SCOPE_EXTENSIONS = {
    "documents": {
        ".csv",
        ".doc",
        ".docx",
        ".key",
        ".md",
        ".numbers",
        ".odp",
        ".ods",
        ".odt",
        ".pages",
        ".pdf",
        ".ppt",
        ".pptx",
        ".rtf",
        ".txt",
        ".xls",
        ".xlsx",
    },
    "photos": {".arw", ".bmp", ".cr2", ".dng", ".gif", ".heic", ".jpeg", ".jpg", ".nef", ".png", ".raw", ".tif", ".tiff", ".webp"},
    "videos": {".avi", ".m4v", ".mkv", ".mov", ".mp4", ".mpeg", ".mpg", ".webm", ".wmv"},
    "audio": {".aac", ".aiff", ".flac", ".m4a", ".mp3", ".ogg", ".wav", ".wma"},
    "archives": {".7z", ".bz2", ".dmg", ".gz", ".iso", ".rar", ".tar", ".tgz", ".xz", ".zip"},
}


def extract_files(options: ExtractionOptions) -> ExtractionReport:
    source = options.source.expanduser().resolve()
    destination = options.destination.expanduser().resolve()
    report = ExtractionReport(
        source=source,
        destination=destination,
        dry_run=options.dry_run,
        scope=options.scope,
        compressed=options.compress,
    )

    if not source.exists():
        raise FileNotFoundError(f"Source does not exist: {source}")
    if not source.is_dir():
        raise NotADirectoryError(f"Source must be a directory: {source}")

    if options.scope != "all" and options.scope not in SCOPE_EXTENSIONS:
        raise ValueError(f"Unknown extraction scope: {options.scope}")

    if not options.dry_run:
        destination.mkdir(parents=True, exist_ok=True)

    archive: zipfile.ZipFile | None = None
    if options.compress:
        report.archive_path = _archive_path(source, destination)
        if not options.dry_run and report.archive_path.exists() and not options.overwrite:
            raise FileExistsError(f"Archive already exists: {report.archive_path}")
        if not options.dry_run:
            archive = zipfile.ZipFile(report.archive_path, mode="w", compression=zipfile.ZIP_DEFLATED)

    try:
        _extract_walk(source, destination, options, report, archive)
    finally:
        if archive is not None:
            archive.close()

    return report


def _extract_walk(
    source: Path,
    destination: Path,
    options: ExtractionOptions,
    report: ExtractionReport,
    archive: zipfile.ZipFile | None,
) -> None:
    for root, dirs, files in os_walk_safe(source, report):
        root_path = Path(root)
        if not options.include_hidden:
            dirs[:] = [name for name in dirs if not name.startswith(".")]
            files = [name for name in files if not name.startswith(".")]

        for file_name in files:
            src_file = root_path / file_name
            report.files_seen += 1

            try:
                rel_path = src_file.relative_to(source)
                if not _matches_scope(src_file, options.scope):
                    report.files_filtered += 1
                    continue
                if options.selected_paths is not None and rel_path not in options.selected_paths:
                    report.files_filtered += 1
                    continue

                report.files_matched += 1
                size = src_file.stat().st_size
                report.bytes_planned += size

                if options.dry_run:
                    continue

                if archive is not None:
                    archive.write(src_file, rel_path.as_posix())
                else:
                    dest_file = destination / rel_path
                    if dest_file.exists() and not options.overwrite:
                        report.files_skipped += 1
                        continue

                    dest_file.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src_file, dest_file)

                report.files_copied += 1
                report.bytes_copied += size
            except OSError as exc:
                report.files_failed += 1
                report.failures.append(f"{src_file}: {exc}")


def os_walk_safe(source: Path, report: ExtractionReport):
    import os

    def on_error(exc: OSError) -> None:
        report.files_failed += 1
        report.failures.append(str(exc))

    yield from os.walk(source, onerror=on_error)


def _matches_scope(path: Path, scope: str) -> bool:
    if scope == "all":
        return True
    return path.suffix.lower() in SCOPE_EXTENSIONS[scope]


def preview_paths(source: Path, scope: str = "all", include_hidden: bool = True) -> list[tuple[Path, int]]:
    """Return readable matching files as relative paths and byte sizes."""
    source = source.expanduser().resolve()
    if not source.exists():
        raise FileNotFoundError(f"Source does not exist: {source}")
    if not source.is_dir():
        raise NotADirectoryError(f"Source must be a directory: {source}")
    if scope != "all" and scope not in SCOPE_EXTENSIONS:
        raise ValueError(f"Unknown extraction scope: {scope}")

    matches: list[tuple[Path, int]] = []
    report = ExtractionReport(source=source, destination=source, dry_run=True, scope=scope)
    for root, dirs, files in os_walk_safe(source, report):
        root_path = Path(root)
        if not include_hidden:
            dirs[:] = [name for name in dirs if not name.startswith(".")]
            files = [name for name in files if not name.startswith(".")]
        for file_name in files:
            path = root_path / file_name
            if not _matches_scope(path, scope):
                continue
            try:
                matches.append((path.relative_to(source), path.stat().st_size))
            except OSError:
                continue
    return matches


def _archive_path(source: Path, destination: Path) -> Path:
    safe_name = "".join(char if char.isalnum() or char in ("-", "_") else "-" for char in source.name).strip("-")
    return destination / f"{safe_name or 'drive-rescue'}-recovered.zip"
