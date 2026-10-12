#!/bin/zsh
# Checks the toolchain for building without Xcode. Never installs anything; prints fixes instead.
# Exit code 1 when something required is missing.
set -uo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"
fails=0
ok()   { print "  ok    $1"; }
warn() { print "  warn  $1"; }
bad()  { print "  FAIL  $1"; fails=$((fails + 1)); }
hint() { print "        $1"; }

print "Required"
dev="$(xcode-select -p 2>/dev/null)"
if [[ -n "$dev" ]]; then ok "developer dir: $dev"; else bad "no developer tools"; hint "xcode-select --install"; fi
if command -v swiftc >/dev/null && sv="$(swiftc --version 2>&1 | head -1)" && [[ "$sv" == *"Swift version"* ]]; then
  ok "$sv"
else
  bad "swiftc does not run"; hint "xcode-select --install"
fi
pick_log="$(mktemp "${TMPDIR:-/tmp}/starter-doctor.XXXXXX")"
if sdk="$(scripts/pick-sdk.sh 2>"$pick_log")"; then
  ok "SDK: $sdk"
  grep -h 'skip' "$pick_log" 2>/dev/null | sed 's/^pick-sdk: /        skipped: /'
else
  bad "no usable macOS SDK"; cat "$pick_log" 2>/dev/null | sed 's/^/        /'
fi
rm -f "$pick_log"
if [[ -n "${sdk:-}" ]]; then
  probe="$(mktemp -d "${TMPDIR:-/tmp}/starter-doctor.XXXXXX")"
  print 'import SwiftUI\n@Observable final class M { var x = 0 }\nstruct V: View { var body: some View { Text("ok") } }' > "$probe/p.swift"
  if SDKROOT="$sdk" swiftc -sdk "$sdk" -typecheck -swift-version 6 -default-isolation MainActor -target arm64-apple-macosx26.0 \
       "$probe/p.swift" >/dev/null 2>"$probe/err"; then
    ok "Swift 6 + -default-isolation MainActor + SwiftUI + @Observable type-check"
  else
    bad "Swift 6 / default isolation type-check failed"; head -5 "$probe/err" | sed 's/^/        /'
  fi
  rm -rf "$probe"
fi
if command -v python3 >/dev/null; then ok "python3 $(python3 -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])') (tooling)"; else bad "python3 missing"; hint "xcode-select --install"; fi
for tool in codesign plutil rsync; do
  command -v $tool >/dev/null && ok "$tool" || bad "$tool missing"
done
os="$(sw_vers -productVersion 2>/dev/null)"
min="$(python3 -c 'import json; print(json.load(open("starter.json"))["app"]["minimumMacOS"])' 2>/dev/null)"
ok "macOS $os (app needs $min or later)"
[[ "$(uname -m)" == arm64 ]] && ok "Apple silicon" || warn "not arm64: the app builds for arm64 only"

print "\nSwiftPM (secondary path, Package.swift)"
if out="$(swift package --version 2>&1)" && [[ "$out" == *"Swift Package Manager"* ]]; then
  ok "$out"
elif [[ "$out" == *"dyld"* || "$out" == *"Symbol not found"* ]]; then
  warn "swift package crashes in dyld: mixed Command Line Tools install (beta leftovers)"
  hint "make build still works. To repair SwiftPM, pick one:"
  hint "  sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install"
  hint "  softwareupdate --list   (then install the offered Command Line Tools)"
else
  warn "swift package not usable: ${out%%$'\n'*}"
fi

print "\nOptional (packaging, local AI)"
for py in python3.12 python3.11 python3.13; do
  if command -v $py >/dev/null; then ok "$py (MLX worker)"; found_py=1; break; fi
done
[[ -n "${found_py:-}" ]] || { warn "no python >= 3.11 (only for the optional mlx module)"; hint "brew install python@3.12"; }
command -v uv >/dev/null && ok "uv" || warn "uv not installed (optional)"
command -v brew >/dev/null && ok "brew $(brew --version 2>/dev/null | head -1 | awk '{print $2}')" || warn "Homebrew not installed (optional)"
for tool in hdiutil iconutil sips tiffutil; do
  command -v $tool >/dev/null && ok "$tool" || warn "$tool missing (make dmg / make icon)"
done
if command -v dmgbuild >/dev/null || [[ -x build/venv-dmg/bin/dmgbuild ]]; then ok "dmgbuild"; else warn "dmgbuild not set up yet (make dmg prepares it in a project venv)"; fi
xcrun --find notarytool >/dev/null 2>&1 && ok "notarytool (optional notarization)" || warn "notarytool missing (only for notarization)"

print ""
if (( fails )); then print "doctor: $fails problem(s)"; exit 1; fi
print "doctor: ready to build"
