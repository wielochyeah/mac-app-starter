"""Globs, the manifest (schema and path classes), the lock and starter.json."""
import copy
import json
import unittest

from starter.tests.helpers import STARTER_JSON, manifest_obj, real_manifest
from starter import config as cfg
from starter import globs
from starter.common import StarterError, checksum_bytes, cut_blocks, is_safe_repo_path, is_starter_origin
from starter.manifest import parse_manifest


class GlobTests(unittest.TestCase):
    def test_semantics(self):
        self.assertTrue(globs.matches("App/Sources/Kit/Core/Lang.swift", ["App/Sources/Kit/**"]))
        self.assertTrue(globs.matches("App/Sources/Kit/Texts/CommonText.swift", ["App/Sources/Kit/**/*Text.swift"]))
        self.assertTrue(globs.matches("App/Sources/Kit/CommonText.swift", ["App/Sources/Kit/**/*Text.swift"]))
        self.assertFalse(globs.matches("App/Sources/Kit/Core/Lang.swift", ["App/Sources/Kit/**/*Text.swift"]))
        self.assertTrue(globs.matches("ai-worker/requirements.txt", ["ai-worker/requirements*.txt"]))
        self.assertFalse(globs.matches("ai-worker/sub/requirements.txt", ["ai-worker/requirements*.txt"]))
        self.assertTrue(globs.matches("README.md", ["./README.md"]))
        self.assertFalse(globs.matches("docs/README.md", ["./README.md"]))
        self.assertTrue(globs.matches("docs/README.md", ["README.md"]))
        self.assertTrue(globs.matches("a/b.txt", ["a/?.txt"]))
        self.assertEqual(globs.literal_prefix("ai-worker/**"), "ai-worker/")
        self.assertEqual(globs.literal_prefix("./docs/KI.md"), "docs/KI.md")


class CommonTests(unittest.TestCase):
    def test_safe_paths(self):
        for bad in ["", "/etc/x", "../x", "a/../b", "a/./b", ".git/config", "a\\b", "C:/x", "a//b", "a/.GIT/x"]:
            self.assertFalse(is_safe_repo_path(bad), bad)
        self.assertTrue(is_safe_repo_path("docs/vorlagen/PLAN.md"))

    def test_starter_origin(self):
        repo = "wielochyeah/mac-app-starter"
        self.assertTrue(is_starter_origin("https://github.com/wielochyeah/mac-app-starter.git", repo))
        self.assertTrue(is_starter_origin("git@github.com:wielochyeah/mac-app-starter.git", repo))
        self.assertFalse(is_starter_origin("https://github.com/someone/notizen.git", repo))
        self.assertFalse(is_starter_origin("https://github.com/x/my-mac-app-starter.git", repo))
        self.assertFalse(is_starter_origin("", repo))

    def test_checksum_ignores_line_endings_of_text_only(self):
        self.assertEqual(checksum_bytes(b"a\r\nb\n"), checksum_bytes(b"a\nb\n"))
        self.assertNotEqual(checksum_bytes(b"\0a\r\n"), checksum_bytes(b"\0a\n"))

    def test_cut_blocks(self):
        text = "a\n\n<!-- s -->\nx\n<!-- e -->\n\nb\n"
        self.assertEqual(cut_blocks(text, "<!-- s -->", "<!-- e -->"), "a\n\nb\n")
        with self.assertRaises(StarterError):
            cut_blocks("<!-- s -->\nx", "<!-- s -->", "<!-- e -->")
        self.assertEqual(cut_blocks("see `<!-- s -->` here", "<!-- s -->", "<!-- e -->"), "see `<!-- s -->` here")


class ManifestTests(unittest.TestCase):
    def setUp(self):
        self.m = manifest_obj()

    def test_classes(self):
        cases = {
            "App/Sources/Kit/Core/Lang.swift": "kit",
            "App/Sources/Kit/Texts/CommonText.swift": "shared",
            "App/Sources/Modules/Island/IslandText.swift": "shared",
            "App/Sources/Modules/Island/IslandView.swift": "kit",
            "App/Sources/Features/Notes/NotesView.swift": "project",
            "App/Tests/SettingsTests.swift": "kit",
            "App/Tests/Features/NotesTests.swift": "project",
            "App/Resources/AppIcon.icns": "project",
            "App/Resources/InfoPlist.json": "shared",
            "scripts/build.sh": "kit",
            "scripts/projekt/seed.py": "project",
            "rules/gruppen/design.json": "kit",
            "rules/projekt/projekt.json": "project",
            "rules/generated/begriffe.json": "shared",
            "docs/bau/status/K.md": "starterOnly",
            "docs/DECISIONS.md": "project",
            "docs/STARTER_DECISIONS.md": "kit",
            "docs/UEBERGABE.md": "shared",
            "README.md": "shared",
            "starter.json": "shared",
            "starter.manifest.json": "kit",
            "starter.lock.json": "project",
            ".claude/hooks/session-start.py": "kit",
            ".claude/skills/neue-ansicht/SKILL.md": "shared",
            "ai-worker/models.json": "shared",
            "ai-worker/worker.py": "kit",
            "docs/BENUTZER.md": "project",
        }
        for path, cls in cases.items():
            self.assertEqual(self.m.classify(path), cls, path)
        self.assertEqual(self.m.matched_lists("docs/BENUTZER.md"), [])

    def test_modules_match_gen_config(self):
        gc = cfg.gen_config()
        self.assertEqual(list(self.m.modules), list(gc.MODULE_DIRS))
        for name, m in self.m.modules.items():
            self.assertEqual(m.folder, gc.MODULE_DIRS[name])
            self.assertEqual(m.needs, gc.MODULE_DEPENDS.get(name, []))
        self.assertEqual(self.m.dependents("ai"), ["mlx"])
        self.assertEqual(self.m.at_least_one, [["window", "menubar"]])

    def test_module_of(self):
        self.assertEqual(self.m.module_of("ai-worker/worker.py"), "mlx")
        self.assertEqual(self.m.module_of("App/Sources/Modules/Island/A.swift"), "island")
        self.assertIsNone(self.m.module_of("App/Sources/Kit/Core/Lang.swift"))

    def test_schema_errors(self):
        raw = real_manifest()
        broken = copy.deepcopy(raw)
        broken["order"] = ["kit", "shared"]
        with self.assertRaises(StarterError):
            parse_manifest(broken)
        broken = copy.deepcopy(raw)
        broken["modules"]["mlx"]["needs"] = ["nope"]
        with self.assertRaises(StarterError):
            parse_manifest(broken)
        broken = copy.deepcopy(raw)
        broken["starterOnly"]["replace"] = {"../x": "docs/y"}
        with self.assertRaises(StarterError):
            parse_manifest(broken)
        broken = copy.deepcopy(raw)
        del broken["modules"]["window"]["folder"]
        with self.assertRaises(StarterError):
            parse_manifest(broken)


class ConfigTests(unittest.TestCase):
    def test_round_trip_keeps_the_bytes(self):
        self.assertEqual(cfg.format_config(json.loads(STARTER_JSON)), STARTER_JSON)

    def test_merge(self):
        base = {"starter": {"version": "1.0.0"}, "app": {"name": "Starter", "accent": "violett", "x": 1},
                "modules": {"window": True, "island": True, "ai": True}, "texts": {"anrede": "du"}}
        project = {"starter": {"version": "1.0.0"}, "app": {"name": "Notizen", "accent": "violett", "x": 1},
                   "modules": {"window": True, "ai": True}, "texts": {"anrede": "sie"}}
        target = {"starter": {"version": "1.1.0"}, "app": {"name": "Starter", "accent": "blau", "x": 2, "new": "n"},
                  "modules": {"window": True, "island": True, "ai": True, "share": False},
                  "texts": {"anrede": "du"}, "fresh": {"a": 1}}
        merged, notes = cfg.merge_config(project, base, target, ["island"])
        self.assertEqual(merged["starter"]["version"], "1.1.0")
        self.assertEqual(merged["app"], {"name": "Notizen", "accent": "blau", "x": 2, "new": "n"})
        self.assertEqual(merged["modules"], {"window": True, "ai": True, "share": False})
        self.assertEqual(merged["texts"]["anrede"], "sie")
        self.assertEqual(merged["fresh"], {"a": 1})
        self.assertTrue(any("modules.share" in n for n in notes))
        self.assertFalse(any("app.name" in n for n in notes))

    def test_both_changed_keeps_project_and_says_so(self):
        merged, notes = cfg.merge_config({"a": {"v": 2}}, {"a": {"v": 1}}, {"a": {"v": 3}}, [])
        self.assertEqual(merged["a"]["v"], 2)
        self.assertTrue(any("a.v" in n and "behalten" in n for n in notes))


if __name__ == "__main__":
    unittest.main()
