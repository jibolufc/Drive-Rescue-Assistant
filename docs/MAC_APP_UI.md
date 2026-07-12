# Mac App UI Direction

## Product Feel

Drive Rescue Assistant should feel simple, functional, minimalist, and calm. It should look like a practical Mac utility made for someone who wants clarity, not noise.

The interface should avoid flashy recovery-tool styling. No alarm-heavy screens, no overdone gradients, no complicated dashboards, and no fake technical drama. The app should quietly tell the user what it found, what is safe, and what action can be taken next.

## Design Principles

- Simple first screen.
- Clear drive list.
- Minimal controls.
- Plain language.
- Strong safety guidance.
- No destructive action in the main path.
- Progress and reports should be easy to understand.
- Everything should feel local, private, and under the user's control.

## Visual Style

- Native macOS SwiftUI look.
- Light and dark mode support.
- Neutral background colors.
- Small amount of accent color for status only.
- No decorative cards inside cards.
- No large hero sections.
- No marketing-style layout.
- Icons should be functional, not decorative.
- Rounded corners should be restrained.
- Typography should be clean and readable.

## App Structure

```text
Sidebar                 Main Area
-----------------------------------------------
Connected Drives        Selected Drive

Backup Drive            Status
USB Drive               Format
Time Machine Disk       Capacity
                        Safety Notes

                        Primary Action
                        Activity
```

## Main Screens

### 1. Connected Drives

The sidebar lists connected drives.

Each row should show:

- Drive name.
- Small drive icon.
- Short status badge: Writable, Read-only, Time Machine, Locked, or Warning.

### 2. Drive Summary

The main panel shows the selected drive.

Fields:

- Name.
- Mount path.
- Format.
- Capacity.
- Free space.
- Writable status.
- Time Machine status.
- Safety recommendation.

The recommendation should be the most important text on the screen.

Examples:

- "Safe to preview extraction."
- "Read-only drive. Extraction may work, but changes are blocked."
- "Time Machine backup detected. Copy files out; do not modify the backup."
- "Older Mac backup layout detected. This can be normal for legacy WD drives."
- "Filesystem damage suspected. Copy readable data before repair or erase."

### 3. Extract View

The extraction flow should be short:

1. Select source.
2. Choose destination.
3. Preview.
4. Extract.
5. View report.

Controls:

- Destination folder picker.
- Preview Extract button.
- Extract Files button.
- Progress bar.
- Cancel button.

### 4. Report View

The report should be plain and useful:

- Files scanned.
- Files copied.
- Files skipped.
- Files failed.
- Data copied.
- Destination path.
- Report file path.

Failed files should be available, but not visually dominant unless failures occurred.

## Empty State

When no drive is selected:

```text
Connect or select a drive to begin.
```

The empty state should not include long instructions. The app should become useful as soon as a drive appears.

## Status Language

Use direct wording:

- "Can extract"
- "Read-only"
- "Needs unlock"
- "Time Machine backup"
- "Permission limited"
- "Preview ready"
- "Extraction complete"

Avoid exaggerated wording:

- "Critical failure"
- "Danger"
- "Hack"
- "Bypass"
- "Guaranteed recovery"

## Store-Friendly UI Rules

For any Apple App Store version:

- Use file/folder pickers for access.
- Explain file access only when needed.
- Keep deletion out of the first release.
- Do not imply the app can bypass macOS protections.
- Keep privacy wording visible in Settings or About.

## First Mac App Build

The first SwiftUI build should include:

- Sidebar drive list.
- Drive detail screen.
- Refresh button.
- Destination picker.
- Dry-run preview button.
- Extract button.
- Progress area.
- Report summary.

It should not include:

- Delete mode.
- Repair mode.
- Formatting.
- Advanced forensic features.
- Cloud sync.
