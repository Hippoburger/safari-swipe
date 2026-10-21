#!/bin/sh
set -e
cd "$(dirname "$0")"
APP=SafariSwipe.app
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/"
mkdir -p "$APP/Contents/Resources"
TMP=$(mktemp -d)
swift icon.swift "$TMP"
iconutil -c icns "$TMP/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$TMP"
swiftc -swift-version 5 -target arm64-apple-macos13 main.swift -o "$APP/Contents/MacOS/SafariSwipe"
"$APP/Contents/MacOS/SafariSwipe" --selftest
codesign --force -s - "$APP"
echo "Built $PWD/$APP"
