#!/bin/zsh
# Packages a DMG that needs no Apple Developer account. The app is signed ad-hoc, so on another Mac the first
# launch takes a right-click > Open (and one more "Open" in the system's dialog). Everything after that is normal.
#
# For the notarized path, with a Developer ID certificate, see scripts/release.sh instead.
# Needs nothing beyond Xcode: hdiutil makes the image, so create-dmg isn't required.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP=Compositor
NAME=Compositor-CN
DIST="$PROJECT_DIR/dist"
WORK="$HOME/Library/Caches/CompositorRelease"

settings=$(xcodebuild -project "$PROJECT_DIR/$APP.xcodeproj" -scheme "$APP" -configuration Release -showBuildSettings 2>/dev/null)
VERSION=$(print -r -- "$settings" | awk -F' = ' '/ MARKETING_VERSION = /{print $2; exit}')
BUILD=$(print -r -- "$settings" | awk -F' = ' '/ CURRENT_PROJECT_VERSION = /{print $2; exit}')
echo "==> $NAME $VERSION ($BUILD)"

rm -rf "$WORK"
mkdir -p "$WORK" "$DIST"

echo "==> Building a Release version"
# No development team and no certificate: the project signs to run locally, and the copy below is signed again
# ad-hoc so the bundle's signature matches its contents after Xcode's own pass.
xcodebuild -quiet \
  -project "$PROJECT_DIR/$APP.xcodeproj" -scheme "$APP" -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$WORK/DerivedData" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
  build

APP_PATH="$WORK/DerivedData/Build/Products/Release/$APP.app"
[[ -d "$APP_PATH" ]] || { echo "No $APP_PATH — the build didn't produce an app."; exit 1; }

echo "==> Signing ad-hoc"
codesign --force --sign - "$APP_PATH"
codesign --verify --verbose=2 "$APP_PATH"

echo "==> Building the DMG"
STAGE="$WORK/dmg"
mkdir -p "$STAGE"
# Named as the fork, so a Mac holding both editions shows two distinguishable apps.
cp -R "$APP_PATH" "$STAGE/$NAME.app"
codesign --force --sign - "$STAGE/$NAME.app"
ln -s /Applications "$STAGE/Applications"
DMG="$DIST/$NAME-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "$NAME $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

echo "==> Done: $DMG"
echo "On another Mac: right-click the app > Open, then Open again in the dialog."
