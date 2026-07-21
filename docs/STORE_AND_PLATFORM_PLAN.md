# Store and Platform Plan

Last reviewed: 2026-07-11

## Product Position

Drive Rescue Assistant should be presented as a safe, local-first file recovery assistant for external storage. It should help people understand a drive, preview what can be copied, select the files they want, and extract them to a safe location.

The product should not be positioned as a destructive repair tool, permission bypass tool, or guaranteed forensic recovery tool.

## Simple User Promise

For non-technical users:

- Plug in a drive.
- Pick the drive.
- See whether it is safe to copy from.
- Preview what can be rescued.
- Choose all files, documents, photos, videos, audio, or archives.
- Optionally compress the result to a ZIP file.
- Extract to a chosen folder.
- Read a plain report when finished.

For technical users:

- Keep the CLI available for repeatable scans and extraction.
- Produce local reports.
- Show device IDs, filesystem type, mount path, writable state, and failure notes.
- Never hide the limits of the current platform.

## Platform Strategy

Use one product name and one shared safety model, but ship different capability levels depending on the operating system.

| Platform | Store | Best First Release | Capability Level |
| --- | --- | --- | --- |
| macOS | Apple Mac App Store | Native SwiftUI utility | Fullest experience: drive scan, diagnosis, preview, filtered extraction, ZIP output |
| iOS/iPadOS | Apple App Store | Not recommended for first release | Limited to user-selected files/folders; no true external disk rescue workflow |
| Android | Google Play | Android companion app | User-selected storage import/copy/export; limited external-drive access |
| Windows | Direct/GitHub/Microsoft Store later | CLI or desktop GUI | Good external drive utility potential, but not part of Apple/Google store plan |
| Linux | Direct/GitHub package later | CLI first | Good technical-user utility potential |

## Apple Store Plan

### Best Apple Target

The best Apple store target is macOS, not iPhone. A Mac can see external drives properly, can show device and filesystem details, and fits the rescue workflow naturally.

### Mac App Store V1

V1 should include:

- Native SwiftUI interface.
- Connected-drive sidebar.
- Drive detail view.
- Safety notes.
- Preview before extraction.
- File group selector.
- ZIP compression option.
- Local extraction report.
- No delete, erase, format, repartition, force-mount, or permission bypass.

### Apple Review Risks

The main risks are:

- The app asking for too much file access.
- The app appearing to bypass macOS permissions.
- Hidden or undocumented disk operations.
- Claims that sound like guaranteed data recovery.
- A local helper or script that does not fit sandbox expectations.

### Apple Readiness Checklist

- Use sandboxed file access.
- Use system file/folder pickers.
- Use user-selected read/write access only where needed.
- Avoid private APIs.
- Keep all processing local.
- Add a clear Privacy Policy URL.
- Add a clear Support URL.
- Add final app icon assets.
- Add App Store screenshots.
- Add review notes explaining why external drive access is needed.
- Build a signed Release archive with the Apple Developer account.

### Apple Store Potential

Potential is good on macOS because the problem is real and practical: old backup drives, read-only drives, awkward file systems, and confusing external storage behavior. The strongest positioning is:

> A calm Mac utility for previewing and safely copying readable files from external drives.

This is more store-safe than promising deep repair or full recovery.

## Google Play Plan

### Best Google Target

The best Google Play target is an Android companion app, not the full desktop rescue tool. Android storage rules are built around user-selected files and folders. That is good for privacy, but it limits low-level disk rescue.

### Android V1

V1 should include:

- Android app built with Kotlin and Jetpack Compose.
- System picker for user-selected files/folders.
- Preview by file type.
- Copy/export selected files.
- ZIP compression option.
- Local-only processing.
- Clear storage permission explanation.
- No broad background scanning.
- No destructive delete flow.

### Android Scope Limits

Android should not promise:

- Full external disk repair.
- Full Time Machine recovery.
- Full APFS/HFS+ recovery.
- Access to every connected USB drive.
- Bypassing Android storage restrictions.

### Google Play Readiness Checklist

- Publish as Android App Bundle.
- Target the required current Android API level at submission time.
- Use Storage Access Framework where possible.
- Avoid high-risk broad storage permissions unless there is a strong need.
- Complete the Data safety form accurately.
- Provide a Privacy Policy URL.
- Provide support email/contact.
- Add content rating.
- Add phone screenshots.
- Add tablet screenshots if tablet support is included.
- Add clear review notes for storage access.

### Google Play Potential

Potential is moderate as a companion tool. It is strongest for:

- Copying files from user-selected storage.
- Compressing selected folders.
- Helping less technical users move files from USB/OTG or document providers.
- Acting as a mobile version of the same safe extraction idea.

It should not be marketed as equal to the Mac version. The Play Store version should be described as:

> A simple file rescue companion for previewing, selecting, copying, and compressing accessible files from user-approved storage locations.

## Cross-Platform Technical Plan

### Shared Concepts

Keep these concepts identical across all versions:

- Drive or source selection.
- Safety status.
- Preview first.
- File group filters.
- ZIP compression.
- Extraction report.
- Local-only processing.
- No destructive defaults.

### Shared Engine

The current Python engine remains useful for desktop platforms:

- macOS CLI and helper logic.
- Windows CLI.
- Linux CLI.
- Testable extraction behavior.

For store apps, some code may need to be native:

- macOS App Store may need native Swift extraction or a sandbox-compliant bundled helper.
- Android should be native Kotlin because Android file access is URI-based, not normal desktop paths.

### Capability Labels

Every app should show plain capability labels:

- Can extract.
- Needs mount.
- Read-only.
- Permission needed.
- Unsupported on this device.
- Preview only.

This keeps the app usable for non-technical users while still being honest for technical users.

## Non-Technical UX Plan

The app should avoid technical language as the first layer.

Use:

- "Can extract"
- "Not mounted"
- "Choose where recovered files go"
- "Preview first"
- "Compress to ZIP"
- "This drive is visible but cannot be copied yet"

Avoid as primary wording:

- "HFS+ extent corruption"
- "APM partition table"
- "security-scoped bookmark"
- "mount identifier"

Technical details can live below the summary for users who want them.

## Technical UX Plan

Technical users should still get:

- Device path.
- Filesystem.
- Mount path.
- Size and free space.
- Writable state.
- Report path.
- CLI command equivalents.
- Copyable diagnostic commands on macOS.

## Store Listing Direction

### App Name Options

- Drive Rescue Assistant
- Drive Rescue
- Rescue Drive Assistant

### Short Description

Preview, select, and safely copy readable files from external storage.

### Longer Store Description Draft

Drive Rescue Assistant helps you understand external storage and safely copy readable files to a location you choose. Preview first, select the file types you need, optionally compress the result to ZIP, and keep a local report of what was copied.

The app is designed to be careful: it does not erase, format, repartition, force-mount, or bypass permissions. It focuses on safe extraction from storage locations you choose.

### Categories

- Apple macOS: Utilities.
- Google Play: Tools or Productivity.

## Privacy Position

Default privacy promise:

- No account required.
- No cloud upload.
- No selling data.
- No ads in V1.
- No background scanning.
- Files are processed locally.
- Reports stay on the user's device unless they choose to share them.

If analytics are added later, they should be optional and must not include file names, file contents, drive contents, or recovered data.

## Release Roadmap

The detailed product-version roadmap, including Advanced Recovery and the separate Forensic Edition, is maintained in `docs/PRODUCT_ROADMAP.md`. The phases below describe Store delivery order only.

### Phase 1: Mac Utility MVP

- Finish SwiftUI app.
- Keep extraction safe and local.
- Support file group selection and ZIP output.
- Improve preview into selectable items.
- Add clearer success/failure reports.

### Phase 2: Mac Store Candidate

- Replace or package helper flow in a store-safe way.
- Add sandboxed file access.
- Add app icon and screenshots.
- Add privacy policy and support page.
- Prepare App Store review notes.
- Test on clean macOS user account.

### Phase 3: Android Companion

- Build Kotlin/Compose app.
- Use Android system file/folder picker.
- Add preview, selection, copy, and ZIP.
- Avoid broad storage permissions.
- Prepare Play listing and Data safety form.

### Phase 4: Desktop Expansion

- Package Windows CLI/GUI.
- Package Linux CLI.
- Keep GitHub releases for technical users.

## Official References

- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple App Sandbox documentation: https://developer.apple.com/documentation/security/app-sandbox
- Apple user-selected file read/write entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_files_user-selected_read-write
- Android Storage Access Framework: https://developer.android.com/training/data-storage/shared/documents-files
- Google Play target API level requirements: https://support.google.com/googleplay/android-developer/answer/11926878
- Google Play app review preparation: https://support.google.com/googleplay/android-developer/answer/9859455
- Google Play Data safety form: https://support.google.com/googleplay/android-developer/answer/10787469
