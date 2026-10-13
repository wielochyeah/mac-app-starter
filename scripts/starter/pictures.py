"""The README pictures: docs/screenshots/list.txt (what make readme-shots writes) and the PNGs in docs/screenshots/.

A list entry is "<lang>-<appearance>/<scene>.png" (a render from build/shots) or "tools/<name>.png"; its picture is
docs/screenshots/<entry with / as ->. A scene of a module starts with the module's name ("island.pane"), so remove
can take a module's lines and pictures with it, and check-kit can find pictures of modules that are gone.
"""
from __future__ import annotations

import re
from typing import Dict, Iterable, List, Optional, Set

LIST = "docs/screenshots/list.txt"
FOLDER = "docs/screenshots/"
_REF = re.compile(r"docs/screenshots/[^)\s\"'<>`]+\.png")


def entry_of(line: str) -> str:
    """The entry of a list line without comment and spaces ("" for comments and empty lines)."""
    return re.sub(r"\s+", "", line.split("#", 1)[0])


def entries(text: str) -> List[str]:
    return [e for e in (entry_of(line) for line in text.split("\n")) if e]


def picture(entry: str) -> str:
    return FOLDER + entry.replace("/", "-")


def scene_of(entry: str) -> Optional[str]:
    """"island.pane" for "de-dark/island.pane.png", None for tool pictures."""
    m = re.fullmatch(r"[a-z]{2}-(?:light|dark)/(.+)\.png", entry)
    return m.group(1) if m else None


def module_of(scene: Optional[str], modules: Iterable[str]) -> Optional[str]:
    if not scene:
        return None
    prefix = scene.split(".", 1)[0]
    return prefix if prefix in set(modules) else None


def scene_of_picture(path: str) -> Optional[str]:
    """"island.pane" for docs/screenshots/de-dark-island.pane.png."""
    m = re.fullmatch(re.escape(FOLDER) + r"[a-z]{2}-(?:light|dark)-(.+)\.png", path)
    return m.group(1) if m else None


def drop_module_lines(text: str, module: str) -> str:
    """The list without the lines of the module's scenes ("<module>.…")."""
    return "\n".join(line for line in text.split("\n")
                     if (scene_of(entry_of(line)) or "").split(".", 1)[0] != module)


def references(text: str) -> List[str]:
    """The docs/screenshots pictures a text names."""
    return _REF.findall(text)


def referenced(texts: Dict[str, str]) -> Set[str]:
    """Pictures named by any Markdown file or listed in list.txt."""
    out: Set[str] = set()
    for path, text in texts.items():
        if path == LIST:
            out.update(picture(e) for e in entries(text))
        elif path.endswith(".md"):
            out.update(references(text))
    return out
