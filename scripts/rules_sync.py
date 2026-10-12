#!/usr/bin/env python3
"""Validates rules/ and writes everything derived from it.

Writes part A of CLAUDE.md (between <!-- regeln:anfang --> and <!-- regeln:ende -->), the project rules block
of part B (from rules/projekt/), rules/generated/begriffe.json (every active term, compiled, for check_texts.py,
check_design.py, the commit-msg hook and AI texts) and rules/generated/ki-schreibregeln.json (writing rules for
prompts). Every file is checked against rules/schema, every pattern is compiled with Python re, and every example
of a term runs against its own pattern and the pack's allowed phrases, so a broken pattern fails here instead of
silently passing the checks.

Usage: scripts/rules_sync.py [--pruefen]
  --pruefen (or --check) writes nothing and fails when a derived file differs from rules/.

Python 3.9 standard library only.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Callable, Dict, List, Optional, Tuple

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rules_lib  # noqa: E402

ROOT = rules_lib.ROOT
START_MARKER = "<!-- regeln:anfang -->"
END_MARKER = "<!-- regeln:ende -->"
PROJECT_START_MARKER = "<!-- projektregeln:anfang -->"
PROJECT_END_MARKER = "<!-- projektregeln:ende -->"
GENERATED_TERMS = "rules/generated/begriffe.json"
GENERATED_AI = "rules/generated/ki-schreibregeln.json"
GENERATED_NOTE = "Erzeugt mit make rules (scripts/rules_sync.py) aus rules/ und starter.json. Nicht von Hand ändern."
KIT_GROUPS = ("schreiben", "design", "technik", "arbeitsweise")
CHECKERS = ("check_texts", "check_design")
ANREDEN = ("du", "sie")
LANG_NAMES = {"de": "de", "en": "en"}

Report = Callable[[str, str], None]


# Schema ---------------------------------------------------------------------------------------------

def validate(value, schema: dict, root: dict, where: str, report: Report) -> None:
    """A small subset of JSON Schema: $ref, type, enum, required, properties, additionalProperties, items,
    minItems, minLength, pattern. Enough for rules/schema and dependency free."""
    if "$ref" in schema:
        name = schema["$ref"].split("/")[-1]
        schema = root["$defs"][name]
    if "enum" in schema and value not in schema["enum"]:
        report(where, f"Wert {json.dumps(value, ensure_ascii=False)} nicht erlaubt (erlaubt: {', '.join(map(str, schema['enum']))})")
        return
    kind = schema.get("type")
    checks = {"object": lambda v: isinstance(v, dict), "array": lambda v: isinstance(v, list),
              "string": lambda v: isinstance(v, str), "boolean": lambda v: isinstance(v, bool)}
    if kind and not checks[kind](value):
        report(where, f"muss vom Typ {kind} sein")
        return
    if isinstance(value, dict):
        for key in schema.get("required", []):
            if key not in value:
                report(where, f"Feld {key} fehlt")
        props = schema.get("properties", {})
        for key, item in value.items():
            if key in props:
                validate(item, props[key], root, f"{where}.{key}", report)
            elif schema.get("additionalProperties") is False:
                report(where, f"unbekanntes Feld {key}")
    if isinstance(value, list):
        if len(value) < schema.get("minItems", 0):
            report(where, f"braucht mindestens {schema['minItems']} Einträge")
        if "items" in schema:
            for index, item in enumerate(value):
                validate(item, schema["items"], root, f"{where}[{index}]", report)
    if isinstance(value, str):
        if len(value) < schema.get("minLength", 0):
            report(where, "darf nicht leer sein")
        if "pattern" in schema and not re.search(schema["pattern"], value):
            report(where, f"„{value}“ passt nicht zum Muster {schema['pattern']}")


# Loading --------------------------------------------------------------------------------------------

class Rules:
    def __init__(self, root: Path):
        self.root = root
        self.errors: List[str] = []
        self.index: dict = {}
        self.kit_groups: List[Tuple[str, dict]] = []
        self.project_group: Optional[Tuple[str, dict]] = None
        self.kit_packs: List[Tuple[str, dict]] = []
        self.project_packs: List[Tuple[str, dict]] = []
        self.config = {"anrede": "du", "zusatzpakete": [], "personen": []}

    def report(self, where: str, message: str) -> None:
        self.errors.append(f"{where}: {message}")

    def read_json(self, relative: str, required: bool = True) -> Optional[dict]:
        path = self.root / relative
        if not path.exists():
            if required:
                self.report(relative, "fehlt")
            return None
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (ValueError, OSError) as error:
            self.report(relative, f"nicht lesbar ({error})")
            return None
        if not isinstance(data, dict):
            self.report(relative, "kein JSON-Objekt")
            return None
        return data

    @property
    def groups(self) -> List[Tuple[str, dict]]:
        return self.kit_groups + ([self.project_group] if self.project_group else [])

    @property
    def packs(self) -> List[Tuple[str, dict]]:
        return self.kit_packs + self.project_packs

    def load(self) -> None:
        index = self.read_json("rules/index.json")
        if index is None:
            return
        self.index = index
        group_schema = self.read_json("rules/schema/gruppe.schema.json") or {}
        pack_schema = self.read_json("rules/schema/paket.schema.json") or {}
        for relative in index.get("gruppen", []):
            data = self.read_json(f"rules/{relative}")
            if data is not None:
                validate(data, group_schema, group_schema, f"rules/{relative}", self.report)
                self.kit_groups.append((f"rules/{relative}", data))
        for relative in index.get("pakete", []):
            data = self.read_json(f"rules/{relative}")
            if data is not None:
                validate(data, pack_schema, pack_schema, f"rules/{relative}", self.report)
                self.kit_packs.append((f"rules/{relative}", data))
        project = index.get("projekt", {})
        group_file = f"rules/{project.get('gruppe', 'projekt/projekt.json')}"
        data = self.read_json(group_file, required=False)
        if data is not None:
            validate(data, group_schema, group_schema, group_file, self.report)
            self.project_group = (group_file, data)
        folder = self.root / "rules" / project.get("pakete", "projekt/pakete")
        if folder.is_dir():
            for path in sorted(folder.glob("*.json")):
                relative = str(path.relative_to(self.root))
                data = self.read_json(relative)
                if data is not None:
                    validate(data, pack_schema, pack_schema, relative, self.report)
                    self.project_packs.append((relative, data))
        self.read_config()

    def read_config(self) -> None:
        data = self.read_json("starter.json")
        texts = (data or {}).get("texts", {})
        if not isinstance(texts, dict):
            self.report("starter.json", "texts muss ein Objekt sein")
            return
        anrede = texts.get("anrede", "du")
        if anrede not in ANREDEN:
            self.report("starter.json", f"texts.anrede muss du oder sie sein, ist {json.dumps(anrede)}")
        else:
            self.config["anrede"] = anrede
        for key in ("zusatzpakete", "personen"):
            value = texts.get(key, [])
            if not isinstance(value, list) or not all(isinstance(v, str) for v in value):
                self.report("starter.json", f"texts.{key} muss eine Liste von Texten sein")
            else:
                self.config[key] = value


# Checks ---------------------------------------------------------------------------------------------

def _apostrophe_ok(pattern: str) -> bool:
    """Every ASCII apostrophe stands in a character class that also holds the typographic one (’)."""
    index = 0
    while index < len(pattern):
        char = pattern[index]
        if char == "\\":
            index += 2
            continue
        if char == "[":
            end = index + 1
            if end < len(pattern) and pattern[end] == "^":
                end += 1
            if end < len(pattern) and pattern[end] == "]":
                end += 1
            while end < len(pattern) and pattern[end] != "]":
                end += 2 if pattern[end] == "\\" else 1
            body = pattern[index + 1:end]
            if "'" in body and "’" not in body:
                return False
            index = end + 1
            continue
        if char == "'":
            return False
        index += 1
    return True


def _term_entry(pack: dict, term: dict, rules_by_pack: Dict[str, List[str]], people: List[str]) -> dict:
    extra = []
    if pack.get("personenAusKonfiguration") and term["art"] == "regex" and people:
        extra = [rules_lib.WORD_START + "(?:" + "|".join(re.escape(p) for p in people) + ")" + rules_lib.WORD_END]
    source = rules_lib.compile_source(term["art"], term["muster"], extra)
    entry = {
        "id": term["id"],
        "paket": pack["id"],
        "regeln": term.get("regeln") or rules_by_pack.get(pack["id"], []),
        "pruefer": pack.get("pruefer", "check_texts"),
        "label": term["label"],
        "hinweis": term["hinweis"],
        "art": term["art"],
    }
    if source is not None:
        entry["quelle"] = source
        entry["flags"] = term.get("flags", "")
    else:
        entry["verfahren"] = term["muster"][0]
    entry["bereiche"] = term["bereiche"]
    entry["sprachen"] = pack.get("sprachen", [])
    entry["erlaubt"] = pack.get("erlaubt", [])
    excluded = list(pack.get("ausgenommenePfade", [])) + list(term.get("ausgenommenePfade", []))
    if excluded:
        entry["ausgenommenePfade"] = excluded
    if pack.get("ausnahmeKommentar"):
        entry["ausnahmeKommentar"] = pack["ausnahmeKommentar"]
    return entry


def check_pack(file: str, pack: dict, seen_terms: Dict[str, str], report: Report) -> None:
    expected = Path(file).stem
    if pack.get("id") != expected:
        report(file, f"id „{pack.get('id')}“ passt nicht zum Dateinamen „{expected}“")
    if pack.get("abschaltbar") is False and pack.get("standardAktiv") is False:
        report(file, "ein Paket, das nicht abschaltbar ist, muss standardmäßig aktiv sein")
    checker = pack.get("pruefer", "check_texts")
    if checker == "check_texts" and not pack.get("sprachen"):
        report(file, "sprachen fehlt (Pflicht für Pakete von check_texts)")
    if checker == "check_design" and not pack.get("ausnahmeKommentar"):
        report(file, "ausnahmeKommentar fehlt (Pflicht für Pakete von check_design)")
    allowed = [e for e in pack.get("erlaubt", []) if not e.get("pfade")]
    for term in pack.get("begriffe", []):
        where = f"{file} ({term.get('id')})"
        if term.get("id") in seen_terms:
            report(where, f"id doppelt, schon in {seen_terms[term['id']]}")
        seen_terms[term.get("id")] = file
        areas = set(term.get("bereiche", []))
        if checker == "check_design" and areas != {"swift"}:
            report(where, "Begriffe von check_design gelten nur im Bereich swift")
        if checker == "check_texts" and "swift" in areas:
            report(where, "der Bereich swift gehört zu Paketen von check_design")
        if term.get("art") == "verfahren":
            if term.get("muster", [""])[0] not in rules_lib.PROCEDURES:
                report(where, f"unbekanntes Verfahren (bekannt: {', '.join(rules_lib.PROCEDURES)})")
        for pattern in term.get("muster", []):
            if not _apostrophe_ok(pattern):
                report(where, f"Apostroph im Muster als ['’] schreiben, sonst rutscht die typografische Form durch: {pattern}")
        source = rules_lib.compile_source(term.get("art", ""), term.get("muster", []))
        if source is not None:
            try:
                re.compile(source, rules_lib.regex_flags(term.get("flags", "")))
            except (re.error, KeyError) as error:
                report(where, f"Muster kompiliert nicht ({error})")
                continue
        probe = rules_lib.Term.from_json(dict(_term_entry(pack, term, {}, []), erlaubt=allowed))
        examples = term.get("beispiele", {})
        if not examples.get("treffer"):
            report(where, "mindestens ein Beispiel für einen Treffer nötig")
        for example in examples.get("treffer", []):
            if not rules_lib.matches(probe, example):
                report(where, f"Beispiel wird nicht erkannt: {json.dumps(example, ensure_ascii=False)}")
        for example in examples.get("erlaubt", []):
            spans = rules_lib.matches(probe, example)
            if spans:
                hits = ", ".join(json.dumps(example[a:b], ensure_ascii=False) for a, b in spans)
                report(where, f"erlaubtes Beispiel wird gemeldet: {json.dumps(example, ensure_ascii=False)} ({hits})")


def check_group(file: str, group: dict, pack_ids: set, seen_rules: set, report: Report) -> None:
    prefix = group.get("praefix", "")
    if group.get("id") != "projekt" and not group.get("regeln"):
        report(file, "regeln ist leer")
    keys = set()
    for rule in group.get("regeln", []):
        where = f"{file} ({rule.get('id')})"
        if not re.match(rf"^{re.escape(prefix)}-\d{{2}}$", rule.get("id", "")):
            report(where, f"id muss {prefix}-NN lauten")
        if rule.get("id") in seen_rules:
            report(where, "id doppelt")
        seen_rules.add(rule.get("id"))
        if rule.get("schluessel") in keys:
            report(where, f"schluessel „{rule.get('schluessel')}“ doppelt")
        keys.add(rule.get("schluessel"))
        if "\n" in rule.get("text", ""):
            report(where, "text ohne Zeilenumbruch schreiben")
        for name in rule.get("pakete", []):
            if name not in pack_ids:
                report(where, f"unbekanntes Paket „{name}“")


# Rendering ------------------------------------------------------------------------------------------

def pack_table(packs: List[dict]) -> List[str]:
    lines = ["| Paket | Gruppe | Prüfung | Sprachen | Stand | Begriffe |", "|---|---|---|---|---|---|"]
    for pack in packs:
        state = ("an, abschaltbar" if pack["abschaltbar"] else "an, Pflicht") if pack["standardAktiv"] else "aus, einschaltbar"
        checker = pack.get("pruefer", "check_texts")
        langs = ", ".join(pack.get("sprachen", [])) or "Swift-Code"
        lines.append(f"| `{pack['id']}` | {pack['gruppe']} | `{checker}` | {langs} | {state} | {len(pack['begriffe'])} |")
    return lines


def render_part_a(index: dict, groups: List[dict], packs: List[dict], config: dict) -> str:
    lines = [START_MARKER, "## Teil A: Allgemeine Regeln", "",
             "Erzeugt mit `make rules` aus `rules/`. Änderungen nur dort, nie in diesem Abschnitt.", ""]
    for paragraph in index.get("praeambel", []):
        lines += [paragraph, ""]
    lines += ["### Rangfolge bei Widerspruch", ""]
    for number, entry in enumerate(index.get("rangfolge", []), 1):
        lines.append(f"{number}. `{entry['pfad']}`: {entry['was']}")
    lines.append("")
    for group in groups:
        lines += [f"### {group['titel']}", "", group["geltung"], ""]
        for rule in group["regeln"]:
            if not rule.get("aufgehoben"):
                lines.append(f"- **{rule['id']}** {rule['text']}")
        lines.append("")
    extra = ", ".join(f"`{p}`" for p in config["zusatzpakete"]) or "keine"
    lines += ["### Sprachpakete", "",
              "Die Prüfungen (`make check-texts`, `make check-design`, Hook `commit-msg`) und die Schreibregeln für KI-Texte lesen "
              f"dieselben Pakete aus `rules/pakete/`. Anrede laut `starter.json`: `{config['anrede']}`. Zusätzlich eingeschaltet: {extra}.", ""]
    lines += pack_table(packs)
    tools = index.get("werkzeuge", [])
    if tools:
        lines += ["", "### Werkzeuge der Regeln", "",
                  "Wo die Werkzeuge und Bausteine liegen, die die Regeln nennen. `make check-rules` prüft, dass jeder Pfad existiert.", "",
                  "| Werkzeug | Regeln | Pfad |", "|---|---|---|"]
        for tool in tools:
            lines.append(f"| {tool['name']} | {', '.join(tool['regeln'])} | `{tool['pfad']}` |")
    lines += ["", END_MARKER]
    return "\n".join(lines)


def render_project(group: Optional[dict], packs: List[dict]) -> str:
    lines = [PROJECT_START_MARKER, "### Projektregeln", "",
             "Erzeugt mit `make rules` aus `rules/projekt/`. Änderungen nur dort, nie in diesem Abschnitt.", ""]
    rules = [r for r in (group or {}).get("regeln", []) if not r.get("aufgehoben")]
    if group:
        lines += [group["geltung"], ""]
    if not rules:
        lines += ["Keine Projektregeln festgelegt.", ""]
    for rule in rules:
        lines.append(f"- **{rule['id']}** {rule['text']}")
    if rules:
        lines.append("")
    if packs:
        lines += ["Sprachpakete des Projekts aus `rules/projekt/pakete/`:", ""] + pack_table(packs)
    else:
        lines.append("Keine Sprachpakete des Projekts.")
    lines += ["", PROJECT_END_MARKER]
    return "\n".join(lines)


def json_text(value) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2) + "\n"


# Sync -----------------------------------------------------------------------------------------------

def sync(root: Path = ROOT) -> Tuple[List[str], List[Tuple[str, str, Optional[str]]], str]:
    """(errors, [(file, expected, current)], summary)."""
    rules = Rules(root)
    rules.load()
    if not rules.index or rules.errors:
        # Structure first: the checks below rely on every required field being there.
        return rules.errors, [], ""
    report = rules.report
    for file, group in rules.kit_groups:
        if group.get("id") not in KIT_GROUPS:
            report(file, f"„{group.get('id')}“ ist keine Gruppe von Teil A")
    if rules.project_group and rules.project_group[1].get("id") != "projekt":
        report(rules.project_group[0], "id muss „projekt“ lauten")

    seen_terms: Dict[str, str] = {}
    for file, pack in rules.packs:
        check_pack(file, pack, seen_terms, report)
    pack_ids = {pack.get("id") for _, pack in rules.packs}
    seen_rules: set = set()
    for file, group in rules.groups:
        check_group(file, group, pack_ids, seen_rules, report)
    for file, pack in rules.packs:
        for term in pack.get("begriffe", []):
            for rule_id in term.get("regeln", []):
                if rule_id not in seen_rules:
                    report(f"{file} ({term.get('id')})", f"regeln nennt unbekannte Regel „{rule_id}“")
    referenced = {name for _, g in rules.groups for r in g.get("regeln", []) if not r.get("aufgehoben") for name in r.get("pakete", [])}
    for file, pack in rules.packs:
        named_by_terms = pack.get("begriffe") and all(t.get("regeln") for t in pack["begriffe"])
        if pack.get("id") not in referenced and not named_by_terms:
            report(file, "Paket wird von keiner Regel genannt")
    by_id = {pack.get("id"): pack for _, pack in rules.packs}
    for name in rules.config["zusatzpakete"]:
        if name not in by_id:
            report("starter.json", f"texts.zusatzpakete nennt unbekanntes Paket „{name}“")
        elif by_id[name].get("standardAktiv"):
            report("starter.json", f"Paket „{name}“ ist ohnehin aktiv")
    for name in rules.config["personen"]:
        if not re.match(r"^[^\W\d_][^\W\d_'’-]*(?:[-'’][^\W\d_]+)*$", name):
            report("starter.json", f"texts.personen: „{name}“ ist kein einzelnes Wort")
    for tool in rules.index.get("werkzeuge", []):
        where = f"rules/index.json (werkzeuge: {tool.get('name') or 'ohne Namen'})"
        if not tool.get("regeln") or any(r not in seen_rules for r in tool.get("regeln", [])):
            report(where, "regeln fehlt oder nennt eine unbekannte Regel")
        if not tool.get("pfad"):
            report(where, "pfad fehlt")
        elif not (root / tool["pfad"]).exists():
            report(where, f"{tool['pfad']} fehlt")
    code = rules.read_json(f"rules/{rules.index.get('code', 'code.json')}")
    if code is not None:
        ui = code.get("uiTexte", {})
        for key in ("aufrufe", "modifikatoren", "textLabels", "zuweisungen"):
            if not isinstance(ui.get(key), list) or not all(isinstance(v, str) and v for v in ui[key]):
                report("rules/code.json", f"uiTexte.{key} muss eine Liste von Namen sein")
        for key in ("verbatimKommentar", "ausnahmeKommentar", "textDateien"):
            if not isinstance(ui.get(key), str) or not ui[key]:
                report("rules/code.json", f"uiTexte.{key} fehlt")

    claude_path = root / "CLAUDE.md"
    claude = claude_path.read_text(encoding="utf-8") if claude_path.exists() else None
    if claude is None:
        report("CLAUDE.md", "fehlt")
        return rules.errors, [], ""
    start, end = claude.find(START_MARKER), claude.find(END_MARKER)
    p_start, p_end = claude.find(PROJECT_START_MARKER), claude.find(PROJECT_END_MARKER)
    if start == -1 or end == -1 or end < start:
        report("CLAUDE.md", f"Markierungen {START_MARKER} und {END_MARKER} fehlen")
    elif p_start < end or p_end < p_start:
        report("CLAUDE.md", f"Markierungen {PROJECT_START_MARKER} und {PROJECT_END_MARKER} fehlen oder stehen vor Teil A")
    if rules.errors:
        return rules.errors, [], ""

    kit_groups = [g for _, g in rules.kit_groups]
    all_groups = [g for _, g in rules.groups]
    rules_by_pack: Dict[str, List[str]] = {}
    for group in all_groups:
        for rule in group["regeln"]:
            if not rule.get("aufgehoben"):
                for name in rule.get("pakete", []):
                    rules_by_pack.setdefault(name, []).append(rule["id"])
    anrede = rules.config["anrede"]
    terms = []
    for _, pack in rules.packs:
        if not (pack["standardAktiv"] or pack["id"] in rules.config["zusatzpakete"]):
            continue
        for term in pack["begriffe"]:
            if term.get("beiAnrede") and term["beiAnrede"] != anrede:
                continue
            terms.append(_term_entry(pack, term, rules_by_pack, rules.config["personen"]))
    part_a = render_part_a(rules.index, kit_groups, [p for _, p in rules.kit_packs], rules.config)
    project = render_project(rules.project_group[1] if rules.project_group else None, [p for _, p in rules.project_packs])
    expected_claude = claude[:start] + part_a + claude[end + len(END_MARKER):p_start] + project + claude[p_end + len(PROJECT_END_MARKER):]
    terms_doc = {"hinweis": GENERATED_NOTE, "anrede": anrede, "zusatzpakete": rules.config["zusatzpakete"],
                 "personen": rules.config["personen"], "begriffe": terms}
    ai_doc = {"hinweis": GENERATED_NOTE, "anrede": anrede,
              "regeln": [{"id": r["id"], "text": r["text"]} for g in all_groups for r in g["regeln"] if r.get("ki") and not r.get("aufgehoben")]}

    def current(relative: str) -> Optional[str]:
        path = root / relative
        return path.read_text(encoding="utf-8") if path.exists() else None

    outputs = [("CLAUDE.md", expected_claude, claude),
               (GENERATED_TERMS, json_text(terms_doc), current(GENERATED_TERMS)),
               (GENERATED_AI, json_text(ai_doc), current(GENERATED_AI))]
    rule_count = sum(len(g["regeln"]) for g in all_groups)
    term_count = sum(len(p["begriffe"]) for _, p in rules.packs)
    summary = (f"{len(all_groups)} Gruppen mit {rule_count} Regeln, {len(rules.packs)} Sprachpakete mit {term_count} Begriffen, "
               f"davon {len(terms)} aktiv, Anrede {anrede}")
    return rules.errors, outputs, summary


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="rules/ prüfen und CLAUDE.md Teil A, rules/generated/*.json schreiben.")
    parser.add_argument("--pruefen", "--check", action="store_true", dest="check",
                        help="nichts schreiben, Fehler bei Abweichung (make check, Hook pre-push, CI)")
    parser.add_argument("--wurzel", default=str(ROOT), help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    root = Path(args.wurzel)
    errors, outputs, summary = sync(root)
    if errors:
        print(f"rules_sync: {len(errors)} Fehler\n  " + "\n  ".join(errors), file=sys.stderr)
        return 1
    stale = [(file, expected) for file, expected, current in outputs if expected != current]
    if args.check:
        if stale:
            print(f"rules_sync: weicht von rules/ ab: {', '.join(f for f, _ in stale)}. Ausführen: make rules", file=sys.stderr)
            return 1
        print(f"rules_sync: gültig, abgeleitete Dateien stimmen überein ({summary}).")
        return 0
    for file, expected in stale:
        path = root / file
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(expected, encoding="utf-8")
    written = "unverändert" if not stale else "geschrieben: " + ", ".join(f for f, _ in stale)
    print(f"rules_sync: {written} ({summary}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
