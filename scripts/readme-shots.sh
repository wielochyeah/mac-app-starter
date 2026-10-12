#!/bin/zsh
# make readme-shots: copies the pictures listed in docs/screenshots/list.txt into docs/screenshots/
# for README.md, each at most README_MAX_WIDTH pixels wide (default 1200; the renders are 2x, so a
# whole window comes out at about 1x), so the repository stays small. Never touches App/Resources.
#
# Entries, one per line (# starts a comment):
#   <lang>-<appearance>/<scene>.png   a render from build/shots (make shots first)
#   tools/icon.png                    the app icon on a light and a dark ground (tools/icon/Icon.swift)
#   tools/dmg.png                     the DMG window with its background (tools/dmg/Background.swift)
# "de-light/window.main.png" becomes docs/screenshots/de-light-window.main.png.
# Downscaling uses sips (part of macOS); a picture already narrow enough is copied as it is.
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"
LIST=docs/screenshots/list.txt
MAX="${README_MAX_WIDTH:-1200}"
[[ -f "$LIST" ]] || { print "readme-shots: $LIST is not yet available (skipped)"; exit 0; }
command -v sips >/dev/null || { print -u2 "readme-shots: sips missing (part of macOS)"; exit 1; }

WORK="$ROOT/build/readme-shots"

# The packaging tools draw icon and DMG previews with the project's accent, symbol and names.
if grep -q '^[[:space:]]*tools/' "$LIST"; then
  source tools/lib/packaging.sh
  pkg_env
  build_tool icon tools/icon/Icon.swift
  build_tool dmg-background tools/dmg/Background.swift tools/dmg/DMGText.swift
  mkdir -p "$WORK"
fi

# Prints the path of the picture for one list entry, rendering tool pictures on the way.
source_of() {
  local entry="$1"
  case "$entry" in
    tools/icon.png)
      build/tools/icon preview "$WORK/icon.png" --accent "$PKG_ACCENT" --symbol "$PKG_SYMBOL" >/dev/null
      print -r -- "$WORK/icon.png" ;;
    tools/dmg.png)
      local args=(--out "$WORK/dmg" --layout tools/dmg/layout.json --icon App/Resources/AppIcon.icns
                  --name "$PKG_DISPLAY_EN" --name-de "$PKG_DISPLAY_DE" --app-label "$PKG_DISPLAY_EN" --app-label-de "$PKG_DISPLAY_DE"
                  --version "$PKG_VERSION" --min-macos "$PKG_MIN_MACOS" --accent "$PKG_ACCENT" --lang "$PKG_DMG_LANG" --anrede "$PKG_ANREDE")
      [[ "$PKG_NOTARIZE" == 1 ]] && args+=(--no-hint)
      build/tools/dmg-background "${args[@]}" >/dev/null
      print -r -- "$WORK/dmg/preview.png" ;;
    tools/*)
      return 1 ;;
    *)
      print -r -- "build/shots/$entry" ;;
  esac
}

missing=0
while IFS= read -r line; do
  line="${line%%#*}"
  line="${line//[[:space:]]/}"
  [[ -z "$line" ]] && continue
  if ! src="$(source_of "$line")"; then
    print -u2 "readme-shots: unknown tool picture $line (tools/icon.png or tools/dmg.png)"; missing=1; continue
  fi
  if [[ ! -f "$src" ]]; then
    print -u2 "readme-shots: missing $src (make shots)"; missing=1; continue
  fi
  dest="docs/screenshots/${line//\//-}"
  width="$(sips -g pixelWidth "$src" | awk '/pixelWidth/ { print $2 }')"
  if (( width > MAX )); then
    sips --resampleWidth "$MAX" "$src" --out "$dest" >/dev/null
  else
    cp "$src" "$dest"
  fi
  print "readme-shots: $dest ($(sips -g pixelWidth -g pixelHeight "$dest" | awk '/pixel/ { printf "%s ", $2 }')px, $(( $(stat -f %z "$dest") / 1024 )) KB)"
done < "$LIST"
exit $missing
