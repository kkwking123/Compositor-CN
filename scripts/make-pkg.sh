#!/bin/zsh
# Wraps an app bundle in a .pkg that installs to /Applications and clears the download attributes on the way in,
# so the app opens with a double-click on any Mac — no right-click > Open, no trip to Terminal.
#
#   ./scripts/make-pkg.sh <path to .app> <file name> <version> <output .pkg>
#
# Only the package gets built here; signing, notarizing and placing the finished file are the caller's business
# (scripts/release-local.sh and scripts/release.sh both call this after they have a finished app).
#
# The work happens under ~/Library/Caches, on the boot volume: pkgbuild locking a half-written package on an
# external or network volume fails with "resource busy" often enough to be worth routing around, which is the
# same reason the DMG is built there.
set -euo pipefail

[[ $# == 4 ]] || { echo "usage: $0 <app> <file name> <version> <out.pkg>"; exit 1; }
APP=${1:a}
NAME=$2
VERSION=$3
OUT=${4:a}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
[[ -d "$APP" ]] || { echo "No $APP — nothing to package."; exit 1; }
[[ "$OUT" == *.pkg ]] || { echo "$OUT should end in .pkg"; exit 1; }

APP_NAME=$(basename "$APP")
BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw -o - "$APP/Contents/Info.plist")
WORK=$(mktemp -d "$HOME/Library/Caches/CompositorPkg.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# A package installs its payload relative to the volume the person picks, so the folder holding the app has to
# be named the way it is under that volume.
mkdir -p "$WORK/payload/Applications" "$WORK/scripts"
ditto "$APP" "$WORK/payload/Applications/$APP_NAME"
# A stale quarantine on this machine's copy would otherwise ride all the way along in the package.
xattr -r -d com.apple.quarantine "$WORK/payload/Applications/$APP_NAME" 2>/dev/null || true

# Installer will not run a script that group or other may write, and a volume mounted without the usual Unix
# permissions (this repository lives on one) hands out files that are. The ownership recorded in the package is
# pkgbuild's default "recommended" — root:wheel, which is what a system install wants and what lets the
# postinstall run at all.
chmod -R a+rX,go-w "$WORK/payload"
sed "s|__APP_NAME__|$APP_NAME|" "$SCRIPT_DIR/pkg/postinstall" > "$WORK/scripts/postinstall"
chmod 755 "$WORK/scripts/postinstall"
# A component package is what Installer opens on a double-click, and it carries the payload, the scripts and the
# version in one file — no distribution step, and nothing to keep in sync between two documents. The file is
# written on the boot volume and copied out at the end, so a failure can't leave a half-made package in place.
mkdir -p "$(dirname "$OUT")"
STAGED="$WORK/$NAME-$VERSION.pkg"
pkgbuild \
  --root "$WORK/payload" \
  --install-location / \
  --ownership recommended \
  --scripts "$WORK/scripts" \
  --identifier "$BUNDLE_ID" \
  --version "$VERSION" \
  "$STAGED"
cp -f "$STAGED" "$OUT"

# Two things have to be true before the package is worth handing to anyone: the app is in the payload, and the
# script that clears the download attributes came along with it.
pkgutil --expand "$OUT" "$WORK/check"
[[ -n $(find "$WORK/check" -name postinstall -print) ]] || {
  echo "The package has no postinstall script — the app would still need right-click > Open."
  exit 1
}
[[ -n $(pkgutil --payload-files "$OUT" | grep "/$APP_NAME/Contents/MacOS/") ]] || {
  echo "The package payload has no executable for $APP_NAME."
  exit 1
}
echo "==> Package contents"
pkgutil --payload-files "$OUT" | sed -n '1,3p'
echo "    $(du -sh "$OUT" | awk '{print $1}')"
