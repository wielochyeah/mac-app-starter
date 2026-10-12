"""Helpers for the tests of the rule checks: a throwaway repository with the real rules/."""
import json
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import rules_lib  # noqa: E402


class Repo:
    """A temp folder with rules/, starter.json and CLAUDE.md copied from this repository, plus stand-ins for every
    tool path named in rules/index.json, so rules_sync, check_texts and check_design run against it."""

    def __init__(self):
        self.root = Path(tempfile.mkdtemp(prefix="rules-test-"))
        shutil.copytree(ROOT / "rules", self.root / "rules")
        for name in ("starter.json", "CLAUDE.md"):
            shutil.copy(ROOT / name, self.root / name)
        for baseline in (self.root / "rules" / "baseline").glob("*.json"):
            baseline.write_text("{}\n", encoding="utf-8")
        index = json.loads((self.root / "rules/index.json").read_text(encoding="utf-8"))
        for tool in index["werkzeuge"]:
            target = self.root / tool["pfad"]
            if (ROOT / tool["pfad"]).is_dir():
                target.mkdir(parents=True, exist_ok=True)
            elif not target.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                if target.suffix == ".json":
                    shutil.copy(ROOT / tool["pfad"], target)
                else:
                    target.write_text("stand-in\n", encoding="utf-8")

    def close(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def path(self, rel):
        return self.root / rel

    def write(self, rel, text):
        target = self.root / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
        return target

    def read_json(self, rel):
        return json.loads((self.root / rel).read_text(encoding="utf-8"))

    def write_json(self, rel, value):
        self.write(rel, json.dumps(value, ensure_ascii=False, indent=2) + "\n")

    def edit_json(self, rel, change):
        value = self.read_json(rel)
        change(value)
        self.write_json(rel, value)

    def terms(self):
        return rules_lib.load_terms(self.root)


def repo_terms():
    return rules_lib.load_terms(ROOT)


def pack_files():
    index = json.loads((ROOT / "rules/index.json").read_text(encoding="utf-8"))
    return [json.loads((ROOT / "rules" / rel).read_text(encoding="utf-8")) for rel in index["pakete"]]
