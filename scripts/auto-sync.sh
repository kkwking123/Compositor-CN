#!/bin/sh
# Pushes this working copy to GitHub every three days, and only when something actually changed.
# Installed as a launchd agent — see launchd/com.kkwking.compositor-cn.auto-sync.plist.
#
# The build check is the point of the script: a half-finished edit is normal in this working copy, sometimes
# while another task is still writing files, so nothing goes to the repository until it compiles.

set -eu

REPO="${REPO:-/Volumes/极空间HD/AI编程/coder/PS-compositor}"
BRANCH="${BRANCH:-main}"
NAME="${NAME:-kkwking123}"
EMAIL="${EMAIL:-11344156+kkwking123@users.noreply.github.com}"
BUILD="$REPO/.build-autosync"
BUILD_LOG="$REPO/.build-autosync.log"
LOG="$REPO/.git/auto-sync.log"

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG"
}

cd "$REPO" 2>/dev/null || { echo "no repository at $REPO" >&2; exit 1; }

# Nothing changed since the last commit: leave the repository alone.
if git diff --quiet HEAD && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    log "no changes; skipped"
    exit 0
fi

if ! xcodebuild -project Compositor.xcodeproj -scheme Compositor -configuration Debug \
        -derivedDataPath "$BUILD" CODE_SIGN_IDENTITY=- build > "$BUILD_LOG" 2>&1; then
    log "build failed; nothing committed — see $BUILD_LOG"
    exit 1
fi

git add -A
COUNT=$(git diff --cached --numstat | wc -l | tr -d ' ')
if [ "$COUNT" = "0" ]; then
    log "changes were only whitespace; skipped"
    exit 0
fi

git -c user.name="$NAME" -c user.email="$EMAIL" commit -q \
    -m "Auto-sync $(date '+%Y-%m-%d'): $COUNT file(s)" \
    -m "Committed by the scheduled sync after a successful build. Review it and amend the message if it" \
    -m "deserves better than this — the history is yours, not the robot's."

if git push -q origin "$BRANCH"; then
    log "pushed $COUNT file(s)"
else
    log "push failed; the commit stays local and will be retried next run"
    exit 1
fi
