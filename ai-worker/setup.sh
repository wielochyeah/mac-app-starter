#!/bin/zsh
# Creates ai-worker/.venv for the optional MLX worker (module mlx) and installs the pinned packages.
# Never installs Homebrew, uv or Python itself: when none fits, it prints the exact commands.
#
#   ai-worker/setup.sh            create or update the venv
#   ai-worker/setup.sh --check    only report what is there (exit 1 when the venv is not usable)
#   ai-worker/setup.sh --lock     after an install: write requirements.lock from the venv
#
# Python: python3.12 (Homebrew), else python3.11 / python3.13, else `uv python find 3.12`.
# Network: pip downloads the packages (dev tooling, BAUPLAN §2.13). Models are not downloaded here;
# the app does that when the user starts it (or `ai-worker/.venv/bin/python ai-worker/download.py`).
set -euo pipefail
HERE="${0:A:h}"
VENV="$HERE/.venv"
MODE="${1:-install}"

say() { print -r -- "setup: $*"; }

find_python() {
  local py
  for py in /opt/homebrew/bin/python3.12 python3.12 /opt/homebrew/bin/python3.11 python3.11 python3.13; do
    if command -v "$py" >/dev/null 2>&1 && "$py" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null; then
      print -r -- "$(command -v "$py")"
      return 0
    fi
  done
  if command -v uv >/dev/null 2>&1 && py="$(uv python find 3.12 2>/dev/null)"; then
    print -r -- "$py"
    return 0
  fi
  return 1
}

venv_ok() {
  [[ -x "$VENV/bin/python" ]] && "$VENV/bin/python" - <<'PY' 2>/dev/null
import importlib.metadata as m, sys
need = {}
for line in open("requirements.txt"):
    line = line.split("#")[0].strip()
    if "==" in line:
        name, version = line.split("==")
        need[name.strip()] = version.strip()
for name, version in need.items():
    if m.version(name) != version:
        raise SystemExit(f"{name} {m.version(name)} != {version}")
import mlx.core as mx
if not mx.metal.is_available():
    raise SystemExit("Metal not available")
PY
}

cd "$HERE"

if [[ "$(uname -m)" != arm64 ]]; then
  say "MLX needs Apple silicon (arm64); this Mac is $(uname -m). The mlx module cannot run here."
  exit 1
fi

case "$MODE" in
  --check)
    if venv_ok; then
      say "ok: $("$VENV/bin/python" -c 'import sys, mlx.core as mx, mlx_lm; print(f"Python {sys.version.split()[0]}, mlx {mx.__version__}, mlx-lm {mlx_lm.__version__}")')"
      exit 0
    fi
    say "the venv is missing or incomplete: run ai-worker/setup.sh"
    exit 1
    ;;
  --lock)
    [[ -x "$VENV/bin/python" ]] || { say "no venv yet: run ai-worker/setup.sh first"; exit 1; }
    {
      print "# Full resolved set for requirements.txt, written by ai-worker/setup.sh --lock on $(sw_vers -productVersion) $(uname -m)."
      "$VENV/bin/python" -m pip freeze --exclude-editable | grep -v '^pip=='
    } > requirements.lock
    say "wrote ai-worker/requirements.lock ($(grep -vc '^#' requirements.lock) packages)"
    exit 0
    ;;
  install) ;;
  *) say "unknown option $MODE (use --check or --lock)"; exit 2 ;;
esac

if ! PY="$(find_python)"; then
  say "no Python >= 3.11 found. Install one of these yourself, then run this script again:"
  say "  brew install python@3.12          (Homebrew, https://brew.sh)"
  say "  uv python install 3.12            (uv, https://docs.astral.sh/uv/)"
  exit 1
fi
say "using $PY ($("$PY" --version 2>&1))"

if [[ -x "$VENV/bin/python" ]] && ! "$VENV/bin/python" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)'; then
  say "existing venv has an old Python, recreating it"
  rm -rf "$VENV"
fi
[[ -x "$VENV/bin/python" ]] || "$PY" -m venv "$VENV"

"$VENV/bin/python" -m pip install --quiet --disable-pip-version-check --upgrade pip
if [[ -f requirements.lock ]]; then
  say "installing requirements.lock"
  "$VENV/bin/python" -m pip install --quiet --disable-pip-version-check -r requirements.lock
else
  say "installing requirements.txt"
  "$VENV/bin/python" -m pip install --quiet --disable-pip-version-check -r requirements.txt
fi

if venv_ok; then
  say "ready: $("$VENV/bin/python" -c 'import sys, mlx.core as mx, mlx_lm; print(f"Python {sys.version.split()[0]}, mlx {mx.__version__}, mlx-lm {mlx_lm.__version__}, Metal {mx.metal.is_available()}")')"
  say "next: download a model in the app (Settings > Models) or with"
  say "  ai-worker/.venv/bin/python ai-worker/download.py --model small"
else
  say "installed, but the check failed:"
  venv_ok || true
  exit 1
fi
