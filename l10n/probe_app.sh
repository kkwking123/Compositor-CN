#!/bin/zsh
# Assembles a throwaway .app around probe_runtime.swift and runs it in each language, from inside the bundle
# so Bundle.main is a real app bundle with en.lproj and zh-Hans.lproj — the same shape the app's resources end
# up in. This is the part a type-check can't reach: whether the table is found at all once the process says it
# prefers Chinese, and whether every format string renders instead of trapping.
set -u
ROOT="/Volumes/极空间HD/AI编程/coder/PS-compositor"
X=/Applications/Xcode.app/Contents/Developer
TC=$X/Toolchains/XcodeDefault.xctoolchain
SDK=$X/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
APP=/tmp/l10n_probe_app/Probe.app
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources/en.lproj $APP/Contents/Resources/zh-Hans.lproj

cat > $APP/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
 <key>CFBundleExecutable</key><string>probe</string>
 <key>CFBundleIdentifier</key><string>local.l10n.probe</string>
 <key>CFBundlePackageType</key><string>APPL</string>
 <key>CFBundleDevelopmentRegion</key><string>en</string>
 <key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string></array>
</dict></plist>
PLIST

cp "$ROOT/Compositor/en.lproj/Localizable.strings" $APP/Contents/Resources/en.lproj/
cp "$ROOT/Compositor/zh-Hans.lproj/Localizable.strings" $APP/Contents/Resources/zh-Hans.lproj/

$TC/usr/bin/swiftc -sdk "$SDK" -target arm64-apple-macosx26.0 -O \
    -o $APP/Contents/MacOS/probe "$ROOT/l10n/probe_runtime.swift" || { echo "probe build failed"; exit 1; }

for lang in en zh-Hans; do
    echo "════════ AppleLanguages = ($lang) ════════"
    $APP/Contents/MacOS/probe -AppleLanguages "($lang)"
done
echo "════════ 无覆盖（跟随本机语言）════════"
$APP/Contents/MacOS/probe
