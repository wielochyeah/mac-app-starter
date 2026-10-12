#!/bin/zsh
# Renders the app icon from tools/icon/Icon.swift with app.accent and app.symbol (starter.json)
# and writes App/Resources/AppIcon.icns (committed; build.sh copies it into the bundle).
#   ICON_OUT=<file.icns>   write somewhere else (e.g. to try an accent without touching the repo)
#   ICON_ACCENT=… ICON_SYMBOL=…   override starter.json for one run
# Also writes build/icon/{preview,smallcheck,dock}.png to look at. No network, nothing installed.
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"
source tools/lib/packaging.sh
pkg_env
for tool in iconutil; do command -v $tool >/dev/null || { print -u2 "icon: $tool missing (xcode-select --install)"; exit 1; }; done

accent="${ICON_ACCENT:-$PKG_ACCENT}"
symbol="${ICON_SYMBOL:-$PKG_SYMBOL}"
out="${ICON_OUT:-App/Resources/AppIcon.icns}"
work="build/icon"

build_tool icon tools/icon/Icon.swift
build/tools/icon selftest --symbol "$symbol" >/dev/null
rm -rf "$work/AppIcon.iconset"
mkdir -p "$work"
opts=(--accent "$accent" --symbol "$symbol")
build/tools/icon iconset "$work/AppIcon.iconset" "${opts[@]}"
build/tools/icon preview "$work/preview.png" "${opts[@]}"
build/tools/icon smallcheck "$work/smallcheck.png" "${opts[@]}"

mkdir -p "${out:h}"
iconutil -c icns "$work/AppIcon.iconset" -o "$work/AppIcon.icns"
mv -f "$work/AppIcon.icns" "$out"
build/tools/icon dock "$work/dock.png" self "$out" "${opts[@]}"
print "icon: $out ($accent, $symbol, $(( $(stat -f %z "$out") / 1024 )) KB); previews in $work/"
