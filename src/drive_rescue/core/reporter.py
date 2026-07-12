from __future__ import annotations

import json
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path

from .models import ExtractionReport


def write_report(report: ExtractionReport, output_dir: Path) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    path = output_dir / f"drive-rescue-report-{stamp}.json"
    payload = asdict(report)
    payload["source"] = str(report.source)
    payload["destination"] = str(report.destination)
    payload["archive_path"] = str(report.archive_path) if report.archive_path else None
    payload["created_at_utc"] = stamp
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return path
