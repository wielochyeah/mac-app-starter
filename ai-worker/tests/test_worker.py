"""The worker protocol, end to end through fake_worker.py (the real worker.Worker, no model).
Run: python3 -m unittest discover -s tests (from ai-worker/). Python 3.9, no MLX needed."""
import json
import os
import queue
import subprocess
import sys
import threading
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, ROOT)
import worker  # noqa: E402

FAKE = os.path.join(ROOT, "fake_worker.py")


class Proc:
    """A fake worker with a reader thread; stdout lines must all be JSON."""

    def __init__(self, *flags):
        self.p = subprocess.Popen([sys.executable, FAKE, *flags], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE, text=True, bufsize=1)
        self.events = queue.Queue()
        self.raw = []
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        for line in self.p.stdout:
            self.raw.append(line)
            try:
                self.events.put(json.loads(line))
            except ValueError:
                self.events.put({"event": "NOT-JSON", "line": line})
        self.events.put(None)

    def send(self, **req):
        self.p.stdin.write(json.dumps(req) + "\n")
        self.p.stdin.flush()

    def next(self, timeout=5.0):
        ev = self.events.get(timeout=timeout)
        if ev is not None and ev.get("event") == "NOT-JSON":
            raise AssertionError("not JSON on stdout: {!r}".format(ev["line"]))
        return ev

    def until(self, pred, timeout=5.0):
        end = time.time() + timeout
        seen = []
        while time.time() < end:
            ev = self.next(max(0.01, end - time.time()))
            if ev is None:
                raise AssertionError("worker exited; seen {}".format(seen))
            seen.append(ev)
            if pred(ev):
                return ev, seen
        raise AssertionError("timed out; seen {}".format(seen))

    def done(self, rid, timeout=5.0):
        return self.until(lambda e: e.get("id") == rid and e["event"] in ("done", "error"), timeout)

    def close(self):
        if self.p.poll() is None:
            try:
                self.send(op="shutdown")
            except (BrokenPipeError, OSError):
                pass
            try:
                self.p.wait(3)
            except subprocess.TimeoutExpired:
                self.p.kill()
                self.p.wait()
        for f in (self.p.stdin, self.p.stdout, self.p.stderr):
            try:
                f.close()
            except OSError:
                pass


class ProtocolTest(unittest.TestCase):
    def setUp(self):
        self.procs = []

    def tearDown(self):
        for p in self.procs:
            p.close()

    def start(self, *flags):
        p = Proc(*flags)
        self.procs.append(p)
        ev = p.next()
        self.assertEqual(ev["event"], "ready")
        self.assertEqual(ev["protocol"], worker.PROTOCOL)
        return p

    def test_generate_streams_tokens_then_done(self):
        p = self.start()
        p.send(op="generate", id=1, prompt="hallo schöne welt", model="/m", stream=True)
        ev, seen = p.done(1)
        self.assertEqual(ev["event"], "done")
        self.assertEqual(ev["text"], "echo: hallo schöne welt")
        kinds = [e["event"] for e in seen]
        self.assertEqual(kinds[0], "started")
        self.assertEqual("".join(e["text"] for e in seen if e["event"] == "token"), ev["text"])

    def test_no_tokens_without_stream(self):
        p = self.start()
        p.send(op="generate", id=1, prompt="a b", model="/m")
        _, seen = p.done(1)
        self.assertNotIn("token", [e["event"] for e in seen])

    def test_ping_is_answered_while_busy(self):
        p = self.start("--gen", "0.3")
        p.send(op="generate", id=1, prompt="eins zwei drei vier", model="/m")
        p.until(lambda e: e["event"] == "started")
        t = time.time()
        p.send(op="ping", id=2)
        ev, _ = p.until(lambda e: e["event"] == "pong")
        self.assertLess(time.time() - t, 0.25)
        self.assertTrue(ev["busy"])
        self.assertEqual(ev["loaded"], "/m")

    def test_interactive_before_background(self):
        p = self.start("--gen", "0.1")
        p.send(op="generate", id=1, prompt="a b c", model="/m")
        p.until(lambda e: e["event"] == "started" and e["id"] == 1)
        p.send(op="generate", id=2, prompt="background", priority=1)
        p.send(op="generate", id=3, prompt="interactive", priority=0)
        _, seen = p.done(2, timeout=8)
        started = [e["id"] for e in seen if e["event"] == "started"]
        self.assertEqual(started, [3, 2])

    def test_cancel_running_and_queued(self):
        p = self.start("--gen", "0.2")
        p.send(op="generate", id=1, prompt="w " * 30, model="/m", stream=True)
        p.until(lambda e: e["event"] == "token")
        p.send(op="generate", id=2, prompt="queued")
        p.send(op="cancel", id=2)
        p.send(op="cancel", id=1)
        ev, _ = p.done(1)
        self.assertTrue(ev.get("cancelled"))
        ev, seen = p.done(2)
        self.assertTrue(ev.get("cancelled"))
        self.assertNotIn({"event": "started", "id": 2}, seen)

    def test_library_output_never_reaches_the_protocol(self):
        p = self.start("--noise")
        p.send(op="generate", id=1, prompt="x", model="/m")
        p.done(1)
        p.send(op="ping", id=2)
        p.until(lambda e: e["event"] == "pong")
        for line in p.raw:
            json.loads(line)
        self.assertFalse(any("chatter" in line for line in p.raw))

    def test_errors_have_kinds(self):
        p = self.start()
        p.send(op="generate", id=1, prompt="x")
        ev, _ = p.done(1)
        self.assertEqual((ev["event"], ev["kind"]), ("error", "not-loaded"))
        p.send(op="load", id=2, model="/models/missing")
        ev, _ = p.done(2)
        self.assertEqual((ev["event"], ev["kind"]), ("error", "load-failed"))
        p.send(op="frobnicate", id=3)
        ev, _ = p.done(3)
        self.assertEqual(ev["kind"], "bad-request")
        p.send(op="generate", id=4, model="/m")
        ev, _ = p.done(4)
        self.assertEqual(ev["kind"], "bad-request")
        p.send(op="load", id=5, model="/m")
        ev, _ = p.done(5)
        self.assertEqual((ev["event"], ev["model"]), ("done", "/m"))

    def test_crash_exits_nonzero_after_started(self):
        p = self.start("--crash")
        p.send(op="generate", id=1, prompt="x", model="/m")
        p.until(lambda e: e["event"] == "started")
        self.assertEqual(p.p.wait(5), 3)

    def test_idle_exit(self):
        p = self.start("--idle", "1")
        ev, _ = p.until(lambda e: e["event"] == "exit", timeout=5)
        self.assertEqual(ev["reason"], "idle")
        self.assertEqual(p.p.wait(3), 0)

    def test_requests_keep_it_alive(self):
        p = self.start("--idle", "1.5", "--gen", "0.4")
        p.send(op="generate", id=1, prompt="a b c d e f", model="/m")
        ev, _ = p.done(1, timeout=6)
        self.assertEqual(ev["event"], "done")
        self.assertIsNone(p.p.poll())

    def test_shutdown_and_eof(self):
        p = self.start()
        p.send(op="shutdown")
        self.assertEqual(p.p.wait(3), 0)
        q = self.start()
        q.p.stdin.close()
        self.assertEqual(q.p.wait(3), 0)


class HelperTest(unittest.TestCase):
    def test_looping(self):
        loop = list(range(12))
        self.assertTrue(worker.looping(loop * 3))
        self.assertFalse(worker.looping(loop * 2))
        self.assertFalse(worker.looping(list(range(60))))

    def test_one_line(self):
        self.assertEqual(worker.one_line("first\nsecond"), "first")
        self.assertEqual(len(worker.one_line("x" * 1000)), 300)
        self.assertEqual(worker.one_line(""), "")


if __name__ == "__main__":
    unittest.main()
