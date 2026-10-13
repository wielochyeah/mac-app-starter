#!/bin/zsh
# Builds build/tests/run-tests (all app sources + App/Tests with -D TESTING) and runs it, then the
# Python tests (scripts/test_python.py). MODULES=… tests another module set; STRICT=1 (make check): warnings are errors.
#   ONLY=Settings      run only Swift tests whose "Suite/test" name starts with this
# Nothing is shown on screen: STARTER_HEADLESS=1, settings and data in a temp dir.
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"

source scripts/lib/swift.sh
require_value MODULES "${MODULES:-}" '^[a-z0-9_]+(,[a-z0-9_]+)*$' window,menubar
require_value ONLY "${ONLY:-}" '^[A-Za-z0-9 ._/:-]+$' Settings
python3 scripts/gen_config.py --out build/gen >/dev/null
source build/gen/app.env
use_sdk

sources=("${(@f)$(swift_sources)}")
tests=("$ROOT"/App/Tests/**/*.swift(N))
flags=("${(@f)$(swift_flags debug)}")

mkdir -p build/tests
TMP="$(mktemp -d "$ROOT/build/.tmp.XXXXXX")"
DATA="$(mktemp -d "$ROOT/build/.testdata.XXXXXX")"
trap 'rm -rf "$TMP" "$DATA"' EXIT
run_swiftc "${flags[@]}" -D TESTING -o "$TMP/run-tests" "${sources[@]}" "${tests[@]}"
mv -f "$TMP/run-tests" build/tests/run-tests

args=()
[[ -n "${ONLY:-}" ]] && args+=(--only "$ONLY")
STARTER_ROOT="$ROOT" STARTER_HEADLESS=1 STARTER_DATA_DIR="$DATA" STARTER_LANG=en build/tests/run-tests "${args[@]}"

if [[ -z "${ONLY:-}" ]]; then
  python3 scripts/test_python.py
fi
