"""Glob matching for repository paths (port of app-starter src/lib/glob.mts).

"**" spans any number of folders, "*" stays within one folder, "?" is one character. A pattern
without a slash matches the file name in any folder; "./" in front anchors it at the root
("./README.md" is only the README at the top). No brace expansion.
"""
from __future__ import annotations

import re
from functools import lru_cache
from typing import Iterable


@lru_cache(maxsize=None)
def _compile(glob: str) -> "re.Pattern[str]":
    anchored = glob.startswith("./")
    body = glob[2:] if anchored else glob
    out = []
    i = 0
    while i < len(body):
        ch = body[i]
        if ch == "*" and i + 1 < len(body) and body[i + 1] == "*":
            if i + 2 < len(body) and body[i + 2] == "/":
                out.append("(?:.*/)?")
                i += 3
            else:
                out.append(".*")
                i += 2
            continue
        if ch == "*":
            out.append("[^/]*")
        elif ch == "?":
            out.append("[^/]")
        else:
            out.append(re.escape(ch))
        i += 1
    source = "".join(out)
    if anchored or "/" in body:
        return re.compile("^" + source + "$")
    return re.compile("(?:^|/)" + source + "$")


def matches(path: str, globs: Iterable[str]) -> bool:
    """True when the repository path (forward slashes) matches any of the globs."""
    return any(_compile(g).match(path) for g in globs)


def literal_prefix(glob: str) -> str:
    """The part of a glob before its first wildcard, without "./" ("ai-worker/**" -> "ai-worker/")."""
    body = glob[2:] if glob.startswith("./") else glob
    cut = len(body)
    for ch in "*?[":
        pos = body.find(ch)
        if pos != -1:
            cut = min(cut, pos)
    return body[:cut]
