"""bin/starter sync --ziel <tag>: brings a project to a newer starter version (port of app-starter's
starter:sync).

The base is the starter release in starter.lock.json (its commit when known, else the tag
v<version>, or --basis), the target a tag of the starter repository; both are fetched into private
refs (refs/starter/basis, refs/starter/ziel) with fsck on. Never the project's own history: "Use this
template" starts a new one. Modules the project removed stay removed: their paths are skipped and
both starter versions are transformed the way `remove` transformed the project (Swift `#if MODUL_*`
blocks, comment markers, Swift files left empty), and the nur-im-starter blocks are cut, so the
comparison sees what the project really got.
  kit paths      take the target; a project change to one is listed (check-kit reports it anyway)
  shared paths   three-way merge with `git merge-file`; conflicts keep the markers, exit code 2
  project paths  untouched, like the starter's build documents (starterOnly)
  starter.json   merged by key (config.merge_config), never by text; starter.lock.json is rewritten
Files that run by themselves or instruct agents (hooks, .claude, CI, scripts, ai-worker, Makefile, Package.swift,
CLAUDE.md, AGENTS.md) are listed loudly. Nothing is committed.
"""
from __future__ import annotations

import datetime
import json
import os
import re
import subprocess
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from . import config as cfg
from . import globs
from .common import (StarterError, checksum, cut_blocks, git, git_bytes, has_block, inside, is_binary,
                     is_safe_repo_path, is_script_text, is_text_path, origin_url, to_lf)
from .manifest import LOCK, MANIFEST, Manifest, is_project, parse_manifest, read_lock, write_lock
from .markers import transform

BASE_REF = "refs/starter/basis"
# Git must not wait for a password at a prompt nobody sees; a private source uses SSH or the credential helper.
NO_PROMPT = {"GIT_TERMINAL_PROMPT": "0"}
TARGET_REF = "refs/starter/ziel"
NEVER_MERGED = {LOCK, cfg.CONFIG}
# Files that run by themselves or tell an agent what to run: hooks, settings, skills and agents of Claude Code, CI,
# scripts, the worker and the files an agent reads first. A sync lists every one of them before anything runs.
EXECUTABLE = [
    ".claude/**", ".github/**", "scripts/**", "bin/**", "tools/**", "ai-worker/**",
    "./Makefile", "./Package.swift", "./CLAUDE.md", "./AGENTS.md",
    "*.sh", "*.entitlements",
]


@dataclass
class SyncResult:
    source_version: str
    target: str
    taken: List[str] = field(default_factory=list)
    merged: List[str] = field(default_factory=list)
    conflicts: List[str] = field(default_factory=list)
    deleted: List[str] = field(default_factory=list)
    overwritten: List[str] = field(default_factory=list)
    kept_deleted_in_starter: List[str] = field(default_factory=list)
    existing_in_project: List[str] = field(default_factory=list)
    config_notes: List[str] = field(default_factory=list)
    executable: List[str] = field(default_factory=list)
    lock: Optional[dict] = None


def _show(root: Path, ref: str, path: str) -> Optional[bytes]:
    return git_bytes(root, ["show", f"{ref}:{path}"])


def _files_at(root: Path, ref: str) -> List[str]:
    files = [f for f in git(root, ["ls-tree", "-r", "-z", "--name-only", ref]).split("\0") if f]
    unsafe = [f for f in files if not is_safe_repo_path(f)]
    if unsafe:
        raise StarterError(f"{ref} enthält unsichere Pfade ({', '.join(unsafe[:3])}); nichts geändert.")
    return files


def _manifest_at(root: Path, ref: str) -> Manifest:
    raw = _show(root, ref, MANIFEST)
    if raw is None:
        raise StarterError(f"{ref} enthält kein {MANIFEST}")
    try:
        return parse_manifest(json.loads(raw.decode("utf-8")))
    except ValueError as e:
        raise StarterError(f"{ref}:{MANIFEST} ist kein gültiges JSON: {e}")


def _config_at(root: Path, ref: str) -> dict:
    raw = _show(root, ref, cfg.CONFIG)
    if raw is None:
        return {}
    try:
        value = json.loads(raw.decode("utf-8"))
    except ValueError:
        return {}
    return value if isinstance(value, dict) else {}


def merge_text(ours: str, base: str, theirs: str) -> Tuple[str, bool]:
    """Three-way merge with git merge-file; returns the text and whether conflicts are left."""
    with tempfile.TemporaryDirectory(prefix="starter-sync-") as tmp:
        paths = []
        for name, text in (("projekt", ours), ("basis", base), ("starter", theirs)):
            p = Path(tmp) / name
            p.write_text(text, encoding="utf-8")
            paths.append(str(p))
        res = subprocess.run(["git", "merge-file", "-p", "-L", "Projekt", "-L", "Basis", "-L", "Starter", *paths],
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if res.returncode < 0:
            raise StarterError(f"git merge-file ist gescheitert: {res.stderr.decode('utf-8', 'replace').strip()}")
        return res.stdout.decode("utf-8"), res.returncode > 0


def removed_modules(root: Path, lock: dict, base: Manifest, project_config: dict) -> List[str]:
    """Modules the project removed: recorded in the lock, or known to the base starter and missing
    from the project's starter.json."""
    named = set(project_config.get("modules") or {})
    out = set(lock.get("removedModules") or [])
    out.update(m for m in base.modules if m not in named)
    return sorted(out)


def _prepared(manifest: Manifest, path: str, content: Optional[bytes], removed: List[str]) -> Optional[str]:
    """A starter version of a text file as the project would have it, or None when absent there."""
    if content is None:
        return None
    text = to_lf(content.decode("utf-8", "replace"))
    if is_text_path(path) or is_script_text(path, text):
        new = transform(path, text, removed)
        if new is None:
            return None
        text = new
        if not path.endswith(".json") and has_block(text, manifest.block_start):
            text = cut_blocks(text, manifest.block_start, manifest.block_end)
    return text


def synced_checksums(root: Path, target_m: Manifest, old: Dict[str, str], synced: List[str]) -> Dict[str, str]:
    """The lock's checksums after a sync: kit files that now hold the target version get their new
    checksum; every other kit entry keeps its old reference, so a kit file the project changed or
    added before the sync (and sync left alone) still shows up in check-kit."""
    sums = {p: c for p, c in old.items() if target_m.classify(p) == "kit" and (root / p).is_file()}
    for path in synced:
        if target_m.classify(path) == "kit" and (root / path).is_file():
            sums[path] = checksum(root, path)
    return dict(sorted(sums.items()))


def default_source(root: Path, repository: str) -> str:
    """The starter on GitHub, over SSH when the project's own origin uses SSH (then the user has a key
    for GitHub, and a private starter needs no password), else over HTTPS."""
    origin = origin_url(root)
    if origin.startswith("git@") or origin.startswith("ssh://"):
        return f"git@github.com:{repository}.git"
    return f"https://github.com/{repository}.git"


def check_source(source: str, target: str) -> None:
    """Refuses credentials in the address (a password, or a token as the user of an http(s) URL); the
    plain SSH user (`ssh://git@host/…`, `git@host:…`) is no secret."""
    m = re.match(r"^([a-z][a-z0-9+.-]*)://([^/]*)@", source, re.I)
    if m and (":" in m.group(2) or "ssh" not in m.group(1).lower()):
        raise StarterError("--quelle mit Zugangsdaten in der Adresse ist nicht erlaubt; für private Quellen SSH "
                           "(git@github.com:<besitzer>/<name>.git) oder den Credential-Helper von Git nutzen.")
    if target.startswith("-") or source.startswith("-"):
        raise StarterError("--ziel und --quelle dürfen nicht mit einem Bindestrich beginnen.")


def sync(root: Path, target: str, source: Optional[str] = None, base: Optional[str] = None,
         dry_run: bool = False, today: Optional[str] = None) -> SyncResult:
    lock = read_lock(root)
    if not is_project(lock):
        raise StarterError("starter.lock.json nennt kein Projekt; zuerst bin/starter init.")
    if re.match(r"^\d", target):
        target = "v" + target
    source = source or default_source(root, lock.get("source") or "")
    check_source(source, target)
    if base is not None and base.startswith("-"):
        raise StarterError("--basis darf nicht mit einem Bindestrich beginnen.")
    fetch = ["-c", "transfer.fsckObjects=true", "fetch", "--quiet", "--no-tags", source]
    try:
        git(root, fetch + [f"+refs/tags/{target}:{TARGET_REF}"], env=NO_PROMPT)
    except StarterError as e:
        raise StarterError(f"{e}. Den Tag {target} gibt es in {source} nicht oder die Quelle ist nicht erreichbar; "
                           f"vorhandene Tags zeigt git ls-remote --tags {source}")
    if base:
        base_spec = base if re.fullmatch(r"[0-9a-f]{40}", base) else f"refs/tags/{base}"
    elif lock.get("commit"):
        base_spec = lock["commit"]
    else:
        base_spec = f"refs/tags/v{lock['version']}"
    try:
        git(root, fetch + [f"+{base_spec}:{BASE_REF}"], env=NO_PROMPT)
    except StarterError as e:
        raise StarterError(f"{e}. Basis {base_spec} nicht gefunden: den Tag v{lock['version']} im Starter "
                           "veröffentlichen oder --basis <tag-oder-commit> angeben.")

    base_m = _manifest_at(root, BASE_REF)
    target_m = _manifest_at(root, TARGET_REF)
    base_files = set(_files_at(root, BASE_REF))
    target_files = set(_files_at(root, TARGET_REF))
    project_config = cfg.read_config(root)
    removed = removed_modules(root, lock, base_m, project_config)
    removed_paths = [p for m in removed for man in (base_m, target_m) if m in man.modules
                     for p in man.modules[m].all_paths]
    result = SyncResult(source_version=lock["version"], target=target)

    def class_of(path: str) -> str:
        return target_m.classify(path) if path in target_files else base_m.classify(path)

    writes: Dict[str, Optional[bytes]] = {}   # path -> content (None = delete)
    synced_kit: List[str] = []                 # kit paths that hold the target version after the sync
    for path in sorted(base_files | target_files):
        kind = class_of(path)
        if kind not in ("kit", "shared") or path in NEVER_MERGED or globs.matches(path, removed_paths):
            continue
        base_raw = _show(root, BASE_REF, path) if path in base_files else None
        theirs_raw = _show(root, TARGET_REF, path) if path in target_files else None
        binary = any(c is not None and is_binary(c) for c in (base_raw, theirs_raw))
        full = inside(root, path)
        ours_raw = full.read_bytes() if full.is_file() else None
        binary = binary or (ours_raw is not None and is_binary(ours_raw))
        if binary:
            base_text, theirs_text = base_raw, theirs_raw
            ours_text = ours_raw
        else:
            base_text = _prepared(base_m, path, base_raw, removed)
            theirs_text = _prepared(target_m, path, theirs_raw, removed)
            ours_text = None if ours_raw is None else to_lf(ours_raw.decode("utf-8", "replace"))
        crlf = ours_raw is not None and not binary and b"\r\n" in ours_raw

        def encoded(text) -> bytes:
            if isinstance(text, bytes):
                return text
            return (text.replace("\n", "\r\n") if crlf else text).encode("utf-8")

        if theirs_text is None:
            if ours_raw is None:
                continue
            if ours_text == base_text:
                writes[path] = None
                result.deleted.append(path)
            else:
                result.kept_deleted_in_starter.append(path)
            continue
        if kind == "kit":
            synced_kit.append(path)
        if theirs_text == ours_text:
            continue
        if kind == "shared" and base_text is None and ours_raw is not None:
            result.existing_in_project.append(path)
            continue
        if kind == "kit" or binary or ours_raw is None or base_text is None or ours_text == base_text:
            if ours_raw is not None and ours_text != base_text:
                result.overwritten.append(path)
            writes[path] = encoded(theirs_text)
            result.taken.append(path)
            continue
        if theirs_text == base_text:
            continue
        text, conflict = merge_text(ours_text, base_text, theirs_text)
        writes[path] = encoded(text)
        (result.conflicts if conflict else result.merged).append(path)

    # The starter's decisions, kept in a project under another name, always follow the starter.
    for src, dst in target_m.move.items():
        theirs_raw = _show(root, TARGET_REF, src)
        full = inside(root, dst)
        if theirs_raw is None:
            continue
        synced_kit.append(dst)
        if full.is_file() and full.read_bytes() == theirs_raw:
            continue
        writes[dst] = theirs_raw
        result.taken.append(dst)

    merged_config, notes = cfg.merge_config(project_config, _config_at(root, BASE_REF), _config_at(root, TARGET_REF),
                                            removed)
    result.config_notes = notes
    config_changed = merged_config != project_config

    touched = result.taken + result.merged + result.conflicts + result.deleted
    result.executable = sorted(p for p in touched if globs.matches(p, EXECUTABLE))
    if dry_run:
        return result

    for path, content in writes.items():
        full = inside(root, path)
        if content is None:
            if full.exists():
                full.unlink()
        else:
            full.parent.mkdir(parents=True, exist_ok=True)
            tmp = full.with_name(full.name + ".starter-tmp")
            tmp.write_bytes(content)
            os.replace(tmp, full)
    if config_changed:
        cfg.write_config(root, merged_config)
    today = today or datetime.date.today().isoformat()
    lock.update({
        "version": target[1:] if target.startswith("v") else target,
        "commit": git(root, ["rev-parse", TARGET_REF]),
        "lastSyncedOn": today,
        "checksums": synced_checksums(root, target_m, lock["checksums"], synced_kit),
    })
    write_lock(root, lock)
    result.lock = lock
    return result


def report(result: SyncResult, dry_run: bool) -> str:
    def row(label: str, items: List[str]) -> str:
        return f"  {label} ({len(items)}): {', '.join(items) if items else 'keine'}"
    lines = [
        f"bin/starter sync von {result.source_version} auf {result.target}"
        f"{' (Probelauf, nichts geschrieben)' if dry_run else ''}:",
        row("vom Starter übernommen", result.taken),
        row("zusammengeführt", result.merged),
        row("mit Konflikt, Markierungen <<<<<<< in der Datei auflösen", result.conflicts),
        row("gelöscht, weil der Starter sie entfernt hat", result.deleted),
        row("Projektänderung an Kit-Datei überschrieben", result.overwritten),
        row("im Starter gelöscht, im Projekt geändert und behalten", result.kept_deleted_in_starter),
        row("neu im Starter, im Projekt schon vorhanden und behalten; von Hand vergleichen",
            result.existing_in_project),
        row("starter.json", result.config_notes),
        row("DAVON CODE UND ANWEISUNGEN FÜR AGENTEN (Hooks, .claude, CI, Skripte, ai-worker, Makefile, Package.swift, "
            "CLAUDE.md, AGENTS.md), vor jedem weiteren Befehl lesen", result.executable),
        "Danach: zuerst git diff lesen, vor allem diese Dateien; dann Konflikte lösen, make rules, make check "
        "und make build, dann committen.",
    ]
    return "\n".join(lines) + "\n"

