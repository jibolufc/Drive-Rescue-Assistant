#!/usr/bin/env bash
set -euo pipefail

APP_NAME="DriveRescueAssistant"
PACKAGE_NAME="DriveRescueAssistant-mac-friend-test"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/build/Xcode"
BUILT_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist/friend-test"
STAGING_DIR="$DIST_DIR/$PACKAGE_NAME"
PACKAGED_APP="$STAGING_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/$PACKAGE_NAME.zip"

rm -rf "$STAGING_DIR" "$ZIP_PATH"
mkdir -p "$STAGING_DIR"

xcodebuild \
  -quiet \
  -project "$ROOT_DIR/DriveRescueAssistant.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

ditto "$BUILT_APP" "$PACKAGED_APP"
mkdir -p "$PACKAGED_APP/Contents/Resources"
/usr/bin/rsync -a \
  --exclude "__pycache__" \
  --exclude "*.pyc" \
  --exclude "*.egg-info" \
  "$ROOT_DIR/src/" \
  "$PACKAGED_APP/Contents/Resources/src/"
ditto "$ROOT_DIR/docs/FRIEND_TEST_GUIDE.md" "$STAGING_DIR/FRIEND_TEST_GUIDE.md"

cat > "$STAGING_DIR/README.txt" <<'EOF'
Drive Rescue Assistant - Friend Test Build

Open FRIEND_TEST_GUIDE.md first.

If macOS blocks the app because it is not yet notarized:
right-click DriveRescueAssistant.app, choose Open, then confirm.

This early build is for testing only.
EOF

cd "$DIST_DIR"
/usr/bin/zip -qry -X "$ZIP_PATH" "$PACKAGE_NAME"

echo "$ZIP_PATH"
