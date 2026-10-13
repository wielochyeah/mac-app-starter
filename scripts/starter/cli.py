"""Command line of bin/starter (German help, like the docs)."""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path
from typing import List, Optional

from . import config as cfg
from . import kitcheck, project, remove, sync
from .common import StarterError, build_env, repo_root, working_files
from .manifest import NEEDS_INIT, PENDING, is_project, read_lock, read_manifest, repo_state, set_pending_build

DESCRIPTION = """Werkzeuge des mac-app-starter: aus der Vorlage ein Projekt machen, Module entfernen,
neue Starter-Stände übernehmen und prüfen, dass Kit-Dateien unverändert sind.
Hilfe zu einem Befehl: bin/starter <befehl> --help"""

_TRANSLATIONS = [
    (r"unrecognized arguments: (.*)", r"unbekannte Argumente: \1"),
    (r"the following arguments are required: (.*)", r"es fehlt: \1"),
    (r"argument (\S+): invalid choice: (.*?) \(choose from (.*)\)", r"\1: \2 gibt es nicht (möglich: \3)"),
    (r"argument (\S+): expected one argument", r"\1 braucht einen Wert"),
    (r"invalid choice: (.*?) \(choose from (.*)\)", r"\1 gibt es nicht (möglich: \2)"),
]


class GermanFormatter(argparse.HelpFormatter):
    def __init__(self, prog, **kwargs):
        kwargs.setdefault("max_help_position", 30)
        super().__init__(prog, **kwargs)

    def add_usage(self, usage, actions, groups, prefix=None):
        return super().add_usage(usage, actions, groups, prefix="Aufruf: " if prefix is None else prefix)


class GermanRawFormatter(GermanFormatter, argparse.RawDescriptionHelpFormatter):
    pass


class Parser(argparse.ArgumentParser):
    def __init__(self, *args, **kwargs):
        kwargs.setdefault("formatter_class", GermanFormatter)
        kwargs.setdefault("add_help", False)
        super().__init__(*args, **kwargs)
        self._positionals.title = "Argumente"
        self._optionals.title = "Optionen"
        self.add_argument("-h", "--help", action="help", help="diese Hilfe zeigen")

    def error(self, message):
        for pattern, repl in _TRANSLATIONS:
            message = re.sub(pattern, repl, message)
        self.print_usage(sys.stderr)
        self.exit(2, f"{self.prog}: {message}\n")


def build_parser() -> Parser:
    p = Parser(prog="bin/starter", description=DESCRIPTION, formatter_class=GermanRawFormatter)
    sub = p.add_subparsers(dest="command", title="Befehle", metavar="<befehl>", parser_class=Parser)

    i = sub.add_parser("init", help="aus einer Kopie des Starters ein Projekt machen",
                       description="Macht aus einer Kopie des Starters („Use this template“) ein Projekt: Name, "
                                   "Bundle-ID, Akzent und Symbol in starter.json, Commit-Identität geleert, "
                                   "Bauunterlagen entfernt, Vorlagen eingesetzt, starter.lock.json geschrieben, "
                                   "nicht gewünschte Module entfernt, Icon neu gezeichnet und gebaut. Im "
                                   "Starter-Repository selbst lehnt init ab; ein zweiter Aufruf ändert nichts.")
    i.add_argument("--name", help="Name der App (Buchstaben, Ziffern, Leerzeichen), etwa „Notizen“")
    i.add_argument("--bundle-id", dest="bundle_id", help="Bundle-ID, etwa de.beispiel.notizen")
    i.add_argument("--accent", help="Akzentfarbe: violett, rot, blau, gruen, orange oder graphit")
    i.add_argument("--symbol", help="SF-Symbol für das App-Icon, etwa note.text")
    i.add_argument("--anrede", choices=["du", "sie"],
                   help="Anrede der deutschen Texte (Standard: wie in starter.json, im Starter du); bei sie "
                        "listet make check-texts die du-Texte des Kits, die umzuschreiben sind")
    i.add_argument("--module-aus", dest="module_aus", action="append", default=[], metavar="MODUL",
                   help="Modul entfernen; mehrfach oder mit Komma (--module-aus island,examples)")
    i.add_argument("--non-interactive", action="store_true", help="nichts fragen; --name ist dann Pflicht")
    i.add_argument("--probelauf", action="store_true", help="zeigen, was sich ändern würde, nichts schreiben")
    i.add_argument("--ohne-build", dest="ohne_build", action="store_true", help="make icon und make build auslassen")
    i.add_argument("--ohne-netz", dest="ohne_netz", action="store_true",
                   help="den Starter-Commit nicht per git ls-remote nachschlagen")

    r = sub.add_parser("remove", help="ein Modul entfernen",
                       description="Entfernt ein Modul: löscht die Pfade, die starter.manifest.json dem Modul "
                                   "zuordnet, die #if MODUL_<NAME>-Blöcke in allen Swift-Dateien (ein #else-Zweig bleibt), "
                                   "die Markierungen modul:<name> in anderen Dateien und den Schalter in "
                                   "starter.json, dann make build. Vorher prüft es Abhängigkeiten (mlx braucht ai; "
                                   "window oder menubar bleibt) und ob andere Dateien Typen des Moduls nutzen; "
                                   "dann ändert es nichts.")
    r.add_argument("modul", help="Name des Moduls (bin/starter modules zeigt alle)")
    r.add_argument("--probelauf", action="store_true", help="zeigen, was sich ändern würde, nichts schreiben")
    r.add_argument("--ohne-build", dest="ohne_build", action="store_true", help="make build danach auslassen")

    s = sub.add_parser("strip-examples", help="das Beispiel-Modul entfernen",
                       description="Entfernt das Modul examples (wie bin/starter remove examples). Ausführen, "
                                   "sobald die erste eigene Funktion steht: bis dahin ist das Beispiel ihre Vorlage.")
    s.add_argument("--probelauf", action="store_true", help="zeigen, was sich ändern würde, nichts schreiben")
    s.add_argument("--ohne-build", dest="ohne_build", action="store_true", help="make build danach auslassen")

    y = sub.add_parser("sync", help="einen neueren Stand des Starters übernehmen",
                       description="Holt den Tag --ziel aus dem Starter-Repository und führt ihn mit dem Projekt "
                                   "zusammen: Kit-Dateien nimmt es vom Starter, gemeinsame Dateien führt es per "
                                   "git merge-file zusammen, Projektdateien bleiben, entfernte Module bleiben "
                                   "entfernt. Es committet nichts. Exit-Code 2: Konflikte sind offen.")
    y.add_argument("--ziel", required=True, help="Tag des Starters, etwa v1.1.0 (eine Version ohne v wird ergänzt)")
    y.add_argument("--quelle", help="Repository des Starters (URL oder Pfad), etwa "
                                    "git@github.com:wielochyeah/mac-app-starter.git für SSH; Standard: source aus "
                                    "starter.lock.json auf GitHub, per SSH, wenn origin des Projekts SSH nutzt")
    y.add_argument("--basis", help="Tag oder Commit der bisherigen Starter-Version, falls der Tag fehlt")
    y.add_argument("--probelauf", action="store_true", help="zeigen, was sich ändern würde, nichts schreiben")

    sub.add_parser("check-kit", help="Kit-Dateien und Prüfungen prüfen",
                   description="In einem Projekt: Kit-Dateien unverändert seit init oder sync, keine Bauunterlagen "
                               "übrig. Im Starter: jede Datei klassifiziert, Module entfernbar ohne Reste. Überall: "
                               "Makefile, Git-Hooks und CI führen die Prüfungen weiter aus.")
    sub.add_parser("modules", help="Module mit Zustand und Pfaden zeigen",
                   description="Zeigt jedes Modul mit Titel, Zustand (an, aus, entfernt), Abhängigkeiten und Pfaden.")
    sub.add_parser("doctor", help="Werkzeuge und Stand prüfen",
                   description="Führt make doctor aus und zeigt, ob dies der Starter oder ein Projekt ist, "
                               "welche Starter-Version es nutzt und ob die Commit-Identität gesetzt ist.")
    return p


def _split_modules(values: List[str]) -> List[str]:
    return [m.strip() for v in values for m in v.split(",") if m.strip()]


def _ask(prompt: str, default: Optional[str], check=None) -> str:
    suffix = f" [{default}]" if default else ""
    while True:
        try:
            answer = input(f"{prompt}{suffix}: ").strip()
        except EOFError:
            raise StarterError("Eingabe beendet; mit --non-interactive und --name aufrufen")
        answer = answer or (default or "")
        if not answer:
            continue
        reason = check(answer) if check else None
        if reason is None:
            return answer
        print(f"  {reason}")


def finish_pending_build(root: Path, label: str, build: bool) -> Optional[int]:
    """When an earlier init or remove left make build red (pendingBuild in the lock), builds again
    instead of reporting success; None when nothing is pending."""
    pending = read_lock(root).get(PENDING)
    if not pending:
        return None
    if not build:
        sys.stderr.write(f"{label}: nach „{pending}“ ist make build noch nicht grün gelaufen; ohne --ohne-build erneut "
                         "aufrufen, dann baut es noch einmal.\n")
        return 1
    missing = remove.swift_missing()
    if missing:
        sys.stderr.write(f"{label}: nach „{pending}“ steht make build noch aus; {missing}. Auf einem Mac erneut "
                         "aufrufen, dann baut es.\n")
        return 1
    print(f"{label}: nach „{pending}“ ist make build noch nicht grün gelaufen, baue noch einmal.")
    if remove.run_make(root, "build"):
        set_pending_build(root, None)
        print(f"{label}: make build ist grün, „{pending}“ ist fertig. Danach: make check und committen.")
        return 0
    sys.stderr.write(f"{label}: make build ist weiter rot (Meldungen oben); „{pending}“ ist nicht fertig.\n")
    return 1


def cmd_init(root: Path, a) -> int:
    lock = read_lock(root)
    if is_project(lock):
        pending = None if a.probelauf else finish_pending_build(root, "bin/starter init", not a.ohne_build)
        if pending is not None:
            return pending
        print(f"bin/starter init: starter.lock.json nennt schon das Projekt {lock['project']}, nichts zu tun.")
        return 0
    manifest = read_manifest(root)
    remove.refuse_in_starter(root, manifest, "bin/starter init")
    if a.non_interactive:
        if not a.name:
            raise StarterError("--non-interactive braucht --name")
        opts = project.InitOptions(name=a.name, bundle_id=a.bundle_id or project.default_bundle_id(a.name),
                                   accent=a.accent, symbol=a.symbol, remove=_split_modules(a.module_aus),
                                   bundle_id_defaulted=not a.bundle_id, anrede=a.anrede)
    else:
        if not sys.stdin.isatty():
            raise StarterError("kein Terminal für Fragen; mit --non-interactive --name <Name> aufrufen")
        print("bin/starter init macht aus dieser Kopie ein Projekt. Es löscht die Bauunterlagen des Starters "
              "(docs/bau) und leert die Commit-Identität.")
        config = cfg.read_config(root)
        present = remove.present_modules(root, manifest, working_files(root), config)
        defaults = project.with_flag_defaults(config, accent=a.accent, symbol=a.symbol, anrede=a.anrede)
        opts = project.interactive_values(manifest, defaults, _ask, present, name=a.name)
        opts.remove += _split_modules(a.module_aus)
        if a.bundle_id:
            opts.bundle_id = a.bundle_id
        print(project.summary(opts), end="")
        confirm = _ask("Fortfahren? j/n", "n")
        if not confirm.lower().startswith("j"):
            print("Abgebrochen, nichts geändert.")
            return 1
    opts.dry_run, opts.build, opts.offline = a.probelauf, not a.ohne_build, a.ohne_netz
    result = project.init(root, opts, check_origin=False)
    if result is None:
        print("bin/starter init: nichts zu tun.")
        return 0
    print(project.report(result, a.probelauf, opts.build), end="")
    if result.build_ok is False:
        sys.stderr.write("bin/starter init: Projekt eingerichtet, aber make build ist rot (Meldungen oben).\n")
        return 1
    return 0


def cmd_remove(root: Path, name: str, dry_run: bool, build: bool) -> int:
    plan = remove.remove_module(root, name, dry_run=dry_run, build=build)
    if plan.dangling:
        sys.stderr.write(remove.dangling_report(plan))
        return 1
    if plan.already_removed and not dry_run:
        pending = finish_pending_build(root, f"bin/starter remove {name}", build)
        if pending is not None:
            return pending
    print(remove.report(plan, dry_run, build), end="")
    if plan.build_ok is False:
        sys.stderr.write(f"bin/starter remove {name}: Modul entfernt, aber make build ist rot (Meldungen oben).\n")
        return 1
    return 0


def cmd_sync(root: Path, a) -> int:
    result = sync.sync(root, a.ziel, source=a.quelle, base=a.basis, dry_run=a.probelauf)
    print(sync.report(result, a.probelauf), end="")
    return 2 if result.conflicts else 0


def cmd_check_kit(root: Path) -> int:
    findings = kitcheck.run(root)
    out = kitcheck.format_findings(findings)
    (sys.stderr if findings.problems else sys.stdout).write(out)
    return 1 if findings.problems else 0


def modules_table(root: Path) -> str:
    manifest = read_manifest(root)
    config = cfg.read_config(root)
    lock = read_lock(root)
    files = working_files(root)
    rows = [("Modul", "Titel", "Zustand", "braucht", "Pfade")]
    for m in manifest.modules.values():
        if m.name in lock["removedModules"] or not remove.module_present(root, manifest, m.name, files, config):
            state = "entfernt"
        else:
            state = "an" if (config.get("modules") or {}).get(m.name) is True else "aus"
        rows.append((m.name, m.title, state, ", ".join(m.needs) or "-", ", ".join(m.paths)))
    widths = [max(len(r[i]) for r in rows) for i in range(4)]
    lines = ["  ".join(r[i].ljust(widths[i]) for i in range(4)) + "  " + r[4] for r in rows]
    lines.insert(1, "  ".join("-" * w for w in widths) + "  " + "-" * 5)
    lines.append("")
    lines.append("an/aus: Schalter in starter.json (aus = nicht gebaut, Dateien bleiben); entfernen mit "
                 "bin/starter remove <modul>. Regeln: " + "; ".join(
                     f"mindestens eines von {', '.join(g)} bleibt an" for g in manifest.at_least_one)
                 + "; " + "; ".join(f"{m.name} braucht {', '.join(m.needs)}" for m in manifest.modules.values()
                                    if m.needs) + ".")
    return "\n".join(lines) + "\n"


def cmd_doctor(root: Path) -> int:
    code = 0
    if (root / "scripts" / "doctor.sh").exists():
        code = subprocess.run(["make", "doctor"], cwd=str(root), env=build_env()).returncode
    lock = read_lock(root)
    config = cfg.read_config(root)
    commit = config.get("commit") or {}
    state = repo_state(root, read_manifest(root), lock)
    if state == "project":
        print(f"starter: Projekt {lock['project']}, Starter {lock['version']}"
              f"{', Commit ' + lock['commit'][:12] if lock.get('commit') else ''}, "
              f"zuletzt abgeglichen {lock.get('lastSyncedOn') or 'nie'}")
    elif state == "needs-init":
        print(f"starter: {NEEDS_INIT}")
        return 1
    elif state == "starter":
        print(f"starter: das ist der Starter selbst (Version {lock['version']}); bin/starter init in einer Kopie")
    else:
        print(f"starter: Starter {lock['version']} ohne Projekt und ohne origin: der Starter selbst oder eine "
              "Kopie, die bin/starter init noch braucht")
    if commit.get("name") and commit.get("email"):
        print(f"starter: Commit-Identität {commit['name']} <{commit['email']}>")
    else:
        print("starter: Commit-Identität fehlt: commit.name und commit.email in starter.json eintragen "
              "(der Hook commit-msg lehnt sonst jeden Commit ab)")
        code = code or 1
    if lock.get("removedModules"):
        print(f"starter: entfernte Module: {', '.join(lock['removedModules'])}")
    if lock.get(PENDING):
        print(f"starter: nach „{lock[PENDING]}“ ist make build noch nicht grün gelaufen (rot oder ohne Swift-Compiler "
              f"übersprungen); auf einem Mac {lock[PENDING]} erneut aufrufen")
        code = code or 1
    return code


def main(argv: Optional[List[str]] = None) -> int:
    # Line by line, also into a pipe (CI, the probe): report lines, make's output and errors stay in order.
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except AttributeError:
        pass
    parser = build_parser()
    args = parser.parse_args(argv)
    if not args.command:
        parser.print_help()
        return 2
    try:
        root = repo_root()
        if args.command == "init":
            return cmd_init(root, args)
        if args.command == "remove":
            return cmd_remove(root, args.modul, args.probelauf, not args.ohne_build)
        if args.command == "strip-examples":
            return cmd_remove(root, "examples", args.probelauf, not args.ohne_build)
        if args.command == "sync":
            return cmd_sync(root, args)
        if args.command == "check-kit":
            return cmd_check_kit(root)
        if args.command == "modules":
            print(modules_table(root), end="")
            return 0
        if args.command == "doctor":
            return cmd_doctor(root)
    except StarterError as e:
        sys.stderr.write(f"bin/starter {args.command}: {e}\n")
        return 1
    except KeyboardInterrupt:
        sys.stderr.write("\nabgebrochen\n")
        return 130
    return 2
