"""Tests for the packaging tools (tools/packaging/pkg.py, tools/dmg/settings.py, layout, pins).

Run: python3 -m unittest discover -s scripts/tests -t . (part of make test).
"""
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "packaging"))
import pkg  # noqa: E402

OTOOL_SAMPLE = """\
build/Starter.app/Contents/MacOS/Starter:
Load command 9
      cmd LC_BUILD_VERSION
  cmdsize 32
 platform 1
    minos 26.0
      sdk 26.5
   ntools 1
     tool 3
  version 1230.1
Load command 10
      cmd LC_SOURCE_VERSION
  cmdsize 16
  version 0.0
"""

OTOOL_MIXED = """\
Load command 1
      cmd LC_BUILD_VERSION
 platform 6
    minos 17.0
Load command 2
      cmd LC_VERSION_MIN_MACOSX
  cmdsize 16
  version 10.15
      sdk 11.0
Load command 3
      cmd LC_BUILD_VERSION
 platform 1
    minos 26.2
"""


def config(**app):
    base = json.loads((ROOT / "starter.json").read_text(encoding="utf-8"))
    base["app"].update(app)
    return base


class SettingsTests(unittest.TestCase):
    def test_defaults_from_starter_json(self):
        s = pkg.settings(config(), environ={})
        self.assertEqual(s["NAME"], "Starter")
        self.assertEqual(s["IDENTITY"], "-")
        self.assertEqual(s["NOTARIZE"], "0")
        self.assertEqual(s["DMG_LANG"], "both")
        self.assertIn(s["ACCENT"], ("violett", "rot", "blau", "gruen", "orange", "graphit"))

    def test_dmg_language_follows_project_languages_and_env(self):
        c = config()
        c["texts"]["languages"] = ["de"]
        self.assertEqual(pkg.settings(c, environ={})["DMG_LANG"], "de")
        self.assertEqual(pkg.settings(c, environ={"DMG_LANG": "en"})["DMG_LANG"], "en")
        with self.assertRaises(pkg.PackagingError):
            pkg.settings(c, environ={"DMG_LANG": "fr"})

    def test_notarize_needs_a_real_identity(self):
        c = config()
        c["signing"] = {"identity": "-", "notarize": True}
        s = pkg.settings(c, environ={})
        self.assertEqual((s["NOTARIZE"], s["NOTARIZE_WANTED"]), ("0", "1"))
        s = pkg.settings(c, environ={"SIGN_IDENTITY": "Developer ID Application: A (AB12CD34EF)"})
        self.assertEqual(s["NOTARIZE"], "1")

    def test_notary_profile_env_wins(self):
        c = config()
        c["signing"]["notaryProfile"] = "from-config"
        self.assertEqual(pkg.settings(c, environ={})["NOTARY_PROFILE"], "from-config")
        self.assertEqual(pkg.settings(c, environ={"NOTARY_PROFILE": "env"})["NOTARY_PROFILE"], "env")

    def test_shell_env_is_quoted(self):
        out = pkg.shell_env({"NAME": "My App", "X": "it's"})
        res = subprocess.run(["/bin/zsh", "-c", out + 'print -r -- "$PKG_NAME|$PKG_X"'], capture_output=True, text=True)
        self.assertEqual(res.stdout.strip(), "My App|it's")


class MinosTests(unittest.TestCase):
    def test_parse_build_version(self):
        self.assertEqual(pkg.parse_minos(OTOOL_SAMPLE), ["26.0"])

    def test_parse_ignores_other_platforms_and_reads_old_command(self):
        self.assertEqual(pkg.parse_minos(OTOOL_MIXED), ["10.15", "26.2"])

    def test_check_passes_when_plist_covers_binaries(self):
        ok, newest, _ = pkg.check_minos("26.0", {"a": ["26.0"], "b": ["15.0"]})
        self.assertTrue(ok)
        self.assertEqual(newest, "26.0")

    def test_check_fails_when_a_binary_needs_more(self):
        ok, newest, msg = pkg.check_minos("26.0", {"/x/libmlx.dylib": ["26.2"], "/x/App": ["26.0"]})
        self.assertFalse(ok)
        self.assertEqual(newest, "26.2")
        self.assertIn("libmlx.dylib", msg)
        self.assertIn("app.minimumMacOS", msg)

    def test_check_without_any_minimum_fails(self):
        self.assertFalse(pkg.check_minos("26.0", {"a": []})[0])

    def test_version_tuple(self):
        self.assertEqual(pkg.version_tuple("26"), (26, 0, 0))
        self.assertLess(pkg.version_tuple("26.0"), pkg.version_tuple("26.0.1"))
        with self.assertRaises(pkg.PackagingError):
            pkg.version_tuple("26.x")


class MachoTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def test_finds_macho_deepest_first_and_skips_links_and_scripts(self):
        app = self.tmp / "A.app" / "Contents"
        (app / "MacOS").mkdir(parents=True)
        (app / "Helpers" / "H.app" / "Contents" / "MacOS").mkdir(parents=True)
        (app / "MacOS" / "A").write_bytes(b"\xcf\xfa\xed\xfe" + b"\0" * 12)
        helper = app / "Helpers" / "H.app" / "Contents" / "MacOS" / "H"
        helper.write_bytes(b"\xca\xfe\xba\xbe" + b"\0" * 12)
        (app / "MacOS" / "run.sh").write_text("#!/bin/sh\n")
        os.symlink(helper, app / "MacOS" / "link")
        found = pkg.macho_files(str(self.tmp / "A.app"))
        self.assertEqual([Path(f).name for f in found], ["H", "A"])

    def test_real_bundle_minimum_matches_starter_json(self):
        app = ROOT / "build" / "Starter.app"
        if not (app / "Contents" / "Info.plist").exists():
            self.skipTest("no build/Starter.app (make build)")
        ok, newest, msg = pkg.bundle_minos(str(app))
        self.assertTrue(ok, msg)


class EntitlementTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def write(self, name, data):
        p = self.tmp / name
        with open(p, "wb") as f:
            plistlib.dump(data, f)
        return p

    def test_extra_entitlements_win(self):
        gen = self.write("gen.plist", {"com.apple.security.device.audio-input": True, "k": False})
        extra = self.write("extra.plist", {"k": True})
        merged = pkg.merged_entitlements(gen, extra)
        self.assertEqual(merged, {"com.apple.security.device.audio-input": True, "k": True})

    def test_missing_files_are_empty(self):
        self.assertEqual(pkg.merged_entitlements(self.tmp / "no.plist", self.tmp / "none.plist"), {})

    def test_shipped_extra_file_is_an_empty_dictionary(self):
        with open(ROOT / "tools" / "entitlements.plist", "rb") as f:
            self.assertEqual(plistlib.load(f), {})

    def test_non_dictionary_is_rejected(self):
        bad = self.write("bad.plist", ["x"])
        with self.assertRaises(pkg.PackagingError):
            pkg.merged_entitlements(bad, self.tmp / "none.plist")


class NotaryTests(unittest.TestCase):
    ID = "Developer ID Application: Example GmbH (AB12CD34EF)"

    def test_ad_hoc_is_refused_with_a_fix(self):
        with self.assertRaises(pkg.PackagingError) as e:
            pkg.notary_plan("x.dmg", "-", "p")
        self.assertIn("signing.identity", str(e.exception))

    def test_other_certificates_are_refused(self):
        with self.assertRaises(pkg.PackagingError):
            pkg.notary_plan("x.dmg", "Apple Development: me", "p")

    def test_sha1_identity_is_accepted(self):
        self.assertTrue(pkg.notary_plan("x.dmg", "A" * 40, "p"))

    def test_missing_profile_explains_store_credentials(self):
        with self.assertRaises(pkg.PackagingError) as e:
            pkg.notary_plan("x.dmg", self.ID, "", team_id="AB12CD34EF", bundle_id="com.example.app")
        self.assertIn("notarytool store-credentials", str(e.exception))
        self.assertIn("--team-id AB12CD34EF", str(e.exception))

    def test_dmg_plan(self):
        cmds = pkg.notary_plan("out/App-1.0.dmg", self.ID, "prof")
        self.assertEqual(cmds[0], ["codesign", "--force", "--timestamp", "--sign", self.ID, "out/App-1.0.dmg"])
        self.assertIn(["xcrun", "notarytool", "submit", "out/App-1.0.dmg", "--keychain-profile", "prof", "--wait"], cmds)
        self.assertIn(["xcrun", "stapler", "staple", "out/App-1.0.dmg"], cmds)

    def test_app_plan_zips_then_staples_the_app(self):
        cmds = pkg.notary_plan("w/App.app", self.ID, "prof")
        names = [c[0] if c[0] != "xcrun" else c[1] for c in cmds]
        self.assertEqual(names, ["codesign", "ditto", "notarytool", "stapler", "rm", "spctl"])
        self.assertEqual(cmds[2][3], "w/App.notarize.zip")
        self.assertEqual(cmds[3][-1], "w/App.app")

    def test_only_app_and_dmg(self):
        with self.assertRaises(pkg.PackagingError):
            pkg.notary_plan("x.zip", self.ID, "p")


class DMGLayoutTests(unittest.TestCase):
    def setUp(self):
        self.layout = json.loads((ROOT / "tools" / "dmg" / "layout.json").read_text(encoding="utf-8"))

    def evaluate_settings(self, **defines):
        ns = {"defines": dict(defines)}
        code = (ROOT / "tools" / "dmg" / "settings.py").read_text(encoding="utf-8")
        exec(compile(code, "settings.py", "exec"), ns)
        return ns

    def test_settings_follow_layout(self):
        s = self.evaluate_settings(app="/x/build/dmg/work.noindex/Starter.app/", background="bg.tiff",
                                   layout=str(ROOT / "tools" / "dmg" / "layout.json"))
        w = self.layout["window"]
        self.assertEqual(s["window_rect"], ((w["x"], w["y"]), (w["width"], w["height"] + w["titlebar"])))
        self.assertEqual(s["icon_locations"], {"Starter.app": tuple(self.layout["app"]),
                                               "Applications": tuple(self.layout["applications"])})
        self.assertEqual(s["symlinks"], {"Applications": "/Applications"})
        self.assertEqual(s["icon_size"], self.layout["iconSize"])
        self.assertIsNone(s["icon"])
        self.assertEqual(s["format"], "UDRW")
        self.assertNotIn("hide_extensions", s)   # would break the signature check

    def test_volume_icon_is_passed_through(self):
        s = self.evaluate_settings(app="A.app", background="b", layout=str(ROOT / "tools" / "dmg" / "layout.json"),
                                   volicon="AppIcon.icns")
        self.assertEqual(s["icon"], "AppIcon.icns")

    def test_icons_fit_and_sit_symmetric(self):
        w, size = self.layout["window"], self.layout["iconSize"]
        for x, y in (self.layout["app"], self.layout["applications"]):
            self.assertGreaterEqual(x - size / 2, 0)
            self.assertLessEqual(x + size / 2, w["width"])
            self.assertGreaterEqual(y - size / 2, 0)
        self.assertEqual(self.layout["app"][0] + self.layout["applications"][0], w["width"])
        self.assertEqual(self.layout["app"][1], self.layout["applications"][1])


class PinTests(unittest.TestCase):
    def test_every_requirement_is_pinned_with_a_hash(self):
        text = (ROOT / "tools" / "dmg" / "requirements.txt").read_text(encoding="utf-8")
        reqs = re.findall(r"^([A-Za-z0-9_.-]+)==([0-9.]+) \\\n\s+--hash=sha256:([0-9a-f]{64})$", text, re.M)
        names = {r[0].replace("_", "-").lower() for r in reqs}
        self.assertEqual(names, {"dmgbuild", "ds-store", "mac-alias"})


class IconToolTests(unittest.TestCase):
    def test_icon_selftest(self):
        tool = ROOT / "build" / "tools" / "icon"
        if not tool.exists():
            self.skipTest("icon tool not built (make icon)")
        res = subprocess.run([str(tool), "selftest"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)


if __name__ == "__main__":
    unittest.main()
