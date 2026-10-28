#!/bin/bash
# Builds "SafeSweep.app" and installs it into ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/SafeSweep.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/SafeSweep "$APP/Contents/MacOS/SafeSweep"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"

mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/SafeSweep.app"
cp -R "$APP" "$HOME/Applications/"
echo "Installed: $HOME/Applications/SafeSweep.app"
