#!/bin/zsh
# A type-check alone can't tell "my edit broke it" from "the beta SDK always complained about this".
# So the same swiftc run is done against a clean worktree of HEAD and the two error sets are compared,
# ignoring line numbers, which shift as soon as a line is added. What appears only in the current tree
# is attributable to this session's changes; what appears in both was already there.
set -u
ROOT="/Volumes/极空间HD/AI编程/coder/PS-compositor"
BASE=/tmp/l10n_baseline
# Not the Command Line Tools: they carry no SwiftUIMacros plugin, so every @State failed to expand and the
# run reported 722 errors that no real build would see. Xcode's own swiftc runs fine even while its license
# blocks xcodebuild, and it resolves the macros the way the app target does — which makes this a type-check
# worth trusting rather than a noise generator.
X=/Applications/Xcode.app/Contents/Developer
TC=$X/Toolchains/XcodeDefault.xctoolchain
SDK=$X/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
HEAD_SHA=$(/Library/Developer/CommandLineTools/usr/bin/git -C "$ROOT" rev-parse HEAD)
# Checked up front, because a wrong path here looks exactly like a clean build: the command isn't found,
# nothing is reported, and the comparison below would say "no new errors".
[ -x $TC/usr/bin/swiftc ] || { echo "no compiler at $TC/usr/bin/swiftc"; exit 1; }
[ -d "$SDK" ] || { echo "no SDK at $SDK"; exit 1; }

# Sources, flags and everything else are identical between the two runs; only the tree differs.
# The stub stands in for Sparkle in both runs, so its three importers are checked rather than dropped.
mkdir -p /tmp/l10n_stub
$TC/usr/bin/swiftc -emit-module -module-name Sparkle -sdk "$SDK" \
    -target arm64-apple-macosx26.0 -o /tmp/l10n_stub/Sparkle.swiftmodule \
    "$ROOT/l10n/SparkleStub.swift" 2>&1 | head -20
[ -f /tmp/l10n_stub/Sparkle.swiftmodule ] || { echo "stub failed"; exit 1; }
echo "stub: ok"

# Flags are taken from the project itself, not guessed: the target sets SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor,
# SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES and builds Debug. Left out, the isolation default made
# hundreds of honest-looking errors appear that the real build never sees.
FLAGS=(-typecheck -force-single-frontend-invocation -sdk "$SDK" -target arm64-apple-macosx26.0
       -default-isolation MainActor -enable-upcoming-feature MemberImportVisibility
       -D DEBUG -module-name Compositor -I /tmp/l10n_stub -swift-version 5)

run() {
    local tree=$1 out=$2
    cd "$tree" || return 1
    find Compositor -name '*.swift' \
        ! -path '*/CompositorTests/*' ! -path '*/CompositorUITests/*' | sort > /tmp/l10n_cmp_src.txt
    echo "  sources: $(wc -l < /tmp/l10n_cmp_src.txt)"
    $TC/usr/bin/swiftc "${FLAGS[@]}" \
        -import-objc-header Compositor/Compositor-Bridging-Header.h \
        @/tmp/l10n_cmp_src.txt > "$out.raw" 2>&1
    echo "  exit: $?  error lines: $(grep -c ' error: ' "$out.raw")"
    # Only the structured `File:line:col: error:` lines. The caret-quoted snippets repeat the same message,
    # and their leading spaces shift with the column — which made the last diff look like errors had moved
    # when only the caret had. file + message + count, positions dropped as they shift with every edit.
    grep ' error: ' "$out.raw" | grep -v '^[[:space:]]' | sed -E 's/:[0-9]+:[0-9]+: error:/| error:/' | sort | uniq -c > "$out"
    grep -c ' error: ' "$out.raw" > "$out.total"
}

if [ -d $BASE ]; then
    /Library/Developer/CommandLineTools/usr/bin/git -C $BASE checkout -f "$HEAD_SHA" 2>&1 | head -2
else
    /Library/Developer/CommandLineTools/usr/bin/git -C "$ROOT" worktree add --detach $BASE "$HEAD_SHA" 2>&1 | tail -2
fi

echo "== baseline (HEAD $HEAD_SHA) =="
run $BASE /tmp/l10n_err_base.txt
echo "== current =="
run "$ROOT" /tmp/l10n_err_cur.txt

# Self-check, and the reason it's here: an earlier run of this script said "no new errors" while it was in
# fact type-checking two files out of 182. A clean report and an empty report look the same, so prove the
# checker sees an edited file by breaking a copy of the tree — never the tree itself.
PROBE=/tmp/l10n_probe_tree
rsync -a --delete "$ROOT/Compositor/" $PROBE/Compositor/ 2>/dev/null || cp -R "$ROOT/Compositor" $PROBE/Compositor
echo 'let l10nHarnessProbe: Int = "deliberately wrong"' >> $PROBE/Compositor/CompositorApp.swift
cd $PROBE || exit 1
find Compositor -name '*.swift' > /tmp/l10n_probe_src.txt
$TC/usr/bin/swiftc "${FLAGS[@]}" \
    -import-objc-header Compositor/Compositor-Bridging-Header.h \
    @/tmp/l10n_probe_src.txt > /tmp/l10n_probe_out.raw 2>&1
if grep -q 'l10nHarnessProbe' /tmp/l10n_probe_out.raw; then
    echo "harness: verified — a planted error in an edited file is caught"
else
    echo "harness: NOT VERIFYING ERRORS — the comparison below means nothing"; exit 1
fi

echo
echo "baseline errors: $(cat /tmp/l10n_err_base.txt.total)   current errors: $(cat /tmp/l10n_err_cur.txt.total)"
echo
echo "### 错误清单的差异（< 基线，> 当前）###"
diff <(sort -k2 /tmp/l10n_err_base.txt) <(sort -k2 /tmp/l10n_err_cur.txt) | head -60
echo
echo "### 当前树里报错最多的文件（前 15）###"
awk '{n=$1; $1=""; sub(/^\t?/,""); split($0,a,"|"); c[a[1]]+=n} END{for(f in c) print c[f], f}' /tmp/l10n_err_cur.txt | sort -rn | head -15
