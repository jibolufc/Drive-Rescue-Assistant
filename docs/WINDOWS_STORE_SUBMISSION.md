# Windows Store Submission

## Reserved Product Identity

- Product name: `Drive Rescue Assistant`
- Package identity name: `ASFCoker.DriveRescueAssistant`
- Publisher: `CN=AC772371-FB65-4313-A8AB-41D0B9D11E49`
- Publisher display name: `ASFCoker`
- Store ID: `9PH7LLDS2V78`

These values are public package identity metadata, not account credentials.

## Generated Package

The Windows GitHub Actions build creates a separate artifact named `MicrosoftStorePackage`. It contains an `.msixupload` file for the Partner Center Packages page.

The Store package is intentionally separate from the public Windows ZIP. It is unsigned at upload time; Microsoft signs accepted MSIX packages for customer distribution, so no developer certificate or private key is required for this path.

## Partner Center Steps

1. Open the Drive Rescue Assistant product in Partner Center.
2. Start a new submission.
3. Complete Pricing and availability.
4. Complete Properties and age ratings.
5. Upload the generated `.msixupload` artifact under Packages.
6. Complete the English (United Kingdom) Store listing.
7. Add the final app icon and Store screenshots before submission.
8. Add public Privacy Policy and Support URLs.
9. Add certification notes explaining that the app reads only user-selected or connected storage and copies files to a user-selected destination.
10. Submit for certification only after the package validation page shows no blocking errors.

## Current Packaging Notes

- Architecture: x64.
- Minimum Windows version: Windows 10 version 1809 (`10.0.17763.0`).
- Capability: `runFullTrust`, required for the packaged desktop application.
- The generated package uses temporary packaging artwork. Replace it with the approved Drive Rescue Assistant logo before public Store submission.
- The direct GitHub `.exe` remains separately packaged and is not signed by the Microsoft Store.
