#!/bin/zsh
# Prints the newest macOS SDK whose Swift interfaces the installed swiftc can read.
#
# $SDKROOT wins if set. Leftover beta SDKs built by a newer Swift than the compiler are skipped
# (a mixed Command Line Tools install ships a 27.0 SDK that the 6.3 compiler cannot import).
# Rule: an SDK is usable when the Swift version that built its interfaces is <= the compiler's
# version (major.minor). Reading line 2 of Swift.swiftinterface takes ~0.1 s; a trial compile per
# SDK would take ~3 s each.
#
# Candidates, in order: xcrun's default, then every MacOSX<ver>.sdk of the selected developer dir
# (Command Line Tools: <dir>/SDKs, Xcode: <dir>/Platforms/MacOSX.platform/Developer/SDKs), newest
# first, then the Command Line Tools SDKs as a last resort when Xcode is selected.
set -euo pipefail
if [[ -n "${SDKROOT:-}" ]]; then print -r -- "$SDKROOT"; exit 0; fi

ver() { sed -nE 's/.*Apple Swift version ([0-9]+)\.([0-9]+).*/\1 \2/p' | head -1; }
read cmaj cmin <<< "$(swiftc --version 2>&1 | ver)"
if [[ -z "${cmaj:-}" ]]; then print -u2 "pick-sdk: cannot read the swiftc version (xcode-select --install)"; exit 1; fi

dev="$(xcode-select -p 2>/dev/null || true)"
clt=/Library/Developer/CommandLineTools
candidates=("$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)")
candidates+=(${(On)$(print -l "$dev"/SDKs/MacOSX[0-9]*.sdk(N) "$dev"/Platforms/MacOSX.platform/Developer/SDKs/MacOSX[0-9]*.sdk(N))})
if [[ "$dev" != "$clt" ]]; then candidates+=(${(On)$(print -l "$clt"/SDKs/MacOSX[0-9]*.sdk(N))}); fi

typeset -U seen
for sdk in "${candidates[@]}"; do
  [[ -n "$sdk" && -d "$sdk" ]] || continue
  real="${sdk:A}"; (( ${seen[(Ie)$real]} )) && continue; seen+=("$real")
  iface=("$real"/usr/lib/swift/Swift.swiftmodule/arm64*-apple-macos.swiftinterface(N))
  (( ${#iface} )) || continue
  read smaj smin <<< "$(head -3 "${iface[1]}" | ver)"
  [[ -n "${smaj:-}" ]] || continue
  if (( smaj > cmaj || (smaj == cmaj && smin > cmin) )); then
    print -u2 "pick-sdk: skip $real (built by Swift $smaj.$smin, compiler is $cmaj.$cmin)"; continue
  fi
  print -r -- "$real"; exit 0
done
print -u2 "pick-sdk: no usable macOS SDK (xcode-select --install)"; exit 1
