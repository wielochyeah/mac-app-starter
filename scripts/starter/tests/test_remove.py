"""bin/starter remove on a fixture repository (no build: build=False)."""
import json
import unittest

from starter.tests.helpers import TempDirCase, base_files, git, make_repo, write_files
from starter.common import StarterError
from starter.manifest import read_lock
from starter.remove import remove_module


class RemoveTests(TempDirCase):
    def repo(self, extra=None, origin=None):
        files = base_files()
        files.update(extra or {})
        return make_repo(self.tmp / "repo", files, origin)

    def remove(self, root, name, **kw):
        kw.setdefault("build", False)
        return remove_module(root, name, **kw)

    def test_removes_files_blocks_markers_and_the_switch(self):
        root = self.repo({"docs/MODULE.md": "# Module\n<!-- modul:island:anfang -->\n## Insel\n"
                                            "<!-- modul:island:ende -->\n## Rest\n"})
        plan = self.remove(root, "island")
        self.assertIn("App/Sources/Modules/Island/IslandModule.swift", plan.deleted)
        self.assertFalse((root / "App/Sources/Modules/Island").exists())
        modules = self.read(root, "App/Sources/Kit/Main/Modules.swift")
        self.assertNotIn("Island", modules)
        self.assertIn("WindowModule.register()", modules)
        self.assertEqual(plan.emptied, ["App/Tests/IslandTests.swift"])
        self.assertFalse((root / "App/Tests/IslandTests.swift").exists())
        self.assertNotIn("Island", self.read(root, "README.md"))
        self.assertEqual(self.read(root, "docs/MODULE.md"), "# Module\n## Rest\n")
        config = self.json(root, "starter.json")
        self.assertNotIn("island", config["modules"])
        self.assertEqual(read_lock(root)["removedModules"], ["island"])
        self.assertEqual(read_lock(root)["checksums"], {}, "no project yet: no checksums")
        self.assertTrue(self.remove(root, "island").already_removed)

    def test_earlier_kit_changes_stay_visible_after_remove(self):
        from starter import kitcheck
        from starter.project import InitOptions, init
        root = self.repo()
        init(root, InitOptions(name="Notizen", bundle_id="de.beispiel.notizen", build=False, offline=True))
        write_files(root, {
            "App/Sources/Kit/Core/Lang.swift": "func tr(en: String, de: String) -> String { de }\n",
            "App/Tests/MineTests.swift": "x\n",
        })
        self.remove(root, "hotkeys", check_origin=False)
        text = "\n".join(kitcheck.run(root).problems)
        self.assertIn("App/Sources/Kit/Core/Lang.swift: geändert", text)
        self.assertIn("App/Tests/MineTests.swift: neu angelegt", text)
        self.assertNotIn("Modules.swift", text, "the removal's own edit is recorded")
        self.assertNotIn("HotkeysModule.swift", text)

    def test_baseline_entries_of_deleted_files_go(self):
        baseline = {"App/Sources/Kit/Core/Lang.swift": ["a | b | c"],
                    "App/Sources/Modules/Island/IslandText.swift": ["d | e | f"],
                    "App/Tests/IslandTests.swift": ["g | h | i"]}
        root = self.repo({"rules/baseline/texte.json": json.dumps(baseline, indent=2) + "\n"})
        plan = self.remove(root, "island")
        self.assertIn("rules/baseline/texte.json", plan.edited)
        self.assertEqual(self.json(root, "rules/baseline/texte.json"),
                         {"App/Sources/Kit/Core/Lang.swift": ["a | b | c"]})

    def test_red_build_is_reported_and_finished_by_a_second_run(self):
        """make build fails (the fixture's build.sh is not executable): the report keeps the next steps and a
        recovery command, the lock notes the red build, and the next call builds again instead of saying done."""
        import contextlib
        import io
        from unittest import mock
        from starter import cli
        from starter import remove as remove_file
        from starter.manifest import PENDING
        from starter.remove import report
        root = self.repo()
        # also on Linux: make build runs (and fails) instead of being skipped for a missing Swift compiler
        patch = mock.patch.object(remove_file, "swift_missing", return_value=None)
        patch.start()
        self.addCleanup(patch.stop)
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            plan = remove_module(root, "background", build=True, check_origin=False)
        self.assertIs(plan.build_ok, False)
        text = report(plan, dry_run=False, build=True)
        self.assertIn("make build ist rot", text)
        self.assertIn("Anmeldeobjekte", text, "the module's next steps are printed")
        self.assertIn("git restore --source=HEAD --staged --worktree -- App/Sources/Modules/Background/", text)
        self.assertNotIn("make check, dann ein Commit", text)
        self.assertEqual(read_lock(root)[PENDING], "bin/starter remove background")
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            self.assertEqual(cli.finish_pending_build(root, "bin/starter remove background", True), 1)
        self.assertIn("weiter rot", out.getvalue())
        write_files(root, {"Makefile": self.read(root, "Makefile").replace("@scripts/build.sh", "@true")})
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(cli.finish_pending_build(root, "bin/starter remove background", True), 0)
        self.assertNotIn(PENDING, read_lock(root))
        self.assertIsNone(cli.finish_pending_build(root, "bin/starter remove background", True))

    def test_uncommitted_files_keep_their_whole_name(self):
        from starter.remove import uncommitted
        root = self.repo()
        write_files(root, {"README.md": "changed\n", "App/Sources/Features/New.swift": "enum New {}\n"})
        git(root, "mv", "docs/DESIGN.md", "docs/GESTALTUNG.md")
        self.assertEqual(sorted(uncommitted(root)), ["App/Sources/Features/New.swift", "README.md", "docs/GESTALTUNG.md"])
        plan = self.remove(root, "island")
        self.assertIn("README.md", plan.dirty)

    def test_without_a_swift_compiler_the_build_is_skipped_and_noted(self):
        """A cloud agent on Linux: remove writes its changes, skips make build, says so and notes pendingBuild."""
        import contextlib
        import io
        from unittest import mock
        from starter import cli, remove as remove_module_file
        from starter.manifest import PENDING
        root = self.repo()
        with mock.patch.object(remove_module_file, "swift_missing", return_value="kein Swift-Compiler (kein Mac, Linux)"), \
                mock.patch.object(remove_module_file, "run_make", side_effect=AssertionError("built")):
            plan = remove_module(root, "island", build=True, check_origin=False)
            text = remove_module_file.report(plan, dry_run=False, build=True)
            self.assertIsNone(plan.build_ok)
            self.assertIn("kein Swift-Compiler (kein Mac, Linux): Build übersprungen", text)
            self.assertIn("--ohne-build", text)
            self.assertEqual(read_lock(root)[PENDING], "bin/starter remove island")
            err = io.StringIO()
            with contextlib.redirect_stderr(err):
                self.assertEqual(cli.finish_pending_build(root, "bin/starter remove island", True), 1)
            self.assertIn("steht make build noch aus", err.getvalue())

    def test_lines_and_pictures_of_the_module_scenes_go(self):
        listing = ("# Bilder\nde-dark/island.pane.png\nde-light/examples.menubar.png  # modul:examples,island\n"
                   "de-light/settings.window.png\ntools/icon.png\n")
        root = self.repo({"docs/screenshots/list.txt": listing,
                          "docs/screenshots/de-dark-island.pane.png": "png",
                          "docs/screenshots/de-light-examples.menubar.png": "png",
                          "docs/screenshots/de-light-settings.window.png": "png",
                          "docs/screenshots/en-dark-island.done.png": "png",
                          "docs/PROJECT.md": "# Projekt\n\n![Insel](docs/screenshots/en-dark-island.done.png)\n"})
        plan = self.remove(root, "island")
        self.assertEqual(plan.pictures, ["docs/screenshots/de-dark-island.pane.png",
                                         "docs/screenshots/de-light-examples.menubar.png",
                                         "docs/screenshots/en-dark-island.done.png"])
        self.assertEqual(plan.picture_refs, ["docs/PROJECT.md:3"])
        from starter.remove import report
        self.assertIn("Diese Stellen zeigen noch ein gelöschtes Bild, bitte anpassen: docs/PROJECT.md:3",
                      report(plan, dry_run=False, build=False))
        self.assertEqual(self.read(root, "docs/screenshots/list.txt"),
                         "# Bilder\nde-light/settings.window.png\ntools/icon.png\n")
        self.assertFalse((root / "docs/screenshots/de-dark-island.pane.png").exists())
        self.assertTrue((root / "docs/screenshots/de-light-settings.window.png").exists())

    def test_dry_run_report_speaks_of_what_would_happen(self):
        from starter.remove import report
        root = self.repo()
        text = report(self.remove(root, "window", dry_run=True), dry_run=True, build=True)
        self.assertIn("würde ändern", text)
        self.assertIn("1 Datei löschen", text)
        self.assertNotIn(" entfernt in", text)

    def test_next_steps_name_the_bundle_id(self):
        root = self.repo()
        plan = self.remove(root, "mlx", dry_run=True)
        self.assertTrue(any("com.example.starter" in s for s in plan.next_steps), plan.next_steps)

    def test_dry_run_writes_nothing(self):
        root = self.repo()
        plan = self.remove(root, "island", dry_run=True)
        self.assertTrue(plan.deleted)
        self.assertEqual(git(root, "status", "--porcelain"), "")

    def test_dangling_reference_writes_nothing(self):
        root = self.repo({
            "App/Sources/Modules/Island/IslandController.swift": "final class IslandController {}\n",
            "App/Sources/Kit/Main/Use.swift": "func show() { _ = IslandController() }\n",
        })
        plan = self.remove(root, "island")
        self.assertEqual(plan.dangling,
                         ["App/Sources/Kit/Main/Use.swift:1 nutzt IslandController "
                          "(aus App/Sources/Modules/Island/IslandController.swift)"])
        self.assertEqual(git(root, "status", "--porcelain"), "")

    def test_guarded_use_is_fine(self):
        root = self.repo({
            "App/Sources/Modules/Island/IslandController.swift": "final class IslandController {}\n",
            "App/Sources/Kit/Main/Use.swift": "func show() {\n    #if MODUL_ISLAND\n    _ = IslandController()\n"
                                              "    #endif\n}\n",
        })
        plan = self.remove(root, "island")
        self.assertEqual(plan.dangling, [])
        self.assertEqual(self.read(root, "App/Sources/Kit/Main/Use.swift"), "func show() {\n}\n")

    def test_ai_needs_mlx_removed_first(self):
        root = self.repo()
        with self.assertRaises(StarterError) as e:
            self.remove(root, "ai")
        self.assertIn("mlx", str(e.exception))
        self.remove(root, "mlx")
        self.assertFalse((root / "ai-worker").exists())
        self.remove(root, "ai")
        self.assertEqual(read_lock(root)["removedModules"], ["ai", "mlx"])

    def test_window_and_menubar_cannot_both_go(self):
        root = self.repo()
        self.remove(root, "window")
        with self.assertRaises(StarterError) as e:
            self.remove(root, "menubar")
        self.assertIn("window, menubar", str(e.exception))
        self.assertTrue((root / "App/Sources/Modules/MenuBar").exists())

    def test_menubar_switched_off_counts_as_gone(self):
        root = self.repo()
        config = self.json(root, "starter.json")
        config["modules"]["menubar"] = False
        write_files(root, {"starter.json": json.dumps(config)})
        with self.assertRaises(StarterError) as e:
            self.remove(root, "window")
        self.assertIn("menubar ist vorhanden, aber in starter.json aus", str(e.exception))

    def test_unknown_module(self):
        with self.assertRaises(StarterError):
            self.remove(self.repo(), "notch")

    def test_refuses_in_the_starter_itself(self):
        root = self.repo(origin="https://github.com/wielochyeah/mac-app-starter.git")
        with self.assertRaises(StarterError) as e:
            self.remove(root, "island")
        self.assertIn("Starter selbst", str(e.exception))

    def test_permissions_only_go_when_no_other_module_needs_them(self):
        root = self.repo()
        manifest = self.json(root, "starter.manifest.json")
        manifest["modules"]["island"]["permissions"] = ["notifications"]
        manifest["modules"]["background"]["permissions"] = ["notifications"]
        manifest["modules"]["hotkeys"]["permissions"] = ["accessibility"]
        config = self.json(root, "starter.json")
        config["permissions"] = ["notifications", "accessibility"]
        write_files(root, {"starter.manifest.json": json.dumps(manifest), "starter.json": json.dumps(config)})
        self.remove(root, "island")
        self.assertEqual(self.json(root, "starter.json")["permissions"], ["notifications", "accessibility"])
        self.remove(root, "hotkeys")
        self.assertEqual(self.json(root, "starter.json")["permissions"], ["notifications"])

    def test_examples_with_strip_examples_name(self):
        root = self.repo()
        self.remove(root, "examples")
        self.assertFalse((root / "App/Sources/Modules/Examples").exists())
        self.assertNotIn("ExamplesModule", self.read(root, "App/Sources/Kit/Main/Modules.swift"))


if __name__ == "__main__":
    unittest.main()
