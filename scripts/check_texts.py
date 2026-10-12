#!/usr/bin/env python3
"""Language check of every text people read (rules S-01 to S-14, D-04, D-10 in CLAUDE.md).

Reads the compiled terms from rules/generated/begriffe.json and the scope from rules/index.json and
rules/code.json, then checks:

  ui         both literals of every tr(en: "…", de: "…") in App/Sources: English with the English packs, German
             with the German packs; both non-empty, the same interpolations (`x.en` and `x.de` count as one), the
             same trailing ellipsis (German with a space before it, English without); tr literals only in *Text.swift
             files; the values of App/Resources/InfoPlist.json the same way
  literals   UI text written as a literal in a view (Text("…"), Button("…"), .help("…"), NSMenuItem(title: "…"),
             title: { "…" } of the Registry types …, list in rules/code.json); Text(verbatim: "…") only with a
             // verbatim: reason comment
  kommentar  comments in Swift and Python files (English), code in backticks left out
  doku       every Markdown file outside the exceptions (German), without code, inline code, HTML comments and
             link targets

A comment // text-ausnahme: reason (Python: # text-ausnahme: reason) on the line of a call or up to three lines above
it exempts that one call or comment. // umbruch: reason above a tr exempts only its deliberate line breaks. Known
findings live in rules/baseline/texte.json, which may only shrink; a fixed entry fails only with --ci.

Usage: scripts/check_texts.py [--streng] [--ci] [--baseline-aktualisieren] [--json <datei>] [pfad …]
Python 3.9 standard library only.
"""
from __future__ import annotations

import argparse
import fnmatch
import io
import json
import re
import sys
import tokenize
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rules_lib  # noqa: E402
import swift_source  # noqa: E402
from rules_lib import Finding, Term  # noqa: E402

ROOT = rules_lib.ROOT
BASELINE = "rules/baseline/texte.json"
SPACES_BEFORE_ELLIPSIS = (" ", chr(0x00A0), chr(0x202F))  # space, no-break space, narrow no-break space
ELLIPSIS = chr(0x2026)
EXCEPTION_REACH = 3
HARD_BREAK = "harter-umbruch"


def own(term_id: str, label: str, rules: List[str], hint: str):
    return term_id, label, rules, hint


T_EMPTY = own("leerer-text", "Text in einer Sprache leer", ["S-10"], "beide Sprachen ausformulieren")
T_ONE_LITERAL = own("tr-ohne-literal", "Nur eine Sprache als Literal", ["S-10"], "beide Texte als Literal in die *Text.swift-Datei schreiben")
T_CONCAT = own("tr-zusammengesetzt", "Zusammengesetzter Text in tr(en:de:)", ["S-10"],
               "einen ganzen Satz je Sprache schreiben; Einsetzungen mit \\(…) in einer static func")
T_OUTSIDE = own("tr-ausserhalb", "tr(en:de:) außerhalb einer *Text.swift-Datei", ["S-10"],
                "Text in <Bereich>Text.swift als static var oder static func anlegen")
T_PLACEHOLDERS = own("einsetzungen", "Einsetzungen unterscheiden sich", ["S-10"], "beide Sprachen tragen dieselben \\(…)-Einsetzungen")
T_ELLIPSIS_PARITY = own("auslassung-paar", "Auslassungszeichen nur in einer Sprache", ["S-10", "S-11"],
                        "„…“ in beiden Sprachen oder in keiner")
T_ELLIPSIS_DE = own("auslassung-de", "Auslassungszeichen ohne Leerzeichen", ["S-11"], "im Deutschen mit Leerzeichen: „Einstellungen …“")
T_ELLIPSIS_EN = own("auslassung-en", "Auslassungszeichen mit Leerzeichen", ["S-11"], "im Englischen direkt angehängt: “Settings…”")
T_LITERAL = own("ui-literal", "UI-Text als Literal in der Ansicht", ["S-10"],
                "Text in <Bereich>Text.swift als tr(en:de:) anlegen und hier lesen")
T_VERBATIM = own("verbatim-ohne-grund", "Text(verbatim:) mit Literal ohne Grund", ["S-10"],
                 "Kommentar // verbatim: Grund in derselben Zeile oder darüber, sonst tr(en:de:)")
T_UNUSED = own("ausnahme-ungenutzt", "Ausnahme ohne Befund", ["S-10"], "den Kommentar entfernen")
T_NO_REASON = own("ausnahme-ohne-grund", "Ausnahme ohne Grund", ["S-10"], "den Grund nach dem Doppelpunkt nennen")
T_LEX = own("nicht-lesbar", "Datei nicht lesbar", ["S-10"], "Literal oder Kommentar schließen")


def make(path: str, line: int, column: int, kind, match: str, context: str = "") -> Finding:
    term_id, label, rules, hint = kind
    return Finding(path, line, column, term_id, label, rules, hint, match, context or " ".join(match.split()))


@dataclass
class Scope:
    swift: List[str]
    comments: List[str]
    docs: List[str]
    infoplist: str
    exceptions: List[dict]

    def areas_for(self, rel: str) -> Optional[Set[str]]:
        """None = every area; a set = only these areas; empty set = file not checked."""
        allowed: Optional[Set[str]] = None
        for entry in self.exceptions:
            if rules_lib.path_matches(rel, [entry["pfad"]]):
                only = set(entry.get("nurBereiche", []))
                allowed = only if allowed is None else allowed & only
        return allowed


def load_scope(root: Path) -> Tuple[Scope, dict]:
    index = rules_lib.read_json_file(root / "rules/index.json", "rules/index.json")
    code_file = f"rules/{index.get('code', 'code.json')}"
    code = rules_lib.read_json_file(root / code_file, code_file)
    scope = index["pruefumfang"]
    return Scope(scope["swift"], scope["kommentare"], scope["doku"], scope["infoplist"], scope.get("ausnahmen", [])), code["uiTexte"]


def walk(root: Path, roots: Sequence[str], suffixes: Tuple[str, ...]) -> List[str]:
    found: Set[str] = set()
    for entry in roots:
        path = root / entry
        if path.is_file() and path.name.endswith(suffixes):
            found.add(entry)
        elif path.is_dir():
            for child in path.rglob("*"):
                if child.is_file() and child.name.endswith(suffixes) and ".git" not in child.parts and "build" not in child.relative_to(root).parts[:1]:
                    found.add(str(child.relative_to(root)))
    return sorted(found)


# Swift ----------------------------------------------------------------------------------------------

@dataclass
class Exceptions:
    lines: Dict[int, Tuple[int, str]]  # code line -> (comment line, reason)
    comments: List[Tuple[int, str]]  # (comment line, reason)
    used: Set[int]
    claimed: Dict[int, int] = field(default_factory=dict)  # comment line -> first line of the call or comment it exempts

    @classmethod
    def collect(cls, src: swift_source.Source, keyword: str) -> "Exceptions":
        lines: Dict[int, Tuple[int, str]] = {}
        comments = []
        pattern = re.compile(r"^\s*/?\s*" + re.escape(keyword) + r":(.*)$")
        for comment in src.comments:
            match = pattern.match(comment.text)
            if not match:
                continue
            reason = match.group(1).strip()
            comments.append((comment.line, reason))
            if comment.own_line:
                for offset in range(1, EXCEPTION_REACH + 1):
                    lines.setdefault(comment.line + offset, (comment.line, reason))
            else:
                lines[comment.line] = (comment.line, reason)
        return cls(lines, comments, set())

    def covers(self, first: int, last: int) -> bool:
        """True when an exception comment reaches these lines. One comment exempts one call or comment: the first one
        that asks for it, so a second call within reach is still checked."""
        for line in range(first, last + 1):
            if line not in self.lines:
                continue
            comment = self.lines[line][0]
            if self.claimed.setdefault(comment, first) != first:
                continue
            self.used.add(comment)
            return True
        return False


def literal_findings(lit: swift_source.Literal, src: swift_source.Source, terms: Sequence[Term], lang: str, rel: str) -> List[Finding]:
    text = lit.text
    base_column = src.column_of(lit.start) + (3 if lit.multiline else 1)

    def line_of(offset: int) -> int:
        return lit.line + (1 if lit.multiline else 0) + text.count("\n", 0, offset)

    def column_of(offset: int) -> int:
        newline = text.rfind("\n", 0, offset)
        return base_column + offset if newline == -1 else offset - newline

    return rules_lib.find_findings(text, terms, "ui", lang, rel, line_of, column_of)


_CLOSURE_LITERAL = re.compile(r'\{\s*(?:return\s+)?"[^"]*"\s*\}')
_FORMAT_SPEC = re.compile(r"%(?:\d+\$)?[-+ 0#']*(?:\d+|\*)?(?:\.(?:\d+|\*))?(?:hh|h|ll|l|q|L|z|t|j)?[a-zA-Z@%]")


def closure_literal(src: swift_source.Source, arg: swift_source.Argument) -> Optional[swift_source.Literal]:
    """The literal of an argument that is a closure returning only that literal: `title: { "Home" }`."""
    masked = src.masked[arg.start:arg.end]
    if not _CLOSURE_LITERAL.fullmatch(masked.strip()):
        return None
    return src.literal_at.get(arg.start + masked.index('"'))


def has_words(text: str) -> bool:
    """A format string is UI text when a word of two letters is left after removing its specifiers ("%d files")."""
    return bool(re.search(r"[^\W\d_]{2}", _FORMAT_SPEC.sub(" ", text)))


def blank_code_spans(text: str) -> str:
    """Backtick code spans in a comment (paths, flags, identifiers) are not prose; offsets stay."""
    return re.sub(r"(`+)(?!`).*?(?<!`)\1(?!`)", lambda m: re.sub(r"[^\n]", " ", m.group(0)), text)


def top_level_literals(src: swift_source.Source, arg: swift_source.Argument) -> List[swift_source.Literal]:
    """Literals of an argument that are not inside a nested call or closure (array elements count), plus the literal
    of a closure that returns only a literal (`title: { "Home" }`, the contribution types of Registry)."""
    closure = closure_literal(src, arg)
    if closure is not None:
        return [closure]
    result = []
    for lit in arg.literals:
        depth = 0
        pos = arg.start
        while pos < lit.start:
            if pos in src.literal_at:
                pos = src.literal_at[pos].end
                continue
            char = src.masked[pos]
            if char in "({":
                depth += 1
            elif char in ")}":
                depth -= 1
            pos += 1
        if depth == 0:
            result.append(lit)
    return result


def parse_call_specs(names: Iterable[str]) -> Dict[str, Optional[Tuple[Set[int], Set[str]]]]:
    """'Text' -> None (first positional plus textLabels); 'StatusMark(#1)' -> ({1}, set()); 'TileOption(title)' -> (set(), {'title'})."""
    specs: Dict[str, Optional[Tuple[Set[int], Set[str]]]] = {}
    for entry in names:
        match = re.match(r"^(\w+)(?:\(([^)]*)\))?$", entry.strip())
        if not match:
            continue
        if match.group(2) is None:
            specs[match.group(1)] = None
            continue
        positions, labels = set(), set()
        for part in match.group(2).split(","):
            part = part.strip()
            if part.startswith("#"):
                positions.add(int(part[1:]))
            elif part:
                labels.add(part)
        specs[match.group(1)] = (positions, labels)
    return specs


def check_swift(rel: str, text: str, terms: Sequence[Term], ui: dict, areas: Optional[Set[str]]) -> List[Finding]:
    findings: List[Finding] = []
    try:
        src = swift_source.parse(rel, text)
    except swift_source.LexError as error:
        return [make(rel, 1, 1, T_LEX, str(error))]
    exceptions = Exceptions.collect(src, ui["ausnahmeKommentar"])
    verbatim = Exceptions.collect(src, ui["verbatimKommentar"])
    breaks = Exceptions.collect(src, ui["umbruchKommentar"])
    for line, reason in exceptions.comments + verbatim.comments + breaks.comments:
        if not reason:
            findings.append(make(rel, line, 1, T_NO_REASON, src.line_text(line).strip()))
    if areas is None or "kommentar" in areas:
        for comment in src.comments:
            comment_findings = rules_lib.find_findings(blank_code_spans(comment.text), terms, "kommentar", "en", rel,
                                                       lambda o, c=comment: c.line + comment_line_offset(c, o),
                                                       lambda o, c=comment: comment_column(src, c, o))
            last = comment.line + comment.text.count("\n")
            if comment_findings and exceptions.covers(comment.line, last):
                continue
            findings += comment_findings
    if areas is None or "ui" in areas:
        findings += check_ui_texts(rel, src, terms, ui, exceptions, verbatim, breaks)
    for table in (exceptions, verbatim, breaks):
        for line, reason in table.comments:
            if line not in table.used and reason:
                findings.append(make(rel, line, 1, T_UNUSED, src.line_text(line).strip()))
    findings.sort(key=lambda f: (f.line, f.column))
    return findings


def check_ui_texts(rel: str, src: swift_source.Source, terms: Sequence[Term], ui: dict, exceptions: Exceptions,
                   verbatim: Exceptions, breaks: Exceptions) -> List[Finding]:
    findings: List[Finding] = []
    is_text_file = fnmatch.fnmatch(Path(rel).name, ui["textDateien"])
    for _, at, open_paren in swift_source.find_calls(src, ["tr"]):
        args, close = swift_source.call_arguments(src, open_paren)
        if [a.label for a in args[:2]] != ["en", "de"] or len(args) != 2:
            continue
        first, last = src.line_of(at), src.line_of(close)
        call_findings = check_tr(rel, src, args, terms, is_text_file, at)
        if any(f.term_id == HARD_BREAK for f in call_findings) and breaks.covers(first, last):
            call_findings = [f for f in call_findings if f.term_id != HARD_BREAK]
        if call_findings and exceptions.covers(first, last):
            continue
        findings += call_findings

    specs = parse_call_specs(ui["aufrufe"])
    mods = parse_call_specs(ui["modifikatoren"])
    labels = set(ui["textLabels"])
    format_labels = set(ui.get("formatLabels", []))
    for table, member in ((specs, False), (mods, True)):
        for name, at, open_paren in swift_source.find_calls(src, list(table), member=member):
            args, close = swift_source.call_arguments(src, open_paren)
            call_findings = []
            positional = -1
            for arg in args:
                if arg.label is None:
                    positional += 1
                if name == "Text" and not member and arg.label == "verbatim":
                    hits = [lit for lit in top_level_literals(src, arg) if lit.has_text]
                    # A reason comment also documents verbatim data (a path, digits); it is used by any verbatim call.
                    covered = verbatim.covers(src.line_of(at), src.line_of(close))
                    if hits and not covered:
                        call_findings += [make(rel, lit.line, src.column_of(lit.start), T_VERBATIM, lit.text) for lit in hits]
                    continue
                spec = table[name]
                if spec is None:
                    wanted = (arg.label is None and positional == 0) or (arg.label in labels)
                else:
                    wanted = (arg.label is None and positional in spec[0]) or (arg.label in spec[1])
                if wanted:
                    for lit in top_level_literals(src, arg):
                        if lit.has_text and (arg.label not in format_labels or has_words(lit.text)):
                            call_findings.append(make(rel, lit.line, src.column_of(lit.start), T_LITERAL, lit.text))
            if call_findings and exceptions.covers(src.line_of(at), src.line_of(close)):
                continue
            findings += call_findings
    assign = re.compile(r"\.(%s)\s*=\s*\"" % "|".join(map(re.escape, ui["zuweisungen"])))
    for match in assign.finditer(src.masked):
        lit = src.literal_at.get(match.end() - 1)
        if lit and lit.has_text and not exceptions.covers(lit.line, lit.line):
            findings.append(make(rel, lit.line, src.column_of(lit.start), T_LITERAL, lit.text))
    return findings


def comment_line_offset(comment: swift_source.Comment, offset: int) -> int:
    return comment.text.count("\n", 0, offset)


def comment_column(src: swift_source.Source, comment: swift_source.Comment, offset: int) -> int:
    before = comment.text[:offset]
    newline = before.rfind("\n")
    if newline == -1:
        return src.column_of(comment.start) + 2 + offset
    return offset - newline


def same_insert(expression: str) -> str:
    """`phrase.en` and `phrase.de` are the same insert in its two languages."""
    return re.sub(r"\.(?:en|de)\b", ".<sprache>", expression)


def check_tr(rel: str, src: swift_source.Source, args: List[swift_source.Argument], terms: Sequence[Term],
             is_text_file: bool, at: int) -> List[Finding]:
    en, de = args
    line, column = src.line_of(at), src.column_of(at)
    findings: List[Finding] = []
    if en.literal is None or de.literal is None:
        loose = [lit for lit in en.literals + de.literals if lit.has_text]
        if loose and (en.literal is not None or de.literal is not None):
            findings.append(make(rel, line, column, T_ONE_LITERAL, src.text[at:at + 60].split("\n")[0]))
        elif loose:
            findings.append(make(rel, line, column, T_CONCAT, src.text[at:at + 60].split("\n")[0]))
        return findings
    if not is_text_file:
        findings.append(make(rel, line, column, T_OUTSIDE, en.literal.text))
    for arg, lang in ((en, "en"), (de, "de")):
        lit = arg.literal
        if not lit.text.strip():
            findings.append(make(rel, lit.line, src.column_of(lit.start), T_EMPTY, f"{lang}: \"\""))
            continue
        findings += literal_findings(lit, src, terms, lang, rel)
    a, b = en.literal, de.literal
    if sorted(map(same_insert, a.interpolations)) != sorted(map(same_insert, b.interpolations)):
        findings.append(make(rel, line, column, T_PLACEHOLDERS,
                             f"en: {', '.join(a.interpolations) or 'keine'}; de: {', '.join(b.interpolations) or 'keine'}"))
    en_text, de_text = a.text.rstrip(), b.text.rstrip()
    if en_text.endswith(ELLIPSIS) != de_text.endswith(ELLIPSIS):
        findings.append(make(rel, line, column, T_ELLIPSIS_PARITY, f"{en_text} / {de_text}"))
    if de_text.endswith(ELLIPSIS) and not de_text[:-1].endswith(SPACES_BEFORE_ELLIPSIS):
        findings.append(make(rel, b.line, src.column_of(b.start), T_ELLIPSIS_DE, de_text))
    if en_text.endswith(ELLIPSIS) and en_text[:-1].endswith(SPACES_BEFORE_ELLIPSIS):
        findings.append(make(rel, a.line, src.column_of(a.start), T_ELLIPSIS_EN, en_text))
    return findings


# Other sources --------------------------------------------------------------------------------------

def check_python_comments(rel: str, text: str, terms: Sequence[Term], keyword: str = "text-ausnahme") -> List[Finding]:
    """Comments of a Python file; `# text-ausnahme: reason` on its own line exempts the next three lines."""
    findings = []
    try:
        tokens = list(tokenize.generate_tokens(io.StringIO(text).readline))
    except (tokenize.TokenError, SyntaxError, IndentationError):
        return findings
    exception = re.compile(r"^#\s*" + re.escape(keyword) + r":(.*)$")
    covered: Dict[int, int] = {}
    used: Set[int] = set()
    comments = [t for t in tokens if t.type == tokenize.COMMENT and not (t.start[0] == 1 and t.string.startswith("#!"))]
    for token in comments:
        match = exception.match(token.string)
        if match is None:
            continue
        if not match.group(1).strip():
            findings.append(make(rel, token.start[0], token.start[1] + 1, T_NO_REASON, token.string))
            continue
        for offset in range(1, EXCEPTION_REACH + 1):
            covered.setdefault(token.start[0] + offset, token.start[0])
    for token in comments:
        hits = rules_lib.find_findings(blank_code_spans(token.string[1:]), terms, "kommentar", "en", rel,
                                       lambda o, t=token: t.start[0], lambda o, t=token: t.start[1] + 2 + o)
        if hits and token.start[0] in covered:
            used.add(covered[token.start[0]])
            continue
        findings += hits
    for token in comments:
        match = exception.match(token.string)
        if match and match.group(1).strip() and token.start[0] not in used:
            findings.append(make(rel, token.start[0], token.start[1] + 1, T_UNUSED, token.string))
    return findings


def check_markdown(rel: str, text: str, terms: Sequence[Term]) -> List[Finding]:
    return rules_lib.find_findings(rules_lib.blank_markdown(text), terms, "doku", "de", rel)


def check_infoplist(rel: str, text: str, terms: Sequence[Term]) -> List[Finding]:
    findings = []
    try:
        data = json.loads(text)
    except ValueError as error:
        return [make(rel, getattr(error, "lineno", 1), 1, T_LEX, f"kein gültiges JSON ({error})")]
    lines = text.split("\n")
    for key, value in data.items():
        if key.startswith("_") or not isinstance(value, dict):
            continue
        line = next((i + 1 for i, l in enumerate(lines) if f'"{key}"' in l), 1)
        for lang in ("en", "de"):
            entry = value.get(lang)
            entry_line = next((i + 1 for i in range(line - 1, len(lines)) if f'"{lang}"' in lines[i]), line)
            if not isinstance(entry, str) or not entry.strip():
                findings.append(make(rel, line, 1, T_EMPTY, f"{key} {lang}"))
                continue
            findings += rules_lib.find_findings(entry, terms, "ui", lang, rel, lambda o, l=entry_line: l, lambda o: o + 1)
    return findings


# Main -----------------------------------------------------------------------------------------------

def collect(root: Path, terms: Sequence[Term], only: Sequence[str] = ()) -> Tuple[List[Finding], int]:
    scope, ui = load_scope(root)
    terms = [t for t in terms if t.pruefer == "check_texts"]
    swift_files = set(walk(root, scope.swift, (".swift",)))
    comment_files = set(walk(root, scope.comments, (".swift", ".py")))
    doc_files = set(walk(root, scope.docs, (".md",)))
    plist = [scope.infoplist] if (root / scope.infoplist).is_file() else []
    candidates = []
    for rel in sorted(swift_files | comment_files | doc_files | set(plist)):
        areas = scope.areas_for(rel)
        if areas is not None and not areas:
            continue
        if rel in doc_files and areas is not None and "doku" not in areas:
            continue
        candidates.append(rel)
    findings: List[Finding] = []
    selected = rules_lib.select_paths(root, only, candidates)
    for rel in selected:
        areas = scope.areas_for(rel)
        text, error = rules_lib.read_text_file(root / rel)
        if text is None:
            findings.append(make(rel, 1, 1, T_LEX, error or ""))
            continue
        if rel in plist:
            findings += check_infoplist(rel, text, terms)
        elif rel.endswith(".md"):
            findings += check_markdown(rel, text, terms)
        elif rel.endswith(".swift"):
            if rel not in swift_files:
                areas = {"kommentar"} if areas is None else areas & {"kommentar"}
            if rel not in comment_files:
                areas = {"ui"} if areas is None else areas & {"ui"}
            findings += check_swift(rel, text, terms, ui, areas)
        elif areas is None or "kommentar" in areas:
            findings += check_python_comments(rel, text, terms, ui["ausnahmeKommentar"])
    findings.sort(key=lambda f: (f.path, f.line, f.column))
    return findings, len(selected)


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Sprachprüfung aller Texte, die Menschen lesen (S-01 bis S-14).")
    parser.add_argument("pfade", nargs="*", help="nur diese Dateien oder Ordner prüfen")
    parser.add_argument("--streng", action="store_true", help="Baseline nicht anwenden")
    parser.add_argument("--baseline-aktualisieren", action="store_true", help="Baseline aus den Befunden schreiben; sie darf nur schrumpfen")
    parser.add_argument("--json", help="Befunde zusätzlich als JSON in diese Datei schreiben")
    parser.add_argument("--ci", action="store_true", help="behobene Befunde, die noch in der Baseline stehen, sind ein Fehler")
    parser.add_argument("--wurzel", default=str(ROOT), help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    root = Path(args.wurzel)
    try:
        findings, files = collect(root, rules_lib.load_terms(root), args.pfade)
        return rules_lib.run_baseline("check_texts", findings, root / BASELINE, args, files, bool(args.pfade))
    except rules_lib.CheckError as error:
        print(f"check_texts: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
