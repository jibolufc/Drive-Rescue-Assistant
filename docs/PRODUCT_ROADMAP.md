# Drive Rescue Assistant Product Roadmap

Last reviewed: 24 July 2026

## Product Lines

Drive Rescue Assistant should grow through three clear capability levels instead of exposing every technical feature to every user.

| Product line | Audience | Promise | Distribution |
| --- | --- | --- | --- |
| DRA Safe Rescue | Everyday users | Explain a troublesome drive and safely copy files that are still readable | Mac App Store, Microsoft Store, and signed direct desktop builds |
| DRA Advanced Recovery | Confident home users and technicians | Create a read-only image and recover recently deleted files where data survives | Signed direct macOS, Windows, and Linux builds; limited image-file analysis may be possible in Store builds |
| DRA Forensic | Investigators and specialist technicians | Acquire and analyse evidence with hashes, audit records, and repeatable workflows | Separate signed direct desktop edition only |

The simple workflow remains the default even after advanced editions exist.

## Current Position: v0.4.0 Release Candidate

Status: usability beta implementation complete; release validation in progress.

Implemented:

- macOS SwiftUI interface.
- Windows and Linux desktop interface.
- Connected-drive discovery and basic diagnosis.
- Source and destination selection.
- Selectable extraction preview.
- Documents, photos, videos, audio, archives, or all-files filters.
- Optional ZIP extraction.
- Read-only source policy for normal extraction.
- Microsoft Store MSIX build pipeline.
- GitHub friend-test releases.
- Approved drive-and-open-chain identity and platform icon assets.
- Determinate extraction progress, current file, elapsed time, and ETA.
- Destination-capacity preflight and low-space blocking.
- Safe cancellation with incomplete ZIP cleanup.
- Partial recovery when individual files are unreadable.
- Clear completion summaries and exportable local JSON reports.
- Self-contained universal Mac extraction engine.

Not yet public-release ready:

- Store-safe macOS build configuration.
- Accepted and stapled notarization for the current Mac release candidate.
- Production Windows direct-download signing.
- Store screenshots, listing copy, support site, and final privacy URLs.
- Clean-machine confirmation on macOS, Windows, and Linux.

## v0.4.0: Identity and Usability Beta

Goal: make the existing rescue workflow feel complete and understandable.

Implementation status: complete. Cross-platform package and non-technical
tester validation remain part of the exit criteria below.

- Adopt the approved drive-and-open-chain logo.
- Generate Apple, Microsoft, Windows, Linux, and GitHub icon assets.
- Add extraction progress, current file, elapsed time, and estimated remaining work.
- Add safe cancellation without leaving partial ZIP files presented as complete.
- Check destination capacity before extraction.
- Explain inaccessible files without stopping the whole job.
- Improve empty, disconnected, permission-denied, and low-space states.
- Produce a clear completion summary and exportable local report.
- Add accessibility labels, keyboard navigation, and high-contrast checks.

Exit criteria:

- Successful extraction tests on macOS, Windows, and Linux.
- No source-drive write operations during Safe Rescue.
- Non-technical testers can complete an extraction without instructions.

## v0.5.0: Reliable Rescue Beta

Goal: make long extractions dependable.

- Resume interrupted folder extraction.
- Record a recovery manifest without storing private file contents.
- Add optional SHA-256 verification of copied files.
- Add conflict choices: skip, rename, or replace.
- Detect source disconnection and resume after reconnection where safe.
- Add duplicate and already-recovered indicators.
- Add destination filesystem warnings for file-size and filename limitations.
- Expand Time Machine and legacy HFS+ explanations.
- Build a synthetic-drive and damaged-file test corpus.

Exit criteria:

- Interrupted sessions resume without silently duplicating or corrupting output.
- Verification results are included in the final report.
- Real-drive testing covers APFS, HFS+, exFAT, FAT32, and NTFS-readable scenarios.

## v0.6.0: Store Architecture

Goal: separate Store-safe capabilities from direct desktop capabilities.

- Add a dedicated Store build configuration using App Sandbox.
- Use system source and destination pickers.
- Use security-scoped resource access on macOS.
- Replace unrestricted Store drive scanning with user-approved source selection.
- Keep `diskutil` mounting and other low-level actions in the direct edition.
- Finish Microsoft Store package identity and validation.
- Add privacy, support, licence, and third-party notices.
- Ensure the app reports unavailable capabilities instead of showing broken controls.

Exit criteria:

- Mac Store build passes sandbox testing on a clean user account.
- Microsoft Store package passes Partner Center package validation.
- Store builds do not request administrator or root access.

## v0.9.0: Public Release Candidate

Goal: complete release engineering and external testing.

- Sign and notarize the direct Mac build.
- Complete Apple Developer signing for the Mac App Store build.
- Sign direct Windows binaries or limit trusted Windows distribution to Microsoft Store.
- Run clean-machine tests on supported OS versions.
- Complete App Store and Microsoft Store screenshots and metadata.
- Add an in-app support link, privacy link, version information, and diagnostic export.
- Complete tester feedback and crash-resolution passes.

Exit criteria:

- No release-blocking test failures.
- Store metadata matches the app's actual capabilities.
- Every package has a documented installation and update path.

## v1.0.0: Safe Rescue

Goal: first stable consumer release.

Core promise:

> Understand the drive, preview what is readable, and copy selected files to safety without modifying the source.

Included:

- Plain-language drive status.
- User-selected source and destination.
- Preview and individual file selection.
- File-group filtering.
- Folder extraction or ZIP output.
- Progress, cancellation, resume, verification, and reports.
- Store-safe Mac edition.
- Microsoft Store Windows edition.
- Signed direct desktop editions where signing is available.

Explicitly excluded:

- Deleted-file reconstruction.
- Raw-sector carving.
- Filesystem repair.
- Encryption bypass.
- Guaranteed recovery claims.

## v1.1.0: Backup Explorer

Goal: make old backup media easier to understand and browse.

- Browse mounted Time Machine backup dates.
- Select files across backup snapshots where macOS permits access.
- Explain APFS and legacy HFS+ Time Machine layouts.
- Compare backup copies by date and size.
- Export from a selected backup to a normal destination.
- Preserve the no-source-write policy.

This remains a readable-file workflow, not deleted-file recovery.

## v2.0.0: Advanced Recovery - Image First

Goal: protect the original device before deeper analysis.

- Add a clearly separated Advanced Recovery workspace.
- Accept a physical source device or an existing raw disk image.
- Create a read-only, resumable image with a map of readable and unreadable areas.
- Prefer proven imaging engines such as GNU ddrescue where supported.
- Record source identity, image size, start/end times, errors, and SHA-256 hashes.
- Require a destination with enough free space.
- Never use the source device as the recovery destination.
- Pause or stop safely when a device repeatedly disconnects.
- Show an immediate professional-recovery warning for clicking or mechanically unstable drives.

Distribution:

- Physical-device imaging: signed direct desktop builds only.
- Existing image-file inspection: potentially available in sandboxed Store builds after review testing.

## v2.1.0: Deleted File Recovery

Goal: recover recently deleted files using surviving filesystem metadata.

- Integrate a proven filesystem-analysis engine such as The Sleuth Kit after licence review.
- Scan disk images before allowing scans of live physical devices.
- Support filesystems incrementally, beginning with the best-tested formats.
- List allocated, deleted, and orphaned entries distinctly.
- Show original name/path only when surviving metadata supports it.
- Add recoverability indicators without promising success.
- Preview supported recoverable files.
- Recover selected files to a different destination.
- Hash recovered output and record failures.

Important limits shown in the interface:

- Overwritten content cannot be reconstructed.
- SSD TRIM may make deleted data unavailable.
- Encrypted content requires the correct password or recovery key.
- Recovered files may be incomplete or corrupt.

## v2.2.0: Deep File Carving

Goal: find file content when names, folders, and filesystem metadata are gone.

- Add signature-based carving from images and unallocated areas.
- Group results by file type and confidence.
- Explain that carved files may lose original names, paths, and dates.
- Detect and flag likely truncated or fragmented output.
- Add pause, resume, and scan-range controls.
- Keep carving results separate from metadata-based recovery results.
- Complete a licensing decision before selecting or distributing a carving engine.

This version must not ship until performance, false-positive rates, third-party licensing, and output validation are acceptable.

## v3.0.0: DRA Forensic Edition

Goal: provide repeatable evidence acquisition and analysis for trained users.

- Separate case-based interface from consumer Safe Rescue.
- Record case number, examiner, source identifiers, notes, and timestamps.
- Acquire raw and approved forensic image formats.
- Verify acquisition with cryptographic hashes.
- Preserve immutable operation and error logs.
- Read image files without modifying evidence.
- Record tool and engine versions in every report.
- Export acquisition and recovery reports suitable for independent review.
- Add timezone handling and a clear chain-of-custody event log.
- Support hardware write-blocker documentation where used.
- Add reproducible CLI workflows for technical users.

The word `forensic` must not imply legal certification. Before release, this edition needs documented validation against known datasets, repeatability testing, licence review, and specialist review.

## Platform Capability Matrix

| Capability | Mac App Store | Microsoft Store | Signed direct macOS | Signed direct Windows | Linux direct |
| --- | --- | --- | --- | --- | --- |
| Safe Rescue | Yes | Yes | Yes | Yes | Yes |
| Backup Explorer | Where sandbox access permits | Not applicable | Yes | Not applicable | Limited |
| Analyse a selected disk image | Possible after validation | Possible | Yes | Yes | Yes |
| Image a physical device | No | Direct/store policy review required | Yes, with explicit permission | Yes, with explicit permission | Yes, with explicit permission |
| Deleted-file recovery | Image-only candidate | Image-only candidate | Yes | Yes | Yes |
| Deep carving | Image-only candidate | Image-only candidate | Yes | Yes | Yes |
| Forensic acquisition | No | No | Yes | Yes | Yes |

## Permanent Safety Boundaries

DRA will not:

- Recover data that has been overwritten.
- Claim to defeat SSD TRIM.
- Bypass encryption, passwords, operating-system permissions, or access controls.
- Write recovered files back to the source evidence.
- Automatically repair, erase, format, or repartition a source device.
- Present software recovery as suitable for a mechanically failing drive in every case.
- Claim forensic certification without formal evidence and validation.

## Technical and Legal Gates

Before the Advanced Recovery or Forensic editions ship:

1. Select engines only after compatibility, maintenance, and licence review.
2. Add all required open-source notices and source-availability obligations.
3. Build deterministic test images with known deleted and overwritten files.
4. Test each filesystem separately; do not infer support from another platform.
5. Validate that source access is read-only at every layer available to the OS.
6. Test abrupt disconnect, bad-sector, low-space, cancellation, and resume behavior.
7. Obtain specialist review before making forensic marketing claims.

## Reference Technologies

- [GNU ddrescue](https://www.gnu.org/software/ddrescue/manual/ddrescue_manual.html): image a device while prioritising readable areas and retaining a resumable mapfile.
- [The Sleuth Kit](https://sleuthkit.org/sleuthkit/desc.php): filesystem and disk-image analysis, including allocated and deleted metadata across common filesystems.
- [The Sleuth Kit licences](https://www.sleuthkit.org/sleuthkit/licenses.php): licence review is required before redistribution.
- [PhotoRec](https://www.cgsecurity.org/wiki/PhotoRec): proven read-only file carving, distributed under GPL v2 or later; inclusion requires a deliberate licensing and distribution decision.
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/): Mac App Store apps must remain appropriately sandboxed and may not request root privilege.
