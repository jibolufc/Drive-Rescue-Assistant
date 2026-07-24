from __future__ import annotations

import os
import shutil
import zipfile
from pathlib import Path

from .models import ExtractionOptions, ExtractionProgress, ExtractionReport

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


class ExtractionCancelled(Exception):
    def __init__(self, report: ExtractionReport):
        super().__init__("Extraction cancelled.")
        self.report = report


class InsufficientSpaceError(OSError):
    def __init__(self, required_bytes: int, available_bytes: int):
        self.required_bytes = required_bytes
        self.available_bytes = available_bytes
        super().__init__(
            f"The destination needs {required_bytes} bytes, but only {available_bytes} bytes are available."
        )


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
    if destination == source or source in destination.parents:
        raise ValueError("Destination must be outside the source folder.")

    if options.scope != "all" and options.scope not in SCOPE_EXTENSIONS:
        raise ValueError(f"Unknown extraction scope: {options.scope}")

    plan = _build_plan(source, options, report)
    _emit_progress(options, report, "planned", None, 0, 0)

    if options.dry_run:
        bytes_previewed = 0
        for index, (_source_path, relative_path, size) in enumerate(plan, start=1):
            bytes_previewed += size
            _emit_progress(
                options,
                report,
                "preview_item",
                relative_path,
                index,
                bytes_previewed,
                current_size=size,
            )
        report.status = "preview"
        return report

    if options.enforce_capacity:
        available = available_capacity(destination)
        required = required_destination_bytes(report.bytes_planned, options.compress)
        if available is not None and required > available:
            report.status = "insufficient_space"
            raise InsufficientSpaceError(required, available)

    destination.mkdir(parents=True, exist_ok=True)
    archive: zipfile.ZipFile | None = None
    temporary_archive: Path | None = None
    final_archive: Path | None = None
    try:
        if options.compress:
            final_archive = _archive_path(source, destination)
            report.archive_path = final_archive
            if final_archive.exists() and not options.overwrite:
                raise FileExistsError(f"Archive already exists: {final_archive}")
            temporary_archive = final_archive.with_suffix(final_archive.suffix + ".partial")
            temporary_archive.unlink(missing_ok=True)
            archive = zipfile.ZipFile(temporary_archive, mode="w", compression=zipfile.ZIP_DEFLATED)

        _copy_plan(plan, destination, options, report, archive)
        if archive is not None:
            archive.close()
            archive = None
        if temporary_archive is not None and final_archive is not None:
            temporary_archive.replace(final_archive)
        report.status = "complete_with_errors" if report.files_failed else "complete"
        _emit_progress(
            options,
            report,
            "complete",
            None,
            report.files_copied + report.files_skipped + report.files_failed,
            report.bytes_copied,
        )
    except ExtractionCancelled:
        report.status = "cancelled"
        raise
    finally:
        if archive is not None:
            archive.close()
        if report.status != "complete" and report.status != "complete_with_errors" and temporary_archive is not None:
            temporary_archive.unlink(missing_ok=True)

    return report


def _build_plan(
    source: Path,
    options: ExtractionOptions,
    report: ExtractionReport,
) -> list[tuple[Path, Path, int]]:
    plan: list[tuple[Path, Path, int]] = []
    for root, dirs, files in os_walk_safe(source, report):
        _raise_if_cancelled(options, report)
        root_path = Path(root)
        if not options.include_hidden:
            dirs[:] = [name for name in dirs if not name.startswith(".")]
            files = [name for name in files if not name.startswith(".")]

        for file_name in files:
            _raise_if_cancelled(options, report)
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
                size = src_file.stat().st_size
                report.files_matched += 1
                report.bytes_planned += size
                plan.append((src_file, rel_path, size))
            except OSError as exc:
                report.files_failed += 1
                report.failures.append(f"{src_file}: {exc}")
    return plan


def _copy_plan(
    plan: list[tuple[Path, Path, int]],
    destination: Path,
    options: ExtractionOptions,
    report: ExtractionReport,
    archive: zipfile.ZipFile | None,
) -> None:
    files_completed = 0
    for src_file, rel_path, size in plan:
        _raise_if_cancelled(options, report)
        _emit_progress(options, report, "copying", rel_path, files_completed, report.bytes_copied)
        _raise_if_cancelled(options, report)

        try:
            if not src_file.exists():
                raise OSError("The source file is no longer available.")
            if archive is not None:
                archive.write(src_file, rel_path.as_posix())
            else:
                dest_file = destination / rel_path
                if dest_file.exists() and not options.overwrite:
                    report.files_skipped += 1
                    files_completed += 1
                    _emit_progress(options, report, "copying", rel_path, files_completed, report.bytes_copied)
                    continue

                dest_file.parent.mkdir(parents=True, exist_ok=True)
                partial_file = dest_file.with_name(dest_file.name + ".drive-rescue-partial")
                partial_file.unlink(missing_ok=True)
                try:
                    shutil.copy2(src_file, partial_file)
                    partial_file.replace(dest_file)
                finally:
                    partial_file.unlink(missing_ok=True)

            report.files_copied += 1
            report.bytes_copied += size
        except OSError as exc:
            report.files_failed += 1
            report.failures.append(f"{src_file}: {exc}")
        files_completed += 1
        _emit_progress(options, report, "copying", rel_path, files_completed, report.bytes_copied)


def _raise_if_cancelled(options: ExtractionOptions, report: ExtractionReport) -> None:
    if options.cancel_check is not None and options.cancel_check():
        report.status = "cancelled"
        raise ExtractionCancelled(report)


def _emit_progress(
    options: ExtractionOptions,
    report: ExtractionReport,
    phase: str,
    current_path: Path | None,
    files_completed: int,
    bytes_completed: int,
    current_size: int = 0,
) -> None:
    if options.progress_callback is None:
        return
    options.progress_callback(
        ExtractionProgress(
            phase=phase,
            current_path=current_path,
            files_completed=files_completed,
            files_total=report.files_matched,
            bytes_completed=bytes_completed,
            bytes_total=report.bytes_planned,
            current_size=current_size,
        )
    )


def os_walk_safe(source: Path, report: ExtractionReport):
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


def required_destination_bytes(bytes_planned: int, compressed: bool) -> int:
    if not compressed:
        return bytes_planned
    overhead = max(1024 * 1024, bytes_planned // 100)
    return bytes_planned + overhead


def available_capacity(destination: Path) -> int | None:
    candidate = destination.expanduser()
    while not candidate.exists() and candidate != candidate.parent:
        candidate = candidate.parent
    try:
        return shutil.disk_usage(candidate).free
    except OSError:
        return None
