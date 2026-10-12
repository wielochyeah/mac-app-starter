"""Shared engine of the rule checks: compiled terms, matching, Markdown blanking, baseline.

rules_sync.py compiles rules/ into rules/generated/begriffe.json with these functions and runs every
pack example through `find_findings`; check_texts.py, check_design.py and check_commit_msg.py read the
generated file and use the same function, so an example that rules_sync accepts is detected the same
way by every check (scripts/tests prove it).

Python 3.9 standard library only.
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

ROOT = Path(__file__).resolve().parents[1]
TERMS_FILE = "rules/generated/begriffe.json"
AREAS = ("ui", "kommentar", "doku", "commit", "ki", "swift")
LANGS = ("de", "en")
WORD_START = r"(?<!\w)"
WORD_END = r"(?!\w)"
FLAG_BITS = {"i": re.IGNORECASE, "m": re.MULTILINE, "s": re.DOTALL, "x": re.VERBOSE}
PROCEDURES = ("markdown-absatz",)


def compile_source(art: str, muster: Sequence[str], extra: Sequence[str] = ()) -> Optional[str]:
    """Pattern source of a term as every check compiles it; None for procedures."""
    alternatives = "|".join(list(muster) + list(extra))
    if art == "regex":
        return alternatives
    if art == "woerter":
        return f"{WORD_START}(?:{alternatives}){WORD_END}"
    return None


def regex_flags(flags: str) -> int:
    bits = 0
    for letter in flags:
        bits |= FLAG_BITS[letter]
    return bits


def phrase_pattern(phrase: str) -> "re.Pattern[str]":
    words = [re.escape(word) for word in phrase.strip().split()]
    return re.compile(r"\s+".join(words), re.IGNORECASE)


def glob_regex(pattern: str) -> "re.Pattern[str]":
    """`**` crosses folders, `*` and `?` stay inside one path segment."""
    out = []
    index = 0
    while index < len(pattern):
        if pattern.startswith("**/", index):
            out.append("(?:.*/)?")
            index += 3
        elif pattern.startswith("**", index):
            out.append(".*")
            index += 2
        elif pattern[index] == "*":
            out.append("[^/]*")
            index += 1
        elif pattern[index] == "?":
            out.append("[^/]")
            index += 1
        else:
            out.append(re.escape(pattern[index]))
            index += 1
    return re.compile("^" + "".join(out) + "$")


def path_matches(path: str, patterns: Iterable[str]) -> bool:
    return any(glob_regex(p).match(path) for p in patterns)


@dataclass
class Term:
    id: str
    paket: str
    regeln: List[str]
    pruefer: str
    label: str
    hinweis: str
    art: str
    bereiche: List[str]
    sprachen: List[str]
    quelle: Optional[str] = None
    flags: str = ""
    verfahren: Optional[str] = None
    erlaubt: List[dict] = field(default_factory=list)
    ausgenommene_pfade: List[str] = field(default_factory=list)
    ausnahme_kommentar: Optional[str] = None
    _regex: Optional["re.Pattern[str]"] = None

    @property
    def regex(self) -> Optional["re.Pattern[str]"]:
        if self._regex is None and self.quelle is not None:
            self._regex = re.compile(self.quelle, regex_flags(self.flags))
        return self._regex

    def applies(self, area: str, lang: Optional[str], path: Optional[str] = None) -> bool:
        if area not in self.bereiche:
            return False
        if lang is not None and self.sprachen and lang not in self.sprachen:
            return False
        if path is not None and self.ausgenommene_pfade and path_matches(path, self.ausgenommene_pfade):
            return False
        return True

    def allowed_spans(self, text: str, path: Optional[str]) -> List[Tuple[int, int]]:
        spans = []
        for entry in self.erlaubt:
            if path is not None and entry.get("pfade") and not path_matches(path, entry["pfade"]):
                continue
            spans += [(m.start(), m.end()) for m in phrase_pattern(entry["phrase"]).finditer(text)]
        return spans

    @classmethod
    def from_json(cls, raw: dict) -> "Term":
        return cls(
            id=raw["id"], paket=raw["paket"], regeln=list(raw.get("regeln", [])), pruefer=raw["pruefer"],
            label=raw["label"], hinweis=raw["hinweis"], art=raw["art"], bereiche=list(raw["bereiche"]),
            sprachen=list(raw.get("sprachen", [])), quelle=raw.get("quelle"), flags=raw.get("flags", ""),
            verfahren=raw.get("verfahren"), erlaubt=list(raw.get("erlaubt", [])),
            ausgenommene_pfade=list(raw.get("ausgenommenePfade", [])), ausnahme_kommentar=raw.get("ausnahmeKommentar"),
        )


@dataclass
class Finding:
    path: str
    line: int
    column: int
    term_id: str
    label: str
    rules: List[str]
    hint: str
    match: str
    context: str

    def fingerprint(self) -> str:
        """Term and match, without line or surrounding text: editing near a known finding keeps it known. The baseline
        keeps one entry per finding, so a second identical finding in the same file is new."""
        return f"{self.term_id} | {' '.join(self.match.split())}"

    def format(self) -> str:
        rules = f" ({', '.join(self.rules)})" if self.rules else ""
        shown = (self.match.strip() or self.match).replace("\n", "\\n")
        return f"{self.path}:{self.line}:{self.column}: {self.label}{rules}: „{shown}“. Stattdessen: {self.hint}"


class CheckError(Exception):
    """A problem with the input of a check (missing path, unreadable file); the check prints it and fails."""


def read_json_file(path: Path, shown: Optional[str] = None):
    """JSON of a file; a missing or broken file stops the check with its name instead of a traceback."""
    shown = shown or str(path)
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise CheckError(f"{shown} fehlt")
    except (OSError, UnicodeDecodeError, ValueError) as error:
        raise CheckError(f"{shown}: nicht lesbar ({error})")


def read_text_file(path: Path) -> Tuple[Optional[str], Optional[str]]:
    """(text, None) or (None, reason) for a source file that is not UTF-8 or cannot be read."""
    try:
        return path.read_text(encoding="utf-8"), None
    except UnicodeDecodeError as error:
        return None, f"kein UTF-8 ({error.reason} an Byte {error.start})"
    except OSError as error:
        return None, error.strerror or str(error)


def select_paths(root: Path, only: Sequence[str], files: Sequence[str]) -> List[str]:
    """Files of the scope under the given paths. A path that does not exist or holds no file of the scope fails, so a
    typo never reports a green check."""
    if not only:
        return list(files)

    def under(rel: str, given: str) -> bool:
        given = given.rstrip("/")
        return given in ("", ".") or rel == given or rel.startswith(given + "/")

    for given in only:
        if not (root / given).exists():
            raise CheckError(f"{given}: Pfad fehlt")
        if not any(under(rel, given) for rel in files):
            raise CheckError(f"{given}: keine Datei im Prüfumfang (rules/index.json, pruefumfang)")
    return [rel for rel in files if any(under(rel, given) for given in only)]


def load_terms(root: Path = ROOT) -> List[Term]:
    path = root / TERMS_FILE
    if not path.exists():
        raise CheckError(f"{TERMS_FILE} fehlt. Ausführen: make rules")
    data = read_json_file(path, TERMS_FILE)
    return [Term.from_json(raw) for raw in data["begriffe"]]


def context_of(text: str, start: int, end: int, width: int = 40) -> str:
    return " ".join(text[max(0, start - width):min(len(text), end + width)].split())


def matches(term: Term, text: str, path: Optional[str] = None) -> List[Tuple[int, int]]:
    """Spans where the term hits the text, outside the pack's allowed phrases."""
    if term.regex is None:
        if term.verfahren == "markdown-absatz":
            return markdown_paragraph_breaks(text)
        return []
    allowed = term.allowed_spans(text, path)
    found = []
    for m in term.regex.finditer(text):
        if m.end() == m.start():
            continue
        if any(a <= m.start() and m.end() <= b for a, b in allowed):
            continue
        found.append((m.start(), m.end()))
    return found


def find_findings(text: str, terms: Sequence[Term], area: str, lang: Optional[str], path: str = "",
                  line_of=None, column_of=None) -> List[Finding]:
    """Every term that applies to (area, lang, path) against text. A character hit by two terms is reported once."""
    taken: List[Tuple[int, int]] = []
    findings: List[Finding] = []
    for term in terms:
        if not term.applies(area, lang, path or None):
            continue
        for start, end in matches(term, text, path or None):
            if any(start < b and a < end for a, b in taken):
                continue
            taken.append((start, end))
            line = line_of(start) if line_of else text.count("\n", 0, start) + 1
            column = column_of(start) if column_of else start - (text.rfind("\n", 0, start) + 1) + 1
            findings.append(Finding(path, line, column, term.id, term.label, term.regeln, term.hinweis,
                                    text[start:end], context_of(text, start, end)))
    findings.sort(key=lambda f: (f.line, f.column))
    return findings


# Markdown -----------------------------------------------------------------------------------------

_FENCE = re.compile(r"^[ \t]{0,3}(`{3,}|~{3,})")


def _blank(match_text: str) -> str:
    return re.sub(r"[^\n]", " ", match_text)


def blank_markdown(text: str) -> str:
    """Prose only: front matter, code blocks, inline code, HTML comments, link targets and autolinks become
    spaces, so offsets, lines and columns of findings stay exact."""
    lines = text.split("\n")
    out = []
    fence: Optional[str] = None
    in_front = bool(lines) and lines[0].strip() == "---"
    for index, line in enumerate(lines):
        if in_front:
            out.append(_blank(line))
            if index > 0 and line.strip() == "---":
                in_front = False
            continue
        match = _FENCE.match(line)
        if fence is not None:
            out.append(_blank(line))
            if match and match.group(1)[0] == fence[0] and len(match.group(1)) >= len(fence) and line.strip() == match.group(1):
                fence = None
            continue
        if match:
            fence = match.group(1)
            out.append(_blank(line))
            continue
        out.append(line)
    result = "\n".join(out)
    result = re.sub(r"<!--.*?-->", lambda m: _blank(m.group(0)), result, flags=re.S)
    result = re.sub(r"(`+)(?!`).*?(?<!`)\1(?!`)", lambda m: _blank(m.group(0)), result, flags=re.S)
    result = re.sub(r"\]\([^)\n]*\)", lambda m: "]" + _blank(m.group(0)[1:]), result)
    result = re.sub(r"^\[[^\]\n]+\]:[^\n]*$", lambda m: _blank(m.group(0)), result, flags=re.M)
    result = re.sub(r"<(?:https?|mailto):[^>\s]*>", lambda m: _blank(m.group(0)), result)
    result = re.sub(r"https?://\S+", lambda m: _blank(m.group(0)), result)
    return result


_BLOCK_START = re.compile(r"^\s*(?:#{1,6}\s|[-*+]\s|\d+[.)]\s|\||>|<|```|~~~|-{3,}\s*$|\*{3,}\s*$|={3,}\s*$)")
_LIST_ITEM = re.compile(r"^(\s*)(?:[-*+]|\d+[.)])\s")


def markdown_paragraph_breaks(text: str) -> List[Tuple[int, int]]:
    """Hard-wrapped Markdown: a prose, list or quote line followed by a continuation line of the same block,
    unless it ends with two spaces or a backslash. Returns the span of each line break."""
    spans = []
    lines = text.split("\n")
    offset = 0
    offsets = []
    for line in lines:
        offsets.append(offset)
        offset += len(line) + 1
    for index in range(len(lines) - 1):
        line, nxt = lines[index], lines[index + 1]
        if not line.strip() or not nxt.strip():
            continue
        if line.endswith("  ") or line.rstrip().endswith("\\"):
            continue
        if line.lstrip().startswith(("|", "#", "<")) or re.match(r"^\s*(?:-{3,}|\*{3,}|={3,})\s*$", line):
            continue
        quote = line.lstrip().startswith(">")
        if quote:
            if nxt.lstrip().startswith(">") and nxt.lstrip()[1:].strip():
                spans.append((offsets[index] + len(line), offsets[index] + len(line) + 1))
            continue
        if _BLOCK_START.match(nxt):
            continue
        spans.append((offsets[index] + len(line), offsets[index] + len(line) + 1))
    return spans


# Baseline -----------------------------------------------------------------------------------------

def load_baseline(path: Path) -> Dict[str, List[str]]:
    if not path.exists():
        return {}
    data = read_json_file(path)
    if not isinstance(data, dict) or not all(isinstance(v, list) and all(isinstance(e, str) for e in v) for v in data.values()):
        raise CheckError(f"{path}: Format {{datei: [fingerabdruck, …]}} erwartet")
    return data


def apply_baseline(findings: Sequence[Finding], baseline: Dict[str, List[str]]):
    """(new findings, known findings, stale entries). Fingerprints, not counts: a new finding of the same term in
    the same file still fails."""
    remaining = {path: list(entries) for path, entries in baseline.items()}
    new, known = [], []
    for finding in findings:
        entries = remaining.get(finding.path)
        fp = finding.fingerprint()
        if entries and fp in entries:
            entries.remove(fp)
            known.append(finding)
        else:
            new.append(finding)
    stale = [(path, entry) for path, entries in remaining.items() for entry in entries]
    return new, known, stale


def to_baseline(findings: Sequence[Finding]) -> Dict[str, List[str]]:
    baseline: Dict[str, List[str]] = {}
    for finding in sorted(findings, key=lambda f: (f.path, f.line, f.column)):
        baseline.setdefault(finding.path, []).append(finding.fingerprint())
    return baseline


def grown_entries(previous: Dict[str, List[str]], nxt: Dict[str, List[str]]) -> List[str]:
    grown = []
    for path, entries in nxt.items():
        pool = list(previous.get(path, []))
        for entry in entries:
            if entry in pool:
                pool.remove(entry)
            else:
                grown.append(f"{path}: {entry}")
    return grown


def counted(number: int, one: str, many: str) -> str:
    """„1 Befund“, „2 Befunde“."""
    return f"{number} {one if number == 1 else many}"


def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def run_baseline(name: str, findings: List[Finding], baseline_path: Path, args, file_count: int, scoped: bool) -> int:
    """Shared command-line behaviour of check_texts.py and check_design.py. Returns the exit code."""
    rel = baseline_path.relative_to(ROOT) if baseline_path.is_absolute() and ROOT in baseline_path.parents else baseline_path
    if args.baseline_aktualisieren:
        if scoped:
            print(f"{name}: --baseline-aktualisieren gilt nur für den ganzen Umfang, ohne Pfade aufrufen.")
            return 1
        previous = load_baseline(baseline_path)
        nxt = to_baseline(findings)
        grown = grown_entries(previous, nxt)
        if grown:
            print(f"{name}: die Baseline darf nur schrumpfen. Neue Befunde zuerst beheben:\n  " + "\n  ".join(grown))
            return 1
        write_json(baseline_path, nxt)
        print(f"{name}: Baseline aktualisiert, {counted(sum(len(v) for v in nxt.values()), 'bekannter Befund', 'bekannte Befunde')}.")
        return 0
    baseline = {} if args.streng else load_baseline(baseline_path)
    new, known, stale = apply_baseline(findings, baseline)
    if args.json:
        write_json(Path(args.json), {
            "dateien": file_count,
            "neu": [f.__dict__ for f in new],
            "bekannt": [f.__dict__ for f in known],
            "veraltet": [{"datei": p, "eintrag": e} for p, e in stale],
        })
    code = 0
    if known:
        print(f"{name}: {counted(len(known), 'bekannter Befund', 'bekannte Befunde')} aus {rel} (alle zeigen: --streng).")
    if stale and not scoped:
        # Locally only a hint, so a strand that fixes a known finding stays green; CI (--ci) insists on the shrink.
        print(f"{name}: behoben, aber noch in {rel} ({len(stale)}): "
              + ", ".join(sorted({p for p, _ in stale})) + ". Verkleinern: --baseline-aktualisieren"
              + (" (in CI ein Fehler)" if not getattr(args, "ci", False) else ""))
        if getattr(args, "ci", False):
            code = 1
    if new:
        for finding in new:
            print(finding.format())
        print(f"{name}: {counted(len(new), 'Befund', 'Befunde')} in {counted(file_count, 'Datei', 'Dateien')}. "
              "Regeln und erlaubte Wendungen: rules/pakete/.")
        code = 1
    elif code == 0:
        print(f"{name}: {counted(file_count, 'Datei', 'Dateien')} geprüft, keine neuen Befunde.")
    return code
