#!/bin/zsh
# Builds build/<Name>.app with one plain swiftc call (no Xcode, no SwiftPM).
#   CONFIG=debug|release (default debug)   MODULES=window,menubar (overrides starter.json)
#   STRICT=1 (make check): warnings are errors
# Steps: gen_config -> swiftc (Info.plist embedded via -sectcreate) -> .app bundle in a temp dir
# -> codesign (ad hoc unless signing.identity or SIGN_IDENTITY names a certificate) -> mv into place.
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"
source scripts/lib/swift.sh
CONFIG="${CONFIG:-debug}"
if [[ "$CONFIG" != debug && "$CONFIG" != release ]]; then
  print -u2 "build.sh: CONFIG must be debug or release (got $CONFIG)"; exit 2
fi
require_value MODULES "${MODULES:-}" '^[a-z0-9_]+(,[a-z0-9_]+)*$' window,menubar
command -v swiftc >/dev/null || { print -u2 "build.sh: swiftc missing (xcode-select --install, then make doctor)"; exit 1; }

python3 scripts/gen_config.py --out build/gen >/dev/null
# SIGN_IDENTITY from the environment wins over signing.identity, as in make dmg and make notarize
sign_override="${SIGN_IDENTITY:-}"
source build/gen/app.env
[[ -n "$sign_override" ]] && SIGN_IDENTITY="$sign_override"
use_sdk

sources=("${(@f)$(swift_sources)}")
flags=("${(@f)$(swift_flags "$CONFIG")}")

mkdir -p build build/cache
TMP="$(mktemp -d "$ROOT/build/.tmp.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
start=$SECONDS
# Same file name as the final binary: the linker's ad-hoc signature identifier is the output name.
run_swiftc "${flags[@]}" \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$ROOT/build/gen/Info.plist" \
  -o "$TMP/$APP_NAME" "${sources[@]}"

APP="$TMP/$APP_NAME.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv "$TMP/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
# Always drop the old dSYM: a release build makes none, and a stale debug one would not match.
rm -rf "build/$APP_NAME.app.dSYM"
if [[ -d "$TMP/$APP_NAME.dSYM" ]]; then mv "$TMP/$APP_NAME.dSYM" "build/$APP_NAME.app.dSYM"; fi
cp build/gen/Info.plist "$APP/Contents/Info.plist"
print -n "APPL????" > "$APP/Contents/PkgInfo"
# Resources: everything in App/Resources except the text sources, then the generated .lproj files.
rsync -a --exclude 'InfoPlist.json' --exclude '*.md' --exclude '.DS_Store' App/Resources/ "$APP/Contents/Resources/"
rsync -a build/gen/Resources/ "$APP/Contents/Resources/"
# MIT and similar licences travel with the app: Settings → About shows Notices/<lang>.md (written
# for the people using the app; THIRD_PARTY_NOTICES.md at the root is the developers' list).
if [[ -d App/Resources/Notices ]]; then
  mkdir -p "$APP/Contents/Resources/Notices"
  cp App/Resources/Notices/*.md "$APP/Contents/Resources/Notices/"
fi

# Ad hoc by default. A Developer ID turns on the hardened runtime, which needs the entitlements
# for every listed permission (build/gen/App.entitlements), or macOS denies them silently.
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  sign_args=(--force --sign -)
else
  sign_args=(--force --options runtime --timestamp --entitlements "$ROOT/build/gen/App.entitlements" --sign "$SIGN_IDENTITY")
fi
if ! sign_out="$(codesign "${sign_args[@]}" "$APP" 2>&1)"; then
  print -u2 -- "$sign_out"
  print -u2 "build.sh: codesign failed (identity: $SIGN_IDENTITY)"
  exit 1
fi

# Replace the old bundle: move it aside first, never write into a bundle a running copy uses.
DEST="build/$APP_NAME.app"
[[ -e "$DEST" ]] && mv "$DEST" "$TMP/previous.app"
mv "$APP" "$DEST"
print "build.sh: $DEST ($CONFIG, modules: ${MODULES_ENABLED// /,}, $((SECONDS - start)) s)"
