#!/usr/bin/env python3
"""Swift code check against the packs of check_design (rules D-01 to D-09 and T-01 to T-06 in CLAUDE.md).

`gestaltung` finds values that bypass the design tokens outside App/Sources/Kit/Design: free colours and system
colours, literal font sizes, paddings, spacings, corner radii, springs and blur (0 and 1 stay allowed for
spacing, 0 for radii). `swift-technik` finds what the Xcode-free build cannot compile, forced try/as, network,
permission requests and login items outside their kit places, and module conditions bin/starter remove cannot
resolve. Comments and string literals are blanked first, so CSS in a string or a word in a comment never counts.

A comment `// design-ausnahme: reason` (or `// technik-ausnahme: reason` for the technik pack) on the same line or
on its own line directly above exempts that line; an exception without a finding or without a reason fails.
Known findings live in rules/baseline/design.json, which may only shrink.

Usage: scripts/check_design.py [--streng] [--baseline-aktualisieren] [--json <datei>] [pfad …]
Python 3.9 standard library only.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Set, Tuple

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rules_lib  # noqa: E402
import swift_source  # noqa: E402
from rules_lib import Finding, Term  # noqa: E402

ROOT = rules_lib.ROOT
BASELINE = "rules/baseline/design.json"


def _finding(rel: str, line: int, column: int, term_id: str, label: str, hint: str, match: str) -> Finding:
    return Finding(rel, line, column, term_id, label, ["D-01"], hint, match, " ".join(match.split()))


def exception_lines(src: swift_source.Source, keyword: str) -> Dict[int, Tuple[int, str]]:
    """code line -> (comment line, reason) for every `// <keyword>: reason` comment."""
    pattern = re.compile(r"^\s*/?\s*" + re.escape(keyword) + r":(.*)$")
    lines: Dict[int, Tuple[int, str]] = {}
    for comment in src.comments:
        match = pattern.match(comment.text)
        if match:
            target = comment.line + 1 if comment.own_line else comment.line
            lines[target] = (comment.line, match.group(1).strip())
    return lines


def check_file(rel: str, text: str, terms: Sequence[Term]) -> List[Finding]:
    try:
        src = swift_source.parse(rel, text)
    except swift_source.LexError as error:
        return [_finding(rel, 1, 1, "nicht-lesbar", "Datei nicht lesbar", "Literal oder Kommentar schließen", str(error))]
    findings: List[Finding] = []
    keywords = sorted({t.ausnahme_kommentar for t in terms if t.ausnahme_kommentar})
    exceptions = {keyword: exception_lines(src, keyword) for keyword in keywords}
    used: Set[Tuple[str, int]] = set()
    for term in terms:
        if not term.applies("swift", None, rel):
            continue
        for start, end in rules_lib.matches(term, src.masked, rel):
            line = src.line_of(start)
            exception = exceptions.get(term.ausnahme_kommentar or "", {}).get(line)
            if exception is not None and exception[1]:
                used.add((term.ausnahme_kommentar, exception[0]))
                continue
            findings.append(Finding(rel, line, src.column_of(start), term.id, term.label, term.regeln, term.hinweis,
                                    src.masked[start:end], src.line_text(line).strip()))
    for keyword, lines in exceptions.items():
        for target, (comment_line, reason) in lines.items():
            if not reason:
                findings.append(_finding(rel, comment_line, 1, "ausnahme-ohne-grund", "Ausnahme ohne Grund",
                                         "den Grund nach dem Doppelpunkt nennen", src.line_text(comment_line).strip()))
            elif (keyword, comment_line) not in used:
                findings.append(_finding(rel, comment_line, 1, "ausnahme-ungenutzt", "Ausnahme ohne Befund",
                                         "den Kommentar entfernen", src.line_text(comment_line).strip()))
    findings.sort(key=lambda f: (f.line, f.column))
    return findings


def collect(root: Path, terms: Sequence[Term], only: Sequence[str] = ()) -> Tuple[List[Finding], int]:
    index = json.loads((root / "rules/index.json").read_text(encoding="utf-8"))
    roots = index["pruefumfang"]["swift"]
    terms = [t for t in terms if t.pruefer == "check_design"]
    findings: List[Finding] = []
    files = 0
    for entry in roots:
        base = root / entry
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*.swift")):
            rel = str(path.relative_to(root))
            if only and not any(rel == p or rel.startswith(p.rstrip("/") + "/") for p in only):
                continue
            files += 1
            findings += check_file(rel, path.read_text(encoding="utf-8"), terms)
    return findings, files


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Gestaltung und Technik im Swift-Code (D-01 bis D-09, T-01 bis T-06).")
    parser.add_argument("pfade", nargs="*", help="nur diese Dateien oder Ordner prüfen")
    parser.add_argument("--streng", action="store_true", help="Baseline nicht anwenden")
    parser.add_argument("--baseline-aktualisieren", action="store_true", help="Baseline aus den Befunden schreiben; sie darf nur schrumpfen")
    parser.add_argument("--json", help="Befunde zusätzlich als JSON in diese Datei schreiben")
    parser.add_argument("--wurzel", default=str(ROOT), help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    root = Path(args.wurzel)
    findings, files = collect(root, rules_lib.load_terms(root), args.pfade)
    return rules_lib.run_baseline("check_design", findings, root / BASELINE, args, files, bool(args.pfade))


if __name__ == "__main__":
    sys.exit(main())
