"""Module markers and what removing a module does to a file.

Swift: cross-module code sits in `#if MODUL_<NAME>` … `#endif` (BAUPLAN §2.5). Removing <name> drops
the block and keeps an `#else` body; `#if !MODUL_<NAME>` keeps its body and drops the `#else` body.
Other `#if` blocks (TESTING, DEBUG, other modules) stay and are processed inside. Conditions that
combine a module flag with anything else, and `#elseif` in a module block, are refused: the tool
cannot decide them, a person must.

Every other text file (and Swift, where an `#if` does not fit, e.g. inside an array literal) uses
comment markers in its own comment syntax (port of app-starter):
  one line   `… // modul:<name>`  (`# modul:<name>` in shell, Python, YAML, Makefile, requirements;
             `<!-- modul:<name> -->` in Markdown and HTML); `// modul:ai,mlx` goes with either module
  block      `// modul:<name>:anfang` … `// modul:<name>:ende`, each on its own line
JSON carries no comments; its module parts go by name (starter.json, see remove.py).
"""
from __future__ import annotations

import re
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple

from .common import StarterError

_DIRECTIVE = re.compile(r"^\s*#(if|elseif|else|endif)\b(.*)$")
_ANY_FLAG = re.compile(r"\bMODUL_([A-Z0-9_]+)\b")


def flag(module: str) -> str:
    return "MODUL_" + module.upper()


def _condition(rest: str) -> str:
    """The condition of a directive without a trailing // comment."""
    pos = rest.find("//")
    return (rest if pos == -1 else rest[:pos]).strip()


def _plain_flag(cond: str) -> Optional[Tuple[str, bool]]:
    """("MODUL_X", negated) for `MODUL_X`, `!MODUL_X`, `(MODUL_X)`; None for anything else."""
    m = re.fullmatch(r"\(?\s*(!)?\s*(MODUL_[A-Z0-9_]+)\s*\)?", cond)
    return (m.group(2), m.group(1) == "!") if m else None


def strip_swift_flag(text: str, module: str, path: str = "") -> str:
    """Removes the `#if MODUL_<NAME>` blocks of one module from Swift source (see module docs)."""
    name = flag(module)
    mention = re.compile(r"\b" + re.escape(name) + r"\b")
    out: List[str] = []
    frames: List[List] = []  # [kind ("mod" | "other"), emitting (bool), line]
    cut = False

    def emitting() -> bool:
        return all(f[1] for f in frames)

    def add(line: str) -> None:
        nonlocal cut
        if cut and not line.strip() and out and not out[-1].strip():
            cut = False
            return
        cut = False
        out.append(line)

    for no, line in enumerate(text.split("\n"), 1):
        m = _DIRECTIVE.match(line)
        if not m:
            if emitting():
                add(line)
            else:
                cut = True
            continue
        keyword, cond = m.group(1), _condition(m.group(2))
        where = f"{path}:{no}" if path else f"Zeile {no}"
        if keyword == "if":
            plain = _plain_flag(cond)
            if plain and plain[0] == name:
                frames.append(["mod", plain[1], no])
                cut = True
            elif mention.search(cond):
                raise StarterError(f"{where}: `#if {cond}` verbindet {name} mit einer weiteren Bedingung; "
                                   f"von Hand in einfache `#if {name}`-Blöcke aufteilen")
            else:
                if emitting():
                    add(line)
                frames.append(["other", True, no])
            continue
        if not frames:
            raise StarterError(f"{where}: #{keyword} ohne passendes #if")
        top = frames[-1]
        if keyword in ("elseif", "else"):
            if top[0] == "mod":
                if keyword == "elseif":
                    raise StarterError(f"{where}: #elseif in einem `#if {name}`-Block; von Hand auflösen")
                top[1] = not top[1]
                cut = True
            else:
                if keyword == "elseif" and mention.search(cond):
                    raise StarterError(f"{where}: `#elseif {cond}` nennt {name}; von Hand auflösen")
                frames.pop()
                if emitting():
                    add(line)
                frames.append(top)
            continue
        frames.pop()
        if top[0] == "other":
            if emitting():
                add(line)
        else:
            cut = True
    if frames:
        line = frames[-1][2]
        raise StarterError(f"{path or 'Datei'}:{line}: #if ohne #endif")
    return "\n".join(out)


def swift_flag_problems(text: str, path: str, known: Iterable[str]) -> List[str]:
    """Checks that module flags are used the way `remove` can handle: plain `#if MODUL_X` /
    `#if !MODUL_X` with a known module, no `#elseif` in such a block, balanced directives."""
    known_flags = {flag(m) for m in known}
    problems: List[str] = []
    stack: List[Tuple[bool, int]] = []  # (is module block, line)
    for no, line in enumerate(text.split("\n"), 1):
        m = _DIRECTIVE.match(line)
        if not m:
            continue
        keyword, cond = m.group(1), _condition(m.group(2))
        flags = _ANY_FLAG.findall(cond)
        where = f"{path}:{no}"
        if keyword == "if":
            plain = _plain_flag(cond)
            if flags and not plain:
                problems.append(f"{where}: `#if {cond}` verbindet ein Modul-Flag mit weiteren Bedingungen "
                                "(erlaubt: ein Flag je #if, verschachteln statt || und &&)")
            if plain and plain[0] not in known_flags:
                problems.append(f"{where}: {plain[0]} ist kein Modul aus starter.manifest.json")
            stack.append((bool(flags), no))
        elif keyword == "elseif":
            if not stack:
                problems.append(f"{where}: #elseif ohne #if")
            elif stack[-1][0] or flags:
                problems.append(f"{where}: #elseif an einem Modul-Flag; bin/starter remove kann das nicht auflösen")
        elif keyword == "else":
            if not stack:
                problems.append(f"{where}: #else ohne #if")
        else:
            if not stack:
                problems.append(f"{where}: #endif ohne #if")
            else:
                stack.pop()
    for _, no in stack:
        problems.append(f"{path}:{no}: #if ohne #endif")
    return problems


def comment_syntax(path: str, text: str = "") -> Optional[Tuple[str, str]]:
    """The line-comment syntax of a file by its name; a script without extension (Git hooks,
    bin/starter) by its shebang."""
    name = path.rsplit("/", 1)[-1]
    if "." not in name and text.startswith("#!"):
        return "#", ""
    if re.search(r"\.(md|html|xml|plist|entitlements)$", name):
        return "<!--", "-->"
    if re.search(r"\.(py|sh|zsh|yml|yaml|txt|toml|cfg)$", name) or name in (
            "Makefile", ".gitignore", ".editorconfig") or name.startswith("requirements"):
        return "#", ""
    if re.search(r"\.(swift|c|h|m|js)$", name):
        return "//", ""
    return None


def strip_comment_markers(text: str, module: str, path: str) -> str:
    """Drops lines ending in the module's marker and blocks between its :anfang and :ende markers."""
    syntax = comment_syntax(path, text)
    if syntax is None:
        return text
    open_, close = (re.escape(s) for s in syntax)
    mod = re.escape(module)
    line_re = re.compile(open_ + r"\s*modul:(?:[a-z0-9_-]+,)*" + mod + r"(?:,[a-z0-9_-]+)*\s*" + close + r"\s*$")
    start_re = re.compile(r"^\s*" + open_ + r"\s*modul:" + mod + r":anfang\s*" + close + r"\s*$")
    end_re = re.compile(r"^\s*" + open_ + r"\s*modul:" + mod + r":ende\s*" + close + r"\s*$")
    kept: List[str] = []
    inside = False
    cut = False
    for no, line in enumerate(text.split("\n"), 1):
        if not inside and start_re.match(line):
            inside, cut = True, True
            continue
        if inside:
            if end_re.match(line):
                inside = False
            continue
        if line_re.search(line):
            cut = True
            continue
        if cut and not line.strip() and kept and not kept[-1].strip():
            cut = False
            continue
        cut = False
        kept.append(line)
    if inside:
        raise StarterError(f"{path}: Markierung modul:{module}:anfang ohne modul:{module}:ende")
    return "\n".join(kept)


def is_empty_swift(text: str) -> bool:
    """True when nothing but comments, imports and compiler directives is left."""
    body = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    for line in body.split("\n"):
        line = re.sub(r"//.*$", "", line).strip()
        if not line or re.match(r"^(@\w+\s+)*import\s", line) or _DIRECTIVE.match(line):
            continue
        return False
    return True


def transform(path: str, text: str, modules: Sequence[str]) -> Optional[str]:
    """The file as `remove` leaves it once `modules` are gone; None when a Swift file has nothing
    left but comments, imports and directives (remove deletes it)."""
    result = text
    for m in modules:
        if path.endswith(".swift"):
            result = strip_swift_flag(result, m, path)
        result = strip_comment_markers(result, m, path)
    if result != text and path.endswith(".swift") and is_empty_swift(result):
        return None
    return result


# --- dangling references -------------------------------------------------------------------------

_DECL = re.compile(
    r"^(?:@[\w.]+(?:\([^)]*\))?\s+)*((?:(?:public|internal|package|private|fileprivate|final|nonisolated|open|"
    r"indirect|static|override|mutating|nonmutating|dynamic|lazy|weak|unowned)\s+)*)"
    r"(class|struct|enum|protocol|actor|typealias|func|let|var)\s+([A-Za-z_]\w*)")


def top_level_decls(text: str) -> List[str]:
    """Names declared at column 0 that other files can see (private and fileprivate ones skipped)."""
    names = []
    for line in text.split("\n"):
        m = _DECL.match(line)
        if m and not re.search(r"\b(private|fileprivate)\b", m.group(1)):
            names.append(m.group(3))
    return names


_NESTED_DECL = re.compile(r"\b(?:class|struct|enum|protocol|actor|typealias)\s+([A-Za-z_]\w*)")


def nested_type_decls(text: str) -> Set[str]:
    """Type names a file declares at any indent (`extension Radius { enum Island {} }`)."""
    body = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return {m.group(1) for line in body.split("\n") for m in _NESTED_DECL.finditer(_code_only(line))}


def _code_only(line: str) -> str:
    line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
    return re.sub(r"//.*$", "", line)


# A name right after a dot is a member (`Metrics.Island`), right after a declaration keyword it is a
# declaration of its own (`enum Island {` nested in another type); neither uses the deleted type.
_NOT_A_USE = re.compile(r"(?:\.\s*|\b(?:class|struct|enum|protocol|actor|typealias|func|let|var)\s+)$")


def references(text: str, names: Set[str]) -> List[Tuple[int, str]]:
    """(line, name) for every use of a name as a whole word outside comments and string literals,
    not counting member access (`Metrics.Island`) and declarations (`enum Island`)."""
    if not names:
        return []
    pattern = re.compile(r"\b(" + "|".join(re.escape(n) for n in sorted(names, key=len, reverse=True)) + r")\b")
    body = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    hits = []
    for no, line in enumerate(body.split("\n"), 1):
        code = _code_only(line)
        for m in pattern.finditer(code):
            if not _NOT_A_USE.search(code[:m.start()]):
                hits.append((no, m.group(1)))
    return hits


def dangling_references(deleted: Dict[str, str], remaining: Dict[str, str]) -> List[str]:
    """Uses of top-level declarations from deleted Swift files in the remaining Swift files (both
    given as path -> text, remaining already transformed). A name that a remaining file declares
    at column 0 as well (a fallback in an `#else` branch) does not count anywhere; a name a remaining
    file declares as a nested type does not count in that file (its own scope, e.g. `Radius.Island`
    used as `Island` inside `extension Radius`)."""
    declared: Dict[str, str] = {}
    for path, text in deleted.items():
        if path.endswith(".swift"):
            for n in top_level_decls(text):
                declared.setdefault(n, path)
    for text in (t for p, t in remaining.items() if p.endswith(".swift")):
        for n in top_level_decls(text):
            declared.pop(n, None)
    problems = []
    for path in sorted(remaining):
        if not path.endswith(".swift"):
            continue
        local = nested_type_decls(remaining[path])
        for no, n in references(remaining[path], set(declared) - local):
            problems.append(f"{path}:{no} nutzt {n} (aus {declared[n]})")
    return problems
