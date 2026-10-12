"""Shared helpers of the starter tools: errors, git, file lists, JSON, checksums, block cutting."""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
from pathlib import Path
from typing import Dict, List, Optional, Sequence


class StarterError(Exception):
    """An expected failure: the CLI prints only its message (a stack trace would read like a crash)."""


def repo_root(start: Optional[Path] = None) -> Path:
    """The folder with starter.manifest.json, from start (default: the current folder) upwards."""
    here = (start or Path.cwd()).resolve()
    for folder in [here, *here.parents]:
        if (folder / "starter.manifest.json").is_file() and (folder / "starter.json").is_file():
            return folder
    raise StarterError("kein Starter-Repository gefunden (starter.manifest.json und starter.json fehlen); "
                       "im Wurzelordner des Projekts aufrufen")


def git(root: Path, args: Sequence[str], check: bool = True, timeout: Optional[float] = None,
        env: Optional[Dict[str, str]] = None) -> str:
    """Runs git in root and returns stdout. Errors name the git subcommand and the last stderr line,
    never the arguments (a source URL may carry an address). env adds variables to the environment."""
    try:
        res = subprocess.run(["git", *args], cwd=str(root), stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             timeout=timeout, env=dict(os.environ, **env) if env else None)
    except subprocess.TimeoutExpired:
        raise StarterError(f"git {_subcommand(args)}: keine Antwort nach {int(timeout or 0)} s")
    if res.returncode != 0:
        if not check:
            return ""
        last = (res.stderr.decode("utf-8", "replace").strip().splitlines() or [""])[-1]
        raise StarterError(f"git {_subcommand(args)} ist gescheitert: {last}")
    return res.stdout.decode("utf-8", "replace").strip()


def git_bytes(root: Path, args: Sequence[str]) -> Optional[bytes]:
    res = subprocess.run(["git", *args], cwd=str(root), stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return res.stdout if res.returncode == 0 else None


def _subcommand(args: Sequence[str]) -> str:
    skip_next = False
    for a in args:
        if skip_next:
            skip_next = False
            continue
        if a == "-c":
            skip_next = True
            continue
        if not a.startswith("-"):
            return a
    return ""


def origin_url(root: Path) -> str:
    return git(root, ["remote", "get-url", "origin"], check=False)


def is_starter_origin(url: str, repository: str) -> bool:
    """True when the origin URL points at the starter repository itself (https or ssh form)."""
    remote = url.strip()
    if remote.endswith(".git"):
        remote = remote[:-4]
    remote = remote.rstrip("/")
    return bool(remote) and (remote.endswith("/" + repository) or remote.endswith(":" + repository))


def working_files(root: Path) -> List[str]:
    """Tracked and new files of the working tree, without ignored ones, that exist on disk."""
    if git(root, ["rev-parse", "--is-inside-work-tree"], check=False) != "true":
        raise StarterError(f"{root} ist kein Git-Repository; zuerst git init, git add -A und einen ersten "
                           "Commit anlegen (die Werkzeuge lesen die Dateiliste aus Git)")
    out = git(root, ["ls-files", "-z", "--cached", "--others", "--exclude-standard"])
    files = sorted({f for f in out.split("\0") if f})
    return [f for f in files if (root / f).is_file()]


def tracked_files(root: Path) -> List[str]:
    out = git(root, ["ls-files", "-z"], check=False)
    return sorted(f for f in out.split("\0") if f)


SAFE_SEGMENT_BAD = {"", ".", ".."}


def is_safe_repo_path(path: str) -> bool:
    """A relative path inside the repository: no "..", "." or ".git" segment, no backslash or
    control character, not absolute. Paths come from the manifest and from a starter tag, and
    every tool writes or deletes with them."""
    if not path or path.startswith("/") or re.match(r"^[A-Za-z]:", path) or re.search(r"[\\\x00-\x1f]", path):
        return False
    return all(seg not in SAFE_SEGMENT_BAD and seg.lower() != ".git" for seg in path.split("/"))


def inside(root: Path, path: str) -> Path:
    """root/path, refusing anything that would land outside root."""
    if not is_safe_repo_path(path):
        raise StarterError(f"{path} ist kein sicherer Pfad im Repository; nichts geschrieben")
    full = (root / path).resolve()
    base = root.resolve()
    if base != full and base not in full.parents:
        raise StarterError(f"{path} liegt außerhalb des Repositorys; nichts geschrieben")
    return root / path


def read_json(path: Path) -> dict:
    try:
        with open(path, encoding="utf-8") as f:
            value = json.load(f)
    except FileNotFoundError:
        raise StarterError(f"{path.name} fehlt")
    except json.JSONDecodeError as e:
        raise StarterError(f"{path.name} ist kein gültiges JSON: {e}")
    if not isinstance(value, dict):
        raise StarterError(f"{path.name}: ein JSON-Objekt erwartet")
    return value


def write_text(path: Path, text: str) -> None:
    """Writes atomically (temp file + rename), creating folders as needed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".starter-tmp")
    tmp.write_text(text, encoding="utf-8")
    os.replace(tmp, path)


def write_json(path: Path, value: dict) -> None:
    write_text(path, json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def is_binary(data: bytes) -> bool:
    return b"\0" in data


def to_lf(text: str) -> str:
    return text.replace("\r\n", "\n").replace("\r", "\n")


def checksum_bytes(data: bytes) -> str:
    """SHA-256; for text, line endings do not count (a CRLF checkout must not look like a change)."""
    if not is_binary(data):
        data = data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    return hashlib.sha256(data).hexdigest()


def checksum(root: Path, path: str) -> str:
    return checksum_bytes((root / path).read_bytes())


def marker_token(marker: str) -> str:
    """The word of a block marker without its comment syntax: `<!-- nur-im-starter:anfang -->` ->
    `nur-im-starter:anfang`."""
    return re.sub(r"^(?:<!--|#|//)\s*|\s*-->$", "", marker.strip())


def is_block_marker(line: str, marker: str) -> bool:
    """A line that is only the marker, in any comment syntax: `<!-- t -->` (Markdown, HTML), `# t`
    (shell, Python, YAML, Makefile) or `// t` (Swift)."""
    token = re.escape(marker_token(marker))
    return re.fullmatch(r"(?:<!--\s*" + token + r"\s*-->|#\s*" + token + r"|//\s*" + token + r")",
                        line.strip()) is not None


def has_block(text: str, start: str) -> bool:
    return any(is_block_marker(line, start) for line in text.split("\n"))


def cut_blocks(text: str, start: str, end: str) -> str:
    """Cuts every block from a line that is only the start marker to a line that is only the end
    marker (both included, in the file's comment syntax) and leaves at most one blank line at the seam."""
    kept: List[str] = []
    inside_block = False
    seam = False
    for line in text.split("\n"):
        if not inside_block and is_block_marker(line, start):
            inside_block = True
            continue
        if inside_block:
            if is_block_marker(line, end):
                inside_block, seam = False, True
            continue
        if seam and not line.strip() and kept and not kept[-1].strip():
            continue
        seam = False
        kept.append(line)
    if inside_block:
        raise StarterError(f"Markierung {start} ohne {end}")
    return "\n".join(kept)


def remove_empty_dirs(root: Path, files: Sequence[str]) -> None:
    """Removes folders the deleted files left empty, bottom up, never root itself."""
    dirs = sorted({str(Path(f).parent) for f in files}, key=len, reverse=True)
    for d in dirs:
        current = Path(d)
        while str(current) not in (".", ""):
            full = root / current
            if not full.is_dir() or any(full.iterdir()):
                break
            full.rmdir()
            current = current.parent


def is_text_path(path: str) -> bool:
    """A text file by its name (extension or a known name without one)."""
    name = path.rsplit("/", 1)[-1]
    return bool(TEXT_FILE.search(path)) or name in TEXT_NAMES


TEXT_FILE = re.compile(r"\.(swift|py|sh|zsh|md|txt|yml|yaml|json|toml|cfg|html|css|js|plist|entitlements|c|h|m)$")
TEXT_NAMES = {"Makefile", ".gitignore", ".editorconfig"}


def is_script_text(path: str, text: str) -> bool:
    """A script without extension (Git hooks, bin/starter) by its shebang line."""
    return "." not in path.rsplit("/", 1)[-1] and text.startswith("#!")


def is_text_file(root: Path, path: str) -> bool:
    """is_text_path, plus scripts without extension that start with a shebang."""
    if is_text_path(path):
        return True
    if "." in path.rsplit("/", 1)[-1]:
        return False
    try:
        with open(root / path, "rb") as f:
            return f.read(2) == b"#!"
    except OSError:
        return False


def build_env() -> Dict[str, str]:
    """The environment for `make build` and friends. /usr/bin/python3 is an xcrun shim that exports
    SDKROOT=<xcrun's default SDK> into this process when it was unset; passed on, scripts/pick-sdk.sh
    would take it as the user's choice and build against a beta SDK the compiler cannot read. An
    SDKROOT equal to xcrun's default is therefore dropped (pick-sdk tries that SDK first anyway);
    any other SDKROOT stays. MODULES/CONFIG/ONLY of an outer make do not leak into the build."""
    env = {k: v for k, v in os.environ.items() if k not in ("MODULES", "CONFIG", "ONLY", "MAKEFLAGS", "MFLAGS",
                                                             "MAKELEVEL")}
    sdk = env.get("SDKROOT")
    if sdk:
        clean = {k: v for k, v in env.items() if k != "SDKROOT"}
        try:
            default = subprocess.run(["xcrun", "--sdk", "macosx", "--show-sdk-path"], env=clean,
                                     stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=20).stdout
            default_path = default.decode().strip()
        except (OSError, subprocess.TimeoutExpired):
            default_path = ""
        if default_path and os.path.realpath(default_path) == os.path.realpath(sdk):
            env = clean
    return env


def checksums(root: Path, files: Sequence[str]) -> Dict[str, str]:
    return {f: checksum(root, f) for f in sorted(files) if (root / f).is_file()}
