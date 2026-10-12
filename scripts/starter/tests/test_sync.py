"""bin/starter sync against a local starter repository with tags v1.0.0 and v1.1.0."""
import json
import shutil
import unittest

from starter.tests.helpers import TempDirCase, base_files, git, make_repo, write_files
from starter.common import StarterError
from starter.manifest import read_lock
from starter.project import InitOptions, init
from starter.remove import remove_module
from starter.sync import sync

SHARED_V1 = "# Agents\n\nline one\nline two\nline three\nline four\nline five\n"


class SyncTests(TempDirCase):
    def setUp(self):
        super().setUp()
        files = base_files()
        files["AGENTS.md"] = SHARED_V1
        files["CLAUDE.md"] = "# Claude\n\nRegel A\n"
        files["docs/KI.md"] = "# KI\n"
        files["App/Sources/Kit/Core/Old.swift"] = "enum Old {}\n"
        self.starter = make_repo(self.tmp / "starter", files)
        git(self.starter, "tag", "v1.0.0")
        self.project = self.tmp / "project"
        shutil.copytree(self.starter, self.project, ignore=shutil.ignore_patterns(".git"))
        make_repo(self.project, {})
        init(self.project, InitOptions(name="Notizen", bundle_id="de.beispiel.notizen", build=False, offline=True,
                                       today="2026-10-12"))
        remove_module(self.project, "island", build=False, check_origin=False)
        git(self.project, "add", "-A")
        git(self.project, "commit", "-qm", "project")
        self.base_commit = git(self.starter, "rev-parse", "HEAD")

    def release(self, files, tag="v1.1.0"):
        write_files(self.starter, files)
        git(self.starter, "add", "-A")
        git(self.starter, "commit", "-qm", tag)
        git(self.starter, "tag", tag)

    def run_sync(self, **kw):
        kw.setdefault("source", str(self.starter))
        kw.setdefault("today", "2026-11-01")
        return sync(self.project, "v1.1.0", **kw)

    def test_kit_shared_and_config(self):
        modules = self.read(self.starter, "App/Sources/Kit/Main/Modules.swift")
        starter_json = self.json(self.starter, "starter.json")
        starter_json["starter"]["version"] = "1.1.0"
        starter_json["modules"]["share"] = False
        starter_json["texts"]["languages"] = ["en", "de", "fr"]
        self.release({
            "App/Sources/Kit/Main/Modules.swift": modules.replace("KitModule.register()",
                                                                  "KitModule.register()\n        Log.start()"),
            "App/Sources/Kit/Core/New.swift": "enum New {}\n",
            "App/Sources/Kit/Core/Old.swift": None,
            "App/Sources/Modules/Island/IslandModule.swift": "enum IslandModule { static func register() {} }\n",
            "AGENTS.md": SHARED_V1.replace("line five", "line five, starter"),
            "CLAUDE.md": "# Claude\n\nRegel A, neu\n",
            "starter.json": json.dumps(starter_json, indent=2),
        })
        write_files(self.project, {
            "AGENTS.md": SHARED_V1.replace("line one", "line one, project"),
            "CLAUDE.md": "# Claude\n\nRegel A, Projekt\n",
        })
        result = self.run_sync()
        self.assertIn("App/Sources/Kit/Main/Modules.swift", result.taken)
        self.assertIn("App/Sources/Kit/Core/New.swift", result.taken)
        self.assertEqual(result.deleted, ["App/Sources/Kit/Core/Old.swift"])
        self.assertEqual(result.merged, ["AGENTS.md"])
        self.assertEqual(result.conflicts, ["CLAUDE.md"])

        modules_after = self.read(self.project, "App/Sources/Kit/Main/Modules.swift")
        self.assertIn("Log.start()", modules_after)
        self.assertNotIn("Island", modules_after, "removed module stays removed")
        self.assertFalse((self.project / "App/Sources/Modules/Island").exists())
        self.assertFalse((self.project / "App/Sources/Kit/Core/Old.swift").exists())
        agents = self.read(self.project, "AGENTS.md")
        self.assertIn("line one, project", agents)
        self.assertIn("line five, starter", agents)
        self.assertIn("<<<<<<< Projekt", self.read(self.project, "CLAUDE.md"))

        config = self.json(self.project, "starter.json")
        self.assertEqual(config["starter"]["version"], "1.1.0")
        self.assertEqual(config["app"]["name"], "Notizen")
        self.assertNotIn("island", config["modules"])
        self.assertIs(config["modules"]["share"], False)
        self.assertEqual(config["texts"]["languages"], ["en", "de", "fr"])

        lock = read_lock(self.project)
        self.assertEqual(lock["version"], "1.1.0")
        self.assertEqual(lock["commit"], git(self.starter, "rev-parse", "v1.1.0^{commit}"))
        self.assertEqual(lock["lastSyncedOn"], "2026-11-01")
        self.assertIn("App/Sources/Kit/Core/New.swift", lock["checksums"])
        self.assertNotIn("App/Sources/Kit/Core/Old.swift", lock["checksums"])

    def test_earlier_kit_changes_stay_visible_after_sync(self):
        from starter import kitcheck
        self.release({"App/Sources/Kit/Core/New.swift": "enum New {}\n"})
        write_files(self.project, {"App/Sources/Kit/Core/MyHack.swift": "enum MyHack {}\n"})
        self.run_sync()
        lock = read_lock(self.project)
        self.assertIn("App/Sources/Kit/Core/New.swift", lock["checksums"])
        self.assertNotIn("App/Sources/Kit/Core/MyHack.swift", lock["checksums"])
        self.assertIn("App/Sources/Kit/Core/MyHack.swift: neu angelegt",
                      "\n".join(kitcheck.run(self.project).problems))

    def test_dry_run_writes_nothing(self):
        self.release({"App/Sources/Kit/Core/New.swift": "enum New {}\n"})
        result = self.run_sync(dry_run=True)
        self.assertEqual(result.taken, ["App/Sources/Kit/Core/New.swift"])
        self.assertEqual(git(self.project, "status", "--porcelain"), "")

    def test_project_change_to_kit_file_is_overwritten_and_listed(self):
        self.release({"App/Sources/Kit/Core/Lang.swift": "func tr(en: String, de: String) -> String { de }\n"})
        write_files(self.project, {"App/Sources/Kit/Core/Lang.swift": "// changed\n"})
        result = self.run_sync()
        self.assertEqual(result.overwritten, ["App/Sources/Kit/Core/Lang.swift"])

    def test_executable_files_are_listed(self):
        self.release({"scripts/build.sh": "#!/bin/zsh\necho new\n", "Makefile": "check:\n"})
        result = self.run_sync()
        self.assertEqual(result.executable, ["Makefile", "scripts/build.sh"])

    def test_base_from_lock_commit(self):
        lock = read_lock(self.project)
        lock["commit"] = self.base_commit
        (self.project / "starter.lock.json").write_text(json.dumps(lock), encoding="utf-8")
        git(self.starter, "tag", "-d", "v1.0.0")
        self.release({"App/Sources/Kit/Core/New.swift": "enum New {}\n"})
        result = self.run_sync()
        self.assertEqual(result.taken, ["App/Sources/Kit/Core/New.swift"])

    def test_missing_base_tag_explains(self):
        git(self.starter, "tag", "-d", "v1.0.0")
        self.release({"App/Sources/Kit/Core/New.swift": "enum New {}\n"})
        with self.assertRaises(StarterError) as e:
            self.run_sync()
        self.assertIn("--basis", str(e.exception))
        result = self.run_sync(base=self.base_commit)
        self.assertEqual(result.taken, ["App/Sources/Kit/Core/New.swift"])

    def test_sources(self):
        from starter.sync import check_source, default_source
        check_source("ssh://git@github.com/wielochyeah/mac-app-starter.git", "v1.1.0")
        check_source("git@github.com:wielochyeah/mac-app-starter.git", "v1.1.0")
        check_source("https://github.com/wielochyeah/mac-app-starter.git", "v1.1.0")
        for bad in ("https://token@github.com/a/b.git", "https://u:p@github.com/a/b.git", "ssh://git:pw@host/a.git"):
            with self.assertRaises(StarterError):
                check_source(bad, "v1.1.0")
        self.assertEqual(default_source(self.project, "a/b"), "https://github.com/a/b.git")
        git(self.project, "remote", "add", "origin", "git@github.com:beispiel/notizen.git")
        self.assertEqual(default_source(self.project, "a/b"), "git@github.com:a/b.git")

    def test_missing_target_tag_explains(self):
        with self.assertRaises(StarterError) as e:
            sync(self.project, "v9.9.9", source=str(self.starter))
        self.assertIn("git ls-remote --tags", str(e.exception))

    def test_refusals(self):
        with self.assertRaises(StarterError):
            sync(self.project, "v1.1.0", source="https://user:token@github.com/x/y.git")
        with self.assertRaises(StarterError):
            sync(self.project, "--upload-pack=evil", source=str(self.starter))
        with self.assertRaises(StarterError):
            sync(self.starter, "v1.1.0", source=str(self.starter))  # not a project


if __name__ == "__main__":
    unittest.main()
