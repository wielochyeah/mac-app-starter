#!/usr/bin/env python3
"""Packaging helpers for scripts/icon.sh, scripts/dmg.sh and scripts/notarize.sh.

Commands (python3 tools/packaging/pkg.py <command> ...):
  env                         shell assignments PKG_* from starter.json (eval them in zsh)
  macho <bundle>              every Mach-O file inside a bundle, deepest path first
  minos <app>                 compares LSMinimumSystemVersion with the newest minos of the bundled
                              binaries (LC_BUILD_VERSION); exit 1 when a binary needs a newer macOS
  entitlements <out.plist>    hardened-runtime entitlements for the distributable: the generated
                              build/gen/App.entitlements (from the listed permissions) plus
                              tools/entitlements.plist (project additions; they win)
  notary <file> [--identity X] [--profile P] [--team T]
                              checks the signing setup and prints the notarization commands for an
                              .app or .dmg, one per line, tab-separated arguments

Environment overrides: DMG_LANG (en|de|both), NOTARY_PROFILE, SIGN_IDENTITY.
Python 3.9 standard library only.
"""
import json
import os
import plistlib
import re
import shlex
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
LANGS = ("en", "de")
MACHO_MAGICS = {
    b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe",  # 64/32-bit, little endian
    b"\xfe\xed\xfa\xcf", b"\xfe\xed\xfa\xce",  # big endian
    b"\xca\xfe\xba\xbe", b"\xca\xfe\xba\xbf",  # universal (fat, fat64)
}


class PackagingError(Exception):
    pass


# MARK: config

def load_config(root=ROOT):
    path = Path(root) / "starter.json"
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        raise PackagingError(f"{path} is missing")
    except json.JSONDecodeError as e:
        raise PackagingError(f"{path} is not valid JSON: {e}")


def settings(config, environ=None):
    """The values the packaging scripts need, with environment overrides applied."""
    environ = os.environ if environ is None else environ
    app = config.get("app", {})
    signing = config.get("signing", {})
    texts = config.get("texts", {})
    names = app.get("displayName", {})
    name = app.get("name", "App")
    langs = [l for l in texts.get("languages", list(LANGS)) if l in LANGS] or list(LANGS)
    dmg_lang = environ.get("DMG_LANG") or ("both" if len(langs) > 1 else langs[0])
    if dmg_lang not in ("en", "de", "both"):
        raise PackagingError(f"DMG_LANG must be en, de or both (got {dmg_lang})")
    anrede = texts.get("anrede", "du")
    if anrede not in ("du", "sie"):
        raise PackagingError(f"texts.anrede in starter.json must be du or sie (got {anrede})")
    identity = environ.get("SIGN_IDENTITY") or signing.get("identity") or "-"
    notarize = bool(signing.get("notarize", False))
    return {
        "NAME": name,
        "DISPLAY_EN": names.get("en", name),
        "DISPLAY_DE": names.get("de", name),
        "BUNDLE_ID": app.get("bundleId", ""),
        "VERSION": str(app.get("version", "0.0.0")),
        "BUILD": str(app.get("build", 1)),
        "MIN_MACOS": str(app.get("minimumMacOS", "26.0")),
        "ACCENT": app.get("accent", "violett"),
        "SYMBOL": app.get("symbol", "sparkles"),
        "DMG_LANG": dmg_lang,
        "ANREDE": anrede,
        "IDENTITY": identity,
        "TEAM_ID": signing.get("teamId", "") or "",
        "NOTARIZE": "1" if notarize and identity != "-" else "0",
        "NOTARIZE_WANTED": "1" if notarize else "0",
        "NOTARY_PROFILE": environ.get("NOTARY_PROFILE") or signing.get("notaryProfile", "") or "",
    }


def shell_env(values):
    return "".join(f"PKG_{k}={shlex.quote(v)}\n" for k, v in values.items())


# MARK: Mach-O and minimum macOS

def is_macho(path):
    try:
        with open(path, "rb") as f:
            return f.read(4) in MACHO_MAGICS
    except OSError:
        return False


def macho_files(bundle):
    """Every Mach-O file inside the bundle (symlinks skipped), deepest first, then by path."""
    found = []
    for dirpath, _dirs, files in os.walk(bundle):
        for name in files:
            p = os.path.join(dirpath, name)
            if not os.path.islink(p) and is_macho(p):
                found.append(p)
    return sorted(found, key=lambda p: (-p.count(os.sep), p))


def parse_minos(otool_text):
    """macOS minimum versions from `otool -l` output (LC_BUILD_VERSION with platform 1 = macOS,
    and the older LC_VERSION_MIN_MACOSX). One entry per load command found."""
    out = []
    block = None
    for raw in otool_text.splitlines():
        line = raw.strip()
        if line.startswith("cmd "):
            block = {"cmd": line.split()[1]}
            continue
        if block is None:
            continue
        parts = line.split()
        if len(parts) < 2:
            continue
        if block["cmd"] == "LC_BUILD_VERSION":
            if parts[0] == "platform":
                block["platform"] = parts[1]
            elif parts[0] == "minos":
                if block.get("platform") in ("1", "MACOS", "macos"):
                    out.append(parts[1])
                block = None
        elif block["cmd"] == "LC_VERSION_MIN_MACOSX" and parts[0] == "version":
            out.append(parts[1])
            block = None
    return out


def version_tuple(v):
    if not re.fullmatch(r"\d+(\.\d+)*", str(v)):
        raise PackagingError(f"not a version: {v!r}")
    parts = [int(x) for x in str(v).split(".")]
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts)


def check_minos(plist_min, binaries):
    """binaries: {path: [minos, ...]}. Returns (ok, newest, message)."""
    pairs = [(version_tuple(v), v, p) for p, vs in binaries.items() for v in vs]
    if not pairs:
        return False, None, "no macOS minimum found in any binary (otool -l printed no LC_BUILD_VERSION)"
    newest_t, newest, path = max(pairs)
    if newest_t > version_tuple(plist_min):
        return False, newest, (f"{Path(path).name} needs macOS {newest}, but Info.plist promises {plist_min} "
                               f"(LSMinimumSystemVersion). Raise app.minimumMacOS in starter.json to {newest} "
                               f"or rebuild that binary for {plist_min}.")
    return True, newest, f"Info.plist {plist_min}, newest binary minimum {newest}"


def bundle_minos(app):
    binaries = {}
    for f in macho_files(app):
        res = subprocess.run(["otool", "-l", f], capture_output=True, text=True)
        binaries[f] = parse_minos(res.stdout)
    with open(Path(app) / "Contents" / "Info.plist", "rb") as fh:
        plist_min = plistlib.load(fh).get("LSMinimumSystemVersion")
    if not plist_min:
        raise PackagingError(f"{app}: Info.plist has no LSMinimumSystemVersion")
    return check_minos(plist_min, binaries)


# MARK: entitlements

def merged_entitlements(generated_path, extra_path):
    def read(p):
        p = Path(p)
        if not p.exists():
            return {}
        with open(p, "rb") as f:
            data = plistlib.load(f)
        if not isinstance(data, dict):
            raise PackagingError(f"{p} must contain a dictionary")
        return data
    merged = dict(read(generated_path))
    merged.update(read(extra_path))
    return merged


# MARK: notarization

def notary_plan(path, identity, profile, team_id="", bundle_id=""):
    """Checks the setup and returns the commands (lists of arguments) that sign, submit and staple
    `path` (.app or .dmg). Raises PackagingError with a fix when something is missing."""
    path = str(path)
    kind = Path(path).suffix.lower()
    if kind not in (".app", ".dmg"):
        raise PackagingError(f"{path}: only .app and .dmg can be notarized")
    if not identity or identity == "-":
        raise PackagingError(
            "signing.identity in starter.json is \"-\" (ad hoc). Notarization needs a Developer ID "
            "Application certificate: set signing.identity to its name, e.g. "
            "\"Developer ID Application: Your Name (TEAMID1234)\" (security find-identity -v -p codesigning lists it).")
    if not identity.startswith("Developer ID Application") and not re.fullmatch(r"[0-9A-F]{40}", identity):
        raise PackagingError(
            f"signing.identity \"{identity}\" is not a Developer ID Application certificate; Apple notarizes "
            "only those (Apple Development / Mac App Distribution certificates are rejected).")
    if not profile:
        team = team_id or "<TEAMID>"
        raise PackagingError(
            "no notarytool keychain profile. Store one once (asks for an app-specific password, kept in the "
            f"keychain): xcrun notarytool store-credentials \"{bundle_id or 'starter'}-notary\" --apple-id "
            f"<you@example.com> --team-id {team}, then set NOTARY_PROFILE or signing.notaryProfile to that name.")
    cmds = []
    if kind == ".app":
        zip_path = str(Path(path).with_suffix(".notarize.zip"))
        cmds.append(["codesign", "--verify", "--strict", "--deep", path])
        cmds.append(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", path, zip_path])
        cmds.append(["xcrun", "notarytool", "submit", zip_path, "--keychain-profile", profile, "--wait"])
        cmds.append(["xcrun", "stapler", "staple", path])
        cmds.append(["rm", "-f", zip_path])
        cmds.append(["spctl", "--assess", "--type", "execute", "--verbose", path])
    else:
        cmds.append(["codesign", "--force", "--timestamp", "--sign", identity, path])
        cmds.append(["xcrun", "notarytool", "submit", path, "--keychain-profile", profile, "--wait"])
        cmds.append(["xcrun", "stapler", "staple", path])
        cmds.append(["spctl", "--assess", "--type", "open", "--context", "context:primary-signature", "--verbose", path])
    return cmds


# MARK: CLI

def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    cmd, rest = argv[0], argv[1:]
    try:
        if cmd == "env":
            sys.stdout.write(shell_env(settings(load_config())))
        elif cmd == "macho" and len(rest) == 1:
            for f in macho_files(rest[0]):
                print(f)
        elif cmd == "minos" and len(rest) == 1:
            ok, newest, msg = bundle_minos(rest[0])
            print(f"minos: {msg}", file=sys.stdout if ok else sys.stderr)
            return 0 if ok else 1
        elif cmd == "entitlements" and len(rest) == 1:
            data = merged_entitlements(ROOT / "build" / "gen" / "App.entitlements", ROOT / "tools" / "entitlements.plist")
            Path(rest[0]).parent.mkdir(parents=True, exist_ok=True)
            with open(rest[0], "wb") as f:
                plistlib.dump(data, f, sort_keys=True)
            print(f"entitlements: {len(data)} key(s) -> {rest[0]}")
        elif cmd == "notary" and rest:
            s = settings(load_config())
            opts = {"--identity": s["IDENTITY"], "--profile": s["NOTARY_PROFILE"], "--team": s["TEAM_ID"]}
            path = None
            i = 0
            while i < len(rest):
                if rest[i] in opts and i + 1 < len(rest):
                    opts[rest[i]] = rest[i + 1]
                    i += 2
                elif path is None and not rest[i].startswith("--"):
                    path = rest[i]
                    i += 1
                else:
                    raise PackagingError(f"notary: unexpected argument {rest[i]}")
            if path is None:
                raise PackagingError("notary: missing file")
            for c in notary_plan(path, opts["--identity"], opts["--profile"], opts["--team"], s["BUNDLE_ID"]):
                print("\t".join(c))
        else:
            print(__doc__, file=sys.stderr)
            return 2
    except PackagingError as e:
        print(f"packaging: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
