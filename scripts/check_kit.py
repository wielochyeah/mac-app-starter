#!/usr/bin/env python3
"""check-kit, step of `make check` (same as bin/starter check-kit; logic in scripts/starter/kitcheck.py).

In a project: kit files unchanged since init/sync, no starter-only leftovers. In the starter: every
file classified, every module removable without leftovers. Everywhere: Makefile, Git hooks and CI
still run the checks.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from starter.cli import main  # noqa: E402

if __name__ == "__main__":
    sys.exit(main(["check-kit"]))
