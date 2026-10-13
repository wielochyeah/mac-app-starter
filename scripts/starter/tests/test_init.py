"""bin/starter init on fixture repositories (no build, no network)."""
import unittest

from starter.tests.helpers import ROOT, TempDirCase, base_files, git, make_repo
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

        self.assertNotIn("tagline", config["app"], "the starter's tagline would greet the project's users")
        self.assertEqual(config["texts"]["anrede"], "du")
        self.assertTrue(result.tagline_cleared)

        self.assertIsNone(init(root, options(name="Anders")), "second run changes nothing")
        self.assertEqual(self.json(root, "starter.json")["app"]["name"], "Notizen")

    def test_blocks_in_moved_and_replaced_files(self):
        """A starter-only block in docs/DECISIONS.md is cut in the moved copy, and the template still replaces it."""
        from starter import kitcheck
        root = self.repo({
            "docs/DECISIONS.md": "# Entscheidungen des Starters\n\nE-01\n\n<!-- nur-im-starter:anfang -->\n"
                                 "Bauplan\n<!-- nur-im-starter:ende -->\n",
        })
        result = init(root, options())
        self.assertEqual(self.read(root, "docs/DECISIONS.md"), "# Entscheidungen\n\n(leer)\n")
        self.assertEqual(self.read(root, "docs/STARTER_DECISIONS.md"), "# Entscheidungen des Starters\n\nE-01\n")
        self.assertIn("docs/STARTER_DECISIONS.md", result.blocks)
        self.assertNotIn("docs/DECISIONS.md", result.blocks)
        f = kitcheck.run(root)
        self.assertEqual(f.problems, [], "\n".join(f.problems))

    def test_blocks_in_every_comment_syntax(self):
        root = self.repo({
            ".github/workflows/ci.yml": "jobs:\n  check:\n    steps:\n      - run: make check\n"
                                        "  # nur-im-starter:anfang\n  template-probe:\n    steps:\n"
                                        "      - run: bin/starter init\n  # nur-im-starter:ende\n",
            "App/Sources/Kit/Main/Probe.swift": "let a = 1\n// nur-im-starter:anfang\nlet b = 2\n"
                                                "// nur-im-starter:ende\nlet c = 3\n",
            "scripts/hooks/pre-push": "#!/bin/zsh\n# nur-im-starter:anfang\necho bau\n# nur-im-starter:ende\n"
                                      "exec make check\n",
        })
        result = init(root, options())
        self.assertEqual(self.read(root, ".github/workflows/ci.yml"),
                         "jobs:\n  check:\n    steps:\n      - run: make check\n")
        self.assertEqual(self.read(root, "App/Sources/Kit/Main/Probe.swift"), "let a = 1\nlet c = 3\n")
        self.assertEqual(self.read(root, "scripts/hooks/pre-push"), "#!/bin/zsh\nexec make check\n")
        self.assertIn("scripts/hooks/pre-push", result.blocks)

    def test_anrede_people_and_rules(self):
        """init writes the chosen address form, drops the starter author's names and regenerates the rules."""
        import json as jsonlib
        from starter.project import report
        config = jsonlib.loads(base_files()["starter.json"])
        config["texts"]["personen"] = ["Riad"]
        sync = ("import json, pathlib\n"
                "c = json.loads(pathlib.Path('starter.json').read_text())\n"
                "pathlib.Path('rules/generated').mkdir(parents=True, exist_ok=True)\n"
                "pathlib.Path('rules/generated/stand.json').write_text(json.dumps(c['texts']))\n")
        root = self.repo({"starter.json": jsonlib.dumps(config, ensure_ascii=False, indent=2) + "\n",
                          "scripts/rules_sync.py": sync})
        result = init(root, options(anrede="sie"))
        self.assertIsNone(result.anrede_findings, "the fixture's check_texts.py writes no JSON")
        written = self.json(root, "starter.json")
        self.assertEqual(written["texts"]["anrede"], "sie")
        self.assertNotIn("personen", written["texts"])
        self.assertNotIn("tagline", written["app"])
        self.assertEqual(self.json(root, "rules/generated/stand.json"), written["texts"],
                         "make rules ran on the new starter.json")
        text = report(result, dry_run=False, build=False)
        self.assertIn("app.tagline des Starters entfernt", text)
        self.assertIn("Anrede Sie", text)
        self.assertIn("make rules: CLAUDE.md Teil A", text)

    def test_anrede_sie_records_the_du_texts_as_known_findings(self):
        """The kit's du texts become findings with anrede sie: they go into the baseline, so make check stays green and
        the list stays as the to-do."""
        import json as jsonlib
        from starter.project import report
        finding = {"path": "App/Sources/Kit/Texts/CommonText.swift", "line": 3, "column": 5, "term_id": "anrede-du",
                   "label": "du", "rules": ["S-05"], "hint": "Sie", "match": "du  kannst", "context": "x"}
        fake = ("import json, sys\n"
                "out = sys.argv[sys.argv.index('--json') + 1]\n"
                f"json.dump({{'dateien': 1, 'neu': [{finding!r}, {dict(finding, line=9, match='dein')!r}], "
                "'bekannt': [], 'veraltet': []}, open(out, 'w'))\n")
        root = self.repo({"scripts/check_texts.py": fake,
                          "rules/baseline/texte.json": jsonlib.dumps({"README.md": ["x | y"]}) + "\n"})
        result = init(root, options(anrede="sie"))
        self.assertEqual(result.anrede_findings, 2)
        self.assertEqual(self.json(root, "rules/baseline/texte.json"),
                         {"App/Sources/Kit/Texts/CommonText.swift": ["anrede-du | du kannst", "anrede-du | dein"],
                          "README.md": ["x | y"]})
        text = report(result, dry_run=False, build=False)
        self.assertIn("2 Stellen", text)
        self.assertIn("--baseline-aktualisieren", text)

    def test_failed_rules_sync_is_a_note(self):
        root = self.repo({"scripts/rules_sync.py": "import sys\nprint('texts.anrede kaputt')\nsys.exit(1)\n"})
        result = init(root, options())
        self.assertTrue(any("make rules ist gescheitert" in n and "texts.anrede kaputt" in n for n in result.notes))
        self.assertFalse(result.rules_synced)

    def test_red_build_keeps_the_report(self):
        from starter.manifest import PENDING
        from starter.project import report
        from unittest import mock
        from starter import project
        root = self.repo()
        with mock.patch.object(project, "swift_missing", return_value=None):  # also on Linux: make build runs and fails
            result = init(root, options(build=True))
        self.assertIs(result.build_ok, False)
        self.assertEqual(read_lock(root)[PENDING], "bin/starter init")
        text = report(result, dry_run=False, build=True)
        self.assertIn("Commit-Identität geleert", text)
        self.assertIn("make build ist rot", text)
        self.assertIn("commit.name und commit.email in starter.json eintragen", text)

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
                    options(symbol="Not A Symbol"), options(anrede="ihr")]:
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

    def test_unguarded_module_type_stops_init_before_any_write(self):
        root = self.repo({"App/Sources/Modules/Island/IslandView.swift": "struct IslandView {}\n",
                          "App/Sources/Kit/Main/Use.swift": "let v = IslandView()\n"})
        with self.assertRaises(StarterError) as e:
            init(root, options(remove=["island"]))
        self.assertIn("App/Sources/Kit/Main/Use.swift:1 nutzt IslandView", str(e.exception))
        self.assertEqual(git(root, "status", "--porcelain"), "")

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
        answers = iter(["1abc", "Mein Tool", "", "pink", "rot", "Not Valid", "hammer", "ihr", "sie",
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
        self.assertEqual((opts.name, opts.bundle_id, opts.accent, opts.symbol, opts.anrede),
                         ("Mein Tool", "com.example.meintool", "rot", "hammer", "sie"))
        self.assertEqual(opts.remove, ["island", "examples"], "Enter keeps mlx, also while it is off in starter.json")
        self.assertEqual(sum(1 for p in asked if p.startswith("Name")), 2)

    def scripted(self, answers, config=None):
        answers = iter(answers)
        asked, said = [], []

        def ask(prompt, default, check):
            while True:
                answer = next(answers) or (default or "")
                asked.append(prompt)
                if check(answer) is None:
                    return answer
                said.append(check(answer))

        m = manifest_obj()
        config = config or {"app": {}, "modules": {n: n != "mlx" for n in m.modules}}
        opts = interactive_values(m, config, ask, list(m.modules), say=said.append)
        return opts, asked, said

    def test_interactive_drops_a_dependent_with_its_dependency(self):
        config = {"app": {}, "modules": {n: True for n in manifest_obj().modules}}
        opts, asked, said = self.scripted(["App", "", "", "", "", "j", "j", "j", "j", "j", "n", "j"], config)
        self.assertEqual(opts.remove, ["ai", "mlx"])
        self.assertFalse(any(p.startswith("Modul mlx") for p in asked), "mlx is not asked once ai goes")
        self.assertTrue(any("mlx" in s and "mit entfernt" in s for s in said))

    def test_interactive_keeps_the_last_app_form(self):
        opts, asked, said = self.scripted(["App", "", "", "", "", "n", "n", "j", "j", "j", "j", "j", "", "j"])
        self.assertEqual(opts.remove, ["window"])
        self.assertEqual(sum(1 for p in asked if p.startswith("Modul menubar")), 2)
        self.assertTrue(any("window, menubar" in s for s in said))

    def test_flags_become_the_defaults_of_the_questions(self):
        from starter.project import with_flag_defaults
        config = {"app": {"accent": "violett", "symbol": "sparkles"}, "texts": {"anrede": "du"}}
        answers = iter(["Notizen", "", "", "", "", "j", "j", "j", "j", "j", "j", "j", "j"])
        opts = interactive_values(manifest_obj(), with_flag_defaults(config, accent="blau", symbol="note.text", anrede="sie"),
                                  lambda prompt, default, check: next(answers) or default, list(manifest_obj().modules))
        self.assertEqual((opts.accent, opts.symbol, opts.anrede), ("blau", "note.text", "sie"))
        self.assertEqual(config["app"]["accent"], "violett", "the read config stays as it was")

    def test_a_bundle_id_flag_is_the_default_and_the_answer_wins(self):
        m = manifest_obj()
        for answer, expected in [("", "de.firma.notizen"), ("de.firma.anders", "de.firma.anders")]:
            answers = iter(["Notizen", answer, "", "", ""] + ["j"] * len(m.modules))
            opts = interactive_values(m, {"app": {}}, lambda prompt, default, check: next(answers) or default,
                                      list(m.modules), bundle_id="de.firma.notizen")
            self.assertEqual(opts.bundle_id, expected, answer)

    def test_an_unknown_sf_symbol_stops_init_before_any_write(self):
        from unittest import mock
        from starter import project
        root = self.repo()
        with mock.patch.object(project, "symbol_problem", return_value="gibt es auf diesem Mac nicht als SF Symbol"):
            with self.assertRaises(StarterError) as caught:
                init(root, options(symbol="kein.symbol"))
        self.assertIn("--symbol „kein.symbol“", str(caught.exception))
        self.assertIsNone(read_lock(root)["project"])
        self.assertTrue((root / "docs/bau").exists())

    def test_interactive_symbol_question_asks_again_for_an_unknown_symbol(self):
        m = manifest_obj()
        answers = iter(["Notizen", "", "", "kein.symbol", "note.text", ""] + ["j"] * len(m.modules))
        asked = []

        def ask(prompt, default, check):
            while True:
                answer = next(answers) or (default or "")
                asked.append(prompt)
                if check(answer) is None:
                    return answer

        opts = interactive_values(m, {"app": {}}, ask, list(m.modules),
                                  symbol_check=lambda v: None if v == "note.text" else "unbekannt")
        self.assertEqual(opts.symbol, "note.text")
        self.assertEqual(sum(1 for p in asked if p.startswith("SF Symbol")), 2)

    @unittest.skipUnless(__import__("sys").platform == "darwin" and __import__("shutil").which("swiftc"),
                         "asks AppKit through a small Swift tool (macOS)")
    def test_real_sf_symbols(self):
        from starter.project import symbol_problem
        root = self.repo()
        (root / "scripts" / "pick-sdk.sh").write_bytes((ROOT / "scripts" / "pick-sdk.sh").read_bytes())
        (root / "scripts" / "pick-sdk.sh").chmod(0o755)
        self.assertIsNone(symbol_problem(root, "sparkles"))
        self.assertIn("SF Symbol", symbol_problem(root, "kein.symbol.xyz"))

    def test_placeholder_bundle_id_and_unknown_starter_commit_are_explained(self):
        from starter.project import report
        root = self.repo()
        result = init(root, options(bundle_id="com.example.notizen"))
        text = report(result, dry_run=False, build=False)
        self.assertIn("com.example. ist ein Platzhalter", text)
        self.assertIn("Starter-Commit: unbekannt: der Tag v1.0.0", text)
        self.assertIn("kein Fehler", text)

    def test_the_starter_tour_goes_and_the_readme_starts_with_the_project(self):
        tour = ("<!-- nur-im-starter:anfang -->\n# Mac-App-Starter\n\nVorlage.\n\n"
                "![Insel](docs/screenshots/de-dark-island.pane.png)\n<!-- nur-im-starter:ende -->\n\n## Aufbau\n\nText.\n")
        listing = ("# Bilder\n# nur-im-starter:anfang\nde-dark/island.pane.png  # modul:island\n# nur-im-starter:ende\n"
                   "de-light/settings.window.png\n")
        root = self.repo({"README.md": tour, "docs/screenshots/list.txt": listing,
                          "docs/screenshots/de-dark-island.pane.png": "png",
                          "docs/screenshots/de-light-settings.window.png": "png",
                          "docs/screenshots/de-light-own.png": "png",
                          "docs/PROJECT.md": "![eigenes](docs/screenshots/de-light-own.png)\n"})
        dry = init(root, options(dry_run=True))
        self.assertEqual(dry.pictures_removed, ["docs/screenshots/de-dark-island.pane.png"])
        self.assertTrue((root / "docs/screenshots/de-dark-island.pane.png").exists())
        result = init(root, options())
        readme = self.read(root, "README.md")
        self.assertTrue(readme.startswith("# Notizen\n\nNotizen ist eine native Mac-App"), readme)
        self.assertNotIn("Mac-App-Starter", readme)
        self.assertIn("## Aufbau", readme)
        self.assertTrue(result.readme_intro)
        self.assertEqual(result.pictures_removed, ["docs/screenshots/de-dark-island.pane.png"])
        self.assertFalse((root / "docs/screenshots/de-dark-island.pane.png").exists())
        self.assertTrue((root / "docs/screenshots/de-light-settings.window.png").exists(), "still listed")
        self.assertTrue((root / "docs/screenshots/de-light-own.png").exists(), "named by a guide")
        self.assertEqual(self.read(root, "docs/screenshots/list.txt"), "# Bilder\nde-light/settings.window.png\n")

    def test_default_bundle_id(self):
        self.assertEqual(default_bundle_id("Meine App 2"), "com.example.meineapp2")


if __name__ == "__main__":
    unittest.main()
