"""Tests for scripts/check_commit_msg.py and the hooks in scripts/hooks."""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rules_testlib import ROOT  # noqa: E402

import check_commit_msg as ccm  # noqa: E402

TERMS = ccm.commit_terms(ROOT)
IDENTITY = {"name": "Ada Example", "email": "ada@example.com"}
TRAILER = "\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\n"


def errors(message, terms=TERMS):
    return ccm.check_message(message, terms)


class MessageTests(unittest.TestCase):
    def test_valid_messages(self):
        for message in [
            "feat(island): add the capsule fallback" + TRAILER,
            "fix: keep the frame after closing the window\n",
            "refactor(kit/design)!: rename the spacing tokens\n\nBody explains why.\n",
            "fixup! docs(rules): describe the arrow keys\n",
            "Merge branch 'strang/G1'\n",
            'Revert "feat(menubar): add the panel"\n',
            "docs(readme): explain ⌘, and ⇧⌘K shortcuts\n",
        ]:
            self.assertEqual(errors(message), [], message)

    def test_format_errors(self):
        self.assertTrue(errors("Added the island\n"))
        self.assertTrue(errors("feature(island): add\n"))
        self.assertTrue(errors("feat(Island): add\n"))
        self.assertTrue(errors("feat(island):add\n"))
        self.assertTrue(errors("feat(island): " + "x" * 90 + "\n"))
        self.assertEqual(errors("feat(island): " + "x" * 86 + "\n"), [])
        self.assertTrue(any("Zeile 2" in e for e in errors("feat: add\nbody without blank line\n")))

    def test_comments_and_scissors_are_ignored(self):
        message = "feat: add the panel\n# Please enter the commit message!\n\n# ------------------------ >8 ------------------------\n+ seamless — diff!\n"
        self.assertEqual(errors(message), [])

    def test_packs_apply_to_subject_and_body(self):
        self.assertTrue(any("Emoji" in e for e in errors("feat: add the panel 🚀\n")))
        self.assertTrue(any("Floskel" in e for e in errors("feat: seamless onboarding\n")))
        self.assertTrue(any("Pfeil" in e for e in errors("fix: build -> test\n")))
        self.assertTrue(any("Ausrufezeichen" in e for e in errors("fix: it works!\n")))
        self.assertTrue(any("Gedankenstrich" in e for e in errors("fix: render — then test\n")))
        self.assertTrue(any("Merkzettel" in e for e in errors("feat: add panel\n\nTODO: wire it\n")))

    def test_ui_only_words_pass_in_commits(self):
        self.assertEqual(errors("fix(lock): unlock the store on error\n"), [])

    def test_range_mode_checks_format_only(self):
        self.assertEqual(ccm.check_message("feat: seamless onboarding\n", None), [])


class AuthorTests(unittest.TestCase):
    def test_matching_author(self):
        self.assertEqual(ccm.check_author("Ada Example <ada@example.com> 1700000000 +0200", IDENTITY), [])

    def test_other_author(self):
        found = ccm.check_author("Bob <bob@example.com> 1700000000 +0200", IDENTITY)
        self.assertIn('git config user.name "Ada Example"', found[0])

    def test_missing_identity_refuses_every_commit(self):
        self.assertEqual(ccm.check_author("Ada Example <ada@example.com> 1 +0", {"name": "", "email": ""}), [ccm.MISSING_IDENTITY])

    def test_identity_is_read_from_starter_json(self):
        identity = ccm.read_identity(ROOT)
        config = json.loads((ROOT / "starter.json").read_text(encoding="utf-8"))
        self.assertEqual(identity, config["commit"])


class GitTests(unittest.TestCase):
    """Runs the real hook in a throwaway repository (its own config, never the repository's)."""

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp(prefix="commit-test-"))
        for rel in ("scripts/check_commit_msg.py", "scripts/rules_lib.py", "rules/generated/begriffe.json",
                    "scripts/hooks/commit-msg", "scripts/hooks/pre-push"):
            (self.dir / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / rel, self.dir / rel)
        config = json.loads((ROOT / "starter.json").read_text(encoding="utf-8"))
        config["commit"] = dict(IDENTITY)
        (self.dir / "starter.json").write_text(json.dumps(config), encoding="utf-8")
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1",
                        GIT_AUTHOR_NAME=IDENTITY["name"], GIT_AUTHOR_EMAIL=IDENTITY["email"],
                        GIT_COMMITTER_NAME=IDENTITY["name"], GIT_COMMITTER_EMAIL=IDENTITY["email"])
        self.git("init", "-q", "-b", "main")
        self.git("config", "core.hooksPath", "scripts/hooks")
        self.git("config", "commit.gpgsign", "false")

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def git(self, *args, env=None, check=True):
        return subprocess.run(["git", *args], cwd=self.dir, env=env or self.env, capture_output=True, text=True, check=check)

    def commit(self, message, env=None):
        (self.dir / "file.txt").write_text(message, encoding="utf-8")
        self.git("add", "-A", env=env)
        return self.git("commit", "-q", "-m", message, env=env, check=False)

    def test_hook_accepts_and_refuses(self):
        self.assertEqual(self.commit("feat: add the first file").returncode, 0)
        refused = self.commit("Added stuff")
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("type(scope): subject", refused.stderr)
        refused = self.commit("feat: seamless magic 🚀")
        self.assertNotEqual(refused.returncode, 0)
        other = dict(self.env, GIT_AUTHOR_NAME="Bob", GIT_AUTHOR_EMAIL="bob@example.com")
        refused = self.commit("feat: add a second file", env=other)
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("Autor ist", refused.stderr)

    def test_hook_refuses_without_identity(self):
        config = json.loads((self.dir / "starter.json").read_text(encoding="utf-8"))
        config["commit"] = {"name": "", "email": ""}
        (self.dir / "starter.json").write_text(json.dumps(config), encoding="utf-8")
        refused = self.commit("feat: add the first file")
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("keine Commit-Identität", refused.stderr)

    def test_range_mode(self):
        self.assertEqual(self.commit("feat: add the first file").returncode, 0)
        self.git("checkout", "-q", "-b", "work")
        self.assertEqual(self.commit("fix: change the file").returncode, 0)
        bot = dict(self.env, GIT_AUTHOR_NAME="renovate[bot]", GIT_AUTHOR_EMAIL="29139614+renovate[bot]@users.noreply.github.com")
        (self.dir / "file.txt").write_text("bot", encoding="utf-8")
        self.git("add", "-A")
        self.git("commit", "-q", "--no-verify", "-m", "Update dependency x", env=bot)
        (self.dir / "file.txt").write_text("skipped", encoding="utf-8")
        self.git("add", "-A")
        self.git("commit", "-q", "--no-verify", "-m", "skipped the hook")
        found = ccm.check_range("main..work", IDENTITY, self.dir)
        self.assertEqual(len(found), 1)
        self.assertIn("skipped the hook", found[0])

    def test_pre_push_hook_is_zsh_and_runs_make_check(self):
        hook = self.dir / "scripts/hooks/pre-push"
        self.assertTrue(os.access(hook, os.X_OK))
        self.assertIn("make check", hook.read_text(encoding="utf-8"))
        self.assertEqual(subprocess.run(["zsh", "-n", str(hook)]).returncode, 0)
        self.assertEqual(subprocess.run(["zsh", "-n", str(self.dir / "scripts/hooks/commit-msg")]).returncode, 0)


if __name__ == "__main__":
    unittest.main()
