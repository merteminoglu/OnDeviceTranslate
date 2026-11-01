#!/bin/bash
#
# Builds Translate from source and installs it into /Applications.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/build/Translate.app"
DEST="/Applications/Translate.app"
STAGE="/Applications/.Translate.app.incoming"
BUNDLE_ID="local.OnDeviceTranslate"

"$ROOT/Scripts/build.sh"

echo "==> Installing to $DEST"
if [ ! -w /Applications ]; then
  echo "    /Applications isn't writable by this account."
  echo "    Re-run with: sudo $0"
  exit 1
fi

# "Translate" is a generic name: never replace an app that isn't this one.
if [ -d "$DEST" ]; then
  EXISTING="$(defaults read "$DEST/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
  if [ "$EXISTING" != "$BUNDLE_ID" ]; then
    echo "    $DEST belongs to '$EXISTING', not $BUNDLE_ID. Leaving it alone."
    exit 1
  fi
fi

# Stage beside the target and swap, rather than deleting first: a failed copy
# then leaves the existing install untouched.
rm -rf "$STAGE"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$SOURCE" "$STAGE"

pkill -x OnDeviceTranslate 2>/dev/null || true
sleep 0.3

rm -rf "$DEST"
mv "$STAGE" "$DEST"
codesign --verify --strict "$DEST"

open "$DEST"
echo "==> Installed and running from /Applications."
