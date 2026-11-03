#!/bin/zsh
# Publishes the packages that scripts/release-local.sh (or release.sh) built: a GitHub Release holding the PKG and
# the DMG, along with the source archives GitHub makes on its own. There is no update feed — this fork has no
# updater.
#
# Run one of the release scripts first, and have `gh` signed in. The PKG goes up first, because it is the one that
# opens with a double-click; the DMG is for people who would rather drag the app themselves.
#
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
DMG="$DIST/$NAME-$VERSION.dmg"
PKG="$DIST/$NAME-$VERSION.pkg"
artifacts=()
if [[ -f "$PKG" ]]; then artifacts+=("$PKG"); fi
if [[ -f "$DMG" ]]; then artifacts+=("$DMG"); fi
(( ${#artifacts} )) || { echo "No $NAME-$VERSION.{pkg,dmg} in dist/ — run scripts/release-local.sh first."; exit 1; }
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "Release $TAG already exists. Raise REVISION (or the version) first."
  exit 1
fi

echo "==> $NAME $VERSION ($BUILD), $TAG"
changes=("${(@f)${RELEASE_NOTES:-}}")
changes=(${changes:#})
notes="$NAME $VERSION，基于上游 $VERSION。装 .pkg（会自动清除下载属性，装完双击就能开）；想自己拖进「应用程序」的话下载 .dmg，首次启动需右键「打开」。"
(( ${#changes} )) && notes=$(printf -- '- %s\n' "${changes[@]}")

echo "==> Creating GitHub Release $TAG"
gh release create "$TAG" "${artifacts[@]}" --repo "$REPO" \
  --title "$NAME $VERSION" --notes "$notes" --target main

echo "==> Done: https://github.com/$REPO/releases/tag/$TAG"
