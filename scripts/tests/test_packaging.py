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


# The settings the tests start from, shaped like starter.json as the starter ships it. A project
# changes its own starter.json (name, languages, signing), so the tests must not read it.
STARTER_CONFIG = {
    "app": {"name": "Starter", "bundleId": "com.example.starter", "displayName": {"en": "Starter", "de": "Starter"},
            "version": "1.0.0", "build": 1, "minimumMacOS": "26.0", "accent": "violett", "symbol": "sparkles"},
    "texts": {"languages": ["en", "de"], "anrede": "du"},
    "signing": {"identity": "-", "teamId": "", "notarize": False},
}


def config(**app):
    base = json.loads(json.dumps(STARTER_CONFIG))
    base["app"].update(app)
    return base


class SettingsTests(unittest.TestCase):
    def test_defaults_from_the_config(self):
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

    def test_anrede_follows_texts_and_is_checked(self):
        c = config()
        c["texts"].pop("anrede", None)
        self.assertEqual(pkg.settings(c, environ={})["ANREDE"], "du")
        c["texts"]["anrede"] = "sie"
        self.assertEqual(pkg.settings(c, environ={})["ANREDE"], "sie")
        c["texts"]["anrede"] = "ihr"
        with self.assertRaises(pkg.PackagingError):
            pkg.settings(c, environ={})

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

    @unittest.skipUnless(Path("/bin/zsh").exists(), "needs zsh (macOS)")
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
        name = json.loads((ROOT / "starter.json").read_text(encoding="utf-8"))["app"]["name"]
        app = ROOT / "build" / f"{name}.app"
        if not (app / "Contents" / "Info.plist").exists():
            self.skipTest(f"no build/{name}.app (make build)")
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

    def test_entitlement_map_gives_nested_programs_their_own(self):
        root = self.tmp
        (root / "tools").mkdir()
        plist = self.write("tools/python.plist", {"com.apple.security.cs.disable-library-validation": True})
        mapping = root / "tools" / "entitlements-map.json"
        mapping.write_text(json.dumps({"Contents/Resources/python/bin/python3*": "tools/python.plist"}), encoding="utf-8")
        self.assertEqual(pkg.entitlement_map(mapping, root),
                         [("Contents/Resources/python/bin/python3*", "tools/python.plist")])
        self.assertTrue(plist.is_file())
        self.assertEqual(pkg.entitlement_map(root / "missing.json", root), [])
        for bad in [{"Contents/MacOS/App": "tools/python.plist"}, {"Contents/../x": "tools/python.plist"},
                    {"/etc/x": "tools/python.plist"}, {"Contents/Resources/x": "../outside.plist"},
                    {"Contents/Resources/x": "tools/missing.plist"}, ["x"]]:
            mapping.write_text(json.dumps(bad), encoding="utf-8")
            with self.assertRaises(pkg.PackagingError, msg=bad):
                pkg.entitlement_map(mapping, root)

    def test_shipped_entitlements_say_no_library_validation_exception_for_the_app(self):
        text = (ROOT / "tools" / "entitlements.plist").read_text(encoding="utf-8")
        self.assertNotIn("<key>com.apple.security.cs.disable-library-validation</key>", text)
        self.assertIn("entitlements-map.json", text)

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


@unittest.skipUnless(Path("/bin/zsh").exists(), "tools/lib/packaging.sh is a zsh library (macOS)")
class SignAppTests(unittest.TestCase):
    """sign_app with a stand-in for codesign that records its arguments: the app's entitlements go to the app, a
    nested program listed in the map gets its own, nothing else gets any."""

    def test_nested_program_gets_its_own_entitlements(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            app = tmp / "A.app" / "Contents"
            for rel in ("MacOS/A", "Resources/python/bin/python3.12", "Resources/lib/x.dylib"):
                (app / rel).parent.mkdir(parents=True, exist_ok=True)
                (app / rel).write_bytes(b"\xcf\xfa\xed\xfe" + b"\0" * 12)
            fake = tmp / "bin"
            fake.mkdir()
            log = tmp / "codesign.log"
            (fake / "codesign").write_text('#!/bin/sh\necho "$@" >> "{}"\n'.format(log), encoding="utf-8")
            os.chmod(fake / "codesign", 0o755)
            mapping = tmp / "map.json"
            mapping.write_text(json.dumps({"Contents/Resources/python/bin/python3*": "tools/entitlements.plist"}),
                               encoding="utf-8")
            script = ('ROOT="$1"; source "$ROOT/tools/lib/packaging.sh"; '
                      'sign_app "$2" "Developer ID Application: Example (AB12CD34EF)" "$3" "$4"')
            env = dict(os.environ, PATH=str(fake) + os.pathsep + os.environ["PATH"])
            res = subprocess.run(["/bin/zsh", "-c", script, "zsh", str(ROOT), str(tmp / "A.app"), "/x/app.plist",
                                  str(mapping)], capture_output=True, text=True, env=env)
            self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
            lines = log.read_text(encoding="utf-8").splitlines()
            python = [line for line in lines if line.endswith("python3.12")]
            dylib = [line for line in lines if line.endswith("x.dylib")]
            main = [line for line in lines if line.endswith("A.app") and "--sign" in line]
            self.assertIn("--entitlements " + str(ROOT / "tools" / "entitlements.plist"), python[0])
            self.assertNotIn("--entitlements", dylib[0])
            self.assertIn("--entitlements /x/app.plist", main[0])


@unittest.skipUnless(sys.platform == "darwin", "scripts/dmg.sh runs on macOS")
class PlaceholderBundleIdTests(unittest.TestCase):
    """make dmg refuses com.example.* with a Developer ID before it builds anything (a copy with only the scripts it
    reads first)."""

    def test_developer_id_refuses_the_placeholder(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            for rel in ("scripts/dmg.sh", "tools/lib/packaging.sh", "tools/packaging/pkg.py"):
                (tmp / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / rel, tmp / rel)
            (tmp / "starter.json").write_text(json.dumps(config()), encoding="utf-8")
            env = dict(os.environ, SIGN_IDENTITY="Developer ID Application: Example (AB12CD34EF)")
            res = subprocess.run([str(tmp / "scripts" / "dmg.sh")], capture_output=True, text=True, env=env, cwd=tmp)
            self.assertEqual(res.returncode, 1, res.stdout + res.stderr)
            self.assertIn("placeholder (com.example.*)", res.stderr)
            self.assertFalse((tmp / "build").exists(), "nothing was built")


@unittest.skipUnless(Path("/bin/zsh").exists(), "scripts/notarize.sh is a zsh script (macOS)")
class NotarizeScriptTests(unittest.TestCase):
    def run_dry(self, stamp):
        with tempfile.TemporaryDirectory() as tmp:
            dmg = Path(tmp) / "App-1.0.0.dmg"
            dmg.write_bytes(b"")
            if stamp is not None:
                (Path(tmp) / ".App-1.0.0.dmg.hint").write_text(stamp + "\n", encoding="utf-8")
            return subprocess.run(
                [str(ROOT / "scripts" / "notarize.sh"), "--dry-run", "--identity",
                 "Developer ID Application: Example (AB12CD34EF)", "--profile", "p", str(dmg)],
                capture_output=True, text=True)

    def test_dmg_with_open_anyway_hint_is_refused(self):
        res = self.run_dry("shown")
        self.assertEqual(res.returncode, 1, res.stdout + res.stderr)
        self.assertIn("signing.notarize", res.stderr)

    def test_dmg_without_hint_or_stamp_is_planned(self):
        for stamp in ("none", None):
            res = self.run_dry(stamp)
            self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
            self.assertIn("notarytool submit", res.stdout)


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


@unittest.skipUnless(sys.platform == "darwin" and shutil.which("swiftc"), "builds Swift tools (macOS with swiftc)")
class ToolBuildTests(unittest.TestCase):
    """Builds the icon and DMG tools (they compile against Kit/Design/Theme.swift and Tokens.swift)
    and runs them, so a Kit change that breaks them fails make test, not the next release.
    build_tool rebuilds only when a source changed, so this is quick after the first run."""

    @classmethod
    def setUpClass(cls):
        script = (
            'set -e; ROOT="$1"; cd "$ROOT"; source tools/lib/packaging.sh; pkg_env; '
            "build_tool icon tools/icon/Icon.swift; "
            "build_tool dmg-background tools/dmg/Background.swift tools/dmg/DMGText.swift"
        )
        # The python3 shim of the Command Line Tools exports xcrun's default SDKROOT (a beta SDK the
        # compiler may not support); let scripts/pick-sdk.sh choose, as make build does.
        env = {k: v for k, v in os.environ.items() if k != "SDKROOT"}
        res = subprocess.run(["/bin/zsh", "-c", script, "zsh", str(ROOT)], capture_output=True, text=True, env=env)
        if res.returncode != 0:
            raise AssertionError("building the packaging tools failed:\n" + res.stdout + res.stderr)

    def test_icon_selftest(self):
        res = subprocess.run([str(ROOT / "build" / "tools" / "icon"), "selftest"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)

    def test_dmg_background_renders(self):
        with tempfile.TemporaryDirectory() as tmp:
            res = subprocess.run(
                [str(ROOT / "build" / "tools" / "dmg-background"), "--out", tmp,
                 "--layout", str(ROOT / "tools" / "dmg" / "layout.json"),
                 "--icon", str(ROOT / "App" / "Resources" / "AppIcon.icns"),
                 "--name", "Photo Shelf", "--name-de", "Fotoablage", "--app-label", "Photo Shelf", "--app-label-de", "Fotoablage",
                 "--lang", "de", "--anrede", "sie"],
                capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
            for name in ("background.png", "background@2x.png", "preview.png", "preview-dark.png"):
                self.assertGreater((Path(tmp) / name).stat().st_size, 0, name)

    def test_dmg_background_rejects_unknown_anrede(self):
        res = subprocess.run([str(ROOT / "build" / "tools" / "dmg-background"), "--out", "x",
                              "--layout", "y", "--anrede", "ihr"], capture_output=True, text=True)
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("du|sie", res.stderr)


def manifest_api():
    """The PackageDescription module of the selected developer dir, or None."""
    dev = subprocess.run(["xcode-select", "-p"], capture_output=True, text=True).stdout.strip() if shutil.which("xcode-select") else ""
    dev = os.environ.get("DEVELOPER_DIR") or dev
    for path in (Path(dev) / "usr/lib/swift/pm/ManifestAPI",
                 Path(dev) / "Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/pm/ManifestAPI"):
        if (path / "PackageDescription.swiftmodule").exists():
            return path
    return None


class PackageManifestTests(unittest.TestCase):
    """Package.swift (the second build path) follows starter.json: modules and app.minimumMacOS, and stops on a
    starter.json it cannot read instead of building another module set."""

    def test_reads_the_minimum_macos_and_never_defaults_modules(self):
        text = (ROOT / "Package.swift").read_text(encoding="utf-8")
        self.assertIn(".macOS(minimumMacOS)", text)
        self.assertNotIn(".v26", text)
        self.assertIn('fatalError("Package.swift: starter.json has no modules")', text)
        self.assertNotIn('var enabled: Set<String> = ["window", "menubar"]', text)

    @unittest.skipUnless(sys.platform == "darwin" and shutil.which("swiftc") and manifest_api(),
                         "type-checks against PackageDescription (macOS)")
    def test_type_checks(self):
        env = {k: v for k, v in os.environ.items() if k != "SDKROOT"}
        sdk = subprocess.run([str(ROOT / "scripts" / "pick-sdk.sh")], capture_output=True, text=True, env=env).stdout.strip()
        res = subprocess.run(["swiftc", "-typecheck", "-sdk", sdk, "-I", str(manifest_api()), "-swift-version", "6",
                              "-package-description-version", "6.2", str(ROOT / "Package.swift")],
                             capture_output=True, text=True, env=dict(env, SDKROOT=sdk))
        self.assertEqual(res.returncode, 0, res.stderr)


if __name__ == "__main__":
    unittest.main()
