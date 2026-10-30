#!/bin/zsh
# Packages a DMG that needs no Apple Developer account. The app is signed ad-hoc, so on another Mac the first
# launch takes a right-click > Open (and one more "Open" in the system's dialog). Everything after that is normal.
#
# For the notarized path, with a Developer ID certificate, see scripts/release.sh instead.
# Needs nothing beyond Xcode: hdiutil makes the image, so create-dmg isn't required.
#
# Every run raises the build number in the project file, so two DMGs taken a day apart can always be told
# apart — in the About panel, in the DMG's name, and in the file's version. SKIP_BUILD_BUMP=1 keeps the
# number as it is, for a throwaway build.
#
# The DMG lands in dist/ and on the Desktop; DESKTOP_DIR=… moves the copy, DESKTOP_DIR= skips it.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP=Compositor
NAME=Compositor-CN              # file name: no spaces, so shells and URLs handle it
APP_NAME="Compositor CN"        # what the Dock and Finder show, badge and all
DIST="$PROJECT_DIR/dist"
DESKTOP_DIR="${DESKTOP_DIR-$HOME/Desktop}"
PBX="$PROJECT_DIR/$APP.xcodeproj/project.pbxproj"
WORK="$HOME/Library/Caches/CompositorRelease"

if [[ -z "${SKIP_BUILD_BUMP:-}" ]]; then
  current=$(grep -oE 'CURRENT_PROJECT_VERSION = [0-9]+' "$PBX" | head -1 | awk '{print $3}')
  [[ -n "$current" ]] || { echo "No CURRENT_PROJECT_VERSION in $PBX"; exit 1; }
  # One pattern, applied to every configuration: the target, its tests and the UI tests must not disagree.
  sed -i '' -E "s/(CURRENT_PROJECT_VERSION = )${current};/\1$((current + 1));/g" "$PBX"
  echo "==> Build number $current → $((current + 1))"
fi

settings=$(xcodebuild -project "$PROJECT_DIR/$APP.xcodeproj" -scheme "$APP" -configuration Release -showBuildSettings 2>/dev/null)
VERSION=$(print -r -- "$settings" | awk -F' = ' '/ MARKETING_VERSION = /{print $2; exit}')
BUILD=$(print -r -- "$settings" | awk -F' = ' '/ CURRENT_PROJECT_VERSION = /{print $2; exit}')
echo "==> $APP_NAME $VERSION ($BUILD)"

# Only the staging area is cleared. Keeping DerivedData turns a repackage from a ten minute full build into
# an incremental one; the Release binary is relinked from the same object files either way.
rm -rf "$WORK/dmg"
mkdir -p "$WORK" "$DIST"

# Release, not Debug: a Debug build carries the whole debug module as Compositor.debug.dylib (~37 MB here)
# plus a previews stub, neither of which exists in Release. The shipped binary is a few hundred KB.
echo "==> Building a Release version"
xcodebuild -quiet \
  -project "$PROJECT_DIR/$APP.xcodeproj" -scheme "$APP" -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$WORK/DerivedData" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
  build

APP_PATH="$WORK/DerivedData/Build/Products/Release/$APP.app"
[[ -d "$APP_PATH" ]] || { echo "No $APP_PATH — the build didn't produce an app."; exit 1; }

# The fork has to be recognisable next to the original: in the Dock, in the menu bar's app item, in the
# About panel, and in the icon. CFBundleDisplayName comes from Config/Info.plist and covers the Dock and
# Finder. CFBundleName, which is what the menu bar's app item and the About panel show, cannot be set from
# either the plist or INFOPLIST_KEY_CFBundleName — with GENERATE_INFOPLIST_FILE on, Xcode always fills it
# from PRODUCT_NAME — so it is rewritten here, before the signature is applied.
plutil -replace CFBundleName -string "$APP_NAME" "$APP_PATH/Contents/Info.plist"
for key in CFBundleName CFBundleDisplayName; do
  got=$(plutil -extract "$key" raw -o - "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo '(missing)')
  [[ "$got" == "$APP_NAME" ]] || { echo "$key is '$got', expected '$APP_NAME'."; exit 1; }
done
plutil -extract CFBundleShortVersionString raw -o - "$APP_PATH/Contents/Info.plist" >/dev/null \
  || { echo "The built app has no version."; exit 1; }
[[ "$BUILD" == $(plutil -extract CFBundleVersion raw -o - "$APP_PATH/Contents/Info.plist") ]] \
  || { echo "The built app's version didn't pick up the bump."; exit 1; }

echo "==> Signing ad-hoc"
# Stripped before signing, since signing has to come after any change to the binary. A Release build still
# carries ~19 MB of symbol tables on top of its 9.7 MB of code, and there's no dSYM shipped to match them
# against — they only make the download bigger.
strip -x "$APP_PATH/Contents/MacOS/$APP"
codesign --force --sign - "$APP_PATH"
codesign --verify --verbose=2 "$APP_PATH"

echo "==> Building the DMG"
STAGE="$WORK/dmg"
mkdir -p "$STAGE"
# Named as the fork, so a Mac holding both editions shows two distinguishable apps.
cp -R "$APP_PATH" "$STAGE/$APP_NAME.app"
codesign --force --sign - "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"
# Built on the boot volume, then copied out. hdiutil locking a sparse image on an external or network
# volume fails with "resource busy" often enough to be worth routing around, and this project sits on one.
DMG_STAGED="$WORK/$NAME-$VERSION.dmg"
rm -f "$DMG_STAGED"
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$STAGE" -ov -format UDZO -o "$DMG_STAGED" >/dev/null

# The new image only replaces the old ones once it exists, so a failed hdiutil can't empty the Desktop.
for dest in "$DIST" "$DESKTOP_DIR"; do
  [[ -n "$dest" ]] || continue
  mkdir -p "$dest"
  # The previous DMG goes first: two builds sitting side by side invite the wrong double-click.
  # (N) so an empty match isn't an error, which is zsh's default.
  rm -f "$dest"/$NAME-*.dmg(N)
  cp -f "$DMG_STAGED" "$dest/"
done

SIZE=$(du -sh "$DMG_STAGED" | awk '{print $1}')
echo "==> Done: $DIST/$NAME-$VERSION.dmg ($SIZE)"
if [[ -n "$DESKTOP_DIR" ]]; then
  echo "        $DESKTOP_DIR/$NAME-$VERSION.dmg"
fi
echo "On another Mac: right-click the app > Open, then Open again in the dialog."
