#!/bin/sh
set -e
cd "$(dirname "$0")"
APP=SafariSwipe.app
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/"
swiftc -swift-version 5 main.swift -o "$APP/Contents/MacOS/SafariSwipe"
"$APP/Contents/MacOS/SafariSwipe" --selftest
codesign --force -s - "$APP"
echo "Built $PWD/$APP"
