#!/bin/zsh
# Wraps the probe in a bundle that carries the *built app's* .lproj folders verbatim, so the lookup
# runs against Xcode's converted UTF-16 tables and an argument domain that Foundation can read at start.
set -eu
X=/Applications/Xcode.app/Contents/Developer
TC=$X/Toolchains/XcodeDefault.xctoolchain
SDK=$X/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
REPO=/Volumes/极空间HD/AI编程/coder/PS-compositor
SRC=$REPO/dist/Compositor.app/Contents/Resources
APP=/tmp/wrapcheck/Check.app

rm -rf /tmp/wrapcheck; mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
cp -R $SRC/en.lproj $SRC/zh-Hans.lproj $APP/Contents/Resources/
printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
  '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
  '<plist version="1.0"><dict>' \
  '<key>CFBundleExecutable</key><string>Check</string>' \
  '<key>CFBundleIdentifier</key><string>local.test.wrapcheck</string>' \
  '<key>CFBundlePackageType</key><string>APPL</string>' \
  '<key>CFBundleDevelopmentRegion</key><string>en</string>' \
  '</dict></plist>' > $APP/Contents/Info.plist

$TC/usr/bin/swiftc $REPO/l10n/probe_built_bundle.swift -sdk "$SDK" -target arm64-apple-macosx26.0 \
  -o $APP/Contents/MacOS/Check
for lang in zh-Hans en; do
  print -u2 "########## $lang ##########"
  $APP/Contents/MacOS/Check $APP -AppleLanguages "$lang"
done
