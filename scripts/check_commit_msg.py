#!/usr/bin/env python3
"""commit-msg hook and CI check of commit messages (rules A-03, A-04 and S-01 to S-04 in CLAUDE.md).

- The subject is `type(scope): subject` (scope optional, lowercase), the whole first line at most 100 characters;
  Git's own merge and revert subjects and fixup!/squash!/amend! prefixes pass.
- Line 2 is empty. Lines starting with # and everything below the scissors line of `git commit -v` do not count.
- Subject and body pass the packs of area `commit` (characters, English filler words, placeholders), like every
  other text people read. The `!` of a breaking change belongs to the format, not to the text.
- The author is the identity from starter.json (`commit.name`, `commit.email`). After `bin/starter init` it is empty,
  and no commit passes until the project enters its own: the identity is asked for, never invented.

Usage: scripts/check_commit_msg.py <message file>             (hook: scripts/hooks/commit-msg)
       scripts/check_commit_msg.py --bereich origin/main..HEAD  (CI: author and format of every commit, no packs,
                                                                 so commits written before a pack changed stay green)
Python 3.9 standard library only.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Sequence

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rules_lib  # noqa: E402
from rules_lib import Term  # noqa: E402

ROOT = rules_lib.ROOT
TYPES = ("feat", "fix", "docs", "style", "refactor", "perf", "test", "build", "ci", "chore", "revert")
MAX_SUBJECT = 100
PREFIX = re.compile(r"^(?:(?:fixup|squash|amend)! )*(?:%s)(?:\([a-z0-9][a-z0-9./-]*\))?!?: " % "|".join(TYPES))
SUBJECT = re.compile(PREFIX.pattern + r"\S.*$")
GIT_OWN_SUBJECT = re.compile(r"^(?:Merge (?:branch|remote-tracking branch|pull request|commit|tag) |Revert \")")
SCISSORS = re.compile(r"^# -+ >8 -+$", re.M)
BOT = re.compile(r"\[bot\] <\d*\+?[^@>]*\[bot\]@users\.noreply\.github\.com>$")

MISSING_IDENTITY = (
    "starter.json nennt keine Commit-Identität. commit.name und commit.email des Projekts dort eintragen (beim "
    "Auftraggeber erfragen, nie erfinden), dann git config user.name und git config user.email gleich setzen. Bis "
    "dahin nimmt dieser Hook keinen Commit an (A-04)."
)


def read_identity(root: Path = ROOT) -> Dict[str, str]:
    try:
        commit = json.loads((root / "starter.json").read_text(encoding="utf-8")).get("commit", {})
    except (OSError, ValueError):
        commit = {}
    return {"name": str(commit.get("name", "") or ""), "email": str(commit.get("email", "") or "")}


def has_identity(expected: Dict[str, str]) -> bool:
    return bool(expected["name"].strip()) and bool(expected["email"].strip())


def check_author(ident: str, expected: Dict[str, str]) -> List[str]:
    if not has_identity(expected):
        return [MISSING_IDENTITY]
    author = re.match(r"^(.*) <([^>]*)>", ident)
    if author and author.group(1) == expected["name"] and author.group(2) == expected["email"]:
        return []
    found = f"{author.group(1)} <{author.group(2)}>" if author else ident
    return [f"Autor ist „{found}“, erwartet „{expected['name']} <{expected['email']}>“ aus starter.json. Setzen: "
            f"git config user.name \"{expected['name']}\" und git config user.email \"{expected['email']}\"."]


def message_lines(text: str) -> List[str]:
    scissors = SCISSORS.search(text)
    body = text if scissors is None else text[:scissors.start()]
    return [line for line in body.split("\n") if not line.startswith("#")]


def check_message(text: str, terms: Optional[Sequence[Term]]) -> List[str]:
    """Errors of a message; terms None checks format only."""
    lines = message_lines(text)
    while lines and lines[-1].strip() == "":
        lines.pop()
    subject = lines[0].strip() if lines else ""
    errors = []
    own = bool(GIT_OWN_SUBJECT.match(subject))
    if not own:
        if not SUBJECT.match(subject):
            errors.append(f"Betreff „{subject}“ hat nicht das Format type(scope): subject (Typen: {', '.join(TYPES)}; "
                          "scope klein geschrieben, optional).")
        if len(subject) > MAX_SUBJECT:
            errors.append(f"Betreff hat {len(subject)} Zeichen, höchstens {MAX_SUBJECT}.")
    if len(lines) > 1 and lines[1].strip() != "":
        errors.append("Zeile 2 muss leer sein: zwischen Betreff und Text eine Leerzeile einfügen.")
    if own or terms is None:
        return errors
    body = "\n".join([PREFIX.sub("", subject)] + lines[1:])
    for finding in rules_lib.find_findings(body, terms, "commit", "en", "COMMIT_EDITMSG"):
        rules = ", ".join(finding.rules)
        errors.append(f"Zeile {finding.line}: „{finding.match}“ ({finding.label}, {rules}). Stattdessen: {finding.hint}.")
    return errors


def commit_terms(root: Path = ROOT) -> List[Term]:
    return [t for t in rules_lib.load_terms(root) if t.pruefer == "check_texts" and "commit" in t.bereiche]


def check_range(spec: str, expected: Dict[str, str], cwd: Path = ROOT) -> List[str]:
    if not has_identity(expected):
        return [MISSING_IDENTITY]
    log = subprocess.run(["git", "log", "--no-merges", "--format=%H%x00%an <%ae>%x00%B%x1e", spec],
                         cwd=cwd, capture_output=True, text=True, check=True).stdout
    errors = []
    for entry in log.split("\x1e"):
        entry = entry.lstrip("\n")
        if not entry.strip():
            continue
        commit, ident, message = (entry.split("\x00") + ["", ""])[:3]
        if BOT.search(ident):
            continue
        errors += [f"{commit[:7]}: {e}" for e in check_author(ident, expected) + check_message(message, None)]
    return errors


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Commit-Nachricht und Autor prüfen (A-03, A-04).")
    parser.add_argument("datei", nargs="?", help="Datei mit der Nachricht (vom Hook commit-msg)")
    parser.add_argument("--bereich", help="alle Commits eines Bereichs prüfen, etwa origin/main..HEAD (CI)")
    args = parser.parse_args(argv)
    expected = read_identity()
    if args.bereich:
        errors = check_range(args.bereich, expected)
        if errors:
            print(f"commit-msg: {len(errors)} Befunde in {args.bereich}\n  " + "\n  ".join(errors), file=sys.stderr)
            return 1
        print(f"commit-msg: Autor und Format aller Commits in {args.bereich} passen.")
        return 0
    if not args.datei:
        parser.error("Datei mit der Nachricht oder --bereich angeben")
    ident = subprocess.run(["git", "var", "GIT_AUTHOR_IDENT"], capture_output=True, text=True, check=True).stdout.strip()
    errors = check_author(ident, expected)
    errors += check_message(Path(args.datei).read_text(encoding="utf-8"), commit_terms())
    if errors:
        print("commit-msg: Commit abgelehnt.\n  " + "\n  ".join(errors), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
