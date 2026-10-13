"""check-kit (step of `make check`), in two parts.

1. In a project (starter.lock.json names one): the kit paths of starter.manifest.json are unchanged
   since init or the last sync (checksums in the lock), and no starter-only file or block is left.
   In the starter itself: every file is classified by exactly the manifest (no file falls through),
   the modules match scripts/gen_config.py, module paths are disjoint and never project files, every
   `#if MODUL_*` is one `remove` can handle, removing any module leaves no use of its Swift types
   outside an `#if` block, and no guide (*.md) still names a removed module's paths or skills.
2. Everywhere: the files that switch the checks on still do so (Makefile targets, Git hooks, CI),
   following the target list in starter.manifest.json ("checks"). A project may change these shared
   files; dropping a check there would otherwise pass unnoticed.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Mapping, Optional, Sequence

from . import config as cfg
from . import globs
from . import pictures as pics
from .common import StarterError, cut_blocks, has_block, is_text_file, working_files
from .manifest import (CLASS_NAMES, NEEDS_INIT, PENDING, Manifest, is_project, kit_checksums, read_lock, read_manifest,
                       repo_state)
from .markers import swift_flag_problems, transform
from .remove import present_modules, read_texts, simulate

SKIP_GUIDES = ["./CHANGELOG.md", "./THIRD_PARTY_NOTICES.md", "docs/DECISIONS.md", "docs/STARTER_DECISIONS.md"]


@dataclass
class Findings:
    ok: List[str] = field(default_factory=list)
    problems: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)


def _read(root: Path, path: str) -> Optional[str]:
    try:
        return (root / path).read_text(encoding="utf-8")
    except (UnicodeDecodeError, FileNotFoundError, IsADirectoryError):
        return None


# --- part 1: project ------------------------------------------------------------------------------

def kit_differences(root: Path, lock: dict, manifest: Manifest, files: Sequence[str]) -> List[str]:
    expected: Dict[str, str] = lock["checksums"]
    actual = kit_checksums(root, manifest, files)
    out = []
    for path in sorted(set(expected) | set(actual)):
        if path not in actual:
            out.append(f"{path}: gelöscht")
        elif path not in expected:
            out.append(f"{path}: neu angelegt")
        elif actual[path] != expected[path]:
            out.append(f"{path}: geändert")
    return out


def check_project(root: Path, manifest: Manifest, lock: dict, files: Sequence[str], f: Findings) -> None:
    diffs = kit_differences(root, lock, manifest, files)
    if diffs:
        f.problems.append(f"{len(diffs)} Kit-Datei weicht von Starter {lock['version']} ab:" if len(diffs) == 1 else
                          f"{len(diffs)} Kit-Dateien weichen von Starter {lock['version']} ab:")
        f.problems += [f"  {d}" for d in diffs]
        f.problems.append(
            "Kit-Dateien kommen aus dem Starter (Liste kit in starter.manifest.json) und bleiben im Projekt "
            "unverändert, damit bin/starter sync neue Starter-Stände übernehmen kann. Geänderte oder gelöschte "
            "Dateien zurückholen (git restore --source <commit von init oder sync> -- <datei>), neue Dateien "
            "verschieben: eigener Code nach App/Sources/Features/, eigene Tests nach App/Tests/Features/, eigene "
            "Skripte nach scripts/projekt/. Den Bedarf in docs/STARTER_FEEDBACK.md eintragen (Skill "
            "starter-rueckfluss).")
    else:
        f.ok.append(f"{len(lock['checksums'])} Kit-Dateien unverändert seit Starter {lock['version']}")
    leftovers = [p for p in files if globs.matches(p, manifest.starter_only_paths) and p not in manifest.replace]
    for p in files:
        if not is_text_file(root, p) or p.endswith(".json"):
            continue
        text = _read(root, p) or ""
        if has_block(text, manifest.block_start):
            leftovers.append(f"{p} (Abschnitt {manifest.block_start})")
    if leftovers:
        f.problems.append("Bauunterlagen des Starters sind noch da; bin/starter init ausführen oder entfernen: "
                          + ", ".join(leftovers))


def picture_problems(manifest: Manifest, files: Sequence[str], texts: Dict[str, str],
                     present: Sequence[str]) -> List[List[str]]:
    """[problems, warnings] for the README pictures: a guide that shows a picture that is not there, a line of
    docs/screenshots/list.txt with a scene of a removed module, a listed picture that make readme-shots has not
    written yet (a hint)."""
    fileset = set(files)
    problems: List[str] = []
    warnings: List[str] = []
    skip = SKIP_GUIDES + manifest.starter_only_paths
    for path in sorted(texts):
        if not path.endswith(".md") or globs.matches(path, skip):
            continue
        for no, line in enumerate(texts[path].split("\n"), 1):
            for ref in pics.references(line):
                module = pics.module_of(pics.scene_of_picture(ref), manifest.modules)
                if module and module not in present:
                    problems.append(f"{path}:{no} zeigt {ref}, eine Szene des entfernten Moduls {module}; die Stelle "
                                    "anpassen")
                elif ref not in fileset:
                    problems.append(f"{path}:{no} zeigt {ref}, das es nicht gibt (make shots und make readme-shots, "
                                    "oder die Zeile anpassen)")
    listing = texts.get(pics.LIST)
    for no, line in enumerate((listing or "").split("\n"), 1):
        entry = pics.entry_of(line)
        if not entry:
            continue
        scene = pics.scene_of(entry)
        module = pics.module_of(scene, manifest.modules)
        if module and module not in present:
            problems.append(f"{pics.LIST}:{no} nennt die Szene {scene} des entfernten Moduls {module}; Zeile löschen")
        elif pics.picture(entry) not in fileset:
            warnings.append(f"{pics.LIST}:{no}: {pics.picture(entry)} fehlt noch (make shots, dann make readme-shots)")
    return [problems, warnings]


def removed_picture_problems(manifest: Manifest, name: str, closure: List[str], texts: Dict[str, str]) -> List[str]:
    """In the starter: guides that, after bin/starter init and removing `closure`, would still show a picture of one
    of those modules' scenes. Starter-only blocks are cut first, as init does."""
    out = []
    skip = SKIP_GUIDES + manifest.starter_only_paths
    for path in sorted(texts):
        if not path.endswith(".md") or globs.matches(path, skip):
            continue
        text = texts[path]
        if has_block(text, manifest.block_start):
            try:
                text = cut_blocks(text, manifest.block_start, manifest.block_end)
            except StarterError:
                continue
        text = transform(path, text, closure) or ""
        for no, line in enumerate(text.split("\n"), 1):
            for ref in pics.references(line):
                if pics.module_of(pics.scene_of_picture(ref), manifest.modules) in closure:
                    out.append(f"remove {name}: {path}:{no} zeigt {ref}; die Stelle mit <!-- modul:{name} --> "
                               "markieren oder in einen Block nur-im-starter setzen")
    return out


# --- part 1: starter ------------------------------------------------------------------------------

def removal_closure(manifest: Manifest, name: str) -> List[str]:
    """The module and everything that needs it (removing ai means mlx is gone first)."""
    out = [name]
    for m in out:
        for d in manifest.dependents(m):
            if d not in out:
                out.append(d)
    return out


def guide_problems(root: Path, manifest: Manifest, modules: List[str], files: Sequence[str],
                   texts: Dict[str, str]) -> List[str]:
    paths = [p for m in modules for p in manifest.modules[m].all_paths]
    prefixes = sorted({globs.literal_prefix(p) for p in paths if len(globs.literal_prefix(p)) > 4})
    skills = sorted({m.group(1) for p in paths for m in [re.match(r"^\.claude/skills/([^/*]+)/", p)] if m})
    skip = paths + manifest.starter_only_paths + SKIP_GUIDES + list(manifest.move.values())
    out = []
    for path in files:
        if not path.endswith(".md") or globs.matches(path, skip) or path not in texts:
            continue
        text = transform(path, texts[path], modules) or ""
        for no, line in enumerate(text.split("\n"), 1):
            hit = next((p for p in prefixes if p in line), None)
            if hit is None:
                hit = next((f"`{s}`" for s in skills if f"`{s}`" in line or f"/{s}" in line), None)
            if hit is not None:
                out.append(f"{path}:{no} nennt {hit}")
    return out


def check_starter(root: Path, manifest: Manifest, lock: dict, files: Sequence[str], f: Findings) -> None:
    config = cfg.read_config(root)
    if lock["checksums"] or lock["removedModules"]:
        f.problems.append("starter.lock.json: im Starter bleiben checksums und removedModules leer")
    version = (config.get("starter") or {}).get("version")
    if lock["version"] != version:
        f.problems.append(f"starter.lock.json version {lock['version']} passt nicht zu starter.json "
                          f"starter.version {version}")

    unclassified = [p for p in files if not manifest.matched_lists(p)]
    if unclassified:
        f.problems.append("Dateien ohne Klasse in starter.manifest.json (kit, shared, project oder starterOnly "
                          "ergänzen): " + ", ".join(unclassified))
    else:
        counts: Dict[str, int] = {}
        for p in files:
            counts[manifest.classify(p)] = counts.get(manifest.classify(p), 0) + 1
        f.ok.append("alle Dateien klassifiziert (" + ", ".join(
            f"{CLASS_NAMES[k]} {counts.get(k, 0)}" for k in ("kit", "shared", "project", "starterOnly")) + ")")

    gc = cfg.gen_config()
    if set(manifest.modules) != set(gc.MODULE_DIRS):
        f.problems.append(f"Module im Manifest ({', '.join(manifest.modules)}) und in scripts/gen_config.py "
                          f"({', '.join(gc.MODULE_DIRS)}) unterscheiden sich")
    for m in manifest.modules.values():
        if gc.MODULE_DIRS.get(m.name) not in (None, m.folder):
            f.problems.append(f"modules.{m.name}.folder ist {m.folder}, scripts/gen_config.py sagt "
                              f"{gc.MODULE_DIRS[m.name]}")
        if sorted(m.needs) != sorted(gc.MODULE_DEPENDS.get(m.name, [])):
            f.problems.append(f"modules.{m.name}.needs passt nicht zu MODULE_DEPENDS in scripts/gen_config.py")
        if f"App/Sources/Modules/{m.folder}/**" not in m.paths:
            f.problems.append(f"modules.{m.name}.paths fehlt App/Sources/Modules/{m.folder}/**")
        if m.name not in (config.get("modules") or {}):
            f.problems.append(f"starter.json modules nennt {m.name} nicht")
        elif (config.get("modules") or {}).get(m.name) is not m.default:
            f.problems.append(f"modules.{m.name}.default passt nicht zu starter.json")

    for p in files:
        owners = [m.name for m in manifest.modules.values() if globs.matches(p, m.paths)]
        if len(owners) > 1:
            f.problems.append(f"{p} gehört mehreren Modulen ({', '.join(owners)}); jeder Pfad höchstens einem, "
                              "ein zweites trägt ihn unter alsoRemoves")
        if (owners or any(globs.matches(p, m.also_removes) for m in manifest.modules.values())) and \
                manifest.classify(p) not in ("kit", "shared"):
            f.problems.append(f"{p} gehört einem Modul, ist aber {CLASS_NAMES[manifest.classify(p)]}; "
                              "remove würde Projektdateien löschen")

    texts = read_texts(root, list(files))
    swift_problems = []
    for p, t in texts.items():
        if p.endswith(".swift"):
            swift_problems += swift_flag_problems(t, p, manifest.modules)
    f.problems += swift_problems
    for p, t in texts.items():
        if p.endswith(".json") or not has_block(t, manifest.block_start):
            continue
        try:
            cut_blocks(t, manifest.block_start, manifest.block_end)
        except StarterError as e:
            f.problems.append(f"{p}: {e}")
    for target, template in manifest.replace.items():
        if (root / target).exists() and not (root / template).exists():
            f.problems.append(f"starterOnly.replace: Vorlage {template} für {target} fehlt")

    if swift_problems:
        return
    removable = 0
    for name in manifest.modules:
        closure = removal_closure(manifest, name)
        try:
            dangling = simulate(manifest, closure, list(files), texts)
        except StarterError as e:
            f.problems.append(f"remove {name}: {e}")
            continue
        guides = guide_problems(root, manifest, closure, files, texts)
        f.problems += removed_picture_problems(manifest, name, closure, texts)
        for d in dangling:
            f.problems.append(f"remove {name}: {d}; mit #if MODUL_{name.upper()} umschließen")
        for g in guides:
            f.problems.append(f"remove {name}: {g}; die Stelle mit <!-- modul:{name} --> markieren oder "
                              f"zwischen <!-- modul:{name}:anfang --> und <!-- modul:{name}:ende --> setzen")
        if not dangling and not guides:
            removable += 1
    f.ok.append(f"{removable} von {len(manifest.modules)} Modulen lassen sich ohne Reste entfernen "
                "(Swift-Typen und Anleitungen geprüft)")


# --- part 2: the checks stay switched on ---------------------------------------------------------

_WEAK = re.compile(r"\|\|\s*(?:true|:)(?=$|[\s;)])|;\s*true\b|--no-verify")


_NOT_RUN = re.compile(r"^\s*(?:#|(?:echo|print|printf)\b)")


def contains_command(text: str, command: str) -> bool:
    """A command as whole words on a line that runs something: "make check" is not found in
    "make check-kit", in a comment or in an echo/print line. A script path may stand in quotes and
    behind a folder (`"$ROOT/scripts/check_commit_msg.py"`, `./scripts/…`)."""
    before = r"""(?:^|[\s;&|("'`/])""" if "/" in command else r"""(?:^|[\s;&|("'`])"""
    pattern = re.compile(before + re.escape(command) + r"""(?=$|[\s;&|)"'`])""")
    return any(pattern.search(line) for line in text.split("\n") if not _NOT_RUN.match(line))


def makefile_targets(text: str) -> Dict[str, Dict[str, str]]:
    """target -> {"prereqs": "...", "recipe": "..."}; define/endef blocks are skipped."""
    out: Dict[str, Dict[str, str]] = {}
    current: Optional[str] = None
    in_define = False
    for line in text.split("\n"):
        if re.match(r"^define\b", line):
            in_define, current = True, None
            continue
        if in_define:
            if re.match(r"^endef\b", line):
                in_define = False
            continue
        if line.startswith("\t") and current is not None:
            out[current]["recipe"] += line + "\n"
            continue
        m = re.match(r"^([A-Za-z0-9_.-]+(?:[ \t]+[A-Za-z0-9_.-]+)*)[ \t]*:(?![=:])(.*)$", line)
        if m and not line.startswith("."):
            current = m.group(1).split()[0]
            for t in m.group(1).split():
                out.setdefault(t, {"prereqs": "", "recipe": ""})
                out[t]["prereqs"] += " " + m.group(2).split("#")[0]
            continue
        if line.strip() and not line.startswith("\t"):
            current = None
    return out


def check_makefile(text: str, wanted: Dict[str, List[str]], name: str = "Makefile") -> List[str]:
    targets = makefile_targets(text)
    problems = []
    for target, parts in wanted.items():
        if target not in targets:
            problems.append(f"{name}: Ziel {target} fehlt")
            continue
        prereqs = targets[target]["prereqs"].split()
        recipe = targets[target]["recipe"]
        for part in parts:
            # A prerequisite ("check: … test"), or the script path / sub-make call in the recipe.
            if part not in prereqs and part not in recipe:
                problems.append(f"{name}: {target} führt „{part}“ nicht mehr aus")
        for line in recipe.split("\n"):
            if re.match(r"^\t[@+]*-", line) or _WEAK.search(line):
                problems.append(f"{name}: {target} kann nicht mehr scheitern („{line.strip()}“)")
    return problems


def run_values(text: str) -> List[str]:
    """The value of every `run:` key of a workflow, block scalars included."""
    lines = text.split("\n")
    values = []
    for i, line in enumerate(lines):
        m = re.match(r"^(\s*)(?:-\s*)?run:\s*(.*)$", line)
        if not m or line.lstrip().startswith("#"):
            continue
        indent, value = m.group(1), m.group(2)
        if not re.match(r"^[|>][-+]?\s*$", value):
            values.append(value)
            continue
        block = []
        for nxt in lines[i + 1:]:
            if nxt.strip() and len(nxt) - len(nxt.lstrip()) <= len(indent):
                break
            if nxt.strip() and not nxt.strip().startswith("#"):
                block.append(nxt.strip())
        values.append("\n".join(block))
    return values


def check_ci(text: str, groups: List[List[str]], name: str) -> List[str]:
    runs = run_values(text)
    problems = []
    for group in groups:
        if not any(contains_command(r, alt) for r in runs for alt in group):
            problems.append(f"{name}: kein Schritt führt „{' oder '.join(group)}“ aus")
    if re.search(r"continue-on-error:\s*true", text):
        problems.append(f"{name}: continue-on-error: true lässt einen roten Schritt als grün durch")
    if re.search(r"^\s*if:\s*(?:false|\$\{\{\s*false\s*\}\})\s*$", text, re.M):
        problems.append(f"{name}: ein Schritt oder Job ist mit if: false abgeschaltet")
    for r in runs:
        if _WEAK.search(r):
            problems.append(f"{name}: „{r.strip()}“ kann nicht mehr scheitern")
    return problems


def check_switches(root: Path, manifest: Manifest, in_project: bool, f: Findings) -> None:
    checks = manifest.checks
    problems: List[str] = []
    missing: List[str] = []
    for path in checks.get("files", []):
        if not (root / path).exists():
            missing.append(path)
    mk = checks.get("makefile") or {}
    if mk:
        text = _read(root, mk.get("file", "Makefile"))
        if text is None:
            problems.append(f"{mk.get('file', 'Makefile')} fehlt")
        else:
            problems += check_makefile(text, mk.get("targets", {}), mk.get("file", "Makefile"))
    for path, commands in (checks.get("hooks") or {}).items():
        text = _read(root, path)
        if text is None:
            continue  # reported through "files"
        for c in commands:
            if not contains_command(text, c):
                problems.append(f"{path}: führt „{c}“ nicht mehr aus")
        for line in text.split("\n"):
            if not line.lstrip().startswith("#") and _WEAK.search(line):
                problems.append(f"{path}: kann nicht mehr scheitern („{line.strip()}“)")
    ci = checks.get("ci") or {}
    if ci:
        text = _read(root, ci["file"])
        if text is None:
            missing.append(ci["file"])
        else:
            problems += check_ci(text, ci.get("steps", []), ci["file"])
    if missing:
        msg = "Dateien der Prüfungen fehlen: " + ", ".join(missing)
        if in_project:
            problems.append(msg + " (make check überspringt sie sonst still)")
        else:
            f.warnings.append(msg + " (im Starter noch im Bau; in einem Projekt ist das ein Fehler)")
    if problems:
        f.problems.append(f"{len(problems)} {'Abweichung' if len(problems) == 1 else 'Abweichungen'} von der "
                          "Soll-Liste der Prüfungen (checks in starter.manifest.json):")
        f.problems += [f"  {p}" for p in problems]
        f.problems.append("Diese Dateien schalten die Prüfungen ein. Das Ziel, den Hook oder den Schritt "
                          "wiederherstellen; braucht das Projekt eine Ausnahme, steht sie mit Grund in "
                          "docs/STARTER_FEEDBACK.md.")
    else:
        f.ok.append("Makefile, Git-Hooks und CI erfüllen die Soll-Liste der Prüfungen")


def run(root: Path, env: Optional[Mapping[str, str]] = None) -> Findings:
    f = Findings()
    manifest = read_manifest(root)
    lock = read_lock(root)
    files = working_files(root)
    state = repo_state(root, manifest, lock, env)
    if state == "project":
        check_project(root, manifest, lock, files, f)
    elif state == "needs-init":
        f.problems.append(NEEDS_INIT)
    else:
        if state == "starter":
            f.ok.append(f"das ist der Starter selbst ({manifest.repository})")
        else:
            f.ok.append("starter.lock.json nennt kein Projekt, kein origin: geprüft wie der Starter selbst")
            f.warnings.append("ohne origin sehen eine Kopie und der Starter gleich aus; in einer Kopie zuerst "
                              "bin/starter init")
        check_starter(root, manifest, lock, files, f)
    if lock.get(PENDING):
        f.warnings.append(f"nach „{lock[PENDING]}“ ist make build noch nicht grün gelaufen (rot oder ohne "
                          f"Swift-Compiler übersprungen); auf einem Mac {lock[PENDING]} erneut aufrufen (baut noch "
                          "einmal und löscht den Vermerk pendingBuild in starter.lock.json)")
    if state == "project" and not any(
            p.startswith("App/Sources/Features/") and p.endswith(".swift")
            and "OnboardingFeatures.items.append" in (_read(root, p) or "") for p in files):
        f.warnings.append("das Onboarding zeigt noch keine Funktionskarte des Projekts (nur die der Module, mit "
                          "strip-examples keine); eine Karte je Funktion: Skill neues-feature, Schritt 8")
    if state in ("project", "starter", "unknown"):
        config = cfg.read_config(root)
        texts = {p: t for p, t in read_texts(root, [p for p in files if p.endswith(".md") or p == pics.LIST]).items()}
        problems, warnings = picture_problems(manifest, files, texts, present_modules(root, manifest, list(files), config))
        f.problems += problems
        f.warnings += warnings
    check_switches(root, manifest, is_project(lock), f)
    return f


def format_findings(f: Findings) -> str:
    lines = [f"check-kit: {o}." for o in f.ok]
    lines += [f"check-kit: Hinweis: {w}" for w in f.warnings]
    lines += [p if p.startswith("  ") else f"check-kit: {p}" for p in f.problems]
    return "\n".join(lines) + "\n"
