#!/bin/zsh
# Renders every RenderScene to build/shots/<lang>-<appearance>/<id>.png (+ index.html when all).
#   ONLY=design.        only scenes whose id starts with this
#   SHOTS_LANG=de       only this language      SHOTS_APPEARANCE=dark   only this appearance
#   NO_BUILD=1          use the existing build/<Name>.app
# Runs the app binary with --render under STARTER_HEADLESS=1: nothing appears on screen.
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"
[[ "${NO_BUILD:-0}" == 1 ]] || scripts/build.sh
source build/gen/app.env
BIN="build/$APP_NAME.app/Contents/MacOS/$APP_NAME"
[[ -x "$BIN" ]] || { print -u2 "render.sh: $BIN missing (make build)"; exit 1; }
OUT="$ROOT/build/shots"
args=(--render "$OUT")
[[ -n "${ONLY:-}" ]] && args+=(--only "$ONLY")
[[ -n "${SHOTS_LANG:-}" ]] && args+=(--lang "$SHOTS_LANG")
[[ -n "${SHOTS_APPEARANCE:-}" ]] && args+=(--appearance "$SHOTS_APPEARANCE")
# a full render starts clean so removed scenes do not linger
if [[ -z "${ONLY:-}${SHOTS_LANG:-}${SHOTS_APPEARANCE:-}" ]]; then rm -rf "$OUT"; fi
mkdir -p "$OUT"
STARTER_HEADLESS=1 STARTER_DATA_DIR="$ROOT/build/render-data" "$BIN" "${args[@]}"
