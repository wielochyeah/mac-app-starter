#!/usr/bin/env python3
"""PreToolUse hook on Bash (see .claude/settings.json): refuses git commands that skip the Git hooks.

The deny patterns in settings.json match text, so combined short flags (`git commit -anm x`), options before the
subcommand (`git -C . commit -n`) and `git -C . config core.hooksPath` slip through them. This hook reads the git
argument list the way git does and refuses:
  - commit, merge, push, am, rebase, cherry-pick or revert with --no-verify or an abbreviation of it,
  - commit with -n, also inside a group of short flags,
  - any change of core.hooksPath: `git config …` that is not a read, `git -c core.hooksPath=…`, and the GIT_CONFIG_*
    variables in front of a command.
It also looks into `sh -c`, `bash -c` and `zsh -c`. Reading the value (`git config --get core.hooksPath`) stays allowed.
A determined script can still get past it; CI repeats every check (`.github/workflows/ci.yml`).

Python 3.9 standard library only.
"""

import json
import os
import re
import shlex
import sys

VERIFY_COMMANDS = {"commit", "merge", "push", "am", "rebase", "cherry-pick", "revert"}
# Short options of git commit that take a value; what follows them in a group is that value.
COMMIT_VALUE_FLAGS = set("mFcCtSu")
# Global options of git that take a separate value.
GLOBAL_VALUE_OPTIONS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path", "--config-env",
                        "--super-prefix", "--list-cmds", "--attr-source"}
CONFIG_READS = {"--get", "--get-all", "--get-regexp", "--get-urlmatch", "--get-color", "--get-colorbool", "-l", "--list",
                "get", "list"}
CONFIG_WRITES = {"--unset", "--unset-all", "--add", "--replace-all", "--rename-section", "--remove-section", "--edit", "-e",
                 "set", "unset", "rename-section", "remove-section", "edit"}
PREFIX_WORDS = {"command", "exec", "env", "nice", "time", "builtin", "nohup"}
SHELLS = {"sh", "bash", "zsh", "dash"}
SEPARATORS = {";", "&&", "||", "|", "&", "|&", "(", ")", "\n"}
REASON = (
    "Gesperrt: dieser Befehl umgeht die Git-Hooks ({}). Die Hooks prüfen Autor, Format und make check; "
    "ein roter Hook wird repariert, nicht umgangen (CLAUDE.md, CONTRIBUTING.md)."
)


def is_hooks_path(text):
    return "hookspath" in text.lower()


def split_commands(command):
    """Token lists of the simple commands in a shell line (split at ; && || | & and parentheses)."""
    lexer = shlex.shlex(command.replace("\n", " ; "), posix=True, punctuation_chars=";&|()")
    lexer.whitespace_split = True
    lexer.commenters = ""
    try:
        tokens = list(lexer)
    except ValueError:
        tokens = command.split()
    out, current = [], []
    for token in tokens:
        if token in SEPARATORS or set(token) <= set(";&|()"):
            if current:
                out.append(current)
            current = []
        else:
            current.append(token)
    if current:
        out.append(current)
    return out


def check_commit_shorts(arg):
    """True when a short-option group of git commit contains n before any option that takes a value."""
    for char in arg[1:]:
        if char == "n":
            return True
        if char in COMMIT_VALUE_FLAGS:
            return False
    return False


def check_git(args):
    """The reason when the git argument list skips the hooks, else None. args excludes the word git."""
    index = 0
    while index < len(args):
        arg = args[index]
        if not arg.startswith("-"):
            break
        if arg in ("-c", "--config-env") and index + 1 < len(args):
            if is_hooks_path(args[index + 1]):
                return "git -c core.hooksPath"
            index += 2
            continue
        if arg.startswith("-c") and is_hooks_path(arg) or arg.startswith("--config-env=") and is_hooks_path(arg):
            return "git -c core.hooksPath"
        index += 2 if arg in GLOBAL_VALUE_OPTIONS else 1
    if index >= len(args):
        return None
    command, rest = args[index], args[index + 1:]
    if command == "config":
        if not any(is_hooks_path(arg) for arg in rest):
            return None
        positional = [arg for arg in rest if not arg.startswith("-")]
        writes = any(arg in CONFIG_WRITES for arg in rest)
        reads = any(arg in CONFIG_READS for arg in rest) or len(positional) == 1
        return "core.hooksPath ändern" if writes or not reads else None
    if command not in VERIFY_COMMANDS:
        return None
    skip_value = False
    for arg in rest:
        if skip_value:
            skip_value = False
            continue
        if arg == "--":
            break
        if arg.startswith("--no-v") and "--no-verify".startswith(arg.split("=", 1)[0]):
            return "--no-verify"
        if command == "commit" and re.match(r"^-[A-Za-z]+$", arg):
            if check_commit_shorts(arg):
                return "git commit -n"
            if arg[-1] in COMMIT_VALUE_FLAGS:
                skip_value = True
    return None


def check(command, depth=0):
    """The reason when a shell line skips the Git hooks, else None."""
    for tokens in split_commands(command):
        position = 0
        while position < len(tokens):
            token = tokens[position]
            if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", token):
                name, _, value = token.partition("=")
                if name.startswith("GIT_CONFIG") and is_hooks_path(value):
                    return "GIT_CONFIG_* mit core.hooksPath"
            elif token not in PREFIX_WORDS:
                break
            position += 1
        if position >= len(tokens):
            continue
        word = os.path.basename(tokens[position])
        rest = tokens[position + 1:]
        if word == "git":
            reason = check_git(rest)
            if reason:
                return reason
        elif word in SHELLS and depth < 3:
            for index, arg in enumerate(rest):
                if arg.startswith("-") and "c" in arg[1:] and not arg.startswith("--") and index + 1 < len(rest):
                    reason = check(rest[index + 1], depth + 1)
                    if reason:
                        return reason
                    break
    return None


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return 0
    if not isinstance(payload, dict) or payload.get("tool_name") != "Bash":
        return 0
    command = (payload.get("tool_input") or {}).get("command")
    if not isinstance(command, str):
        return 0
    reason = check(command)
    if reason:
        decision = {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": REASON.format(reason)}
        print(json.dumps({"hookSpecificOutput": decision}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
