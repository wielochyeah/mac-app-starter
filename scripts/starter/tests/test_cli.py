"""bin/starter as a process: help, errors, exit codes, init and remove end to end (no build)."""
import os
import subprocess
import sys
import unittest

from starter.tests.helpers import ROOT, TempDirCase, base_files, make_repo

BIN = str(ROOT / "bin" / "starter")


def run(args, cwd, stdin=None):
    env = dict(os.environ, LC_ALL="en_US.UTF-8")
    res = subprocess.run([sys.executable, BIN, *args], cwd=str(cwd), input=stdin, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, env=env, timeout=60)
    return res.returncode, res.stdout.decode(), res.stderr.decode()


class CliTests(TempDirCase):
    def test_help_is_german(self):
        code, out, _ = run(["--help"], ROOT)
        self.assertEqual(code, 0)
        self.assertIn("Aufruf: bin/starter", out)
        self.assertIn("diese Hilfe zeigen", out)
        for cmd in ["init", "remove", "strip-examples", "sync", "check-kit", "modules", "doctor"]:
            self.assertIn(cmd, out)
            code, out_cmd, _ = run([cmd, "--help"], ROOT)
            self.assertEqual(code, 0, cmd)
            self.assertIn("Aufruf:", out_cmd)
            self.assertNotIn("usage:", out_cmd)

    def test_errors(self):
        code, _, err = run(["frob"], ROOT)
        self.assertEqual(code, 2)
        self.assertIn("gibt es nicht", err)
        code, _, err = run(["remove"], ROOT)
        self.assertEqual(code, 2)
        self.assertIn("es fehlt: modul", err)
        code, _, err = run(["modules"], self.tmp)
        self.assertEqual(code, 1)
        self.assertIn("kein Starter-Repository", err)
        self.assertNotIn("Traceback", err)

    def test_needs_git(self):
        root = self.tmp / "nogit"
        root.mkdir()
        for name, text in base_files().items():
            if name in ("starter.json", "starter.manifest.json", "starter.lock.json"):
                (root / name).write_text(text, encoding="utf-8")
        code, _, err = run(["check-kit"], root)
        self.assertEqual(code, 1)
        self.assertIn("kein Git-Repository", err)

    def test_init_needs_a_name_or_a_terminal(self):
        root = make_repo(self.tmp / "r", base_files())
        code, _, err = run(["init", "--non-interactive"], root)
        self.assertEqual((code, "--name" in err), (1, True))
        code, _, err = run(["init"], root, stdin=b"")
        self.assertEqual(code, 1)
        self.assertIn("kein Terminal", err)

    def test_init_remove_modules_and_check_kit(self):
        root = make_repo(self.tmp / "r", base_files())
        code, out, err = run(["init", "--non-interactive", "--name", "Notizen", "--module-aus", "island,examples",
                              "--ohne-build", "--ohne-netz"], root)
        self.assertEqual(code, 0, err)
        self.assertIn("com.example.notizen", out)
        self.assertIn("Module entfernt: island, examples", out)
        code, out, _ = run(["modules"], root)
        self.assertRegex(out, r"island\s+Insel an der Notch\s+entfernt")
        self.assertRegex(out, r"mlx\s+MLX-Worker\s+aus")
        code, _, err = run(["remove", "ai", "--ohne-build"], root)
        self.assertEqual(code, 1)
        self.assertIn("bin/starter remove mlx", err)
        code, out, _ = run(["remove", "mlx", "--probelauf"], root)
        self.assertEqual(code, 0)
        self.assertIn("Probelauf", out)
        code, out, _ = run(["init", "--non-interactive", "--name", "X"], root)
        self.assertIn("nichts zu tun", out)

    def test_doctor_names_a_copy_that_needs_init(self):
        root = make_repo(self.tmp / "r", base_files(), "https://github.com/beispiel/notizen.git")
        code, out, _ = run(["doctor"], root)
        self.assertEqual(code, 1)
        self.assertIn("noch nicht eingerichtet", out)
        self.assertNotIn("Starter selbst", out)
        code, _, err = run(["check-kit"], root)
        self.assertEqual(code, 1)
        self.assertIn("bin/starter init", err)

    def test_init_flag_errors_are_german_and_change_nothing(self):
        root = make_repo(self.tmp / "r", base_files())
        for flags, part in ((["--name", "Bücher"], "Umlaute danach in starter.json"),
                            (["--name", "Notizen", "--accent", "lila"], "--accent „lila“: eine von"),
                            (["--name", "Notizen", "--bundle-id", "notizen"], "--bundle-id „notizen“")):
            code, out, err = run(["init", "--non-interactive", "--ohne-build", "--ohne-netz", *flags], root)
            self.assertEqual(code, 1, flags)
            self.assertIn(part, err)
            self.assertNotIn("must", err)
            self.assertNotIn("Hinweis", out, "no bundle id hint when init fails")

    def test_init_refuses_in_this_repository(self):
        if "wielochyeah/mac-app-starter" not in subprocess.run(
                ["git", "remote", "get-url", "origin"], cwd=str(ROOT), stdout=subprocess.PIPE).stdout.decode():
            self.skipTest("no starter origin here")
        code, _, err = run(["init", "--non-interactive", "--name", "X", "--probelauf"], ROOT)
        self.assertEqual(code, 1)
        self.assertIn("Starter selbst", err)


if __name__ == "__main__":
    unittest.main()
