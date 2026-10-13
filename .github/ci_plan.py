#!/usr/bin/env python3
"""Plans the jobs of .github/workflows/ci.yml: which repository this is, which Mac jobs this event needs, and the
module combinations and removals to try.

ci.yml is a shared file and stays the same in every project, so the job "plan" asks this script:
  state     starter, project, needs-init or unknown (scripts/starter/manifest.py, one rule for every tool: the
            starter only when GITHUB_REPOSITORY equals "repository" in starter.manifest.json, without case). A repository
            made with "Use this template" is needs-init until bin/starter init has run: no Mac job, only a Linux job
            that says to run init.
  starter   "true" in the starter itself
  check     the Mac job "make check (starter.json)" (make check, self-test, release build): pull requests that are
            not drafts, pushes to the default branch that did not come through GitHub (a merged pull request was
            checked as a pull request), tags, schedule and manual runs. Not for pushes to working branches: their
            pull request runs it, and the pre-push hook ran make check before.
  full      typecheck of every module combination (one job) and the renders: pushes to the default branch, tags,
            schedule and manual runs (also on a working branch: gh workflow run ci.yml --ref <branch>)
  probes    template probe and module removals: only in the starter, on the default branch, tags and manual runs
  docs      "true" when every changed file is documentation (*.md outside App/, docs/): no Mac job at all
  combos    JSON list of MODULES values (make typecheck reads the same list with --kombinationen)
  removals  JSON list of {name, remove, strip, last} for the job module-removal
Module folders, dependencies and the "at least one of" groups come from starter.manifest.json (fallback below).
Writes name=value lines to $GITHUB_OUTPUT, or prints them without it. --kombinationen prints the combinations, one
per line.

Python 3.9 standard library only.
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

# Used when starter.manifest.json is missing or has no modules (same values as the manifest of the starter).
FALLBACK_MODULES = {
    "window": {"folder": "Window"},
    "menubar": {"folder": "MenuBar"},
    "island": {"folder": "Island"},
    "background": {"folder": "Background"},
    "hotkeys": {"folder": "Hotkeys"},
    "ai": {"folder": "AI"},
    "mlx": {"folder": "MLX", "needs": ["ai"]},
    "examples": {"folder": "Examples", "command": "bin/starter strip-examples"},
}
FALLBACK_AT_LEAST_ONE = [["window", "menubar"]]

# The app forms and the modules that build on them. Each combination must still compile without the others.
# The examples combinations check each `#if MODUL_<NAME>` part of the notes example on its own; they drop out
# once a project runs bin/starter strip-examples.
COMBOS = [
    "window",
    "menubar",
    "window,menubar",
    "menubar,island",
    "menubar,background",
    "window,hotkeys",
    "window,ai",
    "window,ai,mlx",
    "window,examples",
    "menubar,examples",
    "menubar,island,examples",
    "window,ai,examples",
    "menubar,hotkeys,examples",
    "window,background,examples",
]

GITHUB_COMMITTER = "noreply@github.com"
ZERO = re.compile(r"^0+$")


def read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def load_modules(root):
    manifest = read_json(root / "starter.manifest.json") or {}
    modules = manifest.get("modules") or FALLBACK_MODULES
    groups = (manifest.get("rules") or {}).get("atLeastOne") or FALLBACK_AT_LEAST_ONE
    return modules, groups


def present_modules(root, modules):
    base = root / "App" / "Sources" / "Modules"
    return [name for name, info in modules.items() if (base / info.get("folder", name)).is_dir()]


def repo_state(root, env=None):
    """The rule of scripts/starter/manifest.py; unknown when the starter tools are missing."""
    scripts = str(root / "scripts")
    if scripts not in sys.path:
        sys.path.insert(0, scripts)
    try:
        from starter.manifest import detect_state
    except ImportError:
        return "unknown"
    return detect_state(root, env)


def dependents(modules, name, present):
    """Present modules that need `name`, directly or through another module."""
    out = []
    for other in present:
        if name in (modules[other].get("needs") or []) and other not in out:
            out.append(other)
            out += [d for d in dependents(modules, other, present) if d not in out]
    return out


def removal_order(modules, names):
    """`names` ordered so that a module comes before every module it needs."""
    left, out = list(names), []
    while left:
        for name in left:
            if not any(name in (modules[other].get("needs") or []) for other in left if other != name):
                out.append(name)
                left.remove(name)
                break
        else:
            out += left
            break
    return out


def is_strip(info):
    return "strip-examples" in (info.get("command") or "")


def entry(modules, name, gone, last=""):
    ordered = removal_order(modules, gone)
    remove = [m for m in ordered if not is_strip(modules[m])]
    strip = any(is_strip(modules[m]) for m in ordered)
    return {"name": name, "remove": " ".join(remove), "strip": strip, "last": last}


def combinations(root):
    modules, _ = load_modules(root)
    present = present_modules(root, modules)
    combos = [combo for combo in COMBOS if all(part in present for part in combo.split(","))]
    everything = ",".join(present)
    if everything and everything not in combos:
        combos.append(everything)
    return combos


def removals(root):
    modules, groups = load_modules(root)
    present = present_modules(root, modules)
    out = []
    for name in present:
        if any(need in present for need in (modules[name].get("needs") or [])):
            continue  # removed together with what it needs, see that entry
        gone = [name] + dependents(modules, name, present)
        left = [m for m in present if m not in gone]
        if any(not any(m in left for m in group) for group in groups if any(m in present for m in group)):
            continue  # bin/starter refuses it: the last app form stays
        out.append(entry(modules, name, gone))

    keep = []
    for group in groups:
        members = [m for m in group if m in present]
        if members:
            keep.append(members[-1])
    gone = [m for m in present if m not in keep]
    out.append(entry(modules, "alle", gone, last=keep[0] if keep else ""))
    return out


def is_docs(path):
    """Documentation no Mac job reads: Markdown outside App/ (the app ships App/Resources/Notices, and its tests read
    THIRD_PARTY_NOTICES.md) and everything under docs/."""
    if path == "THIRD_PARTY_NOTICES.md" or path.startswith("App/"):
        return False
    return path.endswith(".md") or path.startswith("docs/")


def git(root, *args):
    result = subprocess.run(["git", *args], cwd=str(root), stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return result.stdout.decode("utf-8", "replace").strip() if result.returncode == 0 else None


def changed_files(root, event_name, event):
    """The files this push or pull request changes, or None when that is unknown (new branch, missing history)."""
    if event_name == "pull_request":
        pr = event.get("pull_request") or {}
        base, head = (pr.get("base") or {}).get("sha"), (pr.get("head") or {}).get("sha")
        spec = f"{base}...{head}" if base and head else None
    elif event_name == "push":
        before, after = event.get("before") or "", event.get("after") or ""
        spec = f"{before}..{after}" if before and after and not ZERO.match(before) else None
    else:
        spec = None
    if spec is None:
        return None
    out = git(root, "diff", "--name-only", spec)
    return None if out is None else [line for line in out.split("\n") if line]


def decide(event_name, event, state, committer="", changed=None):
    """{check, full, probes, docs} as booleans for one GitHub event."""
    off = {"check": False, "full": False, "probes": False, "docs": False}
    if state == "needs-init":
        return off
    repository = event.get("repository") or {}
    default = repository.get("default_branch") or "main"
    ref = event.get("ref") or os.environ.get("GITHUB_REF", "")
    tag = ref.startswith("refs/tags/v")
    if event_name == "pull_request":
        draft = bool((event.get("pull_request") or {}).get("draft"))
        plan = {"check": not draft, "full": False, "probes": False}
    elif event_name == "push":
        if tag:
            plan = {"check": True, "full": True, "probes": True}
        elif ref == f"refs/heads/{default}":
            plan = {"check": committer != GITHUB_COMMITTER, "full": True, "probes": True}
        else:
            plan = {"check": False, "full": False, "probes": False}
    elif event_name == "workflow_dispatch":
        plan = {"check": True, "full": True, "probes": True}
    elif event_name == "schedule":
        plan = {"check": True, "full": True, "probes": False}
    else:
        plan = {"check": False, "full": False, "probes": False}
    plan["probes"] = plan["probes"] and state == "starter"
    docs = bool(changed) and all(is_docs(path) for path in changed) and event_name in ("push", "pull_request") \
        and not tag
    if docs:
        plan = {"check": False, "full": False, "probes": False}
    plan["docs"] = docs
    return plan


def plan(root, event_name="", event=None, env=None):
    event = event or {}
    state = repo_state(root, env)
    committer = ""
    after = event.get("after") or ""
    if event_name == "push" and after and not ZERO.match(after):
        committer = git(root, "log", "-1", "--format=%ce", after) or ""
    jobs = decide(event_name, event, state, committer, changed_files(root, event_name, event))
    return {
        "state": state,
        "starter": "true" if state == "starter" else "false",
        "check": "true" if jobs["check"] else "false",
        "full": "true" if jobs["full"] else "false",
        "probes": "true" if jobs["probes"] else "false",
        "docs": "true" if jobs["docs"] else "false",
        "combos": combinations(root),
        "removals": removals(root),
    }


def github_event():
    path = os.environ.get("GITHUB_EVENT_PATH")
    data = read_json(Path(path)) if path else None
    return os.environ.get("GITHUB_EVENT_NAME", ""), data if isinstance(data, dict) else {}


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv[:1] == ["--kombinationen"]:
        root = Path(argv[1]) if len(argv) > 1 else Path.cwd()
        print("\n".join(combinations(root)))
        return 0
    root = Path(argv[0]) if argv else Path.cwd()
    event_name, event = github_event()
    result = plan(root, event_name, event)
    lines = [f"{key}={result[key]}" for key in ("state", "starter", "check", "full", "probes", "docs")]
    lines += [
        "combos=" + json.dumps(result["combos"]),
        "removals=" + json.dumps(result["removals"], ensure_ascii=False),
    ]
    target = os.environ.get("GITHUB_OUTPUT")
    if target:
        with open(target, "a", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
