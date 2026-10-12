#!/bin/zsh
# Builds build/dmg/<Name>-<version>.dmg: release build, designed Finder window (app left,
# Applications right, background from tools/dmg/Background.swift), volume icon, compressed.
#   MODULES=a,b           module override, as for make build
#   DMG_LANG=en|de|both   language of the window texts (default: both when the project has both)
#   DMG_FORMAT=ULMO|UDZO  compression (default ULMO = lzma, smallest; falls back to UDZO)
#   NO_BUILD=1            package the existing build/<Name>.app (must be a release build)
#   KEEP_WORK=1           keep build/dmg/work.noindex (staged app, background, writable image)
# Signing follows starter.json: ad hoc by default; with signing.identity a Developer ID signature
# with hardened runtime, and with signing.notarize also scripts/notarize.sh for app and DMG.
# Network: only once, to install the pinned dmgbuild into build/tools-venv.
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"
source tools/lib/packaging.sh
pkg_env
for tool in hdiutil tiffutil codesign ditto otool; do
  command -v $tool >/dev/null || { print -u2 "dmg: $tool missing (xcode-select --install)"; exit 1; }
done

step() { print -r -- "dmg: $*"; }
fail() { print -u2 -r -- "dmg: $*"; exit 1; }

OUT="$ROOT/build/dmg"
# ".noindex": Spotlight, Launchpad and the Apps view never list the staged copy as a second app.
WORK="$OUT/work.noindex"
VENV="$ROOT/build/tools-venv"
LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
MNT=""

cleanup() {
  if [[ -n "$MNT" && -d "$MNT" ]]; then
    hdiutil detach "$MNT" -quiet 2>/dev/null || hdiutil detach "$MNT" -force -quiet 2>/dev/null || true
    rmdir "$MNT" 2>/dev/null || true
  fi
}
trap cleanup EXIT

detach() {
  local i
  for i in 1 2 3; do
    hdiutil detach "$MNT" -quiet 2>/dev/null && { rmdir "$MNT" 2>/dev/null || true; MNT=""; return 0; }
    sleep 1
  done
  hdiutil detach "$MNT" -force -quiet
  rmdir "$MNT" 2>/dev/null || true
  MNT=""
}

ensure_dmgbuild() {
  # A private venv with the pinned, hash-checked dmgbuild (tools/dmg/requirements.txt). Rebuilt
  # when the requirements change. Uses the system Python 3.9 (/usr/bin/python3) so no Homebrew is needed.
  local req="$ROOT/tools/dmg/requirements.txt" stamp="$VENV/.requirements.sha256" want py
  want="$(shasum -a 256 "$req" | cut -d' ' -f1)"
  if [[ -x "$VENV/bin/dmgbuild" && -f "$stamp" && "$(<"$stamp")" == "$want" ]]; then return 0; fi
  py=/usr/bin/python3
  [[ -x "$py" ]] || py="$(command -v python3)" || fail "python3 missing (xcode-select --install)"
  step "setting up dmgbuild in build/tools-venv ($($py --version 2>&1), pinned in tools/dmg/requirements.txt; downloads from PyPI once)"
  rm -rf "$VENV"
  "$py" -m venv "$VENV"
  "$VENV/bin/python" -m pip install --quiet --disable-pip-version-check --no-input \
    --require-hashes --only-binary :all: -r "$req" || fail "installing dmgbuild failed (network? see the pip output above)"
  print -r -- "$want" > "$stamp"
  step "installed: $("$VENV/bin/python" -m pip list --format=freeze --disable-pip-version-check 2>/dev/null \
    | grep -Ev '^(pip|setuptools)==' | tr '\n' ' ')"
}

# 1. Icon and release build -------------------------------------------------------------------
if [[ ! -f App/Resources/AppIcon.icns ]]; then
  step "App/Resources/AppIcon.icns is missing, rendering it (scripts/icon.sh)"
  scripts/icon.sh
fi
if [[ -z "${NO_BUILD:-}" ]]; then
  CONFIG=release scripts/build.sh
fi
source build/gen/app.env
SRC="build/$APP_NAME.app"
[[ -d "$SRC" ]] || fail "$SRC is missing (make build CONFIG=release)"

rm -rf "$WORK"
mkdir -p "$WORK"
APP="$WORK/$APP_NAME.app"
ditto "$SRC" "$APP"

# 2. Optional MLX worker ------------------------------------------------------------------------
if [[ " $MODULES_ENABLED " == *" mlx "* ]]; then
  if [[ -x ai-worker/package.sh ]]; then
    step "mlx is enabled: ai-worker/package.sh adds the MLX worker to the app"
    ai-worker/package.sh "$APP"
  else
    step "mlx is enabled, but ai-worker/package.sh does not exist: the DMG has no MLX worker"
  fi
fi

# 3. Sign (inside out) and check the minimum macOS ---------------------------------------------
if [[ "$PKG_IDENTITY" == "-" ]]; then
  sign_app "$APP" -
  signed="ad hoc"
else
  python3 tools/packaging/pkg.py entitlements "$WORK/entitlements.plist" >/dev/null
  sign_app "$APP" "$PKG_IDENTITY" "$WORK/entitlements.plist"
  signed="$PKG_IDENTITY"
fi
python3 tools/packaging/pkg.py minos "$APP"

if [[ "$PKG_NOTARIZE" == 1 ]]; then
  scripts/notarize.sh "$APP"
elif [[ "$PKG_NOTARIZE_WANTED" == 1 ]]; then
  step "signing.notarize is true, but signing.identity is \"-\": the DMG is not notarized"
fi

# 4. Background ----------------------------------------------------------------------------------
build_tool dmg-background tools/dmg/Background.swift tools/dmg/DMGText.swift
bg_args=(--out "$WORK/background" --layout tools/dmg/layout.json --icon App/Resources/AppIcon.icns
         --name "$PKG_DISPLAY_EN" --name-de "$PKG_DISPLAY_DE" --app-label "$APP_NAME"
         --version "$PKG_VERSION" --min-macos "$PKG_MIN_MACOS" --accent "$PKG_ACCENT" --lang "$PKG_DMG_LANG")
# The Gatekeeper hint only for builds that are not notarized (they need "Open Anyway" once).
[[ "$PKG_NOTARIZE" == 1 ]] && bg_args+=(--no-hint)
build/tools/dmg-background "${bg_args[@]}"
# One multi-resolution TIFF, so Retina screens get the 2x art.
tiffutil -cathidpicheck "$WORK/background/background.png" "$WORK/background/background@2x.png" \
  -out "$WORK/background.tiff" >/dev/null 2>&1 || fail "tiffutil could not merge the backgrounds"
mkdir -p "$OUT"
cp "$WORK/background/preview.png" "$OUT/preview.png"

# 5. Lay out the window (dmgbuild writes .DS_Store, no Finder scripting) -----------------------
ensure_dmgbuild
step "dmgbuild $("$VENV/bin/python" -c 'import importlib.metadata as m; print(m.version("dmgbuild"))')"
RW="$WORK/rw.dmg"
"$VENV/bin/dmgbuild" -s tools/dmg/settings.py -D app="$APP" -D background="$WORK/background.tiff" \
  -D layout=tools/dmg/layout.json -D volicon=App/Resources/AppIcon.icns "$APP_NAME" "$RW" >"$WORK/dmgbuild.log" 2>&1 \
  || { cat "$WORK/dmgbuild.log" >&2; fail "dmgbuild failed"; }

# Finder shows ".background.tiff" despite the dot (and scrolls the window for it): flag it hidden.
MNT="$(mktemp -d "$WORK/mnt.XXXXXX")"
hdiutil attach -nobrowse -noverify -noautoopen -mountpoint "$MNT" "$RW" >/dev/null
for f in .background.tiff .DS_Store .VolumeIcon.icns .fseventsd; do
  [[ -e "$MNT/$f" ]] && chflags hidden "$MNT/$f"
done
detach

# 6. Compress, sign, notarize ------------------------------------------------------------------
FORMAT="${DMG_FORMAT:-ULMO}"
FINAL="$OUT/$APP_NAME-$PKG_VERSION.dmg"
rm -f "$FINAL"
if ! hdiutil convert -quiet "$RW" -format "$FORMAT" -o "$FINAL" 2>/dev/null; then
  step "$FORMAT not available, using UDZO"
  FORMAT=UDZO
  hdiutil convert -quiet "$RW" -format UDZO -imagekey zlib-level=9 -o "$FINAL"
fi
if [[ "$PKG_IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$PKG_IDENTITY" "$FINAL" || fail "signing the DMG failed"
fi
if [[ "$PKG_NOTARIZE" == 1 ]]; then
  scripts/notarize.sh "$FINAL"
fi

# 7. Check what people will get ------------------------------------------------------------------
hdiutil verify -quiet "$FINAL" || fail "hdiutil verify failed for $FINAL"
MNT="$(mktemp -d "$WORK/mnt.XXXXXX")"
hdiutil attach -readonly -nobrowse -noautoopen -mountpoint "$MNT" "$FINAL" >/dev/null
problems=()
[[ -d "$MNT/$APP_NAME.app" ]] || problems+=("$APP_NAME.app missing")
[[ "$(readlink "$MNT/Applications" 2>/dev/null)" == /Applications ]] || problems+=("Applications link missing")
[[ -f "$MNT/.background.tiff" ]] || problems+=("background missing")
[[ -f "$MNT/.DS_Store" ]] || problems+=(".DS_Store (window layout) missing")
[[ -f "$MNT/.VolumeIcon.icns" ]] || problems+=("volume icon missing")
ls -lO "$MNT/.background.tiff" 2>/dev/null | grep -q hidden || problems+=("background not hidden")
codesign --verify --strict --deep "$MNT/$APP_NAME.app" 2>/dev/null || problems+=("app signature invalid")
detach
(( ${#problems} == 0 )) || fail "the DMG is not right: ${(j:, :)problems}"

# The staged app must never count as an installed app on this Mac.
"$LSR" -u "$APP" >/dev/null 2>&1 || true
[[ -n "${KEEP_WORK:-}" ]] || rm -rf "$WORK"
hint="Gatekeeper hint shown"
[[ "$PKG_NOTARIZE" == 1 ]] && hint="notarized, no hint"
step "${FINAL#$ROOT/} ($(du -h "$FINAL" | cut -f1 | tr -d ' '), $FORMAT, signed $signed, $hint, texts $PKG_DMG_LANG)"
step "window preview: ${OUT#$ROOT/}/preview.png"
