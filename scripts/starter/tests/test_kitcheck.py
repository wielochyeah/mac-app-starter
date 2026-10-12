"""check-kit: the real starter, fixture projects, and the switched-off-check detection."""
import json
import unittest

from starter.tests.helpers import ROOT, TempDirCase, base_files, make_repo, write_files
from starter import kitcheck
from starter.manifest import read_lock
from starter.project import InitOptions, init


def problems_text(findings):
    return "\n".join(findings.problems)


class StarterRepoTests(unittest.TestCase):
    def test_this_repository_passes(self):
        """Governance: every file classified, every module removable, checks switched on."""
        findings = kitcheck.run(ROOT)
        if read_lock(ROOT)["project"] is None:
            self.assertEqual(findings.problems, [], problems_text(findings))


class StarterFixtureTests(TempDirCase):
    def repo(self, extra=None):
        files = base_files()
        files.update(extra or {})
        return make_repo(self.tmp / "repo", files)

    def test_clean_fixture(self):
        f = kitcheck.run(self.repo())
        self.assertEqual(f.problems, [], problems_text(f))

    def test_unclassified_file(self):
        f = kitcheck.run(self.repo({"LICENSE": "MIT\n"}))
        self.assertIn("LICENSE", problems_text(f))

    def test_unguarded_use_of_a_module_type(self):
        f = kitcheck.run(self.repo({
            "App/Sources/Modules/AI/LocalAI.swift": "enum LocalAI {}\n",
            "App/Sources/Modules/MLX/MLXProvider.swift": "struct MLXProvider { let a = LocalAI.self }\n",
            "App/Sources/Kit/Settings/Panes.swift": "let p = LocalAI.self\n",
        }))
        text = problems_text(f)
        self.assertIn("remove ai: App/Sources/Kit/Settings/Panes.swift:1 nutzt LocalAI", text)
        self.assertNotIn("MLXProvider.swift", text, "mlx goes before ai")

    def test_guide_still_naming_a_module(self):
        f = kitcheck.run(self.repo({
            "docs/MODULE.md": "# Module\n\nDie Insel liegt in `App/Sources/Modules/Island/`.\n"
                              "Skill `insel-zustand` hilft.\n<!-- modul:mlx:anfang -->\nai-worker/\n"
                              "<!-- modul:mlx:ende -->\n",
        }))
        text = problems_text(f)
        self.assertIn("remove island: docs/MODULE.md:3 nennt App/Sources/Modules/Island/", text)
        self.assertIn("remove island: docs/MODULE.md:4 nennt `insel-zustand`", text)
        self.assertNotIn("remove mlx", text)

    def test_bad_flags_and_blocks(self):
        f = kitcheck.run(self.repo({
            "App/Sources/Kit/Main/Bad.swift": "#if MODUL_AI && DEBUG\n#endif\n",
            "CLAUDE.md": "<!-- nur-im-starter:anfang -->\nx\n",
        }))
        text = problems_text(f)
        self.assertIn("Bad.swift:1", text)
        self.assertIn("CLAUDE.md", text)

    def test_module_paths_must_not_be_project_files(self):
        root = self.repo({"docs/agents/island.md": "x\n"})
        manifest = json.loads((root / "starter.manifest.json").read_text())
        manifest["modules"]["island"]["paths"].append("docs/agents/island.md")
        write_files(root, {"starter.manifest.json": json.dumps(manifest)})
        self.assertIn("remove würde Projektdateien löschen", problems_text(kitcheck.run(root)))


class ProjectTests(TempDirCase):
    def project(self):
        root = make_repo(self.tmp / "p", base_files())
        init(root, InitOptions(name="Notizen", bundle_id="de.beispiel.notizen", build=False, offline=True))
        return root

    def test_clean_project(self):
        f = kitcheck.run(self.project())
        self.assertEqual(f.problems, [], problems_text(f))

    def test_changed_deleted_and_new_kit_files(self):
        root = self.project()
        write_files(root, {
            "App/Sources/Kit/Core/Lang.swift": "// changed\n",
            "docs/DESIGN.md": None,
            "App/Tests/NotesTests.swift": "x\n",
            "App/Tests/Features/NotesTests.swift": "fine\n",
            "App/Sources/Kit/Texts/CommonText.swift": "shared, may change\n",
        })
        text = problems_text(kitcheck.run(root))
        self.assertIn("App/Sources/Kit/Core/Lang.swift: geändert", text)
        self.assertIn("docs/DESIGN.md: gelöscht", text)
        self.assertIn("App/Tests/NotesTests.swift: neu angelegt", text)
        self.assertNotIn("Features/NotesTests", text)
        self.assertNotIn("CommonText", text)
        self.assertIn("App/Tests/Features/", text)

    def test_starter_leftovers(self):
        root = self.project()
        write_files(root, {"docs/bau/x.md": "x\n", "AGENTS.md": "<!-- nur-im-starter:anfang -->\n<!-- nur-im-starter:ende -->\n"})
        text = problems_text(kitcheck.run(root))
        self.assertIn("docs/bau/x.md", text)
        self.assertIn("AGENTS.md", text)

    def test_missing_check_scripts_fail_in_a_project(self):
        root = self.project()
        write_files(root, {"scripts/check_texts.py": None})
        self.assertIn("scripts/check_texts.py", problems_text(kitcheck.run(root)))

    def test_weakened_hooks_and_ci(self):
        root = self.project()
        write_files(root, {
            "scripts/hooks/pre-push": "#!/bin/zsh\nmake check || true\n",
            ".github/workflows/ci.yml": "jobs:\n  check:\n    continue-on-error: true\n    steps:\n"
                                        "      - run: |\n          make build\n",
        })
        text = problems_text(kitcheck.run(root))
        self.assertIn("scripts/hooks/pre-push: kann nicht mehr scheitern", text)
        self.assertIn("kein Schritt führt „make check“ aus", text)
        self.assertIn("continue-on-error", text)


class SwitchTests(unittest.TestCase):
    WANTED = {"check": ["check-kit", "build", "test"], "check-kit": ["scripts/check_kit.py"],
              "test": ["scripts/test.sh"], "build": ["scripts/build.sh"]}

    def test_real_makefile(self):
        text = (ROOT / "Makefile").read_text()
        self.assertEqual(kitcheck.check_makefile(text, self.WANTED), [])

    def test_dropped_and_weakened(self):
        text = ("check: build test\n\ncheck-kit:\n\t-python3 scripts/check_kit.py\n"
                "test:\n\tscripts/test.sh || true\nbuild:\n\techo\n")
        problems = kitcheck.check_makefile(text, self.WANTED)
        self.assertEqual(len(problems), 4, problems)

    def test_define_blocks_and_variables_are_not_targets(self):
        text = "SHELL := /bin/zsh\ndefine x\nfoo: bar\nendef\n.PHONY: a\na:\n\tb\n"
        self.assertEqual(sorted(kitcheck.makefile_targets(text)), ["a"])

    def test_contains_command(self):
        self.assertTrue(kitcheck.contains_command("exec make check", "make check"))
        self.assertFalse(kitcheck.contains_command("make check-kit", "make check"))

    def test_run_values(self):
        text = "steps:\n  - run: make a\n  - name: x\n    run: |\n      make b\n      # c\n      make d\n  - run: e\n"
        self.assertEqual(kitcheck.run_values(text), ["make a", "make b\nmake d", "e"])


if __name__ == "__main__":
    unittest.main()
