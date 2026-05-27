#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SiliconPulse"
PROJECT="SiliconPulse.xcodeproj"
SCHEME="SiliconPulse"
CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-platform=macOS,arch=arm64}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$DIST_DIR/dmg-staging"

cd "$ROOT_DIR"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' SiliconPulse/Info.plist)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' SiliconPulse/Info.plist)"
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

echo "Building $APP_NAME $VERSION ($BUILD)..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  build

APP_BUNDLE="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/$CONFIGURATION/$APP_NAME.app" -type d | grep -v "Index.noindex" | head -n 1)"

if [[ -z "$APP_BUNDLE" ]]; then
  echo "error: could not locate built $APP_NAME.app in DerivedData" >&2
  exit 1
fi

rm -rf "$STAGING_DIR" "$DMG_PATH" "$DMG_PATH.sha256"
mkdir -p "$STAGING_DIR"

ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

echo "Verifying code signature..."
codesign --verify --deep --strict --verbose=2 "$STAGING_DIR/$APP_NAME.app"

if ! spctl -a -vv -t exec "$STAGING_DIR/$APP_NAME.app"; then
  echo "warning: Gatekeeper assessment failed. Use a Developer ID signed and notarized build before public distribution." >&2
fi

echo "Creating $DMG_NAME..."
mkdir -p "$DIST_DIR"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

shasum -a 256 "$DMG_PATH" | tee "$DMG_PATH.sha256"

echo
echo "Release artifact:"
echo "  $DMG_PATH"
echo
echo "GitHub upload:"
echo "  gh release upload v$VERSION '$DMG_PATH' '$DMG_PATH.sha256' --clobber"
