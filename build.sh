#!/bin/bash
# Builds "Storage Cleaner.app" and installs it into ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/Storage Cleaner.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/StorageCleaner "$APP/Contents/MacOS/StorageCleaner"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"

mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/Storage Cleaner.app"
cp -R "$APP" "$HOME/Applications/"
echo "Installed: $HOME/Applications/Storage Cleaner.app"
