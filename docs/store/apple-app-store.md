# Apple App Store Requirements

If Drive Rescue Assistant becomes a macOS App Store app, it should be positioned as a safe drive assistant, not an unrestricted disk recovery or bypass tool.

## Product Rules

- Use macOS sandboxing.
- Use system file/folder pickers for user-approved access.
- Avoid private Apple APIs.
- Avoid silent scanning of all disks.
- Avoid destructive operations by default.
- Do not erase, format, repartition, force-mount, or bypass permissions.
- Use security-scoped bookmarks only when persistent access is needed.
- Keep all processing local unless a future cloud feature is explicitly added and disclosed.

## Time Machine Wording

The app may say it helps copy accessible files from backup volumes. It should not claim to bypass Time Machine protections or recover every backup item.

## Metadata Needed

- App name.
- Subtitle.
- Description.
- Keywords.
- Support URL.
- Privacy Policy URL.
- App icon.
- Screenshots.
- Category: Utilities.
- Age rating.
- Privacy nutrition labels.
- File access explanation.

## Store-Safe V1 Features

- User-selected drive/folder scan.
- Readable file extraction.
- Reports.
- Clear safety notes.

Delete mode should be excluded from the first store release.

## Current Xcode Project Notes

The repo includes `DriveRescueAssistant.xcodeproj` as the Apple-distribution track.

Current development builds use `Development.entitlements` because the app still calls the local Python CLI engine. A future App Store build should move disk scanning/extraction into native Swift code or a bundled helper that works inside Apple's sandbox rules, then switch to `Store.entitlements`.

Before App Store submission, add:

- Real app icon images in `Assets.xcassets/AppIcon.appiconset`.
- Apple Developer Team ID.
- Signed Release Archive.
- Store-safe sandboxed file access.
- Privacy Policy URL.
- Support URL.
- App Store screenshots.
