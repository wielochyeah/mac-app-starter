#!/bin/zsh
# Builds, quits a running copy and opens build/<Name>.app. For people (and the lead), never for
# automated checks: it shows windows and may ask for permissions.
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"
scripts/build.sh
source build/gen/app.env
APP="$ROOT/build/$APP_NAME.app"
# quit only the copy started from this checkout
pkill -f "$APP/Contents/MacOS/$APP_NAME" 2>/dev/null && sleep 0.5 || true
open "$APP"
