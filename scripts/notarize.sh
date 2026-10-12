#!/bin/zsh
# Notarizes and staples an .app or .dmg signed with a Developer ID (signing.identity in starter.json).
#   scripts/notarize.sh [--dry-run] [--identity "Developer ID Application: …"] [--profile <name>] [file …]
# Without files: build/dmg/<Name>-<version>.dmg (make dmg). make dmg calls this itself when
# signing.notarize is true; that is the way to a notarized DMG. A DMG that make dmg built without
# notarization shows the "Open Anyway" hint in its window and is refused here.
# --dry-run checks the setup and prints the commands without running them.
# Credentials live in the keychain as a notarytool profile (NOTARY_PROFILE or signing.notaryProfile),
# stored once with:
#   xcrun notarytool store-credentials <name> --apple-id <you@example.com> --team-id <TEAMID>
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"
source tools/lib/packaging.sh
pkg_env

dry=0
extra=()
files=()
while (( $# )); do
  case "$1" in
    --dry-run) dry=1 ;;
    --identity|--profile|--team)
      (( $# >= 2 )) || { print -u2 "notarize: $1 needs a value"; exit 2; }
      extra+=("$1" "$2"); shift ;;
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) print -u2 "notarize: unknown option $1"; exit 2 ;;
    *) files+=("$1") ;;
  esac
  shift
done
(( ${#files} )) || files=("build/dmg/$PKG_NAME-$PKG_VERSION.dmg")

identity="$PKG_IDENTITY"
for (( i = 1; i < ${#extra}; i += 2 )); do [[ "${extra[i]}" == --identity ]] && identity="${extra[i+1]}"; done

for f in "${files[@]}"; do
  plan="$(python3 tools/packaging/pkg.py notary "$f" "${extra[@]}")" || exit 1
  stamp="${f:h}/.${f:t}.hint"
  if [[ "$f" == *.dmg && -f "$stamp" && "$(<"$stamp")" == shown ]]; then
    print -u2 -r -- "notarize: $f shows the \"Open Anyway\" hint in its window (built with signing.notarize false).
  Set signing.notarize to true in starter.json and run make dmg: it notarizes app and DMG and leaves the hint out."
    exit 1
  fi
  if (( dry )); then
    print "notarize (dry run): $f"
    for line in "${(@f)plan}"; do cmd=("${(@ps:\t:)line}"); print -r -- "  ${(j: :)${(@q-)cmd}}"; done
    continue
  fi
  [[ -e "$f" ]] || { print -u2 "notarize: $f is missing (make dmg)"; exit 1; }
  xcrun --find notarytool >/dev/null 2>&1 || { print -u2 "notarize: notarytool missing (xcode-select --install)"; exit 1; }
  security find-identity -v -p codesigning 2>/dev/null | grep -qF "$identity" \
    || { print -u2 "notarize: \"$identity\" is not in the keychain (security find-identity -v -p codesigning)"; exit 1; }
  if [[ "$f" == *.app ]]; then
    info="$(codesign -dvv "$f" 2>&1 || true)"
    [[ "$info" == *"Authority=Developer ID Application"* && "$info" == *"(runtime)"* ]] \
      || { print -u2 "notarize: $f is not signed with a Developer ID and the hardened runtime (make dmg signs it)"; exit 1; }
  fi
  print "notarize: $f (waits for Apple, usually a few minutes)"
  for line in "${(@f)plan}"; do
    cmd=("${(@ps:\t:)line}")
    "${cmd[@]}" || { print -u2 "notarize: failed: ${(j: :)${(@q-)cmd}}
  details: xcrun notarytool log <submission id> --keychain-profile <profile>"; exit 1; }
  done
  print "notarize: $f notarized and stapled"
done
