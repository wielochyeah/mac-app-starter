"""Fixture repositories for the starter tool tests: a small starter with the real manifest, lock and
starter.json, one stub per module and a few files of every path class."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Dict, Optional

ROOT = Path(__file__).resolve().parents[3]
# In a project's CI GITHUB_REPOSITORY names the project; the fixtures are starters and copies of their own.
os.environ.pop("GITHUB_REPOSITORY", None)
SCRIPTS = ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from starter.manifest import parse_manifest  # noqa: E402

GIT_ID = ["-c", "user.name=Probe", "-c", "user.email=probe@example.invalid", "-c", "commit.gpgsign=false",
          "-c", "tag.gpgsign=false", "-c", "core.hooksPath=/dev/null"]


# Fixed copies of the starter's own starter.json and lock: in a project the real ones carry the
# project's values, and kit tests must not depend on values a project is told to change.
STARTER_JSON = """{
  "starter": { "version": "1.0.0" },
  "app": {
    "name": "Starter",
    "bundleId": "com.example.starter",
    "displayName": { "en": "Starter", "de": "Starter" },
    "version": "1.0.0",
    "build": 1,
    "minimumMacOS": "26.0",
    "accent": "violett",
    "symbol": "sparkles",
    "copyright": "© 2026"
  },
  "modules": { "window": true, "menubar": true, "island": true, "background": true, "hotkeys": true, "ai": true, "mlx": false, "examples": true },
  "permissions": ["notifications"],
  "texts": { "languages": ["en", "de"], "anrede": "du" },
  "commit": { "name": "Starter Author", "email": "author@example.invalid" },
  "signing": { "identity": "-", "teamId": "", "notarize": false }
}
"""
STARTER_LOCK = json.dumps({
    "description": "fixture", "starter": "mac-app-starter", "version": "1.0.0", "state": "release",
    "source": None, "commit": None, "project": None, "createdOn": None, "lastSyncedOn": None,
    "removedModules": [], "checksums": {},
}, indent=2) + "\n"


def real_manifest() -> dict:
    return json.loads((ROOT / "starter.manifest.json").read_text(encoding="utf-8"))


def modules_swift(manifest: dict) -> str:
    lines = ["enum Modules {", "    static func registerAll() {", "        KitModule.register()"]
    for name, m in manifest["modules"].items():
        lines += [f"        #if MODUL_{name.upper()}", f"        {m['folder']}Module.register()", "        #endif"]
    lines += ["    }", "}", ""]
    return "\n".join(lines)


def base_files() -> Dict[str, str]:
    manifest = real_manifest()
    files = {
        "starter.manifest.json": (ROOT / "starter.manifest.json").read_text(encoding="utf-8"),
        "starter.lock.json": STARTER_LOCK,
        "starter.json": STARTER_JSON,
        "Makefile": "check: check-rules check-texts check-design check-kit build test\n\n"
                    "check-rules:\n\t@python3 scripts/rules_sync.py --check\n"
                    "check-texts:\n\t@python3 scripts/check_texts.py\n"
                    "check-design:\n\t@python3 scripts/check_design.py\n"
                    "check-kit:\n\t@python3 scripts/check_kit.py\n"
                    "build:\n\t@scripts/build.sh\n"
                    "test:\n\t@scripts/test.sh\n",
        ".gitignore": "/build/\n",
        "README.md": "# Starter\n\nIntro.\n\n<!-- nur-im-starter:anfang -->\n## Stand\nBau läuft.\n"
                     "<!-- nur-im-starter:ende -->\n\n## Module\n\n| Modul | Pfad |\n|---|---|\n"
                     "| Insel | `App/Sources/Modules/Island/` | <!-- modul:island -->\n",
        "docs/bau/status/S0.md": "# S0\n",
        "docs/DECISIONS.md": "# Entscheidungen des Starters\n\nE-01 …\n",
        "docs/vorlagen/DECISIONS.md": "# Entscheidungen\n\n(leer)\n",
        "docs/DESIGN.md": "# Design\n",
        "App/Resources/InfoPlist.json": "{}\n",
        "App/Sources/Features/README.md": "Eigene Funktionen.\n",
        "App/Sources/Kit/Core/Lang.swift": "func tr(en: String, de: String) -> String { en }\n",
        "App/Sources/Kit/Texts/CommonText.swift": "enum CommonText {}\n",
        "App/Sources/Kit/Main/Modules.swift": modules_swift(manifest),
        "App/Tests/Harness/Harness.swift": "#if TESTING\nclass TestSuite {}\n#endif\n",
        "App/Tests/IslandTests.swift": "// Island tests\n#if TESTING\n#if MODUL_ISLAND\n"
                                       "final class IslandTests: TestSuite {}\n#endif\n#endif\n",
        "scripts/check_kit.py": "print('ok')\n",
        "scripts/rules_sync.py": "print('ok')\n",
        "scripts/check_texts.py": "print('ok')\n",
        "scripts/check_design.py": "print('ok')\n",
        "scripts/check_commit_msg.py": "print('ok')\n",
        "scripts/hooks/commit-msg": "#!/bin/zsh\npython3 scripts/check_commit_msg.py \"$1\"\n",
        "scripts/hooks/pre-push": "#!/bin/zsh\nexec make check\n",
        ".github/workflows/ci.yml": "jobs:\n  check:\n    steps:\n      - run: make check\n",
        "scripts/build.sh": "#!/bin/zsh\n",
        "scripts/test.sh": "#!/bin/zsh\n",
        "ai-worker/worker.py": "print('worker')\n",
    }
    for name, m in manifest["modules"].items():
        folder = m["folder"]
        files[f"App/Sources/Modules/{folder}/{folder}Module.swift"] = \
            f"enum {folder}Module {{\n    static func register() {{}}\n}}\n"
    files["App/Sources/Modules/Island/IslandText.swift"] = "enum IslandText {}\n"
    return files


def write_files(root: Path, files: Dict[str, Optional[str]]) -> None:
    for path, text in files.items():
        full = root / path
        if text is None:
            if full.exists():
                full.unlink()
            continue
        full.parent.mkdir(parents=True, exist_ok=True)
        full.write_text(text, encoding="utf-8")


def git(root: Path, *args: str) -> str:
    res = subprocess.run(["git", *GIT_ID, *args], cwd=str(root), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if res.returncode != 0:
        raise AssertionError(f"git {' '.join(args)}: {res.stderr.decode()}")
    return res.stdout.decode().strip()


def make_repo(root: Path, files: Optional[Dict[str, str]] = None, origin: Optional[str] = None) -> Path:
    root.mkdir(parents=True, exist_ok=True)
    write_files(root, files if files is not None else base_files())
    git(root, "init", "-q", "-b", "main")
    git(root, "add", "-A")
    git(root, "commit", "-qm", "init")
    if origin:
        git(root, "remote", "add", "origin", origin)
    return root


def manifest_obj():
    return parse_manifest(real_manifest())


class TempDirCase(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="starter-test-"))

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def read(self, root: Path, path: str) -> str:
        return (root / path).read_text(encoding="utf-8")

    def json(self, root: Path, path: str) -> dict:
        return json.loads(self.read(root, path))
