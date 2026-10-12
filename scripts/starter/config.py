"""starter.json: reading, writing in its compact layout, and the structural merge used by sync.

The layout keeps every top-level key on its own line, puts an object inline when none of its values
is an object ({ "window": true, ... }) and spreads it over lines otherwise (the "app" section).
Writing an unchanged config gives back the same bytes, so tools only change what they mean to.
"""
from __future__ import annotations

import copy
import json
import sys
from pathlib import Path
from typing import Any, List, Tuple

from .common import StarterError, read_json, write_text

CONFIG = "starter.json"


def gen_config():
    """scripts/gen_config.py (S0) holds the accents, module folders and validation; reuse, never copy."""
    scripts = str(Path(__file__).resolve().parent.parent)
    if scripts not in sys.path:
        sys.path.insert(0, scripts)
    import gen_config as module  # noqa: E402
    return module


def read_config(root: Path) -> dict:
    return read_json(root / CONFIG)


def _scalar(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False)


def _inline(value: Any) -> str:
    if isinstance(value, dict):
        if not value:
            return "{}"
        return "{ " + ", ".join(f"{_scalar(k)}: {_inline(v)}" for k, v in value.items()) + " }"
    if isinstance(value, list):
        return "[" + ", ".join(_inline(v) for v in value) + "]"
    return _scalar(value)


def _render(value: Any, indent: int, top: bool = False) -> str:
    if isinstance(value, dict) and value and (top or any(isinstance(v, dict) for v in value.values())):
        pad = "  " * (indent + 1)
        items = [f"{pad}{_scalar(k)}: {_render(v, indent + 1)}" for k, v in value.items()]
        return "{\n" + ",\n".join(items) + "\n" + "  " * indent + "}"
    return _inline(value)


def format_config(config: dict) -> str:
    return _render(config, 0, top=True) + "\n"


def write_config(root: Path, config: dict) -> None:
    write_text(root / CONFIG, format_config(config))


def validate_config(config: dict) -> None:
    """The same validation the build runs (scripts/gen_config.py), as a StarterError."""
    gc = gen_config()
    try:
        gc.validate(config)
        gc.resolve_modules(config, None)
    except gc.ConfigError as e:
        raise StarterError(str(e))


def merge_config(project: dict, base: dict, target: dict, removed: List[str]) -> Tuple[dict, List[str]]:
    """Three-way merge of starter.json by key, never by text.

    - a key new in the target (absent in base and project) is added with the target's value
    - a value the project left as in base takes the target's value
    - a value the project changed stays; when the starter changed it too, a note says so
    - keys the project deleted stay deleted; modules in `removed` never come back
    - starter.version always becomes the target's version
    Returns the merged config and German notes for the report."""
    notes: List[str] = []
    merged = copy.deepcopy(project)

    def walk(p: dict, b: dict, t: dict, path: str) -> None:
        for key, t_val in t.items():
            where = f"{path}.{key}" if path else key
            if path == "modules" and key in removed:
                continue
            if key not in p:
                if key not in b:
                    p[key] = copy.deepcopy(t_val)
                    notes.append(f"{where} neu aus dem Starter: {_inline(t_val)}")
                continue
            b_val = b.get(key, _MISSING)
            if isinstance(t_val, dict) and isinstance(p[key], dict):
                walk(p[key], b_val if isinstance(b_val, dict) else {}, t_val, where)
                continue
            if p[key] == t_val:
                continue
            if b_val is not _MISSING and p[key] == b_val:
                p[key] = copy.deepcopy(t_val)
                notes.append(f"{where} vom Starter übernommen: {_inline(t_val)}")
            elif b_val is not _MISSING and t_val != b_val:
                notes.append(f"{where}: Projektwert {_inline(p[key])} behalten, der Starter hat jetzt {_inline(t_val)}")
        for key in p:
            where = f"{path}.{key}" if path else key
            if key not in t and key in b and p[key] == b[key] and not (path == "modules"):
                notes.append(f"{where} gibt es im Starter nicht mehr; im Projekt behalten, von Hand prüfen")

    walk(merged, base, target, "")
    version = (target.get("starter") or {}).get("version")
    if version is not None:
        merged.setdefault("starter", {})["version"] = version
    return merged, notes


class _Missing:
    pass


_MISSING = _Missing()
