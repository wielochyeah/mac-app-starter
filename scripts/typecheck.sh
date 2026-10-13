#!/bin/zsh
# make typecheck: type-checks the app and its tests for every module combination the CI plans
# (.github/ci_plan.py), without building or signing: two swiftc -typecheck runs per combination, a few seconds each.
#   MODULES=window,menubar   only this combination
# Warnings are errors here (STRICT=1, rule A-02). The CI runs this as one job instead of one Mac per combination.
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"
source scripts/lib/swift.sh
require_value MODULES "${MODULES:-}" '^[a-z0-9_]+(,[a-z0-9_]+)*$' window,menubar
command -v swiftc >/dev/null || { print -u2 "typecheck.sh: swiftc missing (xcode-select --install, then make doctor)"; exit 1; }
export STRICT=1
if [[ -n "${MODULES:-}" ]]; then
  combos=("$MODULES")
else
  combos=("${(@f)$(python3 .github/ci_plan.py --kombinationen)}")
fi
use_sdk
tests=("$ROOT"/App/Tests/**/*.swift(N))
failed=()
start=$SECONDS
for combo in "${combos[@]}"; do
  GEN_DIR="$ROOT/build/typecheck/${combo//,/-}"
  if ! MODULES="$combo" python3 scripts/gen_config.py --out "$GEN_DIR" >/dev/null; then failed+=("$combo"); continue; fi
  source "$GEN_DIR/app.env"
  sources=("${(@f)$(swift_sources)}")
  flags=("${(@f)$(swift_flags debug)}")
  if run_swiftc -typecheck "${flags[@]}" "${sources[@]}" && \
     run_swiftc -typecheck "${flags[@]}" -D TESTING "${sources[@]}" "${tests[@]}"; then
    print "typecheck: $combo ok"
  else
    print -u2 "typecheck: $combo ROT"
    failed+=("$combo")
  fi
done
if (( ${#failed} )); then
  print -u2 "typecheck: ${#failed} von ${#combos} Kombinationen rot: ${(j:, :)failed}"
  exit 1
fi
print "typecheck: ${#combos} Kombinationen ohne Fehler und Warnungen ($((SECONDS - start)) s)"
