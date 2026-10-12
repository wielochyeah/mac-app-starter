"""A small Swift lexer for the source checks (check_texts.py, check_design.py).

It finds comments and string literals (plain, multi-line, raw, with interpolation, nested to any
depth) and hands back a masked copy of the source in which both are blanked out with offsets kept,
so a regular expression over the masked code never matches inside a string or a comment and every
offset still maps to the same line and column. It also splits call arguments, which is what both
checks need to read `tr(en:de:)` and UI calls such as `Text("…")`.

Python 3.9 standard library only.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

PLACEHOLDER = "X"
"""Stands in for an interpolation when a literal is read as text: "\\(name) öffnen" -> "X öffnen"."""


@dataclass
class Comment:
    start: int
    end: int
    line: int
    text: str  # without the // or /* */ markers
    own_line: bool  # nothing but whitespace before it on its line


@dataclass
class Literal:
    start: int  # offset of the first quote or #
    end: int  # offset after the closing delimiter
    line: int
    parts: List[Tuple[str, str]] = field(default_factory=list)  # ("text", decoded) or ("code", expression)
    multiline: bool = False
    raw: bool = False

    @property
    def text(self) -> str:
        """The literal as a reader sees it, interpolations replaced by PLACEHOLDER."""
        return "".join(value if kind == "text" else PLACEHOLDER for kind, value in self.parts)

    @property
    def interpolations(self) -> List[str]:
        return [" ".join(value.split()) for kind, value in self.parts if kind == "code"]

    @property
    def has_text(self) -> bool:
        """True when the literal holds anything besides whitespace and interpolations."""
        return any(kind == "text" and value.strip() for kind, value in self.parts)


@dataclass
class Source:
    path: str
    text: str
    masked: str
    comments: List[Comment]
    literals: List[Literal]
    line_starts: List[int]
    literal_at: Dict[int, Literal]

    def line_of(self, offset: int) -> int:
        lo, hi = 0, len(self.line_starts) - 1
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if self.line_starts[mid] <= offset:
                lo = mid
            else:
                hi = mid - 1
        return lo + 1

    def column_of(self, offset: int) -> int:
        return offset - self.line_starts[self.line_of(offset) - 1] + 1

    def line_text(self, line: int) -> str:
        start = self.line_starts[line - 1]
        end = self.line_starts[line] - 1 if line < len(self.line_starts) else len(self.text)
        return self.text[start:end]


class LexError(Exception):
    pass


_CONTINUATION = chr(0x1F)  # marks a backslash line continuation until the indentation is known
_SIMPLE_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "0": "\0", "\\": "\\", '"': '"', "'": "'"}


def _line_starts(text: str) -> List[int]:
    starts = [0]
    for index, char in enumerate(text):
        if char == "\n":
            starts.append(index + 1)
    return starts


class _Lexer:
    def __init__(self, text: str):
        self.text = text
        self.comments: List[Comment] = []
        self.literals: List[Literal] = []
        self.blank: List[Tuple[int, int]] = []  # spans to mask

    # Entry: lexes code until the end, or until the ")" that closes an interpolation.
    def code(self, pos: int, in_interpolation: bool = False) -> int:
        text = self.text
        depth = 0
        n = len(text)
        while pos < n:
            char = text[pos]
            if char == "/" and text.startswith("//", pos):
                end = text.find("\n", pos)
                end = n if end == -1 else end
                self._comment(pos, end, text[pos + 2:end])
                pos = end
            elif char == "/" and text.startswith("/*", pos):
                end = self._block_comment_end(pos)
                self._comment(pos, end, text[pos + 2:end - 2])
                pos = end
            elif char == '"' or (char == "#" and self._raw_string_ahead(pos)):
                pos = self.string(pos)
            elif char == "(":
                depth += 1
                pos += 1
            elif char == ")":
                if in_interpolation and depth == 0:
                    return pos
                depth -= 1
                pos += 1
            else:
                pos += 1
        if in_interpolation:
            raise LexError("interpolation not closed")
        return pos

    def _raw_string_ahead(self, pos: int) -> bool:
        match = re.compile(r'#+"').match(self.text, pos)
        return match is not None

    def _comment(self, start: int, end: int, body: str) -> None:
        line_start = self.text.rfind("\n", 0, start) + 1
        own_line = self.text[line_start:start].strip() == ""
        self.comments.append(Comment(start, end, self.text.count("\n", 0, start) + 1, body, own_line))
        self.blank.append((start, end))

    def _block_comment_end(self, pos: int) -> int:
        depth = 0
        n = len(self.text)
        while pos < n:
            if self.text.startswith("/*", pos):
                depth += 1
                pos += 2
            elif self.text.startswith("*/", pos):
                depth -= 1
                pos += 2
                if depth == 0:
                    return pos
            else:
                pos += 1
        raise LexError("block comment not closed")

    def string(self, start: int) -> int:
        text = self.text
        pos = start
        hashes = 0
        while text[pos] == "#":
            hashes += 1
            pos += 1
        multiline = text.startswith('"""', pos)
        pos += 3 if multiline else 1
        close = ('"""' if multiline else '"') + "#" * hashes
        escape = "\\" + "#" * hashes
        literal = Literal(start=start, end=start, line=text.count("\n", 0, start) + 1, multiline=multiline, raw=hashes > 0)
        buffer: List[str] = []
        n = len(text)
        while True:
            if pos >= n:
                raise LexError(f"string literal not closed (line {literal.line})")
            if text.startswith(close, pos):
                pos += len(close)
                break
            if not multiline and text[pos] == "\n":
                raise LexError(f"line break in a single-line literal (line {literal.line})")
            if text.startswith(escape, pos):
                after = pos + len(escape)
                nxt = text[after] if after < n else ""
                if nxt == "(":
                    if buffer:
                        literal.parts.append(("text", "".join(buffer)))
                        buffer = []
                    inner_end = self.code(after + 1, in_interpolation=True)
                    literal.parts.append(("code", text[after + 1:inner_end]))
                    pos = inner_end + 1
                    continue
                if nxt == "u" and after + 1 < n and text[after + 1] == "{":
                    close_brace = text.index("}", after)
                    buffer.append(chr(int(text[after + 2:close_brace], 16)))
                    pos = close_brace + 1
                    continue
                if multiline and nxt in " \t\n":
                    # A backslash at the end of a line joins it with the next one.
                    line_end = text.find("\n", after)
                    if text[after:line_end].strip() == "":
                        buffer.append(_CONTINUATION)
                        pos = line_end + 1
                        continue
                if nxt in _SIMPLE_ESCAPES:
                    buffer.append(_SIMPLE_ESCAPES[nxt])
                    pos = after + 1
                    continue
                buffer.append(text[pos:after + 1])
                pos = after + 1
                continue
            buffer.append(text[pos])
            pos += 1
        if buffer:
            literal.parts.append(("text", "".join(buffer)))
        literal.end = pos
        if multiline:
            literal.parts = _strip_multiline(literal.parts, text, start, pos)
        self.literals.append(literal)
        self.blank.append((start, pos))
        return pos


def _strip_multiline(parts: List[Tuple[str, str]], text: str, start: int, end: int) -> List[Tuple[str, str]]:
    """Drops the line break after the opening quotes and the indentation of the closing quotes."""
    closing_line_start = text.rfind("\n", start, end) + 1
    indent = re.match(r"[ \t]*", text[closing_line_start:end]).group(0)
    result: List[Tuple[str, str]] = []
    for index, (kind, value) in enumerate(parts):
        if kind == "text":
            if index == 0 and value.startswith("\n"):
                value = value[1:]
            if index == 0 and indent and value.startswith(indent):
                value = value[len(indent):]
            value = value.replace("\n" + indent, "\n") if indent else value
            value = value.replace(_CONTINUATION + indent, "").replace(_CONTINUATION, "")
            if index == len(parts) - 1 and value.endswith("\n"):
                value = value[:-1]
        result.append((kind, value))
    return result


def parse(path: str, text: str) -> Source:
    """Lexes a Swift file; raises LexError for unbalanced literals or comments."""
    lexer = _Lexer(text)
    lexer.code(0)
    chars = list(text)
    for start, end in lexer.blank:
        for index in range(start, end):
            if chars[index] != "\n":
                chars[index] = " "
    # Keep the quotes of top-level literals visible, so a check can see "a literal stands here".
    literal_at: Dict[int, Literal] = {}
    for literal in lexer.literals:
        if not _inside(literal, lexer.literals):
            literal_at[literal.start] = literal
            chars[literal.start] = '"'
            chars[literal.end - 1] = '"'
    masked = "".join(chars)
    comments = sorted(lexer.comments, key=lambda c: c.start)
    literals = sorted(lexer.literals, key=lambda l: l.start)
    return Source(path, text, masked, comments, literals, _line_starts(text), literal_at)


def _inside(literal: Literal, others: List[Literal]) -> bool:
    return any(o is not literal and o.start < literal.start and literal.end <= o.end for o in others)


@dataclass
class Argument:
    label: Optional[str]
    start: int  # offset of the expression (after the label)
    end: int
    literal: Optional[Literal]  # set when the expression is exactly one string literal
    literals: List[Literal] = field(default_factory=list)  # every top-level literal in the expression


_LABEL = re.compile(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*:(?!:)")


def call_arguments(source: Source, open_paren: int) -> Tuple[List[Argument], int]:
    """Splits the arguments of the call whose "(" is at open_paren. Returns them and the offset of ")"."""
    masked = source.masked
    depth = 0
    pos = open_paren + 1
    pieces: List[Tuple[int, int]] = []
    piece_start = pos
    n = len(masked)
    while pos < n:
        char = masked[pos]
        if char == '"' and pos in source.literal_at:
            pos = source.literal_at[pos].end
            continue
        if char in "([{":
            depth += 1
        elif char in ")]}":
            if depth == 0:
                pieces.append((piece_start, pos))
                break
            depth -= 1
        elif char == "," and depth == 0:
            pieces.append((piece_start, pos))
            piece_start = pos + 1
        pos += 1
    close = pos
    arguments: List[Argument] = []
    for start, end in pieces:
        if masked[start:end].strip() == "" and not arguments and len(pieces) == 1:
            break
        label = None
        match = _LABEL.match(masked, start, end)
        expr_start = start
        if match:
            label = match.group(1)
            expr_start = match.end()
        inner = [lit for offset, lit in source.literal_at.items() if expr_start <= offset < end]
        inner.sort(key=lambda lit: lit.start)
        only = None
        stripped_start = expr_start + (len(masked[expr_start:end]) - len(masked[expr_start:end].lstrip()))
        if len(inner) == 1 and inner[0].start == stripped_start and masked[inner[0].end:end].strip() == "":
            only = inner[0]
        arguments.append(Argument(label, expr_start, end, only, inner))
    return arguments, close


def find_calls(source: Source, names: List[str], member: bool = False):
    """Yields (name, offset of name, offset of "(") for calls like Name( or .name( in code."""
    if not names:
        return
    alternatives = "|".join(re.escape(name) for name in sorted(names, key=len, reverse=True))
    if member:
        pattern = re.compile(r"\.(%s)\s*\(" % alternatives)
    else:
        pattern = re.compile(r"(?<![\w.])(%s)\s*\(" % alternatives)
    for match in pattern.finditer(source.masked):
        if not member:
            before = source.masked[:match.start()].rstrip()
            if before.endswith("func") or re.search(r"\bfunc\s*$", before):
                continue
        yield match.group(1), match.start(1), match.end() - 1
