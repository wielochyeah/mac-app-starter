"""Tests for ai-worker/lock.py and the hashed requirements.lock (no network: PyPI answers are stand-ins)."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import lock  # noqa: E402


def pypi(files):
    return lambda url: {"urls": [{"packagetype": "bdist_wheel", "filename": name, "digests": {"sha256": digest}}
                                 for name, digest in files]}


class LockTests(unittest.TestCase):
    def test_only_wheels_this_worker_can_use(self):
        for name, ok in [
            ("mlx-0.32.3-cp312-cp312-macosx_26_0_arm64.whl", True),
            ("mlx-0.32.3-cp310-cp310-macosx_26_0_arm64.whl", False),
            ("mlx-0.32.3-cp314-cp314-macosx_26_0_arm64.whl", False),
            ("mlx_metal-0.32.3-py3-none-macosx_26_0_arm64.whl", True),
            ("tokenizers-0.23.3-cp310-abi3-macosx_11_0_arm64.whl", True),
            ("regex-2026.9.29-cp312-cp312-macosx_10_9_universal2.whl", True),
            ("numpy-2.5.4-cp312-cp312-macosx_14_0_x86_64.whl", False),
            ("numpy-2.5.4-cp312-cp312-manylinux_2_28_aarch64.whl", False),
            ("click-8.5.0-py3-none-any.whl", True),
        ]:
            self.assertEqual(lock.usable(name), ok, name)

    def test_pins_read_freeze_output_and_an_existing_lock(self):
        text = ["# comment", "mlx==0.32.3 \\", "    --hash=sha256:aa \\", "click==8.5.0", "-e ./x"]
        self.assertEqual(lock.pins(text), [("mlx", "0.32.3"), ("click", "8.5.0")])

    def test_render_lists_every_hash(self):
        digests = lock.hashes("mlx", "0.32.3", pypi([("mlx-0.32.3-cp312-cp312-macosx_26_0_arm64.whl", "b" * 64),
                                                     ("mlx-0.32.3-cp313-cp313-macosx_26_0_arm64.whl", "a" * 64),
                                                     ("mlx-0.32.3-cp312-cp312-manylinux_2_28_x86_64.whl", "c" * 64)]))
        self.assertEqual(digests, ["a" * 64, "b" * 64])
        text = lock.render([("mlx", "0.32.3", digests)], "# head")
        self.assertEqual(text, "# head\nmlx==0.32.3 \\\n    --hash=sha256:" + "a" * 64 + " \\\n    --hash=sha256:" + "b" * 64 + "\n")

    def test_no_usable_wheel_stops(self):
        with self.assertRaises(SystemExit):
            lock.hashes("x", "1", pypi([("x-1-cp312-cp312-manylinux_2_28_x86_64.whl", "a" * 64)]))

    def test_the_shipped_lock_pins_every_package_with_a_hash(self):
        path = os.path.join(os.path.dirname(HERE), "requirements.lock")
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        packages = [line for line in text.splitlines() if line and line[0].isalpha()]
        self.assertTrue(packages)
        for line in packages:
            self.assertRegex(line, r"^[A-Za-z0-9_.-]+==[^ ]+ \\$", line)
        self.assertGreaterEqual(text.count("--hash=sha256:"), len(packages))


if __name__ == "__main__":
    unittest.main()
