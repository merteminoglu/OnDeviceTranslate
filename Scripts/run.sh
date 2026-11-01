#!/bin/bash
#
# Build, replace any running copy, and relaunch.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/Translate.app"

"$ROOT/Scripts/build.sh"

echo "==> Restarting"
pkill -x OnDeviceTranslate 2>/dev/null || true
sleep 0.3
open "$APP"
