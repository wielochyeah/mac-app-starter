"""Stands in for download.py in the Swift tests (MLXTests): same JSON lines, no network.
--mode ok      progress in 4 steps, then a complete snapshot under --hf-home and "done"
--mode offline progress, then an "offline" error
--mode slow    progress every 0.1 s for 10 s (to pause it); SIGTERM ends it with "cancelled"
Python 3.9 standard library only."""
import argparse
import json
import os
import signal
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import download  # noqa: E402


def emit(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--revision", default="rev")
    ap.add_argument("--total", type=int, default=1000)
    ap.add_argument("--hf-home", required=True)
    ap.add_argument("--mode", default="ok")
    ap.add_argument("--allow", default="")
    ap.add_argument("--watch-stdin", action="store_true")
    a = ap.parse_args()
    hub = os.path.join(a.hf_home, "hub")
    blobs = os.path.join(download.repo_dir(hub, a.repo), "blobs")
    os.makedirs(blobs, exist_ok=True)
    signal.signal(signal.SIGTERM, lambda *_: (emit({"event": "error", "kind": "cancelled", "error": "stopped",
                                                    "done": download.blob_bytes(hub, a.repo), "total": a.total}),
                                              sys.exit(1)))
    emit({"event": "start", "repo": a.repo, "total": a.total})
    steps = 100 if a.mode == "slow" else 4
    for i in range(1, steps + 1):
        with open(os.path.join(blobs, "weights.incomplete"), "wb") as f:
            f.write(b"\0" * (a.total * i // (steps + 1)))
        emit({"event": "progress", "done": download.blob_bytes(hub, a.repo), "total": a.total})
        time.sleep(0.1 if a.mode == "slow" else 0.02)
        if a.mode == "offline" and i == 2:
            emit({"event": "error", "kind": "offline", "error": "ConnectionError: offline",
                  "done": download.blob_bytes(hub, a.repo), "total": a.total})
            return 1
    os.replace(os.path.join(blobs, "weights.incomplete"), os.path.join(blobs, "weights"))
    with open(os.path.join(blobs, "cfg"), "w") as f:
        f.write("{}")
    snap = os.path.join(download.repo_dir(hub, a.repo), "snapshots", a.revision)
    os.makedirs(snap, exist_ok=True)
    for name, blob in (("config.json", "cfg"), ("model.safetensors", "weights")):
        link = os.path.join(snap, name)
        if not os.path.lexists(link):
            os.symlink(os.path.join("..", "..", "blobs", blob), link)
    emit({"event": "done", "path": snap, "total": a.total})
    return 0


if __name__ == "__main__":
    sys.exit(main())
