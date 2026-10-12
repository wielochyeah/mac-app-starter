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
