# GitHub Release Testing

Use GitHub Releases when you want a friend to download only the packaged app, not browse the full source tree.

## Package Names

Mac friend-test package:

```text
DriveRescueAssistant-mac-friend-test.zip
```

Future Windows friend-test package:

```text
DriveRescueAssistant-windows-friend-test.zip
```

## Recommended Release Title

```text
Drive Rescue Assistant v0.1.0 Friend Test
```

## Recommended Release Notes

```markdown
This is an early friend-test build of Drive Rescue Assistant.

What to test:

- External Drive Rescue
- Move From This Mac
- Preview before copying
- File type filters
- ZIP compression

Safety:

- The app does not erase, format, repartition, or delete source files.
- Preview copies nothing.
- Please do not use this as your only recovery option for a failing drive.

Known limits:

- This Mac build is not yet App Store notarized.
- macOS may ask you to right-click and choose Open.
- This early build may require Python 3 on the tester's Mac.
```

## Public vs Private Repo

If the GitHub repository is public, anyone with the release asset link can download it.

If the repository is private, friends usually need access to the repository to download release assets. For private early testing without repo access, upload the zip to iCloud Drive, Google Drive, Dropbox, or another file-sharing service instead.

## Build Command

From the repo root:

```bash
./script/package_friend_test.sh
```

The zip is written to:

```text
dist/friend-test/DriveRescueAssistant-mac-friend-test.zip
```
