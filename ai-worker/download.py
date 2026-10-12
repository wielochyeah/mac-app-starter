"""Downloads one model from Hugging Face with progress (module mlx). The app (ModelDownloads.swift)
starts it when the user asks for a model and reads JSON lines on stdout:

    {"event": "start", "repo": str, "total": bytes}
    {"event": "progress", "done": bytes, "total": bytes}      every 0.5 s while bytes arrive
    {"event": "done", "path": snapshot folder, "total": bytes}
    {"event": "error", "kind": "offline|failed|cancelled|setup", "error": str, "done": bytes, "total": bytes}

Usage:
    download.py --model small [--catalog models.json] [--hf-home DIR] [--watch-stdin]
    download.py --repo ORG/NAME [--revision SHA] [--allow '*.json,*.safetensors'] [--total BYTES] ...
    download.py --list [--hf-home DIR]          the catalog and what is on disk (no network)

--hf-home is the Hugging Face home (the app passes its own folder in Application Support, so the
models leave with the app's data); default $HF_HOME, else ~/.cache/huggingface. The files land in
<hf-home>/hub/models--ORG--NAME/ like any Hugging Face download, and a stopped download resumes.

How (ported from VoiceBud onboarding.py, MIT, Copyright (c) 2026 Anas Riad): snapshot_download runs
in a child process (this script with --child), so a stop is a plain terminate and the hub client's
memory goes with it; the total comes from the hub's file list (fallback: the catalog size); progress
is the byte count of the repo's blob folder (finished and partial files alike) polled every 0.5 s.
HF_HUB_DISABLE_XET=1 keeps the transfer in ordinary files in that folder, so the count sees it.
--watch-stdin (the app sets it): end of stdin means the app is gone, so the download stops too.
Python 3.9 compatible; huggingface_hub is only imported for the actual download.
"""
import argparse
import fnmatch
import json
import os
import signal
import subprocess
import sys
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
POLL_S = 0.5


def emit(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def hf_home(arg=None):
    return arg or os.environ.get("HF_HOME") or os.path.expanduser("~/.cache/huggingface")


def repo_dir(hub, repo):
    return os.path.join(hub, "models--" + repo.replace("/", "--"))


def snapshot_path(hub, repo, revision=None):
    """The snapshot folder of a complete download, else None. Complete = config.json and at least
    one weights file whose blob exists (a symlink to a half-written blob does not count)."""
    snaps = os.path.join(repo_dir(hub, repo), "snapshots")
    if not os.path.isdir(snaps):
        return None
    names = [revision] if revision else sorted(os.listdir(snaps), key=lambda n: os.path.getmtime(os.path.join(snaps, n)),
                                                reverse=True)
    for name in names:
        snap = os.path.join(snaps, name)
        if not os.path.isdir(snap) or not os.path.exists(os.path.join(snap, "config.json")):
            continue
        if any(n.endswith(".safetensors") and os.path.exists(os.path.join(snap, n)) for n in os.listdir(snap)):
            return snap
    return None


def blob_bytes(hub, repo):
    """Bytes in the repo's blob folder, finished and partial (.incomplete) files alike."""
    folder = os.path.join(repo_dir(hub, repo), "blobs")
    total = 0
    try:
        names = os.listdir(folder)
    except OSError:
        return 0
    for n in names:
        p = os.path.join(folder, n)
        try:
            if not os.path.islink(p) and os.path.isfile(p):
                total += os.path.getsize(p)
        except OSError:
            pass
    return total


def matches(name, patterns):
    return not patterns or any(fnmatch.fnmatch(name, p) for p in patterns)


def remote_total(repo, revision, patterns):
    """Total bytes of the wanted files from the hub's file list, None when it cannot be asked."""
    try:
        from huggingface_hub import HfApi
        info = HfApi().model_info(repo, revision=revision, files_metadata=True, timeout=10)
        size = sum(s.size or 0 for s in info.siblings if matches(s.rfilename, patterns))
        return size or None
    except Exception:
        return None


def load_catalog(path):
    with open(path, encoding="utf-8") as f:
        catalog = json.load(f)
    if not isinstance(catalog.get("models"), list):
        raise ValueError("models.json: 'models' must be a list")
    ids = [m.get("id") for m in catalog["models"]]
    if len(set(ids)) != len(ids):
        raise ValueError("models.json: duplicate ids")
    for m in catalog["models"]:
        for key in ("id", "role", "name", "repo", "bytes"):
            if key not in m:
                raise ValueError("models.json: model {} has no {}".format(m.get("id"), key))
    if catalog.get("default") not in ids:
        raise ValueError("models.json: default {} is not a model id".format(catalog.get("default")))
    return catalog


def offline_error(text):
    t = text.lower()
    return any(w in t for w in ("connection", "resolve", "network", "offline", "timed out", "timeout",
                                "temporary failure", "max retries"))


def child(repo, revision, allow):
    """Runs in the child process: the actual download (resumes partial files by itself)."""
    from huggingface_hub import snapshot_download
    path = snapshot_download(repo_id=repo, revision=revision or None, allow_patterns=allow or None)
    print(path)
    return 0


def run(repo, revision, allow, total, hub_home, watch_stdin, python=sys.executable):
    hub = os.path.join(hub_home, "hub")
    done_path = snapshot_path(hub, repo, revision)
    if done_path:
        size = total or blob_bytes(hub, repo)
        emit({"event": "start", "repo": repo, "total": size})
        emit({"event": "done", "path": done_path, "total": size})
        return 0
    total = remote_total(repo, revision, allow) or total or 0
    emit({"event": "start", "repo": repo, "total": total})
    env = dict(os.environ, HF_HOME=hub_home, HF_HUB_DISABLE_XET="1", HF_HUB_DISABLE_PROGRESS_BARS="1",
               HF_HUB_DISABLE_TELEMETRY="1")
    env.pop("HF_HUB_OFFLINE", None)
    env.pop("HF_HUB_CACHE", None)
    proc = subprocess.Popen([python, os.path.abspath(__file__), "--child", repo, revision or "", ",".join(allow or [])],
                            env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    err_lines = []
    threading.Thread(target=lambda: err_lines.extend(proc.stderr), daemon=True).start()
    state = {"stop": None}

    def stop(reason):
        if state["stop"] is None:
            state["stop"] = reason
            proc.terminate()

    signal.signal(signal.SIGTERM, lambda *_: stop("cancelled"))
    signal.signal(signal.SIGINT, lambda *_: stop("cancelled"))
    if watch_stdin:
        def watch():
            for _ in sys.stdin:
                pass
            stop("cancelled")
        threading.Thread(target=watch, daemon=True).start()

    sent = -1
    while proc.poll() is None:
        got = min(blob_bytes(hub, repo), total) if total else blob_bytes(hub, repo)
        if got != sent:
            emit({"event": "progress", "done": got, "total": total})
            sent = got
        time.sleep(POLL_S)
    out = proc.stdout.read().strip() if proc.stdout else ""
    got = min(blob_bytes(hub, repo), total) if total else blob_bytes(hub, repo)
    path = snapshot_path(hub, repo, revision)
    if proc.returncode == 0 and path:
        emit({"event": "done", "path": path, "total": total or got})
        return 0
    if state["stop"]:
        emit({"event": "error", "kind": "cancelled", "error": "stopped", "done": got, "total": total})
        return 1
    last = next((l.strip() for l in reversed(err_lines) if l.strip()), out or "exit code {}".format(proc.returncode))
    kind = "offline" if offline_error("".join(err_lines[-40:])) else "failed"
    emit({"event": "error", "kind": kind, "error": last[:300], "done": got, "total": total})
    return 1


def main(argv=None):
    ap = argparse.ArgumentParser(description="Download a model for the MLX worker, with JSON progress lines")
    ap.add_argument("--model", help="a model id from the catalog (models.json)")
    ap.add_argument("--catalog", default=os.path.join(HERE, "models.json"))
    ap.add_argument("--repo")
    ap.add_argument("--revision", default="")
    ap.add_argument("--allow", default="", help="comma-separated file patterns")
    ap.add_argument("--total", type=int, default=0, help="size in bytes when the hub cannot be asked")
    ap.add_argument("--hf-home")
    ap.add_argument("--watch-stdin", action="store_true")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--child", nargs=3, metavar=("REPO", "REVISION", "ALLOW"), help=argparse.SUPPRESS)
    args = ap.parse_args(argv)

    if args.child:
        repo, revision, allow = args.child
        return child(repo, revision, [p for p in allow.split(",") if p])

    home = hf_home(args.hf_home)
    if args.list:
        catalog = load_catalog(args.catalog)
        for m in catalog["models"]:
            path = snapshot_path(os.path.join(home, "hub"), m["repo"], m.get("revision"))
            print("{:<10} {:<40} {:>6.2f} GB  {}".format(m["id"], m["repo"], m["bytes"] / 1e9, path or "not downloaded"))
        return 0

    allow = [p for p in args.allow.split(",") if p]
    repo, revision, total = args.repo, args.revision, args.total
    if args.model:
        try:
            catalog = load_catalog(args.catalog)
        except (OSError, ValueError) as e:
            emit({"event": "error", "kind": "setup", "error": str(e), "done": 0, "total": 0})
            return 2
        m = next((m for m in catalog["models"] if m["id"] == args.model), None)
        if m is None:
            emit({"event": "error", "kind": "setup", "error": "unknown model {}".format(args.model), "done": 0, "total": 0})
            return 2
        repo, revision, total = m["repo"], m.get("revision", ""), int(m["bytes"])
        allow = allow or m.get("allow") or catalog.get("allow") or []
    if not repo:
        ap.error("--model or --repo is needed")
    try:
        import huggingface_hub  # noqa: F401
    except ImportError:
        emit({"event": "error", "kind": "setup", "error": "huggingface_hub is not installed: run ai-worker/setup.sh",
              "done": 0, "total": total})
        return 2
    return run(repo, revision, allow, total, home, args.watch_stdin)


if __name__ == "__main__":
    sys.exit(main())
