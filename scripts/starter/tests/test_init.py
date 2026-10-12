"""bin/starter init on fixture repositories (no build, no network)."""
import unittest

from starter.tests.helpers import TempDirCase, base_files, git, make_repo
from starter.common import StarterError, checksum
from starter.manifest import read_lock
from starter.project import InitOptions, default_bundle_id, init, interactive_values, removal_order
from starter.tests.helpers import manifest_obj


def options(**kw):
    kw.setdefault("name", "Notizen")
    kw.setdefault("bundle_id", "de.beispiel.notizen")
    kw.setdefault("build", False)
    kw.setdefault("offline", True)
    kw.setdefault("today", "2026-10-12")
    return InitOptions(**kw)


class InitTests(TempDirCase):
    def repo(self, extra=None, origin=None):
        files = base_files()
        files.update(extra or {})
        return make_repo(self.tmp / "repo", files, origin)

    def test_turns_the_copy_into_a_project(self):
        root = self.repo({"docs/agents/PLAN.md": "# Plan des Starters\n", "docs/vorlagen/PLAN.md": "# Plan\n"})
        result = init(root, options(accent="blau", symbol="note.text", remove=["examples"]))
        config = self.json(root, "starter.json")
        self.assertEqual(config["app"]["name"], "Notizen")
        self.assertEqual(config["app"]["bundleId"], "de.beispiel.notizen")
        self.assertEqual(config["app"]["displayName"], {"en": "Notizen", "de": "Notizen"})
        self.assertEqual(config["app"]["accent"], "blau")
        self.assertEqual(config["app"]["symbol"], "note.text")
        self.assertEqual(config["app"]["version"], "0.1.0")
        self.assertEqual(config["app"]["copyright"], "© 2026")
        self.assertEqual(config["commit"], {"name": "", "email": ""})
        self.assertEqual(config["signing"]["identity"], "-")
        self.assertNotIn("examples", config["modules"])
        self.assertTrue(result.identity_cleared)

        self.assertFalse((root / "docs/bau").exists())
        self.assertIn("docs/bau/status/S0.md", result.removed)
        self.assertEqual(self.read(root, "docs/STARTER_DECISIONS.md"), "# Entscheidungen des Starters\n\nE-01 …\n")
        self.assertEqual(self.read(root, "docs/DECISIONS.md"), "# Entscheidungen\n\n(leer)\n")
        self.assertEqual(self.read(root, "docs/agents/PLAN.md"), "# Plan\n")
        readme = self.read(root, "README.md")
        self.assertNotIn("nur-im-starter", readme)
        self.assertNotIn("Bau läuft", readme)
        self.assertEqual(result.blocks, ["README.md"])

        lock = read_lock(root)
        self.assertEqual(lock["project"], "Notizen")
        self.assertEqual(lock["state"], "project")
        self.assertEqual(lock["source"], "wielochyeah/mac-app-starter")
        self.assertEqual(lock["createdOn"], "2026-10-12")
        self.assertEqual(lock["removedModules"], ["examples"])
        self.assertIn("App/Sources/Kit/Main/Modules.swift", lock["checksums"])
        self.assertIn("docs/STARTER_DECISIONS.md", lock["checksums"])
        self.assertNotIn("starter.json", lock["checksums"])
        self.assertNotIn("App/Sources/Kit/Texts/CommonText.swift", lock["checksums"], "texts are shared")
        self.assertEqual(lock["checksums"]["App/Sources/Kit/Main/Modules.swift"],
                         checksum(root, "App/Sources/Kit/Main/Modules.swift"))

        self.assertIsNone(init(root, options(name="Anders")), "second run changes nothing")
        self.assertEqual(self.json(root, "starter.json")["app"]["name"], "Notizen")

    def test_dry_run_writes_nothing(self):
        root = self.repo()
        result = init(root, options(dry_run=True, remove=["island"]))
        self.assertEqual(result.modules_removed, ["island"])
        self.assertEqual(git(root, "status", "--porcelain"), "")

    def test_refuses_in_the_starter_itself(self):
        root = self.repo(origin="git@github.com:wielochyeah/mac-app-starter.git")
        with self.assertRaises(StarterError):
            init(root, options())

    def test_another_origin_is_a_copy(self):
        root = self.repo(origin="https://github.com/beispiel/notizen.git")
        self.assertIsNotNone(init(root, options()))

    def test_invalid_values(self):
        root = self.repo()
        for bad in [options(name="1App"), options(bundle_id="notizen"), options(accent="pink"),
                    options(symbol="Not A Symbol")]:
            with self.assertRaises(StarterError):
                init(root, bad)
        self.assertEqual(git(root, "status", "--porcelain"), "")

    def test_module_rules(self):
        root = self.repo()
        with self.assertRaises(StarterError) as e:
            init(root, options(remove=["ai"]))
        self.assertIn("mlx", str(e.exception))
        with self.assertRaises(StarterError):
            init(root, options(remove=["window", "menubar"]))
        with self.assertRaises(StarterError):
            init(root, options(remove=["notch"]))
        self.assertEqual(git(root, "status", "--porcelain"), "")
        init(root, options(remove=["ai", "mlx"]))
        self.assertEqual(read_lock(root)["removedModules"], ["ai", "mlx"])

    def test_removal_order(self):
        m = manifest_obj()
        present = list(m.modules)
        self.assertEqual(removal_order(m, ["ai", "mlx", "island"], present), ["mlx", "ai", "island"])
        self.assertEqual(removal_order(m, ["island", "island"], present), ["island"])

    def test_missing_template_leaves_the_file(self):
        root = self.repo({"docs/agents/VORGABEN.md": "# Vorgaben des Starters\n"})
        result = init(root, options())
        self.assertEqual(self.read(root, "docs/agents/VORGABEN.md"), "# Vorgaben des Starters\n")
        self.assertTrue(any("VORGABEN" in m for m in result.missing_templates))

    def test_interactive_questions_re_ask_until_valid(self):
        answers = iter(["1abc", "Mein Tool", "", "pink", "rot", "Not Valid", "hammer",
                        "j", "j", "x", "n", "j", "j", "j", "", "n"])
        asked = []

        def ask(prompt, default, check):
            while True:
                answer = next(answers) or (default or "")
                asked.append(prompt)
                if check(answer) is None:
                    return answer

        m = manifest_obj()
        opts = interactive_values(m, {"app": {"accent": "violett", "symbol": "sparkles"}}, ask, list(m.modules))
        self.assertEqual((opts.name, opts.bundle_id, opts.accent, opts.symbol),
                         ("Mein Tool", "com.example.meintool", "rot", "hammer"))
        self.assertEqual(opts.remove, ["island", "examples"])
        self.assertEqual(sum(1 for p in asked if p.startswith("Name")), 2)

    def test_default_bundle_id(self):
        self.assertEqual(default_bundle_id("Meine App 2"), "com.example.meineapp2")


if __name__ == "__main__":
    unittest.main()
