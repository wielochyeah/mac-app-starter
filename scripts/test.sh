#!/bin/zsh
# Builds build/tests/run-tests (all app sources + App/Tests with -D TESTING) and runs it, then the
# Python tests of scripts/ (and ai-worker/ when present). MODULES=… tests another module set.
#   ONLY=Settings      run only Swift tests whose "Suite/test" name starts with this
# Nothing is shown on screen: STARTER_HEADLESS=1, settings and data in a temp dir.
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"

python3 scripts/gen_config.py --out build/gen >/dev/null
source build/gen/app.env
source scripts/lib/swift.sh
use_sdk

sources=("${(@f)$(swift_sources)}")
tests=("$ROOT"/App/Tests/**/*.swift(N))
flags=("${(@f)$(swift_flags debug)}")

mkdir -p build/tests
TMP="$(mktemp -d "$ROOT/build/.tmp.XXXXXX")"
DATA="$(mktemp -d "$ROOT/build/.testdata.XXXXXX")"
trap 'rm -rf "$TMP" "$DATA"' EXIT
swiftc "${flags[@]}" -D TESTING -o "$TMP/run-tests" "${sources[@]}" "${tests[@]}"
mv -f "$TMP/run-tests" build/tests/run-tests

args=()
[[ -n "${ONLY:-}" ]] && args+=(--only "$ONLY")
STARTER_ROOT="$ROOT" STARTER_HEADLESS=1 STARTER_DATA_DIR="$DATA" STARTER_LANG=en build/tests/run-tests "${args[@]}"

if [[ -z "${ONLY:-}" ]]; then
  python3 -m unittest discover -s scripts/tests -t . -p 'test_*.py' 2>&1 | tail -3
  if [[ -d scripts/starter/tests ]]; then
    # bin/starter and check-kit; the full output only when something fails.
    if ! out="$(python3 -m unittest discover -s scripts/starter/tests -t scripts -p 'test_*.py' 2>&1)"; then
      print -r -- "$out"; exit 1
    fi
    print -r -- "$out" | tail -3
  fi
  if [[ -d ai-worker/tests ]]; then
    PY=python3
    [[ -x "$ROOT/ai-worker/.venv/bin/python" ]] && PY="$ROOT/ai-worker/.venv/bin/python"
    (cd ai-worker && "$PY" -m unittest discover -s tests -p 'test_*.py' 2>&1 | tail -3)
  fi
fi
