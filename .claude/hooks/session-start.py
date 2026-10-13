#!/usr/bin/env python3
"""SessionStart hook (see .claude/settings.json).

Every session, local or in a fresh cloud clone, prepares the same things before its first command:
  1. toolchain: scripts/doctor.sh (never installs anything) reduced to one line, with the fix when it fails; off macOS
     a line that says what runs here and what waits for a Mac
  2. git hooks: core.hooksPath points at scripts/hooks (commit-msg checks author and format, pre-push runs the checks)
  3. git identity (scripts/git_setup.py): never overwritten. In a project, commit.name and commit.email from
     starter.json are set only when git has none, a different identity is reported. The starter ships none (the
     hook checks only the format there); a copy that has not run init gets nothing and the bin/starter init hint.
Each step is idempotent and reports one line; the summary reaches the session as additional context.

Python 3.9 standard library only, so the system python3 of the Command Line Tools runs it. That python3 is an xcrun
shim: it exports SDKROOT (xcrun's default SDK, possibly a beta this compiler cannot read), CPATH, LIBRARY_PATH and
MANPATH into this process. The doctor runs without them, so it sees the same environment as make doctor in a shell.
"""

import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "scripts"))
try:
    import git_setup
except ImportError:  # scripts/ missing: report it instead of failing the session start
    git_setup = None

HOOKS_DIR = "scripts/hooks"


def run(args, cwd, timeout=10, env=None):
    try:
        result = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout, env=env)
    except (OSError, subprocess.TimeoutExpired) as error:
        return None, str(error)
    return result.returncode, (result.stdout or "") + (result.stderr or "")


def identity_line(root, git=run, state=None):
    if git_setup is None:
        return "Git-Identität: scripts/git_setup.py fehlt; nichts gesetzt."
    return git_setup.identity_line(root, git, state)


def hooks_line(root, git=run):
    if git_setup is None:
        return "Git-Hooks: scripts/git_setup.py fehlt; make hooks ausführen."
    return git_setup.hooks_line(root, git)


def summarize_doctor(code, output):
    """One line from the output of scripts/doctor.sh."""
    if code is None:
        return "Werkzeuge: make doctor lief nicht ({}).".format(output.strip()[:200])
    lines = [line.strip() for line in output.splitlines()]
    problems = [line[len("FAIL"):].strip() for line in lines if line.startswith("FAIL")]
    sdk = next((line[len("ok    SDK:"):].strip() for line in lines if line.startswith("ok    SDK:") or line.startswith("ok SDK:")), None)
    if code == 0 and not problems:
        return "Werkzeuge: bereit für make build{}.".format(" (SDK {})".format(os.path.basename(sdk)) if sdk else "")
    detail = "; ".join(problems) if problems else (lines[-1] if lines else "ohne Ausgabe")
    return "Werkzeuge: NICHT bereit ({}). make doctor zeigt die Reparatur; nichts wurde installiert.".format(detail)


# What the xcrun shim adds besides SDKROOT, when the variable was unset before.
SHIM_VALUES = {"CPATH": "/usr/local/include", "LIBRARY_PATH": "/usr/local/lib"}


def xcrun_default_sdk(environ):
    """The SDK xcrun picks without SDKROOT, or "" when xcrun is missing."""
    clean = {key: value for key, value in environ.items() if key != "SDKROOT"}
    code, output = run(["xcrun", "--sdk", "macosx", "--show-sdk-path"], None, timeout=20, env=clean)
    return output.strip().splitlines()[0] if code == 0 and output.strip() else ""


def doctor_env(environ=None, default_sdk=xcrun_default_sdk):
    """The environment for scripts/doctor.sh without what the python3 shim injected.

    scripts/pick-sdk.sh takes a set SDKROOT as the user's choice. An SDKROOT equal to xcrun's default is dropped (the
    shim's value; pick-sdk tries that SDK first anyway), any other SDKROOT stays. MANPATH from the shim points into
    that SDK and goes with it; CPATH and LIBRARY_PATH go when they hold exactly the shim's values.
    """
    env = dict(os.environ if environ is None else environ)
    sdk = env.get("SDKROOT")
    if sdk:
        default = default_sdk(env)
        if default and os.path.realpath(default) == os.path.realpath(sdk):
            del env["SDKROOT"]
            if env.get("MANPATH", "").startswith(sdk):
                del env["MANPATH"]
    for key, value in SHIM_VALUES.items():
        if env.get(key) == value:
            del env[key]
    return env


def doctor_line(root, platform=sys.platform, runner=run, environ=None, default_sdk=xcrun_default_sdk):
    if platform != "darwin":
        return (
            "Werkzeuge: kein Mac. make build, make test und make shots laufen nur unter macOS; "
            "die Prüfskripte in Python (make check-rules, check-texts, check-design, check-kit) laufen hier."
        )
    script = os.path.join(root, "scripts", "doctor.sh")
    if not os.path.isfile(script):
        return "Werkzeuge: scripts/doctor.sh fehlt."
    code, output = runner([script], root, timeout=240, env=doctor_env(environ, default_sdk))
    return summarize_doctor(code, output)


def context(root, platform=sys.platform, git=run, runner=run):
    lines = [
        doctor_line(root, platform, runner),
        hooks_line(root, git),
        identity_line(root, git),
        "Regeln: CLAUDE.md. Neue Vorgaben: docs/agents/VORGABEN.md, sie gehen allem vor und gelten auch für jeden Subagenten. "
        "Die App wird beim Prüfen nie normal gestartet: make test, make shots und --selftest mit STARTER_HEADLESS=1.",
    ]
    return "\n".join(lines)


def project_dir(payload):
    root = os.environ.get("CLAUDE_PROJECT_DIR") or payload.get("cwd") or os.getcwd()
    return os.path.abspath(root)


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        payload = {}
    if not isinstance(payload, dict):
        payload = {}
    text = context(project_dir(payload))
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": text}}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
