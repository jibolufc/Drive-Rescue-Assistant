# Safety Policy

Drive Rescue Assistant is designed around data preservation.

## Hard Rules

- Never delete before extraction.
- Never erase, format, repartition, or force-mount a drive.
- Never modify Time Machine backups in V1.
- Never claim full recovery is guaranteed.
- Always keep generated reports local.
- Plan and check destination capacity before creating extraction output.
- Write ZIP output under a partial name and expose it only after completion.
- Remove temporary partial files after cancellation or copy failure.
- Continue around individual unreadable files while recording them in the
  local report.
- Treat filenames and paths as private user data.

## Deletion Policy

Deletion is excluded from V1. A future delete feature must require:

- Writable drive detection.
- Dry-run preview.
- Clear size and file-count summary.
- Explicit confirmation.
- Report generation.
- Advanced mode.

## Damaged Drives

If a drive is mounted read-only because of suspected corruption, the recommended action is to copy readable files to another storage location before attempting repair.
