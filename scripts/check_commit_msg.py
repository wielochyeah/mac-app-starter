#!/usr/bin/env python3
"""commit-msg hook and CI check of commit messages (rules A-03, A-04 and S-01 to S-04 in CLAUDE.md).

- The subject is `type(scope): subject` (scope optional, lowercase), the whole first line at most 100 characters;
  Git's own merge and revert subjects and fixup!/squash!/amend! prefixes pass.
- Line 2 is empty. Lines starting with # and everything below the scissors line of `git commit -v` do not count.
- Subject and body pass the packs of area `commit` (characters, English filler words, placeholders), like every
  other text people read. The `!` of a breaking change belongs to the format, not to the text.
- The author is the identity from starter.json (`commit.name`, `commit.email`). The starter itself ships an empty
  identity: there every author passes and only the format counts (each contributor keeps their own identity in
  .git/config). A project fills in its own identity after `bin/starter init`; until then, and in a copy that has not
  run init, no commit passes: the identity is asked for, never invented.

Usage: scripts/check_commit_msg.py <message file>             (hook: scripts/hooks/commit-msg)
       scripts/check_commit_msg.py --bereich <von>..<bis>      author and format of every commit in a range, no packs,
                                                                so commits written before a pack changed stay green
       scripts/check_commit_msg.py --github                     CI: the range of this push or pull request
                                                                (GITHUB_EVENT_NAME, GITHUB_EVENT_PATH)
       --nur-format                                             format only, never the author (pull requests)
Commits that GitHub committed (web editor, squash or rebase merge) pass the author check: GitHub vouches for them.
Commits listed in .github/commit-ausnahmen.txt (`<sha> <reason>`) are skipped; the list is for history that cannot
be rewritten, never for new commits.
Python 3.9 standard library only.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

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

GITHUB_COMMITTER = "noreply@github.com"
EXCEPTIONS = ".github/commit-ausnahmen.txt"
ZERO = re.compile(r"^0+$")

MISSING_IDENTITY = (
    "starter.json nennt keine Commit-Identität. commit.name und commit.email des Projekts dort eintragen (beim "
    "Auftraggeber erfragen, nie erfinden), dann git config user.name und git config user.email gleich setzen. Bis "
    "dahin nimmt dieser Hook keinen Commit an (A-04)."
)
NOT_INITIALISED = (
    "Diese Kopie des Starters ist noch nicht eingerichtet: zuerst bin/starter init, dann commit.name und "
    "commit.email des Projekts in starter.json eintragen (beim Auftraggeber erfragen, nie erfinden). Bis dahin "
    "nimmt dieser Hook keinen Commit an (A-04). Ist das der Starter selbst, fehlt origin "
    "(git remote add origin <Adresse des Starters>)."
)


def read_identity(root: Path = ROOT) -> Dict[str, str]:
    """commit.name and commit.email of starter.json; a missing or broken file stops the check with its reason."""
    data = rules_lib.read_json_file(root / "starter.json", "starter.json")
    commit = data.get("commit", {}) if isinstance(data, dict) else {}
    if not isinstance(commit, dict):
        raise rules_lib.CheckError("starter.json: commit muss ein Objekt mit name und email sein")
    return {"name": str(commit.get("name", "") or ""), "email": str(commit.get("email", "") or "")}


def has_identity(expected: Dict[str, str]) -> bool:
    return bool(expected["name"].strip()) and bool(expected["email"].strip())


def repo_state(root: Path = ROOT) -> str:
    """starter, project, needs-init or unknown (scripts/starter/manifest.py); unknown when the starter tools are not
    there, as in a copy of only this script."""
    try:
        from starter.manifest import detect_state
    except ImportError:
        return "unknown"
    return detect_state(root)


def check_author(ident: str, expected: Dict[str, str], state: str = "project") -> List[str]:
    if not has_identity(expected):
        if state == "starter":
            return []  # the starter ships no identity; each contributor commits under their own
        return [MISSING_IDENTITY if state == "project" else NOT_INITIALISED]
    author = re.match(r"^(.*) <([^>]*)>", ident)
    if author and author.group(1) == expected["name"] and author.group(2) == expected["email"]:
        return []
    found = f"{author.group(1)} <{author.group(2)}>" if author else ident
    return [f"Autor ist „{found}“, erwartet „{expected['name']} <{expected['email']}>“ aus starter.json. Wenn das deine "
            f"Identität ist: git config user.name \"{expected['name']}\" und git config user.email \"{expected['email']}\". "
            "Ist es ein neues Projekt aus dem Starter, zuerst bin/starter init ausführen oder die eigene Identität in "
            "starter.json (commit) eintragen; nie die Identität einer anderen Person übernehmen (A-04)."]


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


def read_exceptions(root: Path = ROOT) -> List[str]:
    """Commit hashes from .github/commit-ausnahmen.txt (`<sha> <reason>` per line, # starts a comment)."""
    try:
        text = (root / EXCEPTIONS).read_text(encoding="utf-8")
    except OSError:
        return []
    out = []
    for line in text.split("\n"):
        word = line.split("#", 1)[0].strip().split(" ", 1)[0]
        if re.fullmatch(r"[0-9a-f]{7,40}", word):
            out.append(word)
    return out


def check_range(spec: str, expected: Dict[str, str], cwd: Path = ROOT, format_only: bool = False,
                state: str = "project", exceptions: Sequence[str] = ()) -> List[str]:
    if not format_only and not has_identity(expected) and state != "starter":
        return [MISSING_IDENTITY if state == "project" else NOT_INITIALISED]
    result = subprocess.run(["git", "log", "--no-merges", "--format=%H%x00%an <%ae>%x00%ce%x00%B%x1e", spec],
                            cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        raise rules_lib.CheckError(f"git log {spec} schlägt fehl: {result.stderr.strip() or result.returncode}")
    log = result.stdout
    errors = []
    for entry in log.split("\x1e"):
        entry = entry.lstrip("\n")
        if not entry.strip():
            continue
        commit, ident, committer, message = (entry.split("\x00") + ["", "", ""])[:4]
        if BOT.search(ident) or any(commit.startswith(sha) for sha in exceptions):
            continue
        author = [] if format_only or committer == GITHUB_COMMITTER else check_author(ident, expected, state)
        errors += [f"{commit[:7]}: {e}" for e in author + check_message(message, None)]
    return errors


def resolves(ref: str, cwd: Path) -> bool:
    return subprocess.run(["git", "rev-parse", "-q", "--verify", ref + "^{commit}"], cwd=cwd,
                          capture_output=True).returncode == 0


def github_range(event_name: str, event: dict, cwd: Path = ROOT) -> Tuple[Optional[str], bool, str]:
    """(range, format only, what it is) for a GitHub event; range None when there is nothing to check.

    pull request: base..head, format only (a contributor keeps their own identity).
    push: before..after; for a new branch (before is zero) or a force push whose old head is gone, the commits
    that are not on the default branch, and on the first push of the default branch itself, its whole history.
    Tags, deleted branches, schedule and manual runs bring no new commits."""
    if event_name in ("pull_request", "pull_request_target"):
        pr = event.get("pull_request") or {}
        base, head = (pr.get("base") or {}).get("sha"), (pr.get("head") or {}).get("sha")
        if not base or not head:
            raise rules_lib.CheckError("Ereignis pull_request ohne base.sha und head.sha")
        return f"{base}..{head}", True, "Pull Request"
    if event_name != "push":
        return None, False, f"Ereignis {event_name} bringt keine neuen Commits"
    ref = event.get("ref") or ""
    after = event.get("after") or ""
    if event.get("deleted") or not ref.startswith("refs/heads/") or not after or ZERO.match(after):
        return None, False, "Tag oder gelöschter Branch"
    before = event.get("before") or ""
    default = ((event.get("repository") or {}).get("default_branch") or "main")
    if before and not ZERO.match(before) and resolves(before, cwd):
        return f"{before}..{after}", False, "Push"
    if ref != f"refs/heads/{default}" and resolves(f"origin/{default}", cwd):
        return f"origin/{default}..{after}", False, f"neuer Branch, Commits außerhalb von {default}"
    return after, False, f"erster Push von {ref[len('refs/heads/'):]}, ganze Geschichte"


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Commit-Nachricht und Autor prüfen (A-03, A-04).")
    parser.add_argument("datei", nargs="?", help="Datei mit der Nachricht (vom Hook commit-msg)")
    parser.add_argument("--bereich", help="alle Commits eines Bereichs prüfen, etwa origin/main..HEAD")
    parser.add_argument("--github", action="store_true",
                        help="den Bereich dieses Pushs oder Pull Requests prüfen (CI: GITHUB_EVENT_NAME, GITHUB_EVENT_PATH)")
    parser.add_argument("--nur-format", dest="nur_format", action="store_true", help="nur das Format, nie den Autor")
    args = parser.parse_args(argv)
    try:
        return run(args, parser)
    except rules_lib.CheckError as error:
        print(f"commit-msg: {error}", file=sys.stderr)
        return 1


def report_range(spec: str, format_only: bool, label: str = "") -> int:
    state = repo_state()
    expected = read_identity()
    errors = check_range(spec, expected, ROOT, format_only, state, read_exceptions())
    what = f"{label} {spec}".strip()
    if errors:
        print(f"commit-msg: {len(errors)} Befunde in {what}\n  " + "\n  ".join(errors), file=sys.stderr)
        return 1
    checked = "Format" if format_only or (state == "starter" and not has_identity(expected)) else "Autor und Format"
    print(f"commit-msg: {checked} aller Commits in {what} {'passt' if checked == 'Format' else 'passen'}.")
    return 0


def run(args, parser) -> int:
    if args.github:
        path = os.environ.get("GITHUB_EVENT_PATH")
        if not path:
            raise rules_lib.CheckError("--github braucht GITHUB_EVENT_PATH (nur in GitHub Actions)")
        event = rules_lib.read_json_file(Path(path), "GITHUB_EVENT_PATH")
        spec, format_only, label = github_range(os.environ.get("GITHUB_EVENT_NAME", ""), event, ROOT)
        if spec is None:
            print(f"commit-msg: nichts zu prüfen ({label}).")
            return 0
        return report_range(spec, format_only or args.nur_format, label)
    if args.bereich:
        return report_range(args.bereich, args.nur_format)
    if not args.datei:
        parser.error("Datei mit der Nachricht, --bereich oder --github angeben")
    expected = read_identity()
    ident = subprocess.run(["git", "var", "GIT_AUTHOR_IDENT"], capture_output=True, text=True)
    if ident.returncode != 0:
        raise rules_lib.CheckError(f"git var GIT_AUTHOR_IDENT schlägt fehl: {ident.stderr.strip()}")
    message, error = rules_lib.read_text_file(Path(args.datei))
    if message is None:
        raise rules_lib.CheckError(f"{args.datei}: nicht lesbar ({error})")
    errors = [] if args.nur_format else check_author(ident.stdout.strip(), expected,
                                                     "project" if has_identity(expected) else repo_state())
    errors += check_message(message, commit_terms())
    if errors:
        print("commit-msg: Commit abgelehnt.\n  " + "\n  ".join(errors), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
