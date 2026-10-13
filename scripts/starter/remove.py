"""bin/starter remove <module> and strip-examples.

Order: checks (known module, still present, no present module needs it, the window/menubar rule),
plan (files to delete, Swift `#if MODUL_<NAME>` blocks and comment markers to strip, Swift files that
end up empty), a dangling-reference guard over the remaining Swift files, and only then writes:
delete, strip, starter.json without the module, lock (removedModules, kit checksums in a project),
then `make build` unless --ohne-build. When the guard finds a use of a module type outside an
`#if MODUL_<NAME>` block, nothing is written.
"""
from __future__ import annotations

import json
import platform
import shlex
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional

from . import config as cfg
from . import globs
from . import pictures as pics
from .common import (StarterError, build_env, checksum, git_bytes, inside, is_text_file, remove_empty_dirs,
                     working_files, write_text)
from .manifest import LOCK, Manifest, is_project, read_lock, read_manifest, repo_state, set_pending_build, write_lock
from .markers import dangling_references, transform


@dataclass
class RemovalPlan:
    module: str
    deleted: List[str] = field(default_factory=list)
    edited: Dict[str, str] = field(default_factory=dict)       # path -> new text
    emptied: List[str] = field(default_factory=list)           # Swift files with nothing left
    pictures: List[str] = field(default_factory=list)          # README pictures of the module's scenes
    picture_refs: List[str] = field(default_factory=list)      # guide lines that still show one of them
    dangling: List[str] = field(default_factory=list)
    config: Optional[dict] = None                              # new starter.json
    config_notes: List[str] = field(default_factory=list)
    next_steps: List[str] = field(default_factory=list)
    already_removed: bool = False
    build_ok: Optional[bool] = None                            # None: not built
    build_skipped: Optional[str] = None                        # why make build could not run here
    dirty: List[str] = field(default_factory=list)             # uncommitted changes before the removal

    @property
    def touched(self) -> List[str]:
        return self.deleted + self.emptied + self.pictures + sorted(self.edited) + [cfg.CONFIG, LOCK]


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

    gone: set = set()
    if pics.LIST in remaining:
        before = remaining[pics.LIST]
        after = pics.drop_module_lines(before, name)
        if after != before:
            remaining[pics.LIST] = plan.edited[pics.LIST] = after
        original = (root / pics.LIST).read_text(encoding="utf-8", errors="replace")
        gone = {pics.picture(e) for e in set(pics.entries(original)) - set(pics.entries(after))}
    # The pictures of the module's scenes are generated (make readme-shots) and go with it, listed or not.
    plan.pictures = sorted(p for p in files if p in gone or (
        p.startswith(pics.FOLDER) and pics.module_of(pics.scene_of_picture(p), [name]) == name))
    plan.picture_refs = sorted(f"{path}:{no}" for path, text in remaining.items() if path.endswith(".md")
                               for no, line in enumerate(text.split("\n"), 1)
                               if any(ref in plan.pictures for ref in pics.references(line)))
    prune_baselines(plan, remaining)
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
    bundle = (new_config.get("app") or {}).get("bundleId") or "<bundleId>"
    plan.next_steps = [step.replace("<bundleId>", bundle) for step in module.next_steps]
    return plan


BASELINES = ["rules/baseline/*.json"]


def prune_baselines(plan: RemovalPlan, remaining: Dict[str, str]) -> None:
    """Drops the entries of deleted files from the check baselines ({file: [finding, …]}): the checks
    fail on entries whose finding is gone, and a removed module's files are gone."""
    gone = set(plan.deleted) | set(plan.emptied)
    for path, text in list(remaining.items()):
        if not globs.matches(path, BASELINES):
            continue
        try:
            data = json.loads(text)
        except ValueError:
            continue
        if isinstance(data, dict) and gone.intersection(data):
            new = json.dumps({k: v for k, v in data.items() if k not in gone}, ensure_ascii=False, indent=2) + "\n"
            remaining[path] = plan.edited[path] = new


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
    if repo_state(root, manifest, read_lock(root)) == "starter":
        raise StarterError(f"Das Repository {manifest.repository} ist der Starter selbst; {command} läuft nur "
                           "in einer Kopie („Use this template“, dann bin/starter init).")


def apply_removal(root: Path, plan: RemovalPlan, manifest: Manifest) -> None:
    lock = read_lock(root) if (root / LOCK).exists() else None
    in_project = lock is not None and is_project(lock)
    # Kit files this removal edits, with their checksum before the edit: the lock follows only those
    # the project had left unchanged, so earlier project changes stay visible to check-kit.
    before = {p: checksum(root, p) for p in plan.edited
              if in_project and manifest.classify(p) == "kit" and (root / p).is_file()}
    for path in plan.deleted + plan.emptied + plan.pictures:
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


def swift_missing() -> Optional[str]:
    """Why make build cannot run here (a Linux container of a cloud agent, a Mac without the Command Line Tools),
    or None. The tools then write their changes, skip the build and note it as pendingBuild in the lock."""
    if sys.platform != "darwin":
        return f"kein Swift-Compiler (kein Mac, {platform.system() or sys.platform})"
    if shutil.which("swiftc") is None:
        return "kein Swift-Compiler (swiftc fehlt, xcode-select --install)"
    return None


def run_make(root: Path, target: str) -> bool:
    res = subprocess.run(["make", target], cwd=str(root), env=build_env())
    return res.returncode == 0


def uncommitted(root: Path) -> List[str]:
    """Paths with changes that are not committed (git status), for the warning before a write. The
    porcelain output is read unstripped: its first entry starts with a space (" M file")."""
    out = (git_bytes(root, ["status", "--porcelain", "-z"]) or b"").decode("utf-8", "replace")
    paths, entries = [], out.split("\0")
    index = 0
    while index < len(entries):
        entry = entries[index]
        index += 1
        if len(entry) > 3:
            paths.append(entry[3:])
            if entry[0] in "RC":
                index += 1  # a rename or copy names its source in the next field
    return paths


def remove_module(root: Path, name: str, dry_run: bool = False, build: bool = True,
                  check_origin: bool = True) -> RemovalPlan:
    """Plans and applies the removal; with build, runs make build and records the result in
    plan.build_ok (a red build is noted in the lock, see manifest.set_pending_build)."""
    manifest = read_manifest(root)
    if check_origin and not dry_run:
        refuse_in_starter(root, manifest, f"bin/starter remove {name}")
    plan = plan_removal(root, name, manifest)
    if plan.already_removed or dry_run or plan.dangling:
        return plan
    plan.dirty = uncommitted(root)
    apply_removal(root, plan, manifest)
    if build:
        plan.build_skipped = swift_missing()
        if plan.build_skipped:
            set_pending_build(root, f"bin/starter remove {name}")
        else:
            plan.build_ok = run_make(root, "build")
            set_pending_build(root, None if plan.build_ok else f"bin/starter remove {name}")
    return plan


def _count(n: int, one: str, many: str) -> str:
    return f"{n} {one if n == 1 else many}"


def restore_command(paths: List[str]) -> str:
    return "git restore --source=HEAD --staged --worktree -- " + " ".join(shlex.quote(p) for p in paths)


def report(plan: RemovalPlan, dry_run: bool, build: bool) -> str:
    if plan.already_removed:
        return f"bin/starter remove {plan.module}: das Modul ist schon entfernt, nichts zu tun.\n"

    def names(items: List[str]) -> str:
        return ", ".join(items) if items else "keine"
    flag_name = "MODUL_" + plan.module.upper()
    if dry_run:
        lines = [f"bin/starter remove {plan.module} würde ändern (Probelauf, nichts geschrieben):",
                 f"  {_count(len(plan.deleted), 'Datei', 'Dateien')} löschen: {names(plan.deleted)}",
                 f"  Modul-Blöcke und Markierungen entfernen in: {names(sorted(plan.edited))}",
                 f"  danach leer und löschen: {names(plan.emptied)}",
                 f"  Bilder der Szenen des Moduls löschen: {names(plan.pictures)}",
                 f"  starter.json: {names(plan.config_notes)}"]
        lines += [f"  Danach: {s}" for s in plan.next_steps]
        return "\n".join(lines) + "\n"
    lines = [f"bin/starter remove {plan.module} hat entfernt:",
             f"  {_count(len(plan.deleted), 'Datei', 'Dateien')}: {names(plan.deleted)}",
             f"  Modul-Blöcke und Markierungen entfernt in: {names(sorted(plan.edited))}",
             f"  leer geworden und gelöscht: {names(plan.emptied)}",
             f"  Bilder der Szenen des Moduls gelöscht: {names(plan.pictures)}",
             f"  starter.json: {names(plan.config_notes)}"]
    if plan.picture_refs:
        lines.append(f"  Diese Stellen zeigen noch ein gelöschtes Bild, bitte anpassen: {names(plan.picture_refs)}")
    if plan.dirty:
        lines.append(f"  Hinweis: {_count(len(plan.dirty), 'Datei hatte', 'Dateien hatten')} schon vorher nicht "
                     f"committete Änderungen ({names(plan.dirty[:5])}{', …' if len(plan.dirty) > 5 else ''}).")
    lines += [f"  Danach: {s}" for s in plan.next_steps]
    if plan.build_ok is False:
        lines.append(f"  make build ist rot (Meldungen oben). Stellen, die das Modul noch nutzen, mit #if {flag_name} "
                     f"… #endif umschließen und bin/starter remove {plan.module} erneut aufrufen: es baut dann noch "
                     "einmal.")
        lines.append(f"  Oder zurück zum Stand vor remove (setzt auch frühere, nicht committete Änderungen dieser "
                     f"Dateien zurück): {restore_command(plan.touched)}")
        return "\n".join(lines) + "\n"
    if plan.build_skipped:
        lines.append(f"  {plan.build_skipped}: Build übersprungen. Auf einem Mac bin/starter remove {plan.module} "
                     "erneut aufrufen, dann baut es (Vermerk pendingBuild in starter.lock.json); --ohne-build "
                     "überspringt den Build ausdrücklich.")
    elif not build:
        lines.append("  Danach: make build (mit --ohne-build übersprungen)")
    lines.append(f"  Danach: make check, dann ein Commit nur für dieses Modul, etwa "
                 f"„chore(setup): remove module {plan.module}“")
    return "\n".join(lines) + "\n"


def dangling_report(plan: RemovalPlan) -> str:
    return (f"bin/starter remove {plan.module}: nichts geändert, andere Dateien nutzen noch Typen des Moduls:\n  "
            + "\n  ".join(plan.dangling)
            + f"\nDiese Stellen mit #if MODUL_{plan.module.upper()} … #endif umschließen (in anderen Dateien "
              f"// modul:{plan.module}), dann erneut aufrufen.\n")
