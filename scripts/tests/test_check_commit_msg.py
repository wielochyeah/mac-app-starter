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
        self.assertIn("bin/starter init", found[0], "a new project is told not to take over someone else's identity")

    def test_missing_identity_refuses_every_commit(self):
        empty = {"name": "", "email": ""}
        self.assertEqual(ccm.check_author("Ada Example <ada@example.com> 1 +0", empty), [ccm.MISSING_IDENTITY])
        for state in ("needs-init", "unknown"):
            self.assertEqual(ccm.check_author("Ada <a@example.com> 1 +0", empty, state), [ccm.NOT_INITIALISED], state)

    def test_the_starter_accepts_every_author(self):
        """The starter ships no identity: each contributor commits under their own, only the format counts."""
        self.assertEqual(ccm.check_author("Bob <bob@example.com> 1 +0", {"name": "", "email": ""}, "starter"), [])

    def test_identity_is_read_from_starter_json(self):
        identity = ccm.read_identity(ROOT)
        config = json.loads((ROOT / "starter.json").read_text(encoding="utf-8"))
        self.assertEqual(identity, config["commit"])

    def test_the_starter_ships_no_identity(self):
        lock = json.loads((ROOT / "starter.lock.json").read_text(encoding="utf-8"))
        if lock.get("project") is not None:
            self.skipTest("a project fills in its own identity")
        self.assertEqual(ccm.read_identity(ROOT), {"name": "", "email": ""})


class GithubRangeTests(unittest.TestCase):
    def test_pull_request_checks_the_format_of_its_commits(self):
        event = {"pull_request": {"base": {"sha": "a" * 40}, "head": {"sha": "b" * 40}}}
        self.assertEqual(ccm.github_range("pull_request", event)[:2], ("a" * 40 + ".." + "b" * 40, True))

    def test_nothing_to_check(self):
        for name, event in [("schedule", {}), ("workflow_dispatch", {}),
                            ("push", {"ref": "refs/tags/v1.0.0", "after": "c" * 40}),
                            ("push", {"ref": "refs/heads/x", "deleted": True, "after": "0" * 40})]:
            self.assertIsNone(ccm.github_range(name, event)[0], name)


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
        self.assertIn("nimmt dieser Hook keinen Commit an", refused.stderr)

    def test_hook_in_the_starter_takes_every_author_and_checks_the_format(self):
        shutil.copytree(ROOT / "scripts" / "starter", self.dir / "scripts" / "starter",
                        ignore=shutil.ignore_patterns("tests", "__pycache__"))
        shutil.copy2(ROOT / "scripts" / "gen_config.py", self.dir / "scripts" / "gen_config.py")
        for name in ("starter.manifest.json",):
            shutil.copy2(ROOT / name, self.dir / name)
        lock = json.loads((ROOT / "starter.lock.json").read_text(encoding="utf-8"))
        lock.update({"project": None, "checksums": {}, "removedModules": []})
        (self.dir / "starter.lock.json").write_text(json.dumps(lock), encoding="utf-8")
        config = json.loads((self.dir / "starter.json").read_text(encoding="utf-8"))
        config["commit"] = {"name": "", "email": ""}
        (self.dir / "starter.json").write_text(json.dumps(config), encoding="utf-8")
        manifest = json.loads((ROOT / "starter.manifest.json").read_text(encoding="utf-8"))
        self.git("remote", "add", "origin", "https://github.com/{}.git".format(manifest["repository"].upper()))
        env = {k: v for k, v in self.env.items() if not k.startswith("GITHUB_")}
        contributor = dict(env, GIT_AUTHOR_NAME="Bob", GIT_AUTHOR_EMAIL="bob@example.com")
        self.assertEqual(self.commit("feat: add the first file", env=contributor).returncode, 0)
        refused = self.commit("Added stuff", env=contributor)
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("type(scope): subject", refused.stderr)
        self.git("remote", "set-url", "origin", "https://github.com/someone/new-app.git")
        refused = self.commit("feat: add a second file", env=contributor)
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("bin/starter init", refused.stderr)

    def test_broken_starter_json_is_named_as_broken(self):
        (self.dir / "starter.json").write_text("{", encoding="utf-8")
        refused = self.commit("feat: add the first file")
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("starter.json: nicht lesbar", refused.stderr)
        self.assertNotIn("Traceback", refused.stderr)

    def test_range_without_the_ref_reports_git(self):
        self.assertEqual(self.commit("feat: add the first file").returncode, 0)
        result = subprocess.run([sys.executable, str(self.dir / "scripts/check_commit_msg.py"), "--bereich", "origin/main..HEAD"],
                                cwd=self.dir, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("git log origin/main..HEAD schlägt fehl", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

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

    def test_range_skips_listed_history_and_commits_github_made(self):
        self.assertEqual(self.commit("feat: add the first file").returncode, 0)
        long = "feat: " + "x" * 100
        (self.dir / "file.txt").write_text("long", encoding="utf-8")
        self.git("add", "-A")
        self.git("commit", "-q", "--no-verify", "-m", long)
        sha = self.git("rev-parse", "HEAD").stdout.strip()
        github = dict(self.env, GIT_AUTHOR_NAME="Contributor", GIT_AUTHOR_EMAIL="c@example.com",
                      GIT_COMMITTER_NAME="GitHub", GIT_COMMITTER_EMAIL="noreply@github.com")
        (self.dir / "file.txt").write_text("merged", encoding="utf-8")
        self.git("add", "-A")
        self.git("commit", "-q", "--no-verify", "-m", "fix: take the pull request (#3)", env=github)
        found = ccm.check_range("HEAD~2..HEAD", IDENTITY, self.dir)
        self.assertEqual(len(found), 1, found)
        self.assertIn("Zeichen", found[0])
        self.assertEqual(ccm.check_range("HEAD~2..HEAD", IDENTITY, self.dir, exceptions=[sha[:7]]), [])
        (self.dir / ".github").mkdir()
        (self.dir / ".github" / "commit-ausnahmen.txt").write_text(f"# x\n{sha[:9]} too long, published\n", encoding="utf-8")
        self.assertEqual(ccm.read_exceptions(self.dir), [sha[:9]])

    def test_pull_request_range_ignores_the_author(self):
        self.assertEqual(self.commit("feat: add the first file").returncode, 0)
        other = dict(self.env, GIT_AUTHOR_NAME="Bob", GIT_AUTHOR_EMAIL="bob@example.com")
        (self.dir / "file.txt").write_text("bob", encoding="utf-8")
        self.git("add", "-A")
        self.git("commit", "-q", "--no-verify", "-m", "fix: change the file", env=other)
        self.assertTrue(ccm.check_range("HEAD~1..HEAD", IDENTITY, self.dir))
        self.assertEqual(ccm.check_range("HEAD~1..HEAD", IDENTITY, self.dir, format_only=True), [])

    def test_push_ranges(self):
        self.assertEqual(self.commit("feat: add the first file").returncode, 0)
        first = self.git("rev-parse", "HEAD").stdout.strip()
        self.assertEqual(self.commit("fix: change the file").returncode, 0)
        head = self.git("rev-parse", "HEAD").stdout.strip()
        repo = {"default_branch": "main"}
        push = {"ref": "refs/heads/main", "before": first, "after": head, "repository": repo}
        self.assertEqual(ccm.github_range("push", push, self.dir)[0], f"{first}..{head}")
        new_branch = dict(push, ref="refs/heads/work", before="0" * 40)
        self.git("update-ref", "refs/remotes/origin/main", first)
        self.assertEqual(ccm.github_range("push", new_branch, self.dir)[0], f"origin/main..{head}")
        first_push = dict(push, before="0" * 40)
        self.assertEqual(ccm.github_range("push", first_push, self.dir)[0], head)
        gone = dict(push, before="d" * 40)
        self.assertEqual(ccm.github_range("push", gone, self.dir)[0], head)

    def test_github_mode_reads_the_event(self):
        self.assertEqual(self.commit("feat: add the first file").returncode, 0)
        head = self.git("rev-parse", "HEAD").stdout.strip()
        event = self.dir / "event.json"
        event.write_text(json.dumps({"ref": "refs/heads/main", "before": "0" * 40, "after": head,
                                     "repository": {"default_branch": "main"}}), encoding="utf-8")
        env = dict(self.env, GITHUB_EVENT_NAME="push", GITHUB_EVENT_PATH=str(event))
        result = subprocess.run([sys.executable, str(self.dir / "scripts/check_commit_msg.py"), "--github"],
                                cwd=self.dir, env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("erster Push von main", result.stdout)


if __name__ == "__main__":
    unittest.main()
