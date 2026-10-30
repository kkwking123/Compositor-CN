#!/bin/zsh
# Xcode's license gate keeps xcodebuild away, but the Command Line Tools' swiftc is usable, and a
# type-check is what actually answers the question left open all session: whether 426 added `.localized`
# calls are type-correct. Type-checking needs no SDK version match, no asset catalog and no linking —
# just every source file, the bridging header, and the project's own deployment target of 26.0.
set -u
ROOT="/Volumes/极空间HD/AI编程/coder/PS-compositor"
CLT=/Library/Developer/CommandLineTools
SDK=$CLT/SDKs/MacOSX.sdk
cd "$ROOT" || exit 1

# The app target only: tests are separate targets with their own sources.
# Sparkle comes from SPM and isn't downloaded, so its three importers are left out unless a stub
# module has been built (see stub_sparkle.sh); leaving them out is a real gap, not a clean pass.
find Compositor -name '*.swift' \
    ! -path '*/CompositorTests/*' ! -path '*/CompositorUITests/*' | sort > /tmp/l10n_sources.txt
if [ ! -d /tmp/l10n_stub ]; then
    grep -v -e '/CompositorApp.swift' -e '/CompositorApplicationDelegate.swift' -e '/UpdateDriver.swift' \
        /tmp/l10n_sources.txt > /tmp/l10n_sources_used.txt
    mv /tmp/l10n_sources_used.txt /tmp/l10n_sources.txt
fi

echo "sources: $(wc -l < /tmp/l10n_sources.txt)"
echo "headers: $(ls Compositor/Rendering/*.h | wc -l)"

STUB=()
[ -d /tmp/l10n_stub ] && STUB=(-I /tmp/l10n_stub)

$CLT/usr/bin/swiftc \
    -typecheck \
    -sdk "$SDK" \
    -target arm64-apple-macosx26.0 \
    -module-name Compositor \
    -import-objc-header Compositor/Compositor-Bridging-Header.h \
    -swift-version 5 \
    "${STUB[@]}" \
    @/tmp/l10n_sources.txt 2>&1 | head -80

echo "swiftc exit: ${pipestatus[1]}"
