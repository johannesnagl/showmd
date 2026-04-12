#!/usr/bin/env bash
set -euo pipefail

# showmd release script
# Usage: ./scripts/release.sh [--skip-notarize]
#
# Prerequisites:
#   - Xcode & xcodegen installed
#   - Developer ID Application certificate in keychain
#   - App Store Connect API key or notarytool credentials
#
# Required environment variables:
#   NOTARIZE_TEAM_ID     — Apple Developer Team ID
#
# For notarization (unless --skip-notarize):
#   NOTARIZE_APPLE_ID    — Apple ID email
#   NOTARIZE_PASSWORD    — App-specific password
#   ...or set up a keychain profile:
#   xcrun notarytool store-credentials notarytool --apple-id <email> --team-id <team>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="showmd"
SCHEME="ShowMd"
TEAM_ID="${NOTARIZE_TEAM_ID:?Set NOTARIZE_TEAM_ID to your Apple Developer Team ID}"

SKIP_NOTARIZE=false
if [[ "${1:-}" == "--skip-notarize" ]]; then
  SKIP_NOTARIZE=true
fi

# Extract version from project.yml
VERSION=$(grep 'MARKETING_VERSION' "$PROJECT_DIR/project.yml" | head -1 | sed 's/.*: *"\(.*\)"/\1/')
echo "==> Building $APP_NAME v$VERSION"

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 1: Generate Xcode project
echo "==> Generating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate

# Step 2: Run tests
echo "==> Running tests..."
cd "$PROJECT_DIR/MarkdownRenderer"
swift test
cd "$PROJECT_DIR"

# Step 3: Archive
echo "==> Archiving..."
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
xcodebuild archive \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  | tail -5

# Step 4: Export
echo "==> Exporting..."
EXPORT_DIR="$BUILD_DIR/export"

cat > "$BUILD_DIR/ExportOptions.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
  -exportPath "$EXPORT_DIR" \
  | tail -5

APP_PATH="$EXPORT_DIR/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: $APP_PATH not found after export"
  exit 1
fi

# Step 5: Notarize
if [[ "$SKIP_NOTARIZE" == false ]]; then
  echo "==> Notarizing..."

  ZIP_FOR_NOTARIZE="$BUILD_DIR/$APP_NAME-notarize.zip"
  ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_FOR_NOTARIZE"

  if [[ -n "${NOTARIZE_APPLE_ID:-}" && -n "${NOTARIZE_PASSWORD:-}" ]]; then
    xcrun notarytool submit "$ZIP_FOR_NOTARIZE" \
      --apple-id "$NOTARIZE_APPLE_ID" \
      --team-id "$TEAM_ID" \
      --password "$NOTARIZE_PASSWORD" \
      --wait
  else
    echo "  Notarization credentials not set. Submitting via keychain profile 'notarytool'..."
    echo "  (Set up with: xcrun notarytool store-credentials notarytool --apple-id <email> --team-id $TEAM_ID)"
    xcrun notarytool submit "$ZIP_FOR_NOTARIZE" \
      --keychain-profile "notarytool" \
      --wait
  fi

  echo "==> Stapling..."
  xcrun stapler staple "$APP_PATH"
  rm "$ZIP_FOR_NOTARIZE"
else
  echo "==> Skipping notarization (--skip-notarize)"
fi

# Step 6: Package final zip
echo "==> Packaging..."
RELEASE_ZIP="$BUILD_DIR/$APP_NAME-$VERSION.zip"
cd "$EXPORT_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$RELEASE_ZIP"
cd "$PROJECT_DIR"

# Step 7: Generate checksum
SHA256=$(shasum -a 256 "$RELEASE_ZIP" | awk '{print $1}')
echo "$SHA256  $APP_NAME-$VERSION.zip" > "$RELEASE_ZIP.sha256"

echo ""
echo "==> Release build complete!"
echo "    App:      $APP_PATH"
echo "    Zip:      $RELEASE_ZIP"
echo "    SHA-256:  $SHA256"
echo "    Version:  $VERSION"
echo ""
echo "Next steps:"
echo "  1. Test the app: open \"$APP_PATH\""
echo "  2. Create GitHub release:"
echo "     git tag v$VERSION && git push origin v$VERSION"
echo "     gh release create v$VERSION \"$RELEASE_ZIP\" \"$RELEASE_ZIP.sha256\" \\"
echo "       --title \"showmd v$VERSION\" --notes \"Release v$VERSION\""
echo "  3. Update Homebrew cask with SHA-256: $SHA256"
