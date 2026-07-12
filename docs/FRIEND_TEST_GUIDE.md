# Drive Rescue Assistant Friend Test Guide

Thank you for testing Drive Rescue Assistant.

This is an early test build shared directly by the developer. It is not an App Store release yet.

## What The App Does

Drive Rescue Assistant helps preview and copy readable files from external storage or from a folder on the Mac to another destination.

It is designed to be careful:

- It does not erase drives.
- It does not format drives.
- It does not repartition drives.
- It does not delete source files.
- It asks you to preview before copying.

## How To Open On Mac

1. Download `DriveRescueAssistant-mac-friend-test.zip`.
2. Double-click the zip file.
3. Open `DriveRescueAssistant.app`.
4. If macOS blocks it because it is not yet notarized, right-click the app and choose `Open`, then confirm.

This early build may require Python 3 to be available on the Mac. If the app opens but says Python could not be found, install Python 3 from https://www.python.org/downloads/macos/ or ask the developer for the next packaged build.

## What To Test

### External Drive Rescue

1. Connect an external drive.
2. Open the app.
3. Choose `External Drive Rescue`.
4. Select the drive.
5. Choose a destination folder.
6. Choose `All`, `Documents`, `Photos`, `Videos`, `Audio`, or `Archives`.
7. Optionally tick `Compress to ZIP`.
8. Click `Preview`.
9. If the preview looks right, click `Extract Files`.

### Move From This Mac

1. Choose `Move From This Mac`.
2. Choose a source folder on the Mac.
3. Choose a destination folder, ideally on an external drive.
4. Choose the file type group.
5. Optionally tick `Compress to ZIP`.
6. Click `Preview`.
7. If the preview looks right, click `Copy Files`.

## What Feedback To Send

Please send:

- Mac model and macOS version.
- Whether the app opened normally.
- Whether your drive appeared.
- Whether Preview worked.
- Whether Extract or Copy worked.
- Any exact error message shown in the Activity area.
- A screenshot if something looked confusing.

Do not send private recovered files.

## Known Limits

- This is not a full forensic recovery tool.
- It cannot recover files from physically failed drives.
- It cannot bypass encryption or macOS permissions.
- Unmounted or badly damaged drives may need Disk Utility or professional recovery first.
- The app is local-first and does not upload files.
