"""bin/starter init: turns a fresh copy of the starter ("Use this template") into a project, once.

It sets the app's name, bundle id, accent and symbol in starter.json, empties the commit identity
(an agent must never commit, sign or ship under the starter author's name: until the project enters
its own, the commit-msg hook refuses every commit), resets version and signing, removes the
starter's build documents (starterOnly in starter.manifest.json) and the blocks between the
nur-im-starter markers, keeps the starter's decisions as docs/STARTER_DECISIONS.md, puts empty
templates in place, writes starter.lock.json (starter version, source commit when the tag is found,
checksums of every kit file), removes the modules the project does not want, regenerates the icon
and builds. Running it again changes nothing.
"""
from __future__ import annotations

import datetime
import re
import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional

from . import config as cfg
from . import globs
from .common import (StarterError, cut_blocks, git, has_block, inside, is_text_file, remove_empty_dirs, working_files,
                     write_text)
from .manifest import Manifest, is_project, kit_checksums, read_lock, read_manifest, write_lock
from .remove import (apply_removal, dangling_report, plan_removal, present_modules, read_texts, refuse_in_starter,
                     run_make, simulate)

NEW_VERSION = "0.1.0"


@dataclass
class InitOptions:
    name: str
    bundle_id: str
    accent: Optional[str] = None
    symbol: Optional[str] = None
    remove: List[str] = field(default_factory=list)
    dry_run: bool = False
    build: bool = True
    offline: bool = False
    today: Optional[str] = None
    starter_commit: Optional[str] = None


@dataclass
class InitResult:
    project: str
    version: str
    removed: List[str] = field(default_factory=list)
    moved: List[str] = field(default_factory=list)
    replaced: List[str] = field(default_factory=list)
    missing_templates: List[str] = field(default_factory=list)
    blocks: List[str] = field(default_factory=list)
    identity_cleared: bool = False
    modules_removed: List[str] = field(default_factory=list)
    commit: Optional[str] = None
    checksums: int = 0
    notes: List[str] = field(default_factory=list)


def slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", name.lower()) or "app"


def default_bundle_id(name: str) -> str:
    return f"com.example.{slug(name)}"


def starter_commit_for(root: Path, repository: str, version: str, offline: bool) -> Optional[str]:
    """The commit of the starter release this copy came from, by its tag v<version>: a local tag
    first, then `git ls-remote` (15 s). None without tag or network; sync then uses the tag itself.
    The copy's own HEAD is never the starter commit: "Use this template" starts a new history."""
    local = git(root, ["rev-parse", "-q", "--verify", f"refs/tags/v{version}^{{commit}}"], check=False)
    if re.fullmatch(r"[0-9a-f]{40}", local or ""):
        return local
    if offline:
        return None
    try:
        out = git(root, ["ls-remote", "--tags", f"https://github.com/{repository}.git", f"refs/tags/v{version}"],
                  check=False, timeout=15)
    except StarterError:
        return None
    m = re.match(r"^([0-9a-f]{40})\s", out or "")
    return m.group(1) if m else None


def removal_order(manifest: Manifest, wanted: List[str], present: List[str]) -> List[str]:
    """Modules in an order that removes dependents first (mlx before ai); refuses when a module
    stays that needs one of them."""
    for m in wanted:
        if m not in manifest.modules:
            raise StarterError(f"Modul „{m}“ gibt es nicht. Module: {', '.join(manifest.modules)}")
    wanted = [m for m in dict.fromkeys(wanted) if m in present]
    for m in wanted:
        keeps = [d for d in manifest.dependents(m) if d in present and d not in wanted]
        if keeps:
            raise StarterError(f"Modul {m} wird von {', '.join(keeps)} gebraucht; beide entfernen "
                               f"(--module-aus {','.join(keeps + [m])}) oder {m} behalten.")
    ordered: List[str] = []
    pending = list(wanted)
    while pending:
        for m in pending:
            if all(d in ordered or d not in pending for d in manifest.dependents(m)):
                ordered.append(m)
                pending.remove(m)
                break
        else:
            raise StarterError("Module hängen im Kreis voneinander ab; starter.manifest.json prüfen")
    return ordered


def project_config(config: dict, opts: InitOptions, today: str) -> dict:
    out = dict(config)
    app = dict(out.get("app") or {})
    app["name"] = opts.name
    app["bundleId"] = opts.bundle_id
    app["displayName"] = {"en": opts.name, "de": opts.name}
    app["version"] = NEW_VERSION
    app["build"] = 1
    if opts.accent:
        app["accent"] = opts.accent
    if opts.symbol:
        app["symbol"] = opts.symbol
    app["copyright"] = f"© {today[:4]}"
    out["app"] = app
    out["commit"] = {"name": "", "email": ""}
    signing = dict(out.get("signing") or {})
    signing.update({"identity": "-", "teamId": "", "notarize": False})
    out["signing"] = signing
    return out


def _check_symbol(symbol: Optional[str]) -> None:
    if symbol is not None and check_symbol(symbol):
        raise StarterError(f"--symbol {symbol}: {check_symbol(symbol)}")


def init(root: Path, opts: InitOptions, check_origin: bool = True) -> Optional[InitResult]:
    lock = read_lock(root)
    if is_project(lock):
        return None
    manifest = read_manifest(root)
    if check_origin:
        refuse_in_starter(root, manifest, "bin/starter init")
    today = opts.today or datetime.date.today().isoformat()
    config = cfg.read_config(root)
    _check_symbol(opts.symbol)
    new_config = project_config(config, opts, today)
    cfg.validate_config(new_config)

    files = working_files(root)
    present = present_modules(root, manifest, files, config)
    order = removal_order(manifest, opts.remove, present)
    enabled_after = {m for m, on in (new_config.get("modules") or {}).items() if on is True and m not in order}
    for group in manifest.at_least_one:
        if not enabled_after.intersection(group):
            raise StarterError(f"Mindestens eines der Module {', '.join(group)} muss bleiben, sonst sind die "
                               "Einstellungen nicht erreichbar.")

    # Every removal is checked before anything is written, so a refusal never leaves half an init.
    dangling = simulate(manifest, order, files, read_texts(root, files)) if order else []
    if dangling:
        raise StarterError("nichts geändert, andere Dateien nutzen noch Typen der Module "
                           f"{', '.join(order)}:\n  " + "\n  ".join(dangling)
                           + "\nDiese Stellen mit #if MODUL_<NAME> … #endif umschließen, dann erneut aufrufen.")

    result = InitResult(project=opts.name, version=lock["version"], modules_removed=order)
    result.identity_cleared = bool((config.get("commit") or {}).get("name") or (config.get("commit") or {}).get("email"))
    result.removed = [f for f in files if globs.matches(f, manifest.starter_only_paths) and f not in manifest.replace]
    moves = [(src, dst) for src, dst in manifest.move.items() if (root / src).is_file()]
    result.moved = [dst for _, dst in moves]
    for target, template in manifest.replace.items():
        if (root / template).is_file():
            result.replaced.append(target)
        elif (root / target).exists():
            result.missing_templates.append(f"{target} (Vorlage {template} fehlt)")
    # Every text is cut before anything moves: a moved file and a template copy get the cut text, and a
    # file that a template replaces is not written back over the template.
    block_texts = {}
    for f in files:
        if f in result.removed or f.endswith(".json") or not is_text_file(root, f):
            continue
        text = (root / f).read_text(encoding="utf-8", errors="replace")
        if has_block(text, manifest.block_start):
            block_texts[f] = cut_blocks(text, manifest.block_start, manifest.block_end)
    replaced = set(result.replaced)
    result.blocks = sorted({f for f in block_texts if f not in replaced}
                           | {dst for src, dst in moves if src in block_texts})
    result.commit = opts.starter_commit if opts.starter_commit is not None else \
        starter_commit_for(root, manifest.repository, lock["version"], opts.offline)
    if opts.dry_run:
        return result

    for f in result.removed:
        inside(root, f).unlink()
    remove_empty_dirs(root, result.removed)
    def copy(src: str, dst: str) -> None:
        if src in block_texts:
            write_text(inside(root, dst), block_texts[src])
        else:
            shutil.copyfile(inside(root, src), inside(root, dst))

    for src, dst in moves:
        copy(src, dst)
    for target in result.replaced:
        copy(manifest.replace[target], target)
    for f, text in block_texts.items():
        if f not in replaced:
            write_text(inside(root, f), text)
    cfg.write_config(root, new_config)

    lock.update({
        "state": "project",
        "source": manifest.repository,
        "commit": result.commit,
        "project": opts.name,
        "createdOn": today,
        "lastSyncedOn": today,
        "checksums": kit_checksums(root, manifest, working_files(root)),
    })
    write_lock(root, lock)

    for m in order:
        plan = plan_removal(root, m, manifest)
        if plan.dangling:
            raise StarterError(dangling_report(plan).rstrip())
        apply_removal(root, plan, manifest)
    result.checksums = len(read_lock(root)["checksums"])

    if opts.build:
        if (root / "scripts" / "icon.sh").exists():
            if not run_make(root, "icon"):
                result.notes.append("make icon ist gescheitert; später von Hand ausführen")
        if not run_make(root, "build"):
            raise StarterError("Projekt eingerichtet, aber make build ist rot (Meldungen oben).")
    return result


def report(result: InitResult, dry_run: bool, build: bool) -> str:
    def names(items: List[str]) -> str:
        return ", ".join(items) if items else "keine"
    cleared = "würde geleert" if dry_run else "geleert"
    lines = [
        (f"bin/starter init würde das Projekt {result.project} einrichten (Starter {result.version}, Probelauf, "
         "nichts geschrieben):") if dry_run else
        f"bin/starter init hat das Projekt {result.project} eingerichtet (Starter {result.version}):",
        f"  Bauunterlagen des Starters entfernt: {names(result.removed)}",
        f"  als Nachschlagewerk des Starters angelegt: {names(result.moved)}",
        f"  durch leere Vorlagen ersetzt: {names(result.replaced)}",
        f"  Abschnitte „nur im Starter“ entfernt in: {names(result.blocks)}",
        f"  Module entfernt: {names(result.modules_removed)}",
        f"  Starter-Commit: {result.commit or 'unbekannt (Tag nicht gefunden); sync nutzt dann den Tag selbst'}",
    ]
    if result.missing_templates:
        lines.append(f"  Vorlage fehlt, Datei unverändert: {names(result.missing_templates)}")
    if not dry_run:
        lines.append(f"  {result.checksums} Prüfsummen der Kit-Dateien in starter.lock.json")
    lines.append(f"  starter.json: Name, Bundle-ID, Version {NEW_VERSION}; Commit-Identität {cleared} "
                 "(commit.name und commit.email eintragen, sonst lehnt der Hook commit-msg jeden Commit ab)")
    lines += [f"  Hinweis: {n}" for n in result.notes]
    if not dry_run:
        if not build:
            lines.append("  Danach: make icon und make build (mit --ohne-build übersprungen)")
        lines.append("Danach: commit.name und commit.email in starter.json eintragen, make hooks, make rules, "
                     "make check, docs/PROJECT.md füllen und alles committen.")
    return "\n".join(lines) + "\n"


def check_name(value: str) -> Optional[str]:
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9 ]*", value):
        return "mit einem Buchstaben beginnen, nur Buchstaben, Ziffern und Leerzeichen"
    return None


def check_bundle_id(value: str) -> Optional[str]:
    if not re.fullmatch(r"[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+", value):
        return "Form wie de.firma.app"
    return None


def check_symbol(value: str) -> Optional[str]:
    if not re.fullmatch(r"[a-z0-9]+(\.[a-z0-9]+)*", value):
        return "Name eines SF Symbols wie sparkles oder waveform.circle"
    return None


def interactive_values(manifest: Manifest, config: dict, ask, present: List[str],
                       name: Optional[str] = None, say=print) -> InitOptions:
    """Asks for name (unless given), bundle id, accent, symbol and the modules to keep;
    `ask(prompt, default, check)` returns the answer (default on empty input) and asks again while
    `check(answer)` returns a reason. The module rules are checked with each answer: a module whose
    dependency goes is removed with it (no question), and the last module of an atLeastOne group
    cannot be answered away. A module that is off in starter.json defaults to "n"."""
    accents = cfg.gen_config().ACCENTS
    app = config.get("app") or {}
    switches = config.get("modules") or {}
    name = name or ask("Name der App (A–Z, a–z, Ziffern, Leerzeichen)", None, check_name)
    bundle = ask("Bundle-ID", default_bundle_id(name), check_bundle_id)
    accent = ask(f"Akzentfarbe ({', '.join(accents)})", app.get("accent", "violett"),
                 lambda v: None if v in accents else "eine der genannten Farben")
    symbol = ask("SF Symbol für das App-Icon", app.get("symbol", "sparkles"), check_symbol)
    remove: List[str] = []
    for m in manifest.modules.values():
        if m.name not in present:
            continue
        gone = [n for n in m.needs if n in remove]
        if gone:
            say(f"  Modul {m.name} ({m.title}) braucht {', '.join(gone)} und wird mit entfernt.")
            remove.append(m.name)
            continue

        def check(answer: str, module: str = m.name) -> Optional[str]:
            if answer[:1].lower() not in ("j", "n"):
                return "j oder n"
            if answer[:1].lower() == "n":
                for group in manifest.at_least_one:
                    if module in group and not [g for g in group if g != module and g in present
                                                and g not in remove and switches.get(g) is True]:
                        return (f"eines der Module {', '.join(group)} bleibt, sonst sind die Einstellungen "
                                "nicht erreichbar; hier j antworten")
            return None

        on = switches.get(m.name) is True
        keep = ask(f"Modul {m.name} ({m.title}, in starter.json {'an' if on else 'aus'}) behalten? j/n",
                   "j" if on else "n", check)
        if keep.lower().startswith("n"):
            remove.append(m.name)
    return InitOptions(name=name, bundle_id=bundle, accent=accent, symbol=symbol, remove=remove)


def summary(opts: InitOptions) -> str:
    """What init will do with the interactive answers, shown before "Fortfahren?"."""
    return (f"Zusammenfassung: App {opts.name}, Bundle-ID {opts.bundle_id}, Akzent {opts.accent}, Symbol {opts.symbol}\n"
            f"  Module entfernen: {', '.join(opts.remove) if opts.remove else 'keine'}\n"
            "  Außerdem: Bauunterlagen des Starters löschen, Commit-Identität leeren, starter.lock.json schreiben\n")
