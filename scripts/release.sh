#!/usr/bin/env bash
set -euo pipefail

# showmd release script — direct distribution (no App Store)
# Usage: ./scripts/release.sh [--skip-notarize]
#
# Prerequisites:
#   - Xcode & xcodegen installed
#   - "Developer ID Application" certificate in keychain
#
# Required environment variables:
#   NOTARIZE_TEAM_ID     — Apple Developer Team ID
#
# For notarization (unless --skip-notarize), one of:
#   NOTARIZE_KEYCHAIN_PROFILE — keychain profile name (e.g. "holdor-notarize")
#   NOTARIZE_APPLE_ID + NOTARIZE_PASSWORD — Apple ID + app-specific password

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

# Step 3: Build release (development signing)
echo "==> Building release..."
xcodebuild build \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  | tail -5

# Locate the built app
APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: $APP_PATH not found after build"
  exit 1
fi

# Step 4: Re-sign with Developer ID
echo "==> Signing with Developer ID..."
SIGNING_ID="Developer ID Application: Johannes Nagl ($TEAM_ID)"

# Sign the extension first, then the app (inside-out)
# Must pass entitlements explicitly — codesign --force strips them otherwise
codesign --force --options runtime --sign "$SIGNING_ID" \
  --entitlements "$PROJECT_DIR/ShowMdExtension/ShowMdExtension.entitlements" \
  "$APP_PATH/Contents/PlugIns/ShowMdExtension.appex"
codesign --force --options runtime --sign "$SIGNING_ID" \
  --entitlements "$PROJECT_DIR/ShowMd/ShowMd.entitlements" \
  "$APP_PATH"

# Verify
codesign --verify --deep --strict "$APP_PATH"
echo "==> Signed and verified: $APP_PATH"

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
  elif [[ -n "${NOTARIZE_KEYCHAIN_PROFILE:-}" ]]; then
    echo "  Submitting via keychain profile '$NOTARIZE_KEYCHAIN_PROFILE'..."
    xcrun notarytool submit "$ZIP_FOR_NOTARIZE" \
      --keychain-profile "$NOTARIZE_KEYCHAIN_PROFILE" \
      --wait
  else
    echo "ERROR: Set NOTARIZE_APPLE_ID + NOTARIZE_PASSWORD, or NOTARIZE_KEYCHAIN_PROFILE"
    exit 1
  fi

  echo "==> Stapling..."
  xcrun stapler staple "$APP_PATH"
  rm "$ZIP_FOR_NOTARIZE"
else
  echo "==> Skipping notarization (--skip-notarize)"
fi

# Step 6: Create DMG
echo "==> Creating DMG..."
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
hdiutil create -volname "$APP_NAME" \
  -srcfolder "$APP_PATH" \
  -ov -format UDZO \
  "$DMG_PATH"

# Step 7: Also create zip (for Homebrew)
echo "==> Creating zip..."
RELEASE_ZIP="$BUILD_DIR/$APP_NAME-$VERSION.zip"
cd "$(dirname "$APP_PATH")"
ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$RELEASE_ZIP"
cd "$PROJECT_DIR"

# Step 8: Generate checksums
SHA256_DMG=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
SHA256_ZIP=$(shasum -a 256 "$RELEASE_ZIP" | awk '{print $1}')
echo "$SHA256_DMG  $APP_NAME-$VERSION.dmg" > "$DMG_PATH.sha256"
echo "$SHA256_ZIP  $APP_NAME-$VERSION.zip" > "$RELEASE_ZIP.sha256"

echo ""
echo "==> Release build complete!"
echo "    App:      $APP_PATH"
echo "    DMG:      $DMG_PATH  (SHA-256: $SHA256_DMG)"
echo "    Zip:      $RELEASE_ZIP  (SHA-256: $SHA256_ZIP)"
echo "    Version:  $VERSION"
echo ""
echo "Next steps:"
echo "  1. Test the app: open \"$APP_PATH\""
echo "  2. Create GitHub release:"
echo "     git tag v$VERSION && git push origin v$VERSION"
echo "     gh release create v$VERSION \"$DMG_PATH\" \"$RELEASE_ZIP\" \"$RELEASE_ZIP.sha256\" \\"
echo "       --title \"showmd v$VERSION\" --generate-notes"
echo "  3. Update Homebrew cask with SHA-256: $SHA256_ZIP"
