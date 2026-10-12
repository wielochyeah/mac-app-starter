"""starter.manifest.json (path classes, starter-only content, modules, check targets) and
starter.lock.json (starter version of a repository plus checksums of its kit files)."""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Sequence

from . import globs
from .common import StarterError, checksums, is_safe_repo_path, read_json, write_json

MANIFEST = "starter.manifest.json"
LOCK = "starter.lock.json"
CLASSES = ("starterOnly", "shared", "project", "kit")
CLASS_NAMES = {"starterOnly": "nur im Starter", "shared": "gemeinsam", "project": "Projekt", "kit": "Kit"}


@dataclass
class Module:
    name: str
    title: str
    folder: str
    default: bool
    paths: List[str]
    also_removes: List[str] = field(default_factory=list)
    needs: List[str] = field(default_factory=list)
    permissions: List[str] = field(default_factory=list)
    command: Optional[str] = None
    next_steps: List[str] = field(default_factory=list)
    description: str = ""

    @property
    def flag(self) -> str:
        return "MODUL_" + self.name.upper()

    @property
    def all_paths(self) -> List[str]:
        return self.paths + self.also_removes


@dataclass
class Manifest:
    raw: dict
    repository: str
    order: List[str]
    lists: Dict[str, List[str]]
    starter_only_paths: List[str]
    move: Dict[str, str]
    replace: Dict[str, str]
    block_start: str
    block_end: str
    modules: Dict[str, Module]
    at_least_one: List[List[str]]
    checks: dict

    def classify(self, path: str) -> str:
        """The first list in `order` whose patterns match decides; unmatched paths belong to the project."""
        for name in self.order:
            if globs.matches(path, self.patterns(name)):
                return name
        return "project"

    def matched_lists(self, path: str) -> List[str]:
        return [name for name in self.order if globs.matches(path, self.patterns(name))]

    def patterns(self, name: str) -> List[str]:
        return self.starter_only_paths if name == "starterOnly" else self.lists[name]

    def kit_files(self, files: Sequence[str]) -> List[str]:
        return [f for f in files if self.classify(f) == "kit"]

    def module_of(self, path: str) -> Optional[str]:
        for m in self.modules.values():
            if globs.matches(path, m.paths):
                return m.name
        return None

    def dependents(self, name: str) -> List[str]:
        return [m.name for m in self.modules.values() if name in m.needs]


def _strings(value, where: str) -> List[str]:
    if not isinstance(value, list) or not all(isinstance(v, str) and v for v in value):
        raise StarterError(f"{MANIFEST}: {where} muss eine Liste nicht leerer Texte sein")
    return list(value)


def _path_map(value, where: str) -> Dict[str, str]:
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise StarterError(f"{MANIFEST}: {where} muss ein Objekt sein")
    for k, v in value.items():
        if not isinstance(v, str) or not is_safe_repo_path(k) or not is_safe_repo_path(v):
            raise StarterError(f"{MANIFEST}: {where} enthält einen unsicheren Pfad ({k} -> {v})")
    return dict(value)


def parse_manifest(raw: dict) -> Manifest:
    """Hand-rolled schema check; every problem names the key."""
    repository = raw.get("repository")
    if not isinstance(repository, str) or "/" not in repository:
        raise StarterError(f"{MANIFEST}: repository muss <besitzer>/<name> sein")
    order = _strings(raw.get("order"), "order")
    if sorted(order) != sorted(CLASSES):
        raise StarterError(f"{MANIFEST}: order muss genau {', '.join(CLASSES)} enthalten")
    lists = {name: _strings(raw.get(name), name) for name in ("kit", "shared", "project")}
    so = raw.get("starterOnly")
    if not isinstance(so, dict):
        raise StarterError(f"{MANIFEST}: starterOnly fehlt")
    so_paths = _strings(so.get("paths"), "starterOnly.paths")
    markers = so.get("blockMarkers") or {}
    start, end = markers.get("start"), markers.get("end")
    if not isinstance(start, str) or not isinstance(end, str) or not start or not end:
        raise StarterError(f"{MANIFEST}: starterOnly.blockMarkers braucht start und end")
    rules = raw.get("rules") or {}
    at_least_one = rules.get("atLeastOne", [])
    if not isinstance(at_least_one, list) or not all(isinstance(g, list) for g in at_least_one):
        raise StarterError(f"{MANIFEST}: rules.atLeastOne muss eine Liste von Modul-Listen sein")
    mods_raw = raw.get("modules")
    if not isinstance(mods_raw, dict) or not mods_raw:
        raise StarterError(f"{MANIFEST}: modules fehlt")
    modules: Dict[str, Module] = {}
    for name, m in mods_raw.items():
        if not isinstance(m, dict):
            raise StarterError(f"{MANIFEST}: modules.{name} muss ein Objekt sein")
        if not name.isidentifier() or name.lower() != name:
            raise StarterError(f"{MANIFEST}: Modulname {name} muss klein geschrieben sein (a-z, 0-9, _)")
        folder = m.get("folder")
        if not isinstance(folder, str) or not folder:
            raise StarterError(f"{MANIFEST}: modules.{name}.folder fehlt")
        if not isinstance(m.get("default"), bool):
            raise StarterError(f"{MANIFEST}: modules.{name}.default muss true oder false sein")
        modules[name] = Module(
            name=name,
            title=str(m.get("title", name)),
            folder=folder,
            default=m["default"],
            paths=_strings(m.get("paths"), f"modules.{name}.paths"),
            also_removes=_strings(m.get("alsoRemoves", []), f"modules.{name}.alsoRemoves") if m.get("alsoRemoves") else [],
            needs=_strings(m.get("needs", []), f"modules.{name}.needs") if m.get("needs") else [],
            permissions=list(m.get("permissions", []) or []),
            command=m.get("command"),
            next_steps=list(m.get("nextSteps", []) or []),
            description=str(m.get("description", "")),
        )
    for m in modules.values():
        for n in m.needs:
            if n not in modules:
                raise StarterError(f"{MANIFEST}: modules.{m.name}.needs nennt das unbekannte Modul {n}")
    for group in at_least_one:
        for n in group:
            if n not in modules:
                raise StarterError(f"{MANIFEST}: rules.atLeastOne nennt das unbekannte Modul {n}")
    return Manifest(
        raw=raw,
        repository=repository,
        order=order,
        lists=lists,
        starter_only_paths=so_paths,
        move=_path_map(so.get("move"), "starterOnly.move"),
        replace=_path_map(so.get("replace"), "starterOnly.replace"),
        block_start=start,
        block_end=end,
        modules=modules,
        at_least_one=[list(g) for g in at_least_one],
        checks=raw.get("checks") or {},
    )


def read_manifest(root: Path) -> Manifest:
    return parse_manifest(read_json(root / MANIFEST))


LOCK_KEYS = ("starter", "version", "state", "source", "commit", "project", "createdOn", "lastSyncedOn",
             "removedModules", "checksums")


def read_lock(root: Path) -> dict:
    lock = read_json(root / LOCK)
    missing = [k for k in LOCK_KEYS if k not in lock]
    if missing:
        raise StarterError(f"{LOCK}: es fehlen {', '.join(missing)}")
    if not isinstance(lock["checksums"], dict) or not isinstance(lock["removedModules"], list):
        raise StarterError(f"{LOCK}: checksums muss ein Objekt und removedModules eine Liste sein")
    return lock


def write_lock(root: Path, lock: dict) -> None:
    write_json(root / LOCK, lock)


def is_project(lock: dict) -> bool:
    """project == null is the signal "this is the starter itself"."""
    return lock.get("project") is not None


def kit_checksums(root: Path, manifest: Manifest, files: Sequence[str]) -> Dict[str, str]:
    return checksums(root, manifest.kit_files(files))
