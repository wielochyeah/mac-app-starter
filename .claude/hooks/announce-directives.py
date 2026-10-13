#!/usr/bin/env python3
"""PostToolUse hook (see .claude/settings.json): delivers every open directive from docs/agents/VORGABEN.md once to
each writing agent.

Sessions and subagents do not re-read VORGABEN.md on their own, so a new directive would otherwise reach only the
session that wrote it. The hook speaks only after writing work (Edit, Write, MultiEdit, NotebookEdit, or a git commit,
merge, push, rebase or cherry-pick through Bash); a reading agent never pays for the text.

- A section "## V<n> (...): <title>" is open until its "Stand:" line says "eingearbeitet". Fenced code is ignored, so
  the template inside VORGABEN.md never counts.
- Only the checked-out file gives directives. The copy on origin's default branch (local ref, no fetch) is not
  reviewed for this branch: a section that is new or different there is only named as "unbestätigt, erst nach
  Merge gültig", never delivered as a directive, so text pushed to origin cannot steer agents on other branches.
- Fingerprint = sha256 of the body without "Stand:" lines; a changed wording is delivered again.
- State per agent in <git-common-dir>/starter-vorgaben/<key>.json, shared by all worktrees of the repository.
- Output stays under MAX_CONTEXT_BYTES; hook output above about 10 KB is cut by the harness.

Python 3.9 standard library only.
"""

import hashlib
import json
import os
import re
import subprocess
import sys
import time

DIRECTIVES = "docs/agents/VORGABEN.md"
MAX_CONTEXT_BYTES = 7000
LOCK_STALE_SECONDS = 10
WRITING_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
GIT_WRITE = re.compile(r"\bgit\s+(?:-C\s+\S+\s+)?(?:commit|merge|push|rebase|cherry-pick)\b")
SECTION = re.compile(r"^## (V\d+)\b(.*)$", re.M)
FENCE = re.compile(r"^```.*?^```[^\n]*$", re.M | re.S)

HEADER = (
    "NEUE VORGABEN DES AUFTRAGGEBERS. Sie gelten ab Erhalt dieser Meldung, gehen dem Auftrag und CLAUDE.md vor und "
    "gelten auch für jeden Subagenten: an jeden gestarteten Subagenten weitergeben. Quelle: docs/agents/VORGABEN.md."
)


def is_writing(payload):
    tool = payload.get("tool_name")
    if tool in WRITING_TOOLS:
        return True
    if tool == "Bash":
        command = (payload.get("tool_input") or {}).get("command") or ""
        return bool(GIT_WRITE.search(command))
    return False


def parse(text):
    """Returns {id: (title, body)} of the open sections."""
    text = FENCE.sub(lambda match: re.sub(r"[^\n]", " ", match.group(0)), text)
    matches = list(SECTION.finditer(text))
    sections = {}
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        body = text[match.end():end]
        stand = [line for line in body.splitlines() if line.strip().startswith("Stand:")]
        if any("eingearbeitet" in line for line in stand):
            continue
        sections[match.group(1)] = (match.group(2).strip(), body.strip())
    return sections


def fingerprint(body):
    kept = [line.rstrip() for line in body.splitlines() if not line.strip().startswith("Stand:")]
    return hashlib.sha256("\n".join(kept).strip().encode("utf-8")).hexdigest()[:16]


def git(root, *args):
    try:
        result = subprocess.run(["git", *args], cwd=root, capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return result.stdout if result.returncode == 0 else None


def read_sources(root):
    """(open sections of the checked-out file, open sections on origin's default branch, that branch)."""
    local = ""
    try:
        with open(os.path.join(root, DIRECTIVES), encoding="utf-8") as handle:
            local = handle.read()
    except OSError:
        pass
    head = git(root, "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD")
    branch = head.strip().rsplit("/", 1)[-1] if head else "main"
    remote = git(root, "show", "origin/{}:{}".format(branch, DIRECTIVES)) or ""
    return parse(local), parse(remote), branch


def unconfirmed(local, remote):
    """Sections that origin has new or in another wording than the checked-out file: {id: (title, fingerprint)}."""
    return {number: (title, fingerprint(body)) for number, (title, body) in remote.items()
            if number not in local or fingerprint(local[number][1]) != fingerprint(body)}


def state_dir(root):
    common = git(root, "rev-parse", "--path-format=absolute", "--git-common-dir")
    if common and common.strip():
        return os.path.join(common.strip(), "starter-vorgaben")
    digest = hashlib.sha256(root.encode("utf-8")).hexdigest()[:16]
    return os.path.join(os.path.expanduser("~"), ".cache", "starter-vorgaben", digest)


def agent_key(payload):
    raw = "|".join(str(payload.get(key) or "") for key in ("session_id", "agent_id", "transcript_path"))
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:24]


def render(fresh, remote=(), branch="main"):
    parts = []
    if fresh:
        parts.append(HEADER)
        for number, (title, body), changed in fresh:
            parts.append("## {}{}{}\n{}".format(number, " " + title if title else "", " (geändert)" if changed else "", body))
    note = ""
    if remote:
        names = "; ".join("{} {}".format(number, title).strip() for number, title in remote)
        note = ("HINWEIS: Auf origin/{} stehen Vorgaben, die dieser Stand nicht oder anders enthält: {}. Unbestätigt, erst "
                "nach Merge gültig: nicht danach handeln, bis sie in diesem Branch in {} stehen.").format(branch, names, DIRECTIVES)
        parts.append(note)
    text = "\n\n".join(parts)
    if len(text.encode("utf-8")) > MAX_CONTEXT_BYTES:
        numbers = ", ".join(number for number, _, _ in fresh)
        text = "{}\n\nVOR DEM NÄCHSTEN SCHRITT VOLLSTÄNDIG LESEN: {} in {}.".format(HEADER, numbers, DIRECTIVES)
        if note:
            text += "\n\n" + note[:1500]
    return text


def announce(root, payload):
    """Returns the text to deliver, or None. Records what was delivered."""
    if not is_writing(payload):
        return None
    sections, remote, branch = read_sources(root)
    pending = unconfirmed(sections, remote)
    if not sections and not pending:
        return None
    directory = state_dir(root)
    os.makedirs(directory, mode=0o700, exist_ok=True)
    path = os.path.join(directory, agent_key(payload) + ".json")
    lock = path + ".lock"
    try:
        if os.path.exists(lock) and time.time() - os.path.getmtime(lock) > LOCK_STALE_SECONDS:
            os.remove(lock)
        handle = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except OSError:
        return None  # a parallel tool call of the same agent holds the lock; it delivers
    try:
        os.close(handle)
        try:
            with open(path, encoding="utf-8") as stream:
                seen = json.load(stream)
        except (OSError, ValueError):
            seen = {}
        fresh = []
        for number in sorted(sections, key=lambda key: int(key[1:])):
            title, body = sections[number]
            digest = fingerprint(body)
            if seen.get(number) != digest:
                fresh.append((number, (title, body), number in seen))
                seen[number] = digest
        noted = []
        for number in sorted(pending, key=lambda key: int(key[1:])):
            title, digest = pending[number]
            key = "origin:" + number
            if seen.get(key) != digest:
                noted.append((number, title))
                seen[key] = digest
        if not fresh and not noted:
            return None
        with open(path, "w", encoding="utf-8") as stream:
            json.dump(seen, stream)
        return render(fresh, noted, branch)
    finally:
        try:
            os.remove(lock)
        except OSError:
            pass


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return 0
    if not isinstance(payload, dict):
        return 0
    root = os.path.abspath(os.environ.get("CLAUDE_PROJECT_DIR") or payload.get("cwd") or os.getcwd())
    text = announce(root, payload)
    if text:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": text}}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
