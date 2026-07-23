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

Use an App Store Connect Team API key so notarization is independent of Apple
Account password changes. Individual API keys do not support `notarytool`.

1. In App Store Connect, open Users and Access, then Integrations.
2. Generate a Team API key with the Developer role.
3. Download its `.p8` private key. Apple permits only one download.
4. Store it outside the repository with owner-only permissions.

```bash
mkdir -p "$HOME/.private_keys"
chmod 700 "$HOME/.private_keys"
mv "$HOME/Downloads/AuthKey_YOUR_KEY_ID.p8" "$HOME/.private_keys/"
chmod 600 "$HOME/.private_keys/AuthKey_YOUR_KEY_ID.p8"
```

Save and validate the API credentials in the macOS Keychain:

```bash
xcrun notarytool store-credentials "DriveRescueNotary" \
  --key "$HOME/.private_keys/AuthKey_YOUR_KEY_ID.p8" \
  --key-id "YOUR_KEY_ID" \
  --issuer "YOUR_ISSUER_ID" \
  --validate
```

Never commit a `.p8` file, API key contents, Apple password, or exported signing
identity. The Key ID and Issuer ID are identifiers, not private key material.

Build, submit, wait for Apple, staple the ticket, and recreate the ZIP:

```bash
NOTARY_PROFILE="DriveRescueNotary" ./script/package_macos_release.sh
```

If Apple keeps a submission in progress after the local wait is stopped, query
the existing submission instead of uploading duplicates:

```bash
xcrun notarytool info "SUBMISSION_ID" \
  --keychain-profile "DriveRescueNotary"
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
