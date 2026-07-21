#!/usr/bin/env bash
set -euo pipefail

APP_NAME="DriveRescueAssistant"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: ayodele Coker (C8QY39ZJ4G)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/build/XcodeRelease"
BUILT_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist/macos"
STAGED_APP="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/$APP_NAME-macOS.zip"

rm -rf "$DERIVED_DATA" "$DIST_DIR"
mkdir -p "$DIST_DIR"

xcodebuild \
  -quiet \
  -project "$ROOT_DIR/DriveRescueAssistant.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

ditto "$BUILT_APP" "$STAGED_APP"
mkdir -p "$STAGED_APP/Contents/Resources"
/usr/bin/rsync -a \
  --exclude "__pycache__" \
  --exclude "*.pyc" \
  --exclude "*.egg-info" \
  "$ROOT_DIR/src/" \
  "$STAGED_APP/Contents/Resources/src/"

# Finder and downloaded-source metadata can invalidate a signature after the
# bundle is archived. Remove it before applying the final Developer ID seal.
/usr/bin/xattr -cr "$STAGED_APP"

/usr/bin/codesign \
  --force \
  --sign "$SIGNING_IDENTITY" \
  --options runtime \
  --timestamp \
  "$STAGED_APP"

/usr/bin/codesign --verify --deep --strict --verbose=2 "$STAGED_APP"
/usr/sbin/spctl --assess --type execute --verbose=2 "$STAGED_APP" || true

/usr/bin/ditto \
  -c \
  -k \
  --sequesterRsrc \
  --keepParent \
  "$STAGED_APP" \
  "$ZIP_PATH"

if [[ -n "$NOTARY_PROFILE" ]]; then
  xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
  xcrun stapler staple "$STAGED_APP"
  xcrun stapler validate "$STAGED_APP"

  rm -f "$ZIP_PATH"
  /usr/bin/ditto \
    -c \
    -k \
    --sequesterRsrc \
    --keepParent \
    "$STAGED_APP" \
    "$ZIP_PATH"
else
  printf '\nSigned package created without notarization.\n'
  printf 'Set NOTARY_PROFILE after storing Apple credentials to notarize it.\n'
fi

printf '\nPackage: %s\n' "$ZIP_PATH"
