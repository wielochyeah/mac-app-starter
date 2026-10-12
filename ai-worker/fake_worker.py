"""Stands in for worker.py in tests: the real protocol code (worker.Worker) with a model-free backend.
The answer to a prompt is "echo: <prompt>", streamed word by word.

Fault flags (Swift MLXWorkerTests and tests/test_worker.py use them):
  --gen S          sleep S seconds before every word (a slow generation, for cancel and timeouts)
  --load S         a load takes S seconds
  --crash          exit with code 3 on the first generate (after "started")
  --crash-at-start exit with code 4 before "ready"
  --crash-after N --marker PATH
                   send N words, then exit with code 3, but only while PATH does not exist (it is
                   created first), so the next worker answers: a crash mid-answer, then a retry
  --hang           a generate sends "started" and then never answers (ignores cancel)
  --noise          print to stdout and to fd 1 on every request (must never reach the protocol)
  --idle S         as worker.py (exit after S seconds without a request)
Python 3.9 standard library only."""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import worker  # noqa: E402


def flag(name, default=0.0):
    return float(sys.argv[sys.argv.index(name) + 1]) if name in sys.argv else default


class FakeBackend:
    def __init__(self):
        self.path = None
        self.gen_s = flag("--gen")
        self.load_s = flag("--load")
        self.crash = "--crash" in sys.argv
        self.hang = "--hang" in sys.argv
        self.noise = "--noise" in sys.argv
        self.crash_after = int(flag("--crash-after", -1))
        self.marker = sys.argv[sys.argv.index("--marker") + 1] if "--marker" in sys.argv else None

    @property
    def loaded(self):
        return self.path

    def load(self, path):
        if path == self.path:
            return 0.0
        if path.endswith("missing"):
            raise worker.WorkerError("load-failed", "model folder not found: {}".format(path))
        time.sleep(self.load_s)
        self.path = path
        return self.load_s

    def unload(self):
        self.path = None

    def clear(self):
        pass

    def generate(self, req, on_text, stopped):
        if self.noise:
            print("library chatter on sys.stdout")
            os.write(1, b"C-level chatter on fd 1\n")
        if self.crash:
            sys.stderr.write("fake worker: crashing as asked\n")
            os._exit(3)
        if self.hang:
            while True:
                time.sleep(3600)
        words = ("echo: " + req.get("prompt", "")).split(" ")
        crash_at = -1
        if self.crash_after >= 0 and self.marker and not os.path.exists(self.marker):
            open(self.marker, "w").close()
            crash_at = self.crash_after
        text = ""
        for i, w in enumerate(words):
            if i == crash_at:
                sys.stderr.write("fake worker: crashing mid-answer as asked\n")
                os._exit(3)
            time.sleep(self.gen_s)
            piece = w if i == 0 else " " + w
            text += piece
            on_text(piece)
            if stopped():
                return text, {}, True
        return text, {"tokens": len(words), "eval_s": round(self.gen_s * len(words), 3)}, False


if __name__ == "__main__":
    if "--crash-at-start" in sys.argv:
        sys.exit(4)
    sys.exit(worker.main(sys.argv[1:], backend=FakeBackend()))
