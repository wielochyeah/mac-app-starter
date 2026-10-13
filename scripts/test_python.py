#!/usr/bin/env python3
"""Python tests of the tooling, part of make test and make check-light (no Mac needed): scripts/tests,
scripts/starter/tests (bin/starter and check-kit) and ai-worker/tests when the module mlx is there, the latter with
the python of ai-worker/.venv when it exists. Prints the last lines of each run, the whole output when one fails.

Python 3.9 standard library only.
"""
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def suites(root=ROOT):
    """(label, python, cwd, start folder, top folder) of every suite that exists."""
    out = []
    if (root / "scripts" / "tests").is_dir():
        out.append(("scripts/tests", sys.executable, root, "scripts/tests", "."))
    if (root / "scripts" / "starter" / "tests").is_dir():
        out.append(("scripts/starter/tests", sys.executable, root, "scripts/starter/tests", "scripts"))
    worker = root / "ai-worker"
    if (worker / "tests").is_dir():
        venv = worker / ".venv" / "bin" / "python"
        out.append(("ai-worker/tests", str(venv) if os.access(str(venv), os.X_OK) else sys.executable, worker, "tests", None))
    return out


def main():
    failed = []
    for label, python, cwd, start, top in suites():
        args = [python, "-m", "unittest", "discover", "-s", start, "-p", "test_*.py"]
        if top:
            args += ["-t", top]
        result = subprocess.run(args, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        output = result.stdout.decode("utf-8", "replace").rstrip("\n")
        if result.returncode != 0:
            print(output)
            failed.append(label)
        else:
            print("\n".join(output.split("\n")[-3:]))
    if failed:
        print("test_python: rot in " + ", ".join(failed), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
