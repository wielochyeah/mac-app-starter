#!/bin/zsh
# Builds build/<Name>.app with one plain swiftc call (no Xcode, no SwiftPM).
#   CONFIG=debug|release (default debug)   MODULES=window,menubar (overrides starter.json)
# Steps: gen_config -> swiftc (Info.plist embedded via -sectcreate) -> .app bundle in a temp dir
# -> codesign (ad hoc unless signing.identity is set) -> mv into place.
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"
CONFIG="${CONFIG:-debug}"
if [[ "$CONFIG" != debug && "$CONFIG" != release ]]; then
  print -u2 "build.sh: CONFIG must be debug or release (got $CONFIG)"; exit 2
fi
command -v swiftc >/dev/null || { print -u2 "build.sh: swiftc missing (xcode-select --install, then make doctor)"; exit 1; }

python3 scripts/gen_config.py --out build/gen >/dev/null
source build/gen/app.env
source scripts/lib/swift.sh
use_sdk

sources=("${(@f)$(swift_sources)}")
flags=("${(@f)$(swift_flags "$CONFIG")}")

mkdir -p build build/cache
TMP="$(mktemp -d "$ROOT/build/.tmp.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
start=$SECONDS
# Same file name as the final binary: the linker's ad-hoc signature identifier is the output name.
swiftc "${flags[@]}" \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$ROOT/build/gen/Info.plist" \
  -o "$TMP/$APP_NAME" "${sources[@]}"

APP="$TMP/$APP_NAME.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv "$TMP/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
[[ -d "$TMP/$APP_NAME.dSYM" ]] && { rm -rf "build/$APP_NAME.app.dSYM"; mv "$TMP/$APP_NAME.dSYM" "build/$APP_NAME.app.dSYM"; }
cp build/gen/Info.plist "$APP/Contents/Info.plist"
print -n "APPL????" > "$APP/Contents/PkgInfo"
# Resources: everything in App/Resources except the text sources, then the generated .lproj files.
rsync -a --exclude 'InfoPlist.json' --exclude '*.md' --exclude '.DS_Store' App/Resources/ "$APP/Contents/Resources/"
rsync -a build/gen/Resources/ "$APP/Contents/Resources/"

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --sign - "$APP" >/dev/null 2>&1
else
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi

# Replace the old bundle: move it aside first, never write into a bundle a running copy uses.
DEST="build/$APP_NAME.app"
[[ -e "$DEST" ]] && mv "$DEST" "$TMP/previous.app"
mv "$APP" "$DEST"
print "build.sh: $DEST ($CONFIG, modules: ${MODULES_ENABLED// /,}, $((SECONDS - start)) s)"
