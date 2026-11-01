#!/bin/bash
#
# Builds and opens "Translate UI Preview.app": the production views and core
# wired to a fake engine (Tests/NativeUIHarness/PreviewService.swift), for
# checking the native UI on a Mac without the language packs. Its only
# translations are "Hallo.\nHoe gaat het?" <-> "Hello.\nHow are you?".
# Never shipped; it does not exercise Apple's engine.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/Translate UI Preview.app"
cd "$ROOT"

echo "==> Compiling core"
swift build --product OnDeviceTranslate
PRODUCTS="$(swift build --show-bin-path)"

echo "==> Compiling preview app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
xcrun swiftc -parse-as-library -swift-version 6 -target "$(uname -m)-apple-macos26.0" \
    -I "$PRODUCTS" "$PRODUCTS/TranslateCore.o" \
    Sources/OnDeviceTranslate/OnDeviceTranslateApp.swift \
    Sources/OnDeviceTranslate/TranslatorView.swift \
    Sources/OnDeviceTranslate/NativeTextEditor.swift \
    Sources/OnDeviceTranslate/LanguageSetupView.swift \
    Tests/NativeUIHarness/PreviewService.swift \
    -o "$APP/Contents/MacOS/OnDeviceTranslate"

cp Resources/Info.plist "$APP/Contents/Info.plist"
PLIST="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier local.OnDeviceTranslate.UIPreview' "$PLIST"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName Translate UI Preview' "$PLIST"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Translate UI Preview' "$PLIST"
/usr/libexec/PlistBuddy -c 'Delete :CFBundleIconFile' "$PLIST"
codesign --force --sign - --entitlements Resources/Translate.entitlements "$APP"

echo "==> Opening $APP"
pkill -f "Translate UI Preview.app/Contents/MacOS" 2>/dev/null || true
sleep 0.3
open "$APP"
