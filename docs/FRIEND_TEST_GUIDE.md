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

If macOS says the app is damaged, delete that copy and download the latest package again. Do not move it to the Bin until you have confirmed you downloaded the latest replacement build.

The v0.4 Mac package includes its extraction engine and does not require Python
to be installed separately.

## How To Open On Windows

1. Download `DriveRescueAssistant-windows-x64.zip` from the latest GitHub Release.
2. Extract the zip, then open `DriveRescueAssistant.exe`.
3. If Microsoft Defender SmartScreen appears, choose `More info`, verify the app name, then choose `Run anyway` for this known friend-test build.

The Windows package is self-contained and does not require Python.

## How To Open On Linux

1. Download `DriveRescueAssistant-linux-x64.tar.gz` from the latest GitHub Release.
2. Extract the archive.
3. Mark `DriveRescueAssistant` as executable in the file manager, or run `chmod +x DriveRescueAssistant`.
4. Open it from the file manager or terminal.

The Linux package is self-contained. It targets mainstream x86-64 distributions compatible with Ubuntu 22.04.

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
10. During a longer copy, confirm that the current file, progress, elapsed time,
    and estimated remaining time update.
11. Try Cancel on test data only and confirm the app reports cancellation
    without leaving an incomplete ZIP.

### Move From This Mac

1. Choose `Move From This Mac`.
2. Choose a source folder on the Mac.
3. Choose a destination folder, ideally on an external drive.
4. Choose the file type group.
5. Optionally tick `Compress to ZIP`.
6. Click `Preview`.
7. If the preview looks right, click `Copy Files`.

After a preview, compare the planned size with the free space on the
destination. After copying, open the local report and confirm its totals match
what you selected.

## What Feedback To Send

Please send:

- Mac model and macOS version.
- Whether the app opened normally.
- Whether your drive appeared.
- Whether Preview worked.
- Whether Extract or Copy worked.
- Whether progress, Cancel, and the completion report behaved clearly.
- On Windows/Linux, whether individual file selection worked.
- Any exact error message shown in the Activity area.
- A screenshot if something looked confusing.

Do not send private recovered files.

## Known Limits

- This is not a full forensic recovery tool.
- It cannot recover files from physically failed drives.
- It cannot bypass encryption or macOS permissions.
- Unmounted or badly damaged drives may need Disk Utility or professional recovery first.
- The app is local-first and does not upload files.
