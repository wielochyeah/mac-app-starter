"""Tests for scripts/gen_config.py (run: python3 -m unittest discover -s scripts/tests -t .)."""
import json
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import gen_config  # noqa: E402


class GenConfigTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        (self.tmp / "App" / "Resources").mkdir(parents=True)
        shutil.copy(ROOT / "starter.json", self.tmp / "starter.json")
        shutil.copy(ROOT / "App" / "Resources" / "InfoPlist.json", self.tmp / "App" / "Resources" / "InfoPlist.json")
        self.out = self.tmp / "gen"

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def config(self):
        return json.loads((self.tmp / "starter.json").read_text())

    def write(self, config):
        (self.tmp / "starter.json").write_text(json.dumps(config))

    def plist(self):
        return plistlib.loads((self.out / "Info.plist").read_bytes())

    def test_default_modules_and_window_app(self):
        modules = gen_config.generate(self.tmp, self.out)
        self.assertEqual(modules, ["window", "menubar", "island", "background", "hotkeys", "ai", "examples"])
        self.assertFalse(self.plist()["LSUIElement"])
        swift = (self.out / "AppConfig.swift").read_text()
        self.assertIn('static let bundleId = "com.example.starter"', swift)
        self.assertIn("static let accent: AccentName = .violett", swift)
        self.assertIn('"examples"', swift)
        self.assertNotIn('"mlx"', swift)

    def test_menubar_only_is_an_agent_app(self):
        gen_config.generate(self.tmp, self.out, "menubar")
        p = self.plist()
        self.assertTrue(p["LSUIElement"])
        env = (self.out / "app.env").read_text()
        self.assertIn("MODULE_FLAGS='-D MODUL_MENUBAR'", env.replace("MODULE_FLAGS=-D MODUL_MENUBAR", "MODULE_FLAGS='-D MODUL_MENUBAR'"))

    def test_entitlements_follow_permissions(self):
        gen_config.generate(self.tmp, self.out)
        self.assertEqual(plistlib.loads((self.out / "App.entitlements").read_bytes()), {})
        c = self.config()
        c["permissions"] = ["notifications", "microphone", "automation:com.apple.mail", "location"]
        self.write(c)
        gen_config.generate(self.tmp, self.out)
        ent = plistlib.loads((self.out / "App.entitlements").read_bytes())
        self.assertEqual(ent, {
            "com.apple.security.device.audio-input": True,
            "com.apple.security.automation.apple-events": True,
            "com.apple.security.personal-information.location": True,
        })

    def test_automation_with_target(self):
        c = self.config()
        c["permissions"] = ["automation:com.apple.mail"]
        self.write(c)
        gen_config.generate(self.tmp, self.out)
        self.assertIn("NSAppleEventsUsageDescription", self.plist())
        ent = plistlib.loads((self.out / "App.entitlements").read_bytes())
        self.assertTrue(ent.get("com.apple.security.automation.apple-events"))
        self.assertIn('"automation:com.apple.mail"', (self.out / "AppConfig.swift").read_text())
        for bad in ["automation", "automation:", "automation:mail", "microphone:x"]:
            c["permissions"] = [bad]
            self.write(c)
            with self.assertRaises(gen_config.ConfigError):
                gen_config.generate(self.tmp, self.out)

    def test_tagline(self):
        c = self.config()
        c["app"]["tagline"] = {"en": "Notes that \"stay\" short.", "de": "Kurze Notizen."}
        self.write(c)
        gen_config.generate(self.tmp, self.out)
        swift = (self.out / "AppConfig.swift").read_text()
        self.assertIn('static let tagline: (en: String, de: String) = (en: "Notes that \\"stay\\" short.", de: "Kurze Notizen.")', swift)
        c["app"]["tagline"] = {"en": "Only English."}
        self.write(c)
        gen_config.generate(self.tmp, self.out)
        self.assertIn('(en: "Only English.", de: "Only English.")', (self.out / "AppConfig.swift").read_text())
        del c["app"]["tagline"]
        self.write(c)
        gen_config.generate(self.tmp, self.out)
        self.assertIn('static let tagline: (en: String, de: String) = (en: "", de: "")', (self.out / "AppConfig.swift").read_text())
        for bad in ["One line", {"en": 3}]:
            c["app"]["tagline"] = bad
            self.write(c)
            with self.assertRaises(gen_config.ConfigError):
                gen_config.generate(self.tmp, self.out)

    def test_bundle_keys(self):
        gen_config.generate(self.tmp, self.out)
        p = self.plist()
        self.assertEqual(p["CFBundleIdentifier"], "com.example.starter")
        self.assertEqual(p["CFBundleExecutable"], "Starter")
        self.assertEqual(p["LSMinimumSystemVersion"], "26.0")
        self.assertEqual(p["CFBundleVersion"], "1")
        self.assertEqual(p["CFBundleLocalizations"], ["en", "de"])
        self.assertEqual(p["CFBundlePackageType"], "APPL")

    def test_usage_descriptions_for_listed_permissions(self):
        c = self.config()
        c["permissions"] = ["notifications", "microphone", "location"]
        self.write(c)
        gen_config.generate(self.tmp, self.out)
        p = self.plist()
        self.assertIn("NSMicrophoneUsageDescription", p)
        self.assertIn("NSLocationWhenInUseUsageDescription", p)
        self.assertNotIn("NSCameraUsageDescription", p)
        de = (self.out / "Resources" / "de.lproj" / "InfoPlist.strings").read_text()
        self.assertIn('"NSMicrophoneUsageDescription" = "Das Mikrofon', de)
        if shutil.which("plutil"):
            for lang in ("en", "de"):
                subprocess.run(["plutil", "-lint", str(self.out / "Resources" / f"{lang}.lproj" / "InfoPlist.strings")],
                               check=True, capture_output=True)

    def test_missing_usage_text_fails(self):
        c = self.config()
        c["permissions"] = ["camera"]
        self.write(c)
        texts = json.loads((self.tmp / "App" / "Resources" / "InfoPlist.json").read_text())
        del texts["NSCameraUsageDescription"]["de"]
        (self.tmp / "App" / "Resources" / "InfoPlist.json").write_text(json.dumps(texts))
        with self.assertRaises(gen_config.ConfigError):
            gen_config.generate(self.tmp, self.out)

    def test_strings_are_escaped(self):
        c = self.config()
        c["app"]["displayName"]["de"] = 'Mein "Starter"\\'
        self.write(c)
        gen_config.generate(self.tmp, self.out)
        de = (self.out / "Resources" / "de.lproj" / "InfoPlist.strings").read_text()
        self.assertIn('"CFBundleDisplayName" = "Mein \\"Starter\\"\\\\";', de)
        swift = (self.out / "AppConfig.swift").read_text()
        self.assertIn('de: "Mein \\"Starter\\"\\\\"', swift)

    def test_rules(self):
        with self.assertRaises(gen_config.ConfigError):
            gen_config.generate(self.tmp, self.out, "island,background")   # neither window nor menubar
        with self.assertRaises(gen_config.ConfigError):
            gen_config.generate(self.tmp, self.out, "window,mlx")          # mlx needs ai
        with self.assertRaises(gen_config.ConfigError):
            gen_config.generate(self.tmp, self.out, "window,teleport")
        c = self.config()
        c["app"]["accent"] = "pink"
        self.write(c)
        with self.assertRaises(gen_config.ConfigError):
            gen_config.generate(self.tmp, self.out)

    def test_override_order_is_canonical(self):
        modules = gen_config.generate(self.tmp, self.out, " Examples, window ,ai")
        self.assertEqual(modules, ["window", "ai", "examples"])

    def test_unchanged_files_keep_their_mtime(self):
        gen_config.generate(self.tmp, self.out)
        before = (self.out / "AppConfig.swift").stat().st_mtime_ns
        gen_config.generate(self.tmp, self.out)
        self.assertEqual((self.out / "AppConfig.swift").stat().st_mtime_ns, before)

    def test_cli_exit_code(self):
        r = subprocess.run([sys.executable, str(ROOT / "scripts" / "gen_config.py"), "--root", str(self.tmp),
                            "--out", str(self.out), "--modules", "island"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)
        self.assertIn("window or menubar", r.stderr)


if __name__ == "__main__":
    unittest.main()
