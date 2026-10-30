#!/bin/zsh
# Publishes the DMG that scripts/release-local.sh (or release.sh) built: a GitHub Release holding it, along with
# the source archives GitHub makes on its own. There is no update feed — this fork has no updater.
#
# Run one of the release scripts first, and have `gh` signed in.
# Release notes, a change a line: RELEASE_NOTES=$'First change\nSecond change' ./scripts/publish.sh
# The revision number marks this fork's releases, which share the upstream version: REVISION=2 makes v1.5.12-cn.2.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP=Compositor
NAME=Compositor-CN
REPO=kkwking123/Compositor-CN
DIST="$PROJECT_DIR/dist"

settings=$(xcodebuild -project "$PROJECT_DIR/$APP.xcodeproj" -scheme "$APP" -configuration Release -showBuildSettings 2>/dev/null)
VERSION=$(print -r -- "$settings" | awk -F' = ' '/ MARKETING_VERSION = /{print $2; exit}')
BUILD=$(print -r -- "$settings" | awk -F' = ' '/ CURRENT_PROJECT_VERSION = /{print $2; exit}')
REVISION="${REVISION:-1}"
TAG="v$VERSION-cn.$REVISION"
SOURCE="$DIST/$NAME-$VERSION.dmg"
[[ -f "$SOURCE" ]] || { echo "No $SOURCE — run scripts/release-local.sh first."; exit 1; }
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "Release $TAG already exists. Raise REVISION (or the version) first."
  exit 1
fi

echo "==> $NAME $VERSION ($BUILD), $TAG"
changes=("${(@f)${RELEASE_NOTES:-}}")
changes=(${changes:#})
notes="$NAME $VERSION，基于上游 $VERSION。"
(( ${#changes} )) && notes=$(printf -- '- %s\n' "${changes[@]}")

echo "==> Creating GitHub Release $TAG"
gh release create "$TAG" "$SOURCE" --repo "$REPO" \
  --title "$NAME $VERSION" --notes "$notes" --target main

echo "==> Done: https://github.com/$REPO/releases/tag/$TAG"
