#!/usr/bin/env python3
"""PreToolUse hook on Bash (see .claude/settings.json): refuses commands that skip the Git hooks or that turn an allowed
command into something else.

The permission rules in settings.json match text: combined short flags (`git commit -anm x`), options before the
subcommand (`git -C . commit -n`), extra goals or variables after an allowed `make build MODULES=…` and options that run
programs slip through them. This hook reads the argument list the way git and make do and refuses:
  - commit, merge, push, am, rebase, cherry-pick or revert with --no-verify or an abbreviation of it, commit with -n
    (also inside a group of short flags), and any change of core.hooksPath (`git config …` that is not a read,
    `git -c core.hooksPath=…`, GIT_CONFIG_* variables);
  - `git -c` with any key but a harmless display setting (an alias with ! or a pager runs a program), --config-env and
    --exec-path; fetch, pull, clone and ls-remote with --upload-pack, -u, --config or -c (clone also --template);
    push with --receive-pack or --exec; diff, log and show with --no-index, --ext-diff or --output; difftool with -x,
    --extcmd or --tool;
  - variables in front of a command that make git or make run something else (GIT_CONFIG_*, GIT_SSH_COMMAND,
    GIT_EXTERNAL_DIFF, GIT_EXEC_PATH, PAGER, EDITOR, MAKEFLAGS …), also through export;
  - make with more than one goal, with an option, or with a variable that is not in MAKE_VARS or not in its form;
  - a program under build/ started with --selftest from another path than build/<Name>.app/Contents/MacOS/<Name>
    (.. included), or with more than one test id after it.
It also looks into `sh -c`, `bash -c` and `zsh -c`. Reading values (`git config --get core.hooksPath`) stays allowed.
This is best effort: a script can still call git or make another way. CI repeats every check (.github/workflows/ci.yml).

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
# `git -c <key>=…` stays allowed for these keys only: they change what git shows, never what it runs.
SAFE_CONFIG_KEYS = re.compile(r"^(?:color\.[a-z.]+|core\.quotepath|advice\.[a-z]+|log\.[a-z]+|diff\.noprefix)$", re.I)
# Options of a subcommand that run a program or read and write outside the repository. A short option also counts
# inside a group (-qu).
DANGEROUS_OPTIONS = {
    "fetch": {"--upload-pack", "-u", "--config", "-c"},
    "pull": {"--upload-pack", "-u", "--config", "-c"},
    "clone": {"--upload-pack", "-u", "--config", "-c", "--template"},
    "ls-remote": {"--upload-pack", "--exec"},
    "push": {"--receive-pack", "--exec"},
    "diff": {"--no-index", "--ext-diff", "--output"},
    "log": {"--ext-diff", "--output"},
    "show": {"--ext-diff", "--output"},
    "difftool": {"-x", "--extcmd", "-t", "--tool"},
}
# Variables in front of a command (or exported) that change which program git or make runs.
DANGEROUS_ENV = re.compile(
    r"^(?:GIT_CONFIG\w*|GIT_EXTERNAL_DIFF|GIT_SSH|GIT_SSH_COMMAND|GIT_ASKPASS|SSH_ASKPASS|GIT_EDITOR|GIT_SEQUENCE_EDITOR|"
    r"EDITOR|VISUAL|GIT_EXEC_PATH|GIT_TEMPLATE_DIR|GIT_PROXY_COMMAND|GIT_DIR|GIT_WORK_TREE|GIT_TRACE\w*|"
    r"MAKEFLAGS|MAKEFILES|MFLAGS|GNUMAKEFLAGS|MAKE|BASH_ENV|ENV|ZDOTDIR|PYTHONPATH|PYTHONSTARTUP|PYTHONHOME|"
    r"LD_PRELOAD|DYLD_\w+)$")
PAGER_ENV = {"GIT_PAGER", "PAGER"}
# make: the variables of the Makefile and the environment the scripts read, each in its only allowed form.
MAKE_VARS = {
    "MODULES": r"[a-z0-9_]+(,[a-z0-9_]+)*",
    "CONFIG": r"debug|release",
    "ONLY": r"[A-Za-z0-9 ._/:-]+",
    "SHOTS_LANG": r"en|de",
    "SHOTS_APPEARANCE": r"light|dark",
    "NO_BUILD": r"[01]",
    "STRICT": r"[01]",
    "CHECK_FLAGS": r"(--ci|--streng)( (--ci|--streng))?",
}
MAKE_ENV = dict(MAKE_VARS, **{
    "SIGN_IDENTITY": r"-|[A-Za-z0-9 .:()_,-]+",
    "NOTARY_PROFILE": r"[A-Za-z0-9._-]+",
    "README_MAX_WIDTH": r"[0-9]+",
    "STARTER_PROBE_KEEP": r"[01]",
    "STARTER_PROBE_JOBS": r"[0-9]+",
    "DEVELOPER_DIR": r"/Library/Developer/CommandLineTools|/Applications/Xcode[A-Za-z0-9._-]*\.app/Contents/Developer",
    "SDKROOT": r"/Library/Developer/CommandLineTools/SDKs/MacOSX[0-9.]*\.sdk|"
               r"/Applications/Xcode[A-Za-z0-9._-]*\.app/Contents/Developer/Platforms/MacOSX\.platform/Developer/SDKs/"
               r"MacOSX[0-9.]*\.sdk",
})
MAKE_WORDS = {"make", "gmake"}
SELFTEST_PATH = re.compile(r"^(?:\./)?build/[^/]+\.app/Contents/MacOS/[^/]+$")
SELFTEST_ID = re.compile(r"^[A-Za-z0-9._-]+$")
PREFIX_WORDS = {"command", "exec", "env", "nice", "time", "builtin", "nohup"}
EXPORT_WORDS = {"export", "declare", "typeset", "local", "readonly"}
SHELLS = {"sh", "bash", "zsh", "dash"}
SEPARATORS = {";", "&&", "||", "|", "&", "|&", "(", ")", "\n"}
ASSIGNMENT = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", re.S)

HOOKS = (
    "Gesperrt: dieser Befehl umgeht die Git-Hooks ({}). Die Hooks prüfen Autor, Format und make check; "
    "ein roter Hook wird repariert, nicht umgangen (CLAUDE.md, CONTRIBUTING.md)."
)
RUNS = (
    "Gesperrt: {} kann ein anderes Programm starten oder Dateien außerhalb des Repositorys lesen oder schreiben. "
    "Den Befehl ohne diese Option ausführen; braucht es sie wirklich, führt eine Person ihn im eigenen Terminal aus."
)
MAKE = (
    "Gesperrt: make ruft nur ein Ziel auf, ohne Optionen, mit den Variablen " + ", ".join(sorted(MAKE_VARS))
    + " in ihrer erlaubten Form ({}). Mehrere Ziele nacheinander aufrufen (make check-rules && make check-texts)."
)
SELFTEST = (
    "Gesperrt: der Selbsttest läuft nur mit build/<Name>.app/Contents/MacOS/<Name> aus diesem Repository, ohne .. im "
    "Pfad ({})."
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


def config_key(assignment):
    return assignment.split("=", 1)[0].strip()


def dangerous_option(command, arg):
    """The option of `arg` that DANGEROUS_OPTIONS lists for this subcommand, else None."""
    options = DANGEROUS_OPTIONS.get(command)
    if not options:
        return None
    name = arg.split("=", 1)[0]
    if name in options:
        return name
    if arg.startswith("--"):
        return None
    if re.match(r"^-[A-Za-z]+", arg):
        for option in options:
            if len(option) == 2 and option[1] in arg[1:]:
                return option
    return None


def check_git(args):
    """(template, detail) when the git argument list skips the hooks or runs a program, else None. args excludes git."""
    index = 0
    while index < len(args):
        arg = args[index]
        if not arg.startswith("-"):
            break
        if arg in ("-c", "--config-env") or arg.startswith("-c") or arg.startswith("--config-env="):
            value = args[index + 1] if arg in ("-c", "--config-env") and index + 1 < len(args) else \
                arg[2:] if arg.startswith("-c") else arg.split("=", 1)[1]
            if is_hooks_path(value) or is_hooks_path(arg):
                return HOOKS, "git -c core.hooksPath"
            if arg.startswith("--config-env"):
                return RUNS, "git --config-env"
            if not SAFE_CONFIG_KEYS.match(config_key(value)):
                return RUNS, "git -c {}".format(config_key(value) or "…")
            index += 2 if arg in ("-c", "--config-env") else 1
            continue
        if arg == "--exec-path" or arg.startswith("--exec-path="):
            return RUNS, "git --exec-path"
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
        return (HOOKS, "core.hooksPath ändern") if writes or not reads else None
    for arg in rest:
        if arg == "--":
            break
        option = dangerous_option(command, arg)
        if option:
            return RUNS, "git {} {}".format(command, option)
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
            return HOOKS, "--no-verify"
        if command == "commit" and re.match(r"^-[A-Za-z]+$", arg):
            if check_commit_shorts(arg):
                return HOOKS, "git commit -n"
            if arg[-1] in COMMIT_VALUE_FLAGS:
                skip_value = True
    return None


def check_env(name, value):
    """(template, detail) for a variable that changes which program runs, else None."""
    if name.startswith("GIT_CONFIG") and is_hooks_path(value):
        return HOOKS, "GIT_CONFIG_* mit core.hooksPath"
    if name in PAGER_ENV and value not in ("", "cat"):
        return RUNS, "{}={}".format(name, value)
    if DANGEROUS_ENV.match(name):
        return RUNS, "die Variable {}".format(name)
    return None


def check_make(assignments, args):
    """(template, detail) when make gets more than one goal, an option or a variable outside MAKE_VARS, else None."""
    for name, value in assignments:
        pattern = MAKE_ENV.get(name)
        if pattern is None:
            return MAKE, "Variable {} davor".format(name)
        if not re.fullmatch(pattern, value):
            return MAKE, "{}={}".format(name, value)
    goals = []
    for arg in args:
        match = ASSIGNMENT.match(arg)
        if match:
            name, value = match.group(1), match.group(2)
            if name not in MAKE_VARS:
                return MAKE, "Variable {}".format(name)
            if not re.fullmatch(MAKE_VARS[name], value):
                return MAKE, "{}={}".format(name, value)
        elif arg.startswith("-"):
            return MAKE, "Option {}".format(arg)
        else:
            goals.append(arg)
    if len(goals) > 1:
        return MAKE, "Ziele {}".format(" ".join(goals))
    return None


def check_selftest(path, args):
    """The allow rule `STARTER_HEADLESS=1 build/*.app/Contents/MacOS/* --selftest` matches text, and its * also
    matches ../ and further arguments: a program under build/ runs only as build/<Name>.app/Contents/MacOS/<Name>
    with --selftest and at most one test id. Other paths are no business of this rule (they are asked for)."""
    if not (path.startswith("build/") or path.startswith("./build/")):
        return None
    if not any(arg.startswith("--selftest") for arg in args):
        return None
    if ".." in path.split("/") or not SELFTEST_PATH.match(path):
        return SELFTEST, path
    if args[0] != "--selftest" or len(args) > 2 or (len(args) == 2 and not SELFTEST_ID.match(args[1])):
        return SELFTEST, " ".join([path] + args)
    return None


def check_tokens(tokens, depth):
    assignments = []
    position = 0
    while position < len(tokens):
        token = tokens[position]
        match = ASSIGNMENT.match(token)
        if match:
            assignments.append((match.group(1), match.group(2)))
        elif token not in PREFIX_WORDS:
            break
        position += 1
    for name, value in assignments:
        found = check_env(name, value)
        if found:
            return found
    if position >= len(tokens):
        return None
    word = os.path.basename(tokens[position])
    rest = tokens[position + 1:]
    if word in EXPORT_WORDS:
        for arg in rest:
            match = ASSIGNMENT.match(arg)
            found = check_env(match.group(1), match.group(2)) if match else None
            if found:
                return found
        return None
    if word == "git":
        return check_git(rest)
    if word in MAKE_WORDS:
        return check_make(assignments, rest)
    if word in SHELLS and depth < 3:
        for index, arg in enumerate(rest):
            if arg.startswith("-") and "c" in arg[1:] and not arg.startswith("--") and index + 1 < len(rest):
                return check_line(rest[index + 1], depth + 1)
        return None
    return check_selftest(tokens[position], rest)


def check_line(command, depth=0):
    for tokens in split_commands(command):
        found = check_tokens(tokens, depth)
        if found:
            return found
    return None


def check(command):
    """The reason when a shell line must not run, else None."""
    found = check_line(command)
    if not found:
        return None
    template, detail = found
    return template.format(detail)


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
        decision = {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": reason}
        print(json.dumps({"hookSpecificOutput": decision}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
