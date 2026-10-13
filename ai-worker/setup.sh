#!/bin/zsh
# Creates ai-worker/.venv for the optional MLX worker (module mlx) and installs the pinned packages.
# Never installs Homebrew, uv or Python itself: when none fits, it prints the exact commands.
#
#   ai-worker/setup.sh            create or update the venv from requirements.lock
#   ai-worker/setup.sh --check    only report what is there (exit 1 when the venv is not usable)
#   ai-worker/setup.sh --lock     after changing requirements.txt: resolve it in a scratch venv and write
#                                 requirements.lock with the sha256 of every wheel (ai-worker/lock.py)
#
# Python: python3.12 (Homebrew), else python3.11 / python3.13, else `uv python find 3.12`.
# Network: pip downloads the packages (developer tooling only), each checked against its hash in requirements.lock
# (--require-hashes) and only as a wheel (--only-binary :all:, no build scripts run). pip itself is the one of the
# venv and is not upgraded. Models are not downloaded here; the app does that when the user clicks Download (or
# `ai-worker/.venv/bin/python ai-worker/download.py`).
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
    PY="$(find_python)" || { say "no Python >= 3.11 found (see ai-worker/setup.sh without options)"; exit 1; }
    scratch="$(mktemp -d "${TMPDIR:-/tmp}/ai-worker-lock.XXXXXX")"
    trap 'rm -rf "$scratch"' EXIT
    "$PY" -m venv "$scratch/venv"
    say "resolving requirements.txt in a scratch venv (wheels only)"
    "$scratch/venv/bin/python" -m pip install --quiet --disable-pip-version-check --only-binary :all: -r requirements.txt
    "$scratch/venv/bin/python" -m pip freeze --exclude-editable | grep -Ev '^(pip|setuptools)==' \
      | python3 "$HERE/lock.py" > "$scratch/requirements.lock"
    mv "$scratch/requirements.lock" requirements.lock
    say "wrote ai-worker/requirements.lock ($(grep -c '^[A-Za-z]' requirements.lock) packages with hashes)"
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

[[ -f requirements.lock ]] || { say "requirements.lock is missing: run ai-worker/setup.sh --lock first"; exit 1; }
say "installing requirements.lock (hashes checked, wheels only)"
"$VENV/bin/python" -m pip install --quiet --disable-pip-version-check --no-input \
  --require-hashes --only-binary :all: -r requirements.lock

if venv_ok; then
  say "ready: $("$VENV/bin/python" -c 'import sys, mlx.core as mx, mlx_lm; print(f"Python {sys.version.split()[0]}, mlx {mx.__version__}, mlx-lm {mlx_lm.__version__}, Metal {mx.metal.is_available()}")')"
  say "next: download a model in the app (Settings > Models) or with"
  say "  ai-worker/.venv/bin/python ai-worker/download.py --model small"
else
  say "installed, but the check failed:"
  venv_ok || true
  exit 1
fi
