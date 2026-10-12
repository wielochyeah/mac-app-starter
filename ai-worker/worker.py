"""The local language model in its own process (module mlx). The app (MLXWorkerClient.swift) starts
it and talks JSON lines over stdin/stdout. It exits by itself after --idle seconds without a request,
so the model and its libraries leave RAM completely (an in-process unload leaves the libraries).

Requests (one JSON object per line on stdin; every request with an "id" gets exactly one final
event, "done" or "error", for that id):

    {"op": "ping", "id": n}                       answered at once, also while a generation runs
    {"op": "load", "id": n, "model": path}         load a model folder (a Hugging Face snapshot)
    {"op": "generate", "id": n, "prompt": str, "system": str, "model": path?, "max_tokens": n,
     "temp": t, "stream": bool, "loop_guard": bool, "priority": 0|1}
    {"op": "cancel", "id": n}                     stop request n (queued or running); no own answer
    {"op": "unload", "id": n}                     drop the model, keep the process
    {"op": "shutdown"}                            exit (also on end of stdin)

Events (stdout):

    {"event": "ready", "protocol": 1, "pid": n}   the process reads requests now
    {"event": "pong", "id": n, "loaded": path|null, "busy": bool}
    {"event": "started", "id": n}                 a request leaves the queue (the client's clock starts)
    {"event": "token", "id": n, "text": str}      streamed text pieces ("stream": true)
    {"event": "done", "id": n, ...}               "text" + "stats" for generate, "load_s" for load,
                                                  "cancelled": true when it was stopped
    {"event": "error", "id": n, "kind": str, "error": str}
    {"event": "exit", "reason": "idle"}           just before an idle exit (exit code 0)

Error kinds: bad-request, not-loaded, load-failed, generate-failed, mlx-missing.

Scheduling: requests wait in a priority queue (0 = interactive before 1 = background, then in
arrival order); one runs at a time on the main thread, the only thread that touches MLX (MLX is not
re-entrant). The reader thread handles "cancel" and "ping" at once, so a running generation sees a
cancel after its next token.

Ported from VoiceBud llm_worker.py (MIT, Copyright (c) 2026 Anas Riad): protected stdout (fd trick),
reader thread + priority queue, "started" event, idle watchdog with os._exit, MLX cache limit and
clear after every request, system-prompt prefix cache with the marker trick, loop guard, chat
template without thinking. Python 3.9 compatible (tests run on the system python without MLX).
"""
import argparse
import copy
import itertools
import json
import os
import queue
import sys
import threading
import time
from collections import OrderedDict

PROTOCOL = 1
MARK = "⁣STARTERMARK⁣"   # invisible separators around a marker (see prefix())
MAX_PREFIXES = 4
LOOP_WINDOW = 12                   # loop guard: stop when the last 12 tokens already ran twice before
DEFAULT_MAX_TOKENS = 512


def one_line(text, limit=300):
    """An error for the protocol and the log: its first line only (a Metal error runs over many)."""
    lines = str(text).strip().splitlines() or [""]
    return lines[0][:limit]


def looping(toks, window=LOOP_WINDOW):
    """The newest `window` tokens already appear twice earlier: the model repeats itself."""
    tail = toks[-window:]
    hits, i = 0, 0
    while i <= len(toks) - 2 * window:
        if toks[i:i + window] == tail:
            hits += 1
            i += window
        else:
            i += 1
    return hits >= 2


class MLXBackend:
    """mlx-lm behind the protocol. Imported lazily, so ping works (and tests run) without MLX."""

    def __init__(self, cache_limit_mb=64):
        self.cache_limit = int(cache_limit_mb) * 1024 * 1024
        self.path = None
        self.model = None
        self.tok = None
        self.prefixes = OrderedDict()
        self.mx = None

    def _import(self):
        if self.mx is None:
            try:
                import mlx.core as mx
            except ImportError as e:
                raise WorkerError("mlx-missing", "MLX is not installed: run ai-worker/setup.sh ({})".format(e))
            mx.set_cache_limit(self.cache_limit)
            self.mx = mx

    @property
    def loaded(self):
        return self.path

    def load(self, path):
        if path == self.path and self.model is not None:
            return 0.0
        self.unload()
        self._import()
        if not os.path.isdir(path):
            raise WorkerError("load-failed", "model folder not found: {}".format(path))
        t = time.time()
        try:
            from mlx_lm import load
            self.model, self.tok = load(path)
        except Exception as e:  # broken download, unsupported architecture, out of memory
            self.model = self.tok = None
            raise WorkerError("load-failed", "{}: {}".format(type(e).__name__, one_line(e)))
        self.path = path
        return time.time() - t

    def unload(self):
        if self.model is None:
            return
        self.model = self.tok = None
        self.path = None
        self.prefixes.clear()
        import gc
        gc.collect()
        self.clear()

    def clear(self):
        if self.mx is not None:
            self.mx.clear_cache()

    def chat(self, system, user):
        msgs = ([{"role": "system", "content": system}] if system else []) + [{"role": "user", "content": user}]
        try:
            return self.tok.apply_chat_template(msgs, add_generation_prompt=True, tokenize=False,
                                                enable_thinking=False)
        except TypeError:       # templates without the thinking switch
            return self.tok.apply_chat_template(msgs, add_generation_prompt=True, tokenize=False)

    def prefix(self, system):
        """The system prompt's tokens and a prompt cache filled with them, computed once (LRU)."""
        from mlx_lm.models.cache import make_prompt_cache
        if system in self.prefixes:
            self.prefixes.move_to_end(system)
            return self.prefixes[system], 0.0
        t = time.time()
        probe = self.chat(system, MARK)
        ids = self.tok.encode(probe[:probe.index(MARK)])
        cache = make_prompt_cache(self.model)
        self.model(self.mx.array(ids)[None], cache=cache)
        self.mx.eval([c.state for c in cache])
        self.prefixes[system] = (ids, cache)
        while len(self.prefixes) > MAX_PREFIXES:
            self.prefixes.popitem(last=False)
        return self.prefixes[system], time.time() - t

    def generate(self, req, on_text, stopped):
        """(text, stats). on_text(piece) for every decoded piece; stopped() ends early."""
        if self.model is None:
            raise WorkerError("not-loaded", "no model loaded")
        from mlx_lm import stream_generate
        from mlx_lm.models.cache import make_prompt_cache
        from mlx_lm.sample_utils import make_sampler
        system = req.get("system") or ""
        ids = self.tok.encode(self.chat(system, req.get("prompt", "")))
        prefix_s = 0.0
        cache, feed = make_prompt_cache(self.model), ids
        if system:
            (pids, pcache), prefix_s = self.prefix(system)
            if ids[:len(pids)] == pids:          # else the template tokenised across the boundary
                cache, feed = copy.deepcopy(pcache), ids[len(pids):]
        sampler = make_sampler(temp=float(req.get("temp", 0.0)))
        t, text, last, toks = time.time(), "", None, []
        looped = cut = False
        steps = stream_generate(self.model, self.tok, feed, max_tokens=int(req.get("max_tokens", DEFAULT_MAX_TOKENS)),
                                sampler=sampler, prompt_cache=cache)
        for r in steps:
            text += r.text
            last = r
            toks.append(r.token)
            if r.text:
                on_text(r.text)
            if stopped():
                cut = True
                break
            if req.get("loop_guard") and len(toks) >= 3 * LOOP_WINDOW and len(toks) % 8 == 0 and looping(toks):
                looped = True
                break
        if hasattr(steps, "close"):
            steps.close()
        total = time.time() - t
        prompt_s = (last.prompt_tokens / last.prompt_tps) if last is not None and last.prompt_tps else 0.0
        stats = {"prefix_s": round(prefix_s, 3), "prompt_s": round(prompt_s, 3),
                 "eval_s": round(max(0.0, total - prompt_s), 3),
                 "tokens": last.generation_tokens if last is not None else 0,
                 "tps": round(last.generation_tps, 1) if last is not None else 0.0,
                 "peak_mb": round(last.peak_memory * 1000, 1) if last is not None else 0.0,
                 "cached": len(feed) < len(ids), "looped": looped}
        return text, stats, cut


class WorkerError(Exception):
    def __init__(self, kind, message):
        Exception.__init__(self, message)
        self.kind = kind


class Worker:
    """The protocol: reader thread, priority queue, main loop, idle watchdog."""

    def __init__(self, backend, out, idle=300.0, clock=time.time):
        self.backend = backend
        self.out = out
        self.idle = idle
        self.clock = clock
        self.lock = threading.Lock()
        self.inbox = queue.PriorityQueue()
        self.order = itertools.count()
        self.cancelled = set()
        self.running = None
        self.stopping = False
        self.last = clock()

    def send(self, obj):
        with self.lock:
            self.out.write(json.dumps(obj, ensure_ascii=False) + "\n")
            self.out.flush()

    # -- reader thread ------------------------------------------------------------------------
    def read(self, lines):
        for line in lines:
            line = line.strip()
            if not line:
                continue
            try:
                req = json.loads(line)
                if not isinstance(req, dict):
                    raise ValueError("not an object")
            except ValueError as e:
                self.send({"event": "error", "id": None, "kind": "bad-request", "error": "not JSON: {}".format(one_line(e))})
                continue
            op = req.get("op")
            if op == "cancel":
                self.cancelled.add(req.get("id"))
                continue
            if op == "ping":
                self.send({"event": "pong", "id": req.get("id"), "loaded": self.backend.loaded,
                           "busy": self.running is not None})
                continue
            if op == "shutdown":
                self.stopping = True
                self.inbox.put((-1, next(self.order), {"op": "shutdown"}))
                continue
            try:
                prio = min(max(int(req.get("priority", 0)), 0), 9)
            except (TypeError, ValueError):
                prio = 0
            self.inbox.put((prio, next(self.order), req))
        self.stopping = True
        self.inbox.put((-1, next(self.order), {"op": "shutdown"}))

    # -- idle watchdog ------------------------------------------------------------------------
    def idle_due(self):
        return (self.idle > 0 and self.running is None and self.inbox.empty()
                and self.clock() - self.last > self.idle)

    def watchdog(self, tick=1.0):
        while True:
            time.sleep(tick)
            if self.idle_due():
                self.send({"event": "exit", "reason": "idle"})
                os._exit(0)

    # -- main loop (the only thread that touches MLX) ----------------------------------------
    def loop(self):
        while True:
            req = self.inbox.get()[2]
            op, rid = req.get("op"), req.get("id")
            if op == "shutdown":
                return 0
            if rid in self.cancelled:
                self.cancelled.discard(rid)
                self.send({"event": "done", "id": rid, "cancelled": True})
                continue
            self.running = rid
            try:
                self.handle(op, rid, req)
            except WorkerError as e:
                self.send({"event": "error", "id": rid, "kind": e.kind, "error": str(e)})
            except Exception as e:  # a bug here must not take the process down
                self.send({"event": "error", "id": rid, "kind": "generate-failed",
                           "error": "{}: {}".format(type(e).__name__, one_line(e))})
            finally:
                self.running = None
                self.cancelled.discard(rid)
                try:
                    self.backend.clear()
                except Exception:
                    pass
                self.last = self.clock()

    def handle(self, op, rid, req):
        if op == "load":
            path = req.get("model")
            if not path:
                raise WorkerError("bad-request", "load needs a model")
            self.send({"event": "started", "id": rid})
            secs = self.backend.load(path)
            self.send({"event": "done", "id": rid, "model": path, "load_s": round(secs, 2)})
        elif op == "unload":
            self.backend.unload()
            self.send({"event": "done", "id": rid})
        elif op == "generate":
            if not isinstance(req.get("prompt"), str):
                raise WorkerError("bad-request", "generate needs a prompt")
            load_s = 0.0
            if req.get("model"):
                load_s = self.backend.load(req["model"])
            elif self.backend.loaded is None:
                raise WorkerError("not-loaded", "no model loaded")
            self.send({"event": "started", "id": rid})
            stream = bool(req.get("stream"))

            def on_text(piece):
                if stream:
                    self.send({"event": "token", "id": rid, "text": piece})

            def stopped():
                return rid in self.cancelled or self.stopping

            text, stats, cut = self.backend.generate(req, on_text, stopped)
            if load_s:
                stats["load_s"] = round(load_s, 2)
            if cut:
                self.send({"event": "done", "id": rid, "cancelled": True})
            else:
                self.send({"event": "done", "id": rid, "text": text, "stats": stats})
        else:
            raise WorkerError("bad-request", "unknown op {!r}".format(op))


def protect_stdout():
    """The protocol keeps the real stdout; fd 1 (and sys.stdout) go to stderr, so whatever a
    library prints, Python or C, lands in the log and never inside the JSON stream."""
    proto = os.fdopen(os.dup(1), "w", buffering=1, encoding="utf-8")
    os.dup2(2, 1)
    sys.stdout = sys.stderr
    return proto


def offline_env():
    """Local files only: a missing file must never turn into a network call."""
    os.environ.setdefault("HF_HUB_OFFLINE", "1")
    os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")
    os.environ.setdefault("HF_HUB_DISABLE_PROGRESS_BARS", "1")
    os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")


def main(argv=None, backend=None):
    ap = argparse.ArgumentParser(description="MLX worker (JSON lines on stdin/stdout)")
    ap.add_argument("--idle", type=float, default=300.0, help="exit after this many seconds without a request (0 = never)")
    ap.add_argument("--cache-limit-mb", type=float, default=64, help="MLX buffer cache limit")
    ap.add_argument("--model", default="", help="load this model folder at start")
    args, _ = ap.parse_known_args(argv)
    offline_env()
    out = protect_stdout()
    worker = Worker(backend or MLXBackend(args.cache_limit_mb), out, idle=args.idle)
    threading.Thread(target=worker.watchdog, name="watchdog", daemon=True).start()
    worker.send({"event": "ready", "protocol": PROTOCOL, "pid": os.getpid()})
    if args.model:
        worker.inbox.put((0, next(worker.order), {"op": "load", "id": 0, "model": args.model}))
    threading.Thread(target=worker.read, args=(sys.stdin,), name="stdin", daemon=True).start()
    return worker.loop()


if __name__ == "__main__":
    sys.exit(main())
