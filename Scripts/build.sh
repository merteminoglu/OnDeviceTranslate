#!/bin/bash
#
# Builds Translate.app.
#
# The bundle is assembled by hand rather than through an .xcodeproj: SwiftPM
# produces the binary, codesign the signature. The icon is the checked-in
# Resources/AppIcon.icns; Scripts/make-icon.sh regenerates it.
#
# The entitlements matter: they turn on the App Sandbox with no network
# client/server access, which is what guarantees translation stays offline.
# Running the bare SwiftPM binary (or from Xcode) skips them.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${CONFIG:-release}"
APP="$ROOT/build/Translate.app"

cd "$ROOT"

echo "==> Compiling ($CONFIG)"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/OnDeviceTranslate"

echo "==> Assembling bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/OnDeviceTranslate"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
plutil -lint -s "$APP/Contents/Info.plist"

# Ad-hoc is enough: the app needs no privacy grant (Accessibility, Screen
# Recording…) that macOS would tie to a stable signature.
echo "==> Signing ad-hoc with sandbox entitlements"
codesign --force --sign - --entitlements "$ROOT/Resources/Translate.entitlements" "$APP"
codesign --verify --strict "$APP"

echo "==> Built $APP"
