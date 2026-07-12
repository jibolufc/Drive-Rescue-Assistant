from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path

from .core.extractor import extract_files
from .core.models import DriveInfo, ExtractionOptions
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
    extract.add_argument("--report-dir", default="drive-rescue-reports", help="Where JSON reports are written.")

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
    options = ExtractionOptions(
        source=Path(args.source),
        destination=Path(args.to),
        dry_run=args.dry_run,
        include_hidden=not args.no_hidden,
        overwrite=args.overwrite,
        scope=args.scope,
        compress=args.compress,
    )
    report = extract_files(options)
    report_path = write_report(report, Path(args.report_dir))

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
    return 0 if report.files_failed == 0 else 2


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
