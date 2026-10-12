#!/usr/bin/env python3
"""Plans the module jobs of .github/workflows/ci.yml from what this repository contains.

A project removes modules with bin/starter remove, but ci.yml is a shared file and stays the same. So the job "plan"
asks this script which module combinations to build and which removals to try, and whether this is the starter:
  starter   "true" in the starter itself (starter.lock.json without a project), "false" in a project
  combos    JSON list of MODULES values for the build matrix; a combination is dropped when one of its modules is gone,
            the last entry builds every module that is still there
  removals  JSON list of {name, remove, strip, last} for the job module-removal (only in the starter): remove these
            modules in this order, strip-examples when strip is true, and expect bin/starter to refuse removing last
Module folders, dependencies and the "at least one of" groups come from starter.manifest.json (fallback below).
Writes name=value lines to $GITHUB_OUTPUT, or prints them without it.

Python 3.9 standard library only.
"""

import json
import os
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
# The examples combinations build each `#if MODUL_<NAME>` part of the notes example on its own; they drop out
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


def is_starter(root):
    lock = read_json(root / "starter.lock.json")
    return lock is None or lock.get("project") is None


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


def plan(root):
    modules, groups = load_modules(root)
    present = present_modules(root, modules)
    combos = [combo for combo in COMBOS if all(part in present for part in combo.split(","))]
    everything = ",".join(present)
    if everything and everything not in combos:
        combos.append(everything)

    removals = []
    for name in present:
        if any(need in present for need in (modules[name].get("needs") or [])):
            continue  # removed together with what it needs, see that entry
        gone = [name] + dependents(modules, name, present)
        left = [m for m in present if m not in gone]
        if any(not any(m in left for m in group) for group in groups if any(m in present for m in group)):
            continue  # bin/starter refuses it: the last app form stays
        removals.append(entry(modules, name, gone))

    keep = []
    for group in groups:
        members = [m for m in group if m in present]
        if members:
            keep.append(members[-1])
    gone = [m for m in present if m not in keep]
    removals.append(entry(modules, "alle", gone, last=keep[0] if keep else ""))
    return {"starter": "true" if is_starter(root) else "false", "combos": combos, "removals": removals}


def main():
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    result = plan(root)
    lines = [
        "starter=" + result["starter"],
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
