"""download.py without the network: cache layout, progress bytes, catalog, error kinds.
Python 3.9, no huggingface_hub needed."""
import io
import json
import os
import re
import shutil
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, ROOT)
import download  # noqa: E402

REPO = "org/tiny-model"


class CacheTest(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.mkdtemp(prefix="dl-test-")
        self.hub = os.path.join(self.home, "hub")
        self.repo = download.repo_dir(self.hub, REPO)
        os.makedirs(os.path.join(self.repo, "blobs"))

    def tearDown(self):
        shutil.rmtree(self.home, ignore_errors=True)

    def blob(self, name, size):
        path = os.path.join(self.repo, "blobs", name)
        with open(path, "wb") as f:
            f.write(b"\0" * size)
        return path

    def snapshot(self, rev, files):
        snap = os.path.join(self.repo, "snapshots", rev)
        os.makedirs(snap, exist_ok=True)
        for name, blob in files.items():
            os.symlink(os.path.relpath(blob, snap) if os.path.exists(blob) else blob, os.path.join(snap, name))
        return snap

    def test_repo_dir_layout(self):
        self.assertTrue(self.repo.endswith("models--org--tiny-model"))

    def test_blob_bytes_counts_partial_files_not_links(self):
        self.blob("aaa", 100)
        self.blob("bbb.incomplete", 50)
        os.symlink(os.path.join(self.repo, "blobs", "aaa"), os.path.join(self.repo, "blobs", "link"))
        self.assertEqual(download.blob_bytes(self.hub, REPO), 150)
        self.assertEqual(download.blob_bytes(self.hub, "org/absent"), 0)

    def test_snapshot_needs_config_and_existing_weights(self):
        self.assertIsNone(download.snapshot_path(self.hub, REPO))
        cfg = self.blob("cfg", 10)
        missing = os.path.join(self.repo, "blobs", "not-there")
        self.snapshot("r1", {"config.json": cfg, "model.safetensors": missing})
        self.assertIsNone(download.snapshot_path(self.hub, REPO), "a link to a missing blob is not complete")
        weights = self.blob("w", 20)
        snap = self.snapshot("r2", {"config.json": cfg, "model.safetensors": weights})
        self.assertEqual(download.snapshot_path(self.hub, REPO), snap)
        self.assertEqual(download.snapshot_path(self.hub, REPO, "r2"), snap)
        self.assertIsNone(download.snapshot_path(self.hub, REPO, "r1"))
        self.assertIsNone(download.snapshot_path(self.hub, REPO, "r3"))

    def test_present_model_reports_done_without_network(self):
        cfg, weights = self.blob("cfg", 10), self.blob("w", 90)
        snap = self.snapshot("rev", {"config.json": cfg, "model.safetensors": weights})
        out = io.StringIO()
        with redirect_stdout(out):
            code = download.run(REPO, "rev", ["*.json"], 100, self.home, False)
        events = [json.loads(l) for l in out.getvalue().splitlines()]
        self.assertEqual(code, 0)
        self.assertEqual([e["event"] for e in events], ["start", "done"])
        self.assertEqual(events[1]["path"], snap)
        self.assertEqual(events[1]["total"], 100)


class CatalogTest(unittest.TestCase):
    def test_shipped_catalog(self):
        catalog = download.load_catalog(os.path.join(ROOT, "models.json"))
        ids = [m["id"] for m in catalog["models"]]
        self.assertIn(catalog["default"], ids)
        for m in catalog["models"]:
            self.assertRegex(m["revision"], r"^[0-9a-f]{40}$", m["id"])
            self.assertGreater(m["bytes"], 0)
            self.assertIn(m["role"], ("fast", "quality"))
            self.assertTrue(re.match(r"^[\w.-]+/[\w.-]+$", m["repo"]), m["repo"])
        default = next(m for m in catalog["models"] if m["id"] == catalog["default"])
        self.assertLessEqual(default["bytes"], 1_000_000_000, "the default model stays at or under 1 GB")

    def test_broken_catalogs(self):
        cases = [
            {"default": "a", "models": "x"},
            {"default": "a", "models": [{"id": "a", "role": "fast", "name": "A", "repo": "o/a", "bytes": 1},
                                        {"id": "a", "role": "fast", "name": "A", "repo": "o/a", "bytes": 1}]},
            {"default": "a", "models": [{"id": "a", "role": "fast", "name": "A", "bytes": 1}]},
            {"default": "b", "models": [{"id": "a", "role": "fast", "name": "A", "repo": "o/a", "bytes": 1}]},
        ]
        for case in cases:
            with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
                json.dump(case, f)
            try:
                with self.assertRaises(ValueError):
                    download.load_catalog(f.name)
            finally:
                os.remove(f.name)

    def test_patterns(self):
        self.assertTrue(download.matches("model.safetensors", ["*.json", "*.safetensors"]))
        self.assertFalse(download.matches("README.md", ["*.json", "*.safetensors"]))
        self.assertTrue(download.matches("README.md", []))

    def test_offline_detection(self):
        self.assertTrue(download.offline_error("ConnectionError: Max retries exceeded"))
        self.assertTrue(download.offline_error("Temporary failure in name resolution"))
        self.assertFalse(download.offline_error("RepositoryNotFoundError: 404"))

    def test_unknown_model_is_a_setup_error(self):
        out = io.StringIO()
        with redirect_stdout(out):
            code = download.main(["--model", "nope", "--hf-home", tempfile.gettempdir()])
        self.assertEqual(code, 2)
        ev = json.loads(out.getvalue().splitlines()[-1])
        self.assertEqual((ev["event"], ev["kind"]), ("error", "setup"))


if __name__ == "__main__":
    unittest.main()
