"""Template probe (make probe; not part of make test, it builds the app several times).

Copies the starter's files (git ls-files, new files included) into a temp folder, `git init`, runs
`bin/starter init --non-interactive` with icon and build, checks that a commit fails while the commit
identity is empty (when the commit-msg hook exists), then removes each module in its own copy of
that project and builds it:
  island, background, hotkeys, examples, mlx, menubar   removed, make build green, check-kit part 1 green
  ai        refused (mlx still there); then mlx and ai removed, build green
  window    removed, build green; then menubar refused (one of window/menubar stays)
Runs only in the starter itself (starter.lock.json without project). STARTER_PROBE_KEEP=1 keeps the
temp folder; STARTER_PROBE_JOBS sets how many copies build at once (default 3).
"""
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from starter.tests.helpers import GIT_ID, ROOT
from starter import kitcheck
from starter.manifest import read_lock, read_manifest

CLEAN_ENV = {k: v for k, v in os.environ.items() if k not in ("MODULES", "CONFIG", "ONLY", "NO_BUILD", "MAKEFLAGS",
                                                                "MFLAGS", "MAKELEVEL")}


def sh(args, cwd, check=False):
    res = subprocess.run(args, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=CLEAN_ENV)
    out = res.stdout.decode("utf-8", "replace")
    if check and res.returncode != 0:
        raise AssertionError(f"{' '.join(args)} in {cwd}: exit {res.returncode}\n{out[-3000:]}")
    return res.returncode, out


def starter(cwd, *args):
    return sh([sys.executable, str(cwd / "bin" / "starter"), *args], cwd)


def copy_tree(src: Path, dst: Path) -> None:
    """The project with its Git history; of build/ only the compiler cache, so each copy builds faster."""
    def ignore(folder, names):
        return [n for n in names if Path(folder) == src / "build" and n != "cache"]
    shutil.copytree(src, dst, symlinks=True, ignore=ignore)


@unittest.skipIf(read_lock(ROOT)["project"] is not None, "die Probe läuft nur im Starter selbst")
class TemplateProbe(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix="starter-probe-"))
        cls.base = cls.tmp / "base"
        cls.base.mkdir()
        files = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=str(ROOT),
                               stdout=subprocess.PIPE, check=True).stdout.decode().split("\0")
        for f in filter(None, files):
            src = ROOT / f
            if src.is_file():
                dst = cls.base / f
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
        sh(["git", "init", "-q", "-b", "main"], cls.base, check=True)
        sh(["git", *GIT_ID, "add", "-A"], cls.base, check=True)
        sh(["git", *GIT_ID, "commit", "-qm", "chore: copy mac-app-starter"], cls.base, check=True)
        start = time.time()
        cls.init_code, cls.init_out = starter(cls.base, "init", "--non-interactive", "--name", "Probe App",
                                              "--bundle-id", "com.example.probe", "--ohne-netz")
        cls.init_seconds = time.time() - start
        sh(["git", *GIT_ID, "add", "-A"], cls.base)
        sh(["git", *GIT_ID, "commit", "-qm", "chore: init"], cls.base)
        cls.results = {}
        if cls.init_code == 0:
            cls.results = cls.run_removals()

    @classmethod
    def tearDownClass(cls):
        report = [f"probe: init {'grün' if cls.init_code == 0 else 'ROT'} ({cls.init_seconds:.0f} s)"]
        for name, steps in cls.results.items():
            report.append(f"probe: {name}: " + "; ".join(f"{label} exit {code} ({secs:.0f} s)"
                                                          for label, code, _, secs in steps))
        print("\n" + "\n".join(report), file=sys.stderr)
        if os.environ.get("STARTER_PROBE_KEEP") == "1":
            print(f"probe: Ordner bleibt: {cls.tmp}", file=sys.stderr)
        else:
            shutil.rmtree(cls.tmp, ignore_errors=True)

    @classmethod
    def run_removals(cls):
        manifest = read_manifest(cls.base)
        plans = {name: [("remove " + name, ["remove", name])] for name in manifest.modules}
        plans["ai"] += [("remove mlx", ["remove", "mlx"]), ("remove ai", ["remove", "ai"])]
        plans["window"] += [("remove menubar", ["remove", "menubar", "--ohne-build"])]

        def run(name):
            copy = cls.tmp / f"ohne-{name}"
            copy_tree(cls.base, copy)
            steps = []
            for label, args in plans[name]:
                start = time.time()
                code, out = starter(copy, *args)
                steps.append((label, code, out, time.time() - start))
            return name, steps

        jobs = int(os.environ.get("STARTER_PROBE_JOBS", "3"))
        with ThreadPoolExecutor(max_workers=jobs) as pool:
            return dict(pool.map(run, list(plans)))

    def step(self, name, index):
        label, code, out, _ = self.results[name][index]
        return code, out

    def test_init(self):
        self.assertEqual(self.init_code, 0, self.init_out[-3000:])
        self.assertIn("bin/starter init hat das Projekt Probe App eingerichtet", self.init_out)
        self.assertTrue((self.base / "build" / "Probe App.app").is_dir(), "make build ran")
        self.assertFalse((self.base / "docs" / "bau").exists())
        lock = read_lock(self.base)
        self.assertEqual(lock["project"], "Probe App")
        findings = kitcheck.Findings()
        kitcheck.check_project(self.base, read_manifest(self.base), lock, kitcheck.working_files(self.base), findings)
        self.assertEqual(findings.problems, [])

    def test_commit_fails_without_identity(self):
        hook = self.base / "scripts" / "hooks" / "commit-msg"
        if not hook.exists():
            self.skipTest("scripts/hooks/commit-msg fehlt noch (Strang G)")
        (self.base / "probe.txt").write_text("x\n")
        sh(["git", "add", "probe.txt"], self.base)
        code, out = sh(["git", "-c", "core.hooksPath=scripts/hooks", "-c", "user.name=Probe",
                        "-c", "user.email=probe@example.invalid", "commit", "-qm", "feat: probe"], self.base)
        sh(["git", "reset", "-q", "probe.txt"], self.base)
        (self.base / "probe.txt").unlink()
        self.assertNotEqual(code, 0, "commit-msg must refuse while starter.json has no commit identity\n" + out)

    def test_each_module_is_removable(self):
        if self.init_code != 0:
            self.skipTest("init ist rot")
        for name in ["island", "background", "hotkeys", "examples", "mlx", "menubar", "window"]:
            with self.subTest(module=name):
                code, out = self.step(name, 0)
                self.assertEqual(code, 0, out[-3000:])
                self.assertIn(f"bin/starter remove {name} hat entfernt", out)
                self.assertIn("build.sh: build/Probe App.app", out)
                copy = self.tmp / f"ohne-{name}"
                lock = read_lock(copy)
                self.assertIn(name, lock["removedModules"])
                findings = kitcheck.Findings()
                kitcheck.check_project(copy, read_manifest(copy), lock, kitcheck.working_files(copy), findings)
                self.assertEqual(findings.problems, [])

    def test_ai_waits_for_mlx(self):
        if self.init_code != 0:
            self.skipTest("init ist rot")
        code, out = self.step("ai", 0)
        self.assertEqual(code, 1)
        self.assertIn("Modul ai wird noch von mlx gebraucht", out)
        for index in (1, 2):
            code, out = self.step("ai", index)
            self.assertEqual(code, 0, out[-3000:])
            self.assertIn("build.sh: build/Probe App.app", out)

    def test_window_then_menubar_is_refused(self):
        if self.init_code != 0:
            self.skipTest("init ist rot")
        code, out = self.step("window", 1)
        self.assertEqual(code, 1)
        self.assertIn("Mindestens eines der Module window, menubar muss bleiben", out)


if __name__ == "__main__":
    unittest.main()
