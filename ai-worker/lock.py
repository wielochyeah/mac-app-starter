#!/usr/bin/env python3
"""Writes ai-worker/requirements.lock with hashes: reads `name==version` lines (pip freeze of the venv, or an
existing lock) on stdin and adds the sha256 of every wheel PyPI lists for that version that this worker can use
(macOS arm64 or universal2, CPython 3.11 to 3.13, abi3 or pure Python). setup.sh installs the lock with
--require-hashes --only-binary :all:, so pip takes only these files.

Usage: ai-worker/.venv/bin/python -m pip freeze --exclude-editable | python3 ai-worker/lock.py > ai-worker/requirements.lock
       (ai-worker/setup.sh --lock does that). Network: PyPI's JSON API, developer tooling only.
Python 3.9 standard library only.
"""
import json
import re
import sys
import urllib.request

ABI3 = re.compile(r"-cp3\d+-abi3-")
PURE = re.compile(r"-none-any\.whl$")
PURE_MAC = re.compile(r"-py3-none-macosx_")


def usable(filename):
    """A wheel pip may pick on Apple silicon with CPython 3.11 to 3.13."""
    if PURE.search(filename):
        return True
    if not re.search(r"macosx_\d+_\d+_(?:arm64|universal2)\.whl$", filename):
        return False
    if ABI3.search(filename) or PURE_MAC.search(filename):
        return True
    return re.search(r"-cp31[123]-cp31[123]-", filename) is not None


def pins(lines):
    out = []
    for line in lines:
        line = line.split("#", 1)[0].strip().rstrip("\\").strip()
        if "==" in line and not line.startswith("--"):
            name, version = line.split("==", 1)
            out.append((name.strip(), version.strip()))
    return out


def hashes(name, version, fetch=None):
    fetch = fetch or (lambda url: json.load(urllib.request.urlopen(url, timeout=30)))
    data = fetch(f"https://pypi.org/pypi/{name}/{version}/json")
    found = sorted({u["digests"]["sha256"] for u in data.get("urls", [])
                    if u.get("packagetype") == "bdist_wheel" and usable(u.get("filename", ""))})
    if not found:
        raise SystemExit(f"lock: no usable wheel for {name}=={version} (macOS arm64, CPython 3.11 to 3.13)")
    return found


def render(entries, header):
    out = [header]
    for name, version, digests in entries:
        out.append(f"{name}=={version} \\")
        out += [f"    --hash=sha256:{d}" + (" \\" if i < len(digests) - 1 else "") for i, d in enumerate(digests)]
    return "\n".join(out) + "\n"


def main():
    entries = [(name, version, hashes(name, version)) for name, version in pins(sys.stdin)]
    if not entries:
        raise SystemExit("lock: no name==version lines on stdin")
    header = ("# Full resolved set for requirements.txt with the sha256 of every usable wheel (ai-worker/lock.py).\n"
              "# ai-worker/setup.sh installs it with --require-hashes --only-binary :all:.")
    sys.stdout.write(render(entries, header))
    return 0


if __name__ == "__main__":
    sys.exit(main())
