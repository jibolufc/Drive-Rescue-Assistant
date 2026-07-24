from __future__ import annotations

import argparse
import json
import signal
import sys
from dataclasses import asdict
from pathlib import Path

from .core.extractor import ExtractionCancelled, InsufficientSpaceError, extract_files
from .core.models import DriveInfo, ExtractionOptions, ExtractionProgress, ExtractionReport
from .core.reporter import write_report
from .core.safety import diagnose_drive
from .platforms.current import platform_adapter


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command == "scan":
        return command_scan(args)
    if args.command == "inspect":
        return command_inspect(args)
    if args.command == "extract":
        return command_extract(args)

    parser.print_help()
    return 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="drive-rescue", description="Scan and extract readable files from external drives.")
    sub = parser.add_subparsers(dest="command")

    scan = sub.add_parser("scan", help="List mounted drives detected on this OS.")
    scan.add_argument("--json", action="store_true", help="Output machine-readable JSON.")

    inspect = sub.add_parser("inspect", help="Inspect one drive or mount path.")
    inspect.add_argument("target", help="Mount path, drive letter, or device identifier.")
    inspect.add_argument("--json", action="store_true", help="Output machine-readable JSON.")

    extract = sub.add_parser("extract", help="Extract readable files from a source folder or mounted drive.")
    extract.add_argument("source", help="Source mount path or folder.")
    extract.add_argument("--to", required=True, help="Destination folder.")
    extract.add_argument("--dry-run", action="store_true", help="Preview without copying files.")
    extract.add_argument("--no-hidden", action="store_true", help="Skip hidden files and folders.")
    extract.add_argument("--overwrite", action="store_true", help="Overwrite existing destination files.")
    extract.add_argument(
        "--scope",
        choices=["all", "documents", "photos", "videos", "audio", "archives"],
        default="all",
        help="Choose which file group to extract.",
    )
    extract.add_argument("--compress", action="store_true", help="Write matched files into a ZIP archive.")
    extract.add_argument("--report-dir", help="Where JSON reports are written. Defaults to a folder in the destination.")
    extract.add_argument("--events-json", action="store_true", help=argparse.SUPPRESS)
    extract.add_argument("--selection-file", help=argparse.SUPPRESS)

    return parser


def command_scan(args: argparse.Namespace) -> int:
    adapter = platform_adapter()
    drives = adapter.scan_drives() if hasattr(adapter, "scan_drives") else []
    if args.json:
        print(json.dumps([_drive_to_json(drive) for drive in drives], indent=2))
        return 0

    if not drives:
        print("No mounted drives detected by this adapter.")
        return 0

    for index, drive in enumerate(drives, start=1):
        print(f"{index}. {drive.name}")
        print(f"   Mount: {drive.mount_path or 'not mounted'}")
        print(f"   Device: {drive.device_id or 'unknown'}")
        print(f"   Format: {drive.filesystem or 'unknown'}")
        print(f"   Writable: {_yes_no_unknown(drive.is_writable)}")
        print(f"   Time Machine: {'yes' if drive.is_time_machine else 'no'}")
    return 0


def command_inspect(args: argparse.Namespace) -> int:
    adapter = platform_adapter()
    drive = adapter.inspect_drive(args.target)
    if args.json:
        print(json.dumps(_drive_to_json(drive), indent=2))
        return 0

    print(f"Name: {drive.name}")
    print(f"Mount: {drive.mount_path or 'not mounted'}")
    print(f"Device: {drive.device_id or 'unknown'}")
    print(f"Format: {drive.filesystem or 'unknown'}")
    print(f"Size: {_format_bytes(drive.size_bytes)}")
    print(f"Free: {_format_bytes(drive.free_bytes)}")
    print(f"Writable: {_yes_no_unknown(drive.is_writable)}")
    print(f"Time Machine: {'yes' if drive.is_time_machine else 'no'}")
    print("Safety notes:")
    for note in diagnose_drive(drive):
        print(f"- {note}")
    return 0


def command_extract(args: argparse.Namespace) -> int:
    cancel_requested = False

    def request_cancel(_signum: int, _frame: object) -> None:
        nonlocal cancel_requested
        cancel_requested = True

    previous_sigterm = signal.signal(signal.SIGTERM, request_cancel)
    progress_callback = _json_progress_callback if args.events_json else None
    report_dir = Path(args.report_dir) if args.report_dir else Path(args.to) / "Drive Rescue Reports"

    try:
        selected_paths = None
        if args.selection_file:
            selection_payload = json.loads(Path(args.selection_file).read_text(encoding="utf-8"))
            if not isinstance(selection_payload, list) or not all(isinstance(item, str) for item in selection_payload):
                raise ValueError("Selection file must contain a JSON list of relative paths.")
            selected_paths = frozenset(Path(item) for item in selection_payload)

        options = ExtractionOptions(
            source=Path(args.source),
            destination=Path(args.to),
            dry_run=args.dry_run,
            include_hidden=not args.no_hidden,
            overwrite=args.overwrite,
            scope=args.scope,
            compress=args.compress,
            progress_callback=progress_callback,
            cancel_check=lambda: cancel_requested,
            selected_paths=selected_paths,
        )
        report = extract_files(options)
    except ExtractionCancelled as exc:
        report = exc.report
        report_path = write_report(report, report_dir)
        _print_report(report, report_path)
        _emit_json_summary(report, report_path, args.events_json)
        return 130
    except InsufficientSpaceError as exc:
        if args.events_json:
            _emit_json_event(
                {
                    "event": "error",
                    "code": "insufficient_space",
                    "message": str(exc),
                    "required_bytes": exc.required_bytes,
                    "available_bytes": exc.available_bytes,
                }
            )
        print(str(exc), file=sys.stderr)
        return 3
    except (OSError, ValueError) as exc:
        code = "permission_denied" if isinstance(exc, PermissionError) else "source_unavailable"
        if args.events_json:
            _emit_json_event({"event": "error", "code": code, "message": str(exc)})
        print(str(exc), file=sys.stderr)
        return 4
    finally:
        signal.signal(signal.SIGTERM, previous_sigterm)

    report_path = write_report(report, report_dir)
    _print_report(report, report_path)
    _emit_json_summary(report, report_path, args.events_json)
    return 0 if report.files_failed == 0 else 2


def _print_report(report: ExtractionReport, report_path: Path) -> None:
    verb = "planned" if report.dry_run else "copied"
    print(f"Files seen: {report.files_seen}")
    print(f"Scope: {report.scope}")
    print(f"Compressed: {'yes' if report.compressed else 'no'}")
    print(f"Files matched: {report.files_matched}")
    print(f"Files filtered out: {report.files_filtered}")
    print(f"Files {verb}: {report.files_matched - report.files_skipped - report.files_failed if report.dry_run else report.files_copied}")
    print(f"Files skipped: {report.files_skipped}")
    print(f"Files failed: {report.files_failed}")
    print(f"Bytes planned: {_format_bytes(report.bytes_planned)}")
    if not report.dry_run:
        print(f"Bytes copied: {_format_bytes(report.bytes_copied)}")
    if report.archive_path:
        print(f"Archive: {report.archive_path}")
    print(f"Report: {report_path}")


def _json_progress_callback(progress: ExtractionProgress) -> None:
    _emit_json_event(
        {
            "event": "progress",
            "phase": progress.phase,
            "current_path": str(progress.current_path) if progress.current_path else None,
            "files_completed": progress.files_completed,
            "files_total": progress.files_total,
            "bytes_completed": progress.bytes_completed,
            "bytes_total": progress.bytes_total,
            "current_size": progress.current_size,
        }
    )


def _emit_json_summary(report: ExtractionReport, report_path: Path, enabled: bool) -> None:
    if not enabled:
        return
    _emit_json_event(
        {
            "event": "summary",
            "status": report.status,
            "files_seen": report.files_seen,
            "files_matched": report.files_matched,
            "files_filtered": report.files_filtered,
            "files_copied": report.files_copied,
            "files_skipped": report.files_skipped,
            "files_failed": report.files_failed,
            "bytes_planned": report.bytes_planned,
            "bytes_copied": report.bytes_copied,
            "archive_path": str(report.archive_path) if report.archive_path else None,
            "report_path": str(report_path),
        }
    )


def _emit_json_event(payload: dict) -> None:
    print(f"DRA_EVENT {json.dumps(payload, separators=(',', ':'))}", flush=True)


def _drive_to_json(drive: DriveInfo) -> dict:
    payload = asdict(drive)
    payload["mount_path"] = str(drive.mount_path) if drive.mount_path else None
    return payload


def _yes_no_unknown(value: bool | None) -> str:
    if value is None:
        return "unknown"
    return "yes" if value else "no"


def _format_bytes(value: int | None) -> str:
    if value is None:
        return "unknown"
    units = ["B", "KB", "MB", "GB", "TB", "PB"]
    amount = float(value)
    for unit in units:
        if amount < 1024 or unit == units[-1]:
            return f"{amount:.1f} {unit}" if unit != "B" else f"{int(amount)} B"
        amount /= 1024
    return f"{value} B"
