"""bin/starter remove <module> and strip-examples.

Order: checks (known module, still present, no present module needs it, the window/menubar rule),
plan (files to delete, Swift `#if MODUL_<NAME>` blocks and comment markers to strip, Swift files that
end up empty), a dangling-reference guard over the remaining Swift files, and only then writes:
delete, strip, starter.json without the module, lock (removedModules, kit checksums in a project),
then `make build` unless --ohne-build. When the guard finds a use of a module type outside an
`#if MODUL_<NAME>` block, nothing is written.
"""
from __future__ import annotations

import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional

from . import config as cfg
from . import globs
from .common import (StarterError, build_env, checksum, inside, is_starter_origin, is_text_file, origin_url, remove_empty_dirs,
                     working_files, write_text)
from .manifest import LOCK, Manifest, is_project, read_lock, read_manifest, write_lock
from .markers import dangling_references, transform


@dataclass
class RemovalPlan:
    module: str
    deleted: List[str] = field(default_factory=list)
    edited: Dict[str, str] = field(default_factory=dict)       # path -> new text
    emptied: List[str] = field(default_factory=list)           # Swift files with nothing left
    dangling: List[str] = field(default_factory=list)
    config: Optional[dict] = None                              # new starter.json
    config_notes: List[str] = field(default_factory=list)
    next_steps: List[str] = field(default_factory=list)
    already_removed: bool = False


def module_present(root: Path, manifest: Manifest, name: str, files: List[str], config: dict) -> bool:
    """A module is present while any of its files exists or starter.json still names it."""
    module = manifest.modules[name]
    return name in (config.get("modules") or {}) or any(globs.matches(f, module.paths) for f in files)


def present_modules(root: Path, manifest: Manifest, files: List[str], config: dict) -> List[str]:
    return [m for m in manifest.modules if module_present(root, manifest, m, files, config)]


def plan_removal(root: Path, name: str, manifest: Optional[Manifest] = None,
                 files: Optional[List[str]] = None) -> RemovalPlan:
    manifest = manifest or read_manifest(root)
    if name not in manifest.modules:
        raise StarterError(f"Modul „{name}“ gibt es nicht. Module: {', '.join(manifest.modules)}")
    files = files if files is not None else working_files(root)
    config = cfg.read_config(root)
    module = manifest.modules[name]
    plan = RemovalPlan(module=name)
    if not module_present(root, manifest, name, files, config):
        plan.already_removed = True
        return plan

    present = present_modules(root, manifest, files, config)
    users = [d for d in manifest.dependents(name) if d in present]
    if users:
        first = users[0]
        raise StarterError(f"Modul {name} wird noch von {', '.join(users)} gebraucht. "
                           f"Zuerst bin/starter remove {first} ausführen, dann {name}.")
    enabled = {m for m, on in (config.get("modules") or {}).items() if on is True and m != name}
    for group in manifest.at_least_one:
        if name in group and not enabled.intersection(group):
            others = [m for m in group if m != name]
            hint = ""
            off = [m for m in others if m in present]
            if off:
                hint = f" {', '.join(off)} ist vorhanden, aber in starter.json aus; erst einschalten."
            raise StarterError(f"Mindestens eines der Module {', '.join(group)} muss bleiben, sonst sind die "
                               f"Einstellungen nicht erreichbar. {name} bleibt.{hint}")

    plan.deleted = [f for f in files if globs.matches(f, module.all_paths)]
    deleted = set(plan.deleted)
    remaining: Dict[str, str] = {}
    for path in files:
        if path in deleted or not is_text_file(root, path) or path in ("starter.json", LOCK):
            continue
        try:
            text = (root / path).read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        new = transform(path, text, [name])
        if new is None:
            plan.emptied.append(path)
        else:
            remaining[path] = new
            if new != text:
                plan.edited[path] = new

    gone = {p: (root / p).read_text(encoding="utf-8", errors="replace") for p in plan.deleted + plan.emptied
            if p.endswith(".swift")}
    plan.dangling = dangling_references(gone, remaining)

    new_config = cfg.read_config(root)
    modules = dict(new_config.get("modules") or {})
    if name in modules:
        del modules[name]
        plan.config_notes.append(f"modules.{name} gestrichen")
    new_config["modules"] = modules
    still_needed = {p for m in present if m != name for p in manifest.modules[m].permissions}
    drop = [p for p in module.permissions if p not in still_needed and p in (new_config.get("permissions") or [])]
    if drop:
        new_config["permissions"] = [p for p in new_config["permissions"] if p not in drop]
        plan.config_notes.append(f"permissions ohne {', '.join(drop)}")
    plan.config = new_config
    plan.next_steps = list(module.next_steps)
    return plan


def read_texts(root: Path, files: List[str]) -> Dict[str, str]:
    """Text files (by extension or shebang) that decode as UTF-8, path -> text."""
    out = {}
    for path in files:
        if is_text_file(root, path):
            try:
                out[path] = (root / path).read_text(encoding="utf-8")
            except (UnicodeDecodeError, OSError):
                continue
    return out


def simulate(manifest: Manifest, modules: List[str], files: List[str], texts: Dict[str, str]) -> List[str]:
    """Uses of the modules' Swift types that would be left after removing all of them, without
    touching any file. Raises StarterError for a module flag remove cannot resolve."""
    gone = [p for m in modules for p in manifest.modules[m].all_paths]
    deleted = {p: texts.get(p, "") for p in files if globs.matches(p, gone)}
    remaining: Dict[str, str] = {}
    for path, text in texts.items():
        if path in deleted or path in ("starter.json", LOCK):
            continue
        new = transform(path, text, modules)
        if new is None:
            deleted[path] = text
        else:
            remaining[path] = new
    return dangling_references({p: t for p, t in deleted.items() if p.endswith(".swift")}, remaining)


def refuse_in_starter(root: Path, manifest: Manifest, command: str) -> None:
    if is_starter_origin(origin_url(root), manifest.repository):
        raise StarterError(f"Das Repository {manifest.repository} ist der Starter selbst; {command} läuft nur "
                           "in einer Kopie („Use this template“, dann bin/starter init).")


def apply_removal(root: Path, plan: RemovalPlan, manifest: Manifest) -> None:
    lock = read_lock(root) if (root / LOCK).exists() else None
    in_project = lock is not None and is_project(lock)
    # Kit files this removal edits, with their checksum before the edit: the lock follows only those
    # the project had left unchanged, so earlier project changes stay visible to check-kit.
    before = {p: checksum(root, p) for p in plan.edited
              if in_project and manifest.classify(p) == "kit" and (root / p).is_file()}
    for path in plan.deleted + plan.emptied:
        full = inside(root, path)
        if full.exists():
            full.unlink()
    remove_empty_dirs(root, plan.deleted + plan.emptied)
    for path, text in plan.edited.items():
        write_text(inside(root, path), text)
    if plan.config is not None:
        cfg.write_config(root, plan.config)
    if lock is not None:
        if plan.module not in lock["removedModules"]:
            lock["removedModules"] = sorted(lock["removedModules"] + [plan.module])
        if in_project:
            sums = dict(lock["checksums"])
            for path in plan.deleted + plan.emptied:
                sums.pop(path, None)
            for path, old in before.items():
                if sums.get(path) == old:
                    sums[path] = checksum(root, path)
            lock["checksums"] = dict(sorted(sums.items()))
        write_lock(root, lock)


def run_make(root: Path, target: str) -> bool:
    res = subprocess.run(["make", target], cwd=str(root), env=build_env())
    return res.returncode == 0


def remove_module(root: Path, name: str, dry_run: bool = False, build: bool = True,
                  check_origin: bool = True) -> RemovalPlan:
    manifest = read_manifest(root)
    if check_origin and not dry_run:
        refuse_in_starter(root, manifest, f"bin/starter remove {name}")
    plan = plan_removal(root, name, manifest)
    if plan.already_removed or dry_run or plan.dangling:
        return plan
    apply_removal(root, plan, manifest)
    if build and not run_make(root, "build"):
        plan.next_steps.append("make build ist rot: die Meldungen oben lesen, mit git diff vergleichen und "
                               "verbliebene Stellen mit #if MODUL_" + name.upper() + " umschließen")
        raise StarterError(f"Modul {name} ist entfernt, aber make build ist rot (Meldungen oben).")
    return plan


def report(plan: RemovalPlan, dry_run: bool, build: bool) -> str:
    if plan.already_removed:
        return f"bin/starter remove {plan.module}: das Modul ist schon entfernt, nichts zu tun.\n"
    def names(items: List[str]) -> str:
        return ", ".join(items) if items else "keine"
    head = (f"bin/starter remove {plan.module} würde entfernen (Probelauf, nichts geschrieben):" if dry_run
            else f"bin/starter remove {plan.module} hat entfernt:")
    lines = [
        head,
        f"  {len(plan.deleted)} Dateien: {names(plan.deleted)}",
        f"  Modul-Blöcke und Markierungen entfernt in: {names(sorted(plan.edited))}",
        f"  leer geworden und gelöscht: {names(plan.emptied)}",
        f"  starter.json: {names(plan.config_notes)}",
    ]
    lines += [f"  Danach: {s}" for s in plan.next_steps]
    if not dry_run:
        if not build:
            lines.append("  Danach: make build (mit --ohne-build übersprungen)")
        lines.append(f"  Danach: make check, dann ein Commit nur für dieses Modul, etwa "
                     f"„chore(starter): remove module {plan.module}“")
    return "\n".join(lines) + "\n"


def dangling_report(plan: RemovalPlan) -> str:
    return (f"bin/starter remove {plan.module}: nichts geändert, andere Dateien nutzen noch Typen des Moduls:\n  "
            + "\n  ".join(plan.dangling)
            + f"\nDiese Stellen mit #if MODUL_{plan.module.upper()} … #endif umschließen (in anderen Dateien "
              f"// modul:{plan.module}), dann erneut aufrufen.\n")
