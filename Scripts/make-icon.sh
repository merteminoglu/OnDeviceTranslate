#!/bin/bash
#
# Regenerates Resources/AppIcon.icns from Scripts/render-icon.swift. Not part of
# the normal build; run it after changing the artwork and keep the result.
#
# render-icon.swift writes the ICNS container itself, so packaging does not
# depend on iconutil's image-conversion service.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/build/icon"
cd "$ROOT"

rm -rf "$WORK"
mkdir -p "$WORK"
xcrun swiftc -O Scripts/render-icon.swift -o "$WORK/render-icon"
"$WORK/render-icon" "$WORK/AppIcon.iconset" "$ROOT/Resources/AppIcon.icns"
rm -rf "$WORK"
echo "==> Wrote Resources/AppIcon.icns"
