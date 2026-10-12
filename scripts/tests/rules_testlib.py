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


FIXTURE_TEXTS = {"languages": ["en", "de"], "anrede": "du"}
FIXTURE_INFOPLIST = {"_comment": "Testdatei", "NSMicrophoneUsageDescription": {
    "en": "Used only while you dictate.", "de": "Nur während du diktierst."}}


class Repo:
    """A temp folder with rules/ and CLAUDE.md copied from this repository, plus stand-ins for every tool path named in
    rules/index.json, so rules_sync, check_texts and check_design run against it. Project settings are pinned (address
    form du, no extra packs, no names, a fixed InfoPlist.json), so the tests pass in every project made from the starter;
    the derived files are rewritten for these settings."""

    def __init__(self, texts=None):
        self.root = Path(tempfile.mkdtemp(prefix="rules-test-"))
        shutil.copytree(ROOT / "rules", self.root / "rules")
        shutil.copy(ROOT / "CLAUDE.md", self.root / "CLAUDE.md")
        starter = json.loads((ROOT / "starter.json").read_text(encoding="utf-8"))
        starter["texts"] = dict(texts or FIXTURE_TEXTS)
        self.write_json("starter.json", starter)
        for baseline in (self.root / "rules" / "baseline").glob("*.json"):
            baseline.write_text("{}\n", encoding="utf-8")
        index = json.loads((self.root / "rules/index.json").read_text(encoding="utf-8"))
        for tool in index["werkzeuge"]:
            target = self.root / tool["pfad"]
            if (ROOT / tool["pfad"]).is_dir():
                target.mkdir(parents=True, exist_ok=True)
            elif not target.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text("stand-in\n", encoding="utf-8")
        self.write_json("App/Resources/InfoPlist.json", FIXTURE_INFOPLIST)
        self.sync()

    def sync(self):
        import rules_sync  # noqa: E402 (scripts/ is on the path from above)
        errors, outputs, _ = rules_sync.sync(self.root)
        if errors:
            raise AssertionError("rules_sync im Test-Repository: " + "; ".join(errors))
        for rel, expected, current in outputs:
            if expected != current:
                (self.root / rel).write_text(expected, encoding="utf-8")

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
    """The compiled terms of this repository, limited to the starter's own packs (a project's packs stay out)."""
    index = json.loads((ROOT / "rules/index.json").read_text(encoding="utf-8"))
    kit = {Path(rel).stem for rel in index["pakete"]}
    return [t for t in rules_lib.load_terms(ROOT) if t.paket in kit]


def pack_files():
    index = json.loads((ROOT / "rules/index.json").read_text(encoding="utf-8"))
    return [json.loads((ROOT / "rules" / rel).read_text(encoding="utf-8")) for rel in index["pakete"]]
