#!/usr/bin/env python3
"""Git hooks path and commit identity, for `make hooks` and the SessionStart hook (.claude/hooks/session-start.py).

- core.hooksPath points at scripts/hooks (commit-msg checks author and format, pre-push runs the checks).
- The commit identity is never overwritten. A project (bin/starter init has run) with commit.name and commit.email in
  starter.json gets them as local git config only when git has none; a different identity is reported, not changed.
  The starter ships no identity: each contributor commits under their own and the commit-msg hook checks only the
  format there. In a copy of the starter that has not run init, nothing is set and the line says so.

Usage: scripts/git_setup.py        (make hooks: both lines, exit 1 when the hooks path could not be set)
Python 3.9 standard library only.
"""
import json
import os
import subprocess
import sys

HOOKS_DIR = "scripts/hooks"
SCRIPTS = os.path.dirname(os.path.abspath(__file__))


def run(args, cwd, timeout=10, env=None):
    try:
        result = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout, env=env)
    except (OSError, subprocess.TimeoutExpired) as error:
        return None, str(error)
    return result.returncode, (result.stdout or "") + (result.stderr or "")


def read_identity(root):
    """(name, email) from starter.json, or None when the file or the commit block is missing or broken."""
    try:
        with open(os.path.join(root, "starter.json"), encoding="utf-8") as handle:
            config = json.load(handle)
    except (OSError, ValueError):
        return None
    commit = config.get("commit") if isinstance(config, dict) else None
    if not isinstance(commit, dict):
        return None
    name, email = commit.get("name"), commit.get("email")
    if not isinstance(name, str) or not isinstance(email, str):
        return None
    return name.strip(), email.strip()


def repo_state(root):
    """starter, project, needs-init or unknown, by the rule of scripts/starter/manifest.py."""
    if SCRIPTS not in sys.path:
        sys.path.insert(0, SCRIPTS)
    try:
        from starter.manifest import detect_state
    except ImportError:
        return "unknown"
    return detect_state(__import__("pathlib").Path(root))


def hooks_line(root, git=run):
    if not os.path.isdir(os.path.join(root, HOOKS_DIR)):
        return "Git-Hooks: {} fehlt, nichts eingerichtet.".format(HOOKS_DIR)
    code, current = git(["git", "config", "--get", "core.hooksPath"], root)
    if code == 0 and current.strip() == HOOKS_DIR:
        return "Git-Hooks: {} aktiv.".format(HOOKS_DIR)
    code, output = git(["git", "config", "core.hooksPath", HOOKS_DIR], root)
    if code == 0:
        return "Git-Hooks: {} eingerichtet.".format(HOOKS_DIR)
    return "Git-Hooks: Einrichten gescheitert ({}). make hooks ausführen.".format(output.strip()[:200])


NOT_INITIALISED = (
    "Git-Identität: nichts gesetzt. Kopie des Starters, noch nicht eingerichtet: zuerst bin/starter init, dann "
    "commit.name und commit.email des Projekts in starter.json eintragen (beim Auftraggeber erfragen, nie erfinden)."
)
UNKNOWN = (
    "Git-Identität: nichts gesetzt. starter.lock.json nennt kein Projekt, und es gibt kein origin: in einer Kopie des "
    "Starters zuerst bin/starter init; ist das der Starter selbst, origin setzen (git remote add origin <Adresse>)."
)


def identity_line(root, git=run, state=None):
    identity = read_identity(root)
    if identity is None:
        return "Git-Identität: starter.json ohne Block commit; nichts gesetzt."
    state = state or repo_state(root)
    if state == "needs-init":
        return NOT_INITIALISED
    if state == "unknown":
        return UNKNOWN
    name, email = identity
    current = {}
    for key in ("user.name", "user.email"):
        code, value = git(["git", "config", "--get", key], root)
        current[key] = value.strip() if code == 0 else ""
    if not name or not email:
        if state == "starter":
            own = "{} <{}>".format(current["user.name"], current["user.email"]) if all(current.values()) else \
                "keine gesetzt: git config user.name und git config user.email mit der eigenen Identität"
            return ("Git-Identität: der Starter trägt keine; Commits laufen unter der Identität aus der Git-Konfiguration "
                    "({}), der Hook commit-msg prüft hier nur das Format.".format(own))
        return ("Git-Identität: FEHLT. commit.name und commit.email in starter.json sind leer; der Hook commit-msg nimmt "
                "keinen Commit an. Die Identität beim Auftraggeber erfragen, nie erfinden.")
    wanted = {"user.name": name, "user.email": email}
    if all(current[key] == value for key, value in wanted.items()):
        return "Git-Identität: passt zu starter.json."
    if any(current[key] and current[key] != value for key, value in wanted.items()):
        return ("Git-Identität: git nutzt {} <{}>, starter.json nennt {} <{}>; nichts geändert. Der Hook commit-msg nimmt "
                "Commits nur unter der Identität aus starter.json an. Ist das deine Identität für dieses Projekt: "
                "git config user.name \"{}\" und git config user.email \"{}\".".format(
                    current["user.name"] or "-", current["user.email"] or "-", name, email, name, email))
    for key, value in wanted.items():
        if not current[key]:
            git(["git", "config", key, value], root)
    return "Git-Identität: aus starter.json gesetzt ({} <{}>), nur für dieses Repository.".format(name, email)


def main():
    root = os.getcwd()
    hooks = hooks_line(root)
    print(hooks)
    print(identity_line(root))
    return 1 if "gescheitert" in hooks else 0


if __name__ == "__main__":
    sys.exit(main())
