#!/bin/bash
# Builds SafeSweep.app.
#
#   ./build.sh             Build for this Mac and install into ~/Applications
#   ./build.sh --package   Build a universal (Apple Silicon + Intel) app and package
#                          it as build/SafeSweep.dmg and build/SafeSweep.zip
#
# VERSION=1.2.0 ./build.sh --package   overrides the version from Info.plist.
set -euo pipefail
cd "$(dirname "$0")"

MODE="${1:-install}"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)}"
APP="build/SafeSweep.app"

if [[ "$MODE" == "--package" ]]; then
    BUILD_FLAGS=(-c release --arch arm64 --arch x86_64)
else
    BUILD_FLAGS=(-c release)
fi
swift build "${BUILD_FLAGS[@]}"
# The output folder differs between Swift versions; ask SwiftPM where it is.
BINARY="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)/SafeSweep"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/SafeSweep"
cp Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"

if [[ "$MODE" == "--package" ]]; then
    STAGE="build/dmg"
    rm -rf "$STAGE" build/SafeSweep.dmg build/SafeSweep.zip
    mkdir -p "$STAGE"
    cp -R "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname "SafeSweep $VERSION" -srcfolder "$STAGE" -ov -format UDZO build/SafeSweep.dmg
    ditto -c -k --keepParent "$APP" build/SafeSweep.zip
    rm -rf "$STAGE"
    echo "Packaged SafeSweep $VERSION: build/SafeSweep.dmg, build/SafeSweep.zip"
else
    mkdir -p "$HOME/Applications"
    rm -rf "$HOME/Applications/SafeSweep.app"
    cp -R "$APP" "$HOME/Applications/"
    echo "Installed: $HOME/Applications/SafeSweep.app"
fi
