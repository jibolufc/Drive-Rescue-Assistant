# macOS Signing and Notarization

Drive Rescue Assistant uses two separate Apple distribution paths:

- Direct download: Developer ID signing, hardened runtime, and notarization.
- Mac App Store: Apple Distribution signing and the sandbox entitlements in
  `macos/DriveRescueAssistant/Resources/Store.entitlements`.

The direct build remains outside the App Sandbox because drive discovery uses
macOS disk tools. It must retain the app's extraction-first safety controls.

## Current Signing Identity

```text
Developer ID Application: ayodele Coker (C8QY39ZJ4G)
```

The certificate and its private key belong in the login Keychain. Never commit
a private key, `.p12` file, Apple password, or App Store Connect API key.

## Create a Signed Package

```bash
./script/package_macos_release.sh
```

The output is:

```text
dist/macos/DriveRescueAssistant-macOS.zip
```

The release script builds a universal app for Apple-silicon and Intel Macs.

## Configure Notarization

Create an app-specific password at Apple Account, then store the credentials in
the login Keychain once:

```bash
xcrun notarytool store-credentials "DriveRescueNotary" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "C8QY39ZJ4G" \
  --password "YOUR_APP_SPECIFIC_PASSWORD"
```

Enter sensitive values only into Terminal when prompted or into the command on
your own Mac. Do not put real credentials into this file or GitHub Actions.

Build, submit, wait for Apple, staple the ticket, and recreate the ZIP:

```bash
NOTARY_PROFILE="DriveRescueNotary" ./script/package_macos_release.sh
```

## Verification

```bash
codesign --verify --deep --strict --verbose=2 \
  dist/macos/DriveRescueAssistant.app

spctl --assess --type execute --verbose=2 \
  dist/macos/DriveRescueAssistant.app

xcrun stapler validate dist/macos/DriveRescueAssistant.app
```

Before public release, test the ZIP on a different Mac downloaded through a
browser. Gatekeeper should open a notarized build without the damaged-app or
unverified-developer warning.
