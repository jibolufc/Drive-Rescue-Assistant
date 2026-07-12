# Drive Troubleshooting Notes

These notes guide Drive Rescue Assistant's diagnosis wording and future Mac app help screens.

## Visible But Not Mounted

If macOS detects the physical drive but the volume is not mounted, extraction cannot begin yet. The tool should show:

```text
Drive is visible but not mounted; extraction is unavailable until it is mounted.
```

Recommended next checks:

```bash
diskutil list
diskutil info /dev/<disk>
diskutil info /dev/<volume>
diskutil mount readOnly /dev/<volume>
diskutil verifyVolume /dev/<volume>
```

The tool must not erase, repair, or force-mount automatically.

## Older WD / Apple Partition Map Drives

Older Mac-formatted WD drives may use Apple Partition Map instead of GUID Partition Map. They may also include tiny legacy driver partitions such as:

- Apple_Driver43
- Apple_Driver_ATA
- Apple_FWDriver
- Apple_Driver_IOKit
- Apple_Patches

These small partitions are normal on older Apple Partition Map disks and should not be treated as the main problem by themselves. The app should hide them from the normal drive list and focus on the main user volume.

## HFS+ Invalid Extent Entry

If `diskutil verifyVolume` reports:

```text
Invalid extent entry
File system verify or repair failed
```

This indicates HFS+ filesystem metadata corruption. An extent entry tells macOS where pieces of a file are stored on disk. When that metadata is invalid:

- The physical drive may still be detected.
- Some files may still be readable.
- New writes are unsafe.
- Time Machine may refuse to continue using the disk.
- First Aid may be unable to repair the volume.

The app should recommend copying readable data out first, not writing to the drive.

## Time Machine Disk That Is Full

A full Time Machine disk should normally still mount. Time Machine usually deletes the oldest backups automatically when it needs space.

If a Time Machine disk does not mount, the likely issue is not simply that it is full. More likely causes include:

- Filesystem corruption.
- Permission or ownership problems.
- Disk hardware errors.
- Enclosure or cable problems.
- Unsupported or legacy partition layout edge cases.

## Hardware Clues

Positive signs:

- Drive appears in `diskutil list`.
- Drive appears in System Report under USB or Thunderbolt.
- Drive spins smoothly.
- Finder can browse some contents.

Warning signs:

- Repeated clicking.
- Spinning up and stopping repeatedly.
- Mount attempts hang or fail.
- Kernel logs show repeated I/O errors.
- Repair or erase fails.

## Practical Recommendation

For an old backup drive with unrepairable HFS+ corruption, the safest advice is:

1. Copy out any historical backup data the user needs.
2. Start a fresh Time Machine backup on a newer drive.
3. Treat the old drive as temporary or secondary storage only.
4. If reusing the old drive, erase it only after important data is copied elsewhere.
5. Prefer GUID Partition Map and APFS for a fresh modern Time Machine disk.

The app should avoid presenting repair or erase as the first recommendation.
