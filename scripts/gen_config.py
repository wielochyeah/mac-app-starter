#!/usr/bin/env python3
"""starter.json -> generated build inputs (never edit the outputs by hand).

Writes into --out (default build/gen):
  AppConfig.swift                      enum AppConfig with app name, ids, version, accent, modules ...
  Info.plist                           bundle keys, LSUIElement (true when the window module is off),
                                       LSMinimumSystemVersion, usage descriptions for listed permissions
  Resources/<lang>.lproj/InfoPlist.strings   localized display name + usage descriptions
                                       (texts from App/Resources/InfoPlist.json)
  App.entitlements                     hardened-runtime entitlements for the listed permissions
                                       (used by build.sh when signing.identity is a Developer ID)
  app.env                              shell variables for scripts/build.sh and scripts/test.sh

The module list comes from starter.json "modules" unless --modules (or $MODULES) overrides it,
e.g. MODULES=window,menubar. Python 3.9 standard library only.
"""
import argparse
import json
import os
import plistlib
import re
import shlex
import sys
from pathlib import Path

# module key -> folder under App/Sources/Modules (also the order used everywhere)
MODULE_DIRS = {
    "window": "Window",
    "menubar": "MenuBar",
    "island": "Island",
    "background": "Background",
    "hotkeys": "Hotkeys",
    "ai": "AI",
    "mlx": "MLX",
    "examples": "Examples",
}
# module -> modules it needs
MODULE_DEPENDS = {"mlx": ["ai"]}
# permission (starter.json "permissions") -> Info.plist usage-description keys it needs
PERMISSION_KEYS = {
    "notifications": [],
    "accessibility": [],
    "inputMonitoring": [],
    "screenRecording": [],
    "microphone": ["NSMicrophoneUsageDescription"],
    "camera": ["NSCameraUsageDescription"],
    "automation": ["NSAppleEventsUsageDescription"],
    "speechRecognition": ["NSSpeechRecognitionUsageDescription"],
    "contacts": ["NSContactsUsageDescription"],
    "calendars": ["NSCalendarsFullAccessUsageDescription"],
    "reminders": ["NSRemindersFullAccessUsageDescription"],
    "photos": ["NSPhotoLibraryUsageDescription"],
    "location": ["NSLocationUsageDescription", "NSLocationWhenInUseUsageDescription"],
    "bluetooth": ["NSBluetoothAlwaysUsageDescription"],
    "localNetwork": ["NSLocalNetworkUsageDescription"],
}
# permission -> hardened-runtime entitlements it needs. Without them macOS silently denies the
# resource once the app is signed with --options runtime (Developer ID path in build.sh).
PERMISSION_ENTITLEMENTS = {
    "microphone": ["com.apple.security.device.audio-input"],
    "camera": ["com.apple.security.device.camera"],
    "automation": ["com.apple.security.automation.apple-events"],
    "contacts": ["com.apple.security.personal-information.addressbook"],
    "calendars": ["com.apple.security.personal-information.calendars"],
    "reminders": ["com.apple.security.personal-information.calendars"],
    "photos": ["com.apple.security.personal-information.photos-library"],
    "location": ["com.apple.security.personal-information.location"],
}
ACCENTS = ["violett", "rot", "blau", "gruen", "orange", "graphit"]
LANGS = ["en", "de"]


class ConfigError(Exception):
    pass


def load_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        raise ConfigError(f"{path} is missing")
    except json.JSONDecodeError as e:
        raise ConfigError(f"{path} is not valid JSON: {e}")


def resolve_modules(config, override):
    modules = config.get("modules", {})
    unknown = [m for m in modules if m not in MODULE_DIRS]
    if unknown:
        raise ConfigError(f"starter.json: unknown module(s) {', '.join(unknown)}; known: {', '.join(MODULE_DIRS)}")
    if override is not None and override.strip():
        wanted = [m.strip().lower() for m in override.split(",") if m.strip()]
        bad = [m for m in wanted if m not in MODULE_DIRS]
        if bad:
            raise ConfigError(f"MODULES: unknown module(s) {', '.join(bad)}; known: {', '.join(MODULE_DIRS)}")
        enabled = set(wanted)
    else:
        enabled = {m for m, on in modules.items() if on is True}
    if "window" not in enabled and "menubar" not in enabled:
        raise ConfigError("at least one of the modules window or menubar must stay enabled (otherwise Settings is unreachable)")
    for m, needs in MODULE_DEPENDS.items():
        for n in needs:
            if m in enabled and n not in enabled:
                raise ConfigError(f"module {m} needs module {n}")
    return [m for m in MODULE_DIRS if m in enabled]


def validate(config):
    app = config.get("app")
    if not isinstance(app, dict):
        raise ConfigError("starter.json: \"app\" section is missing")
    for key in ("name", "bundleId", "version", "build", "minimumMacOS", "accent", "symbol"):
        if key not in app:
            raise ConfigError(f"starter.json: app.{key} is missing")
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9 ]*", app["name"]):
        raise ConfigError("starter.json: app.name must start with a letter and contain only letters, digits, spaces")
    if not re.fullmatch(r"[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+", app["bundleId"]):
        raise ConfigError("starter.json: app.bundleId must look like com.example.app")
    if not re.fullmatch(r"\d+\.\d+(\.\d+)?", app["version"]):
        raise ConfigError("starter.json: app.version must look like 1.0.0")
    if not isinstance(app["build"], int) or app["build"] < 1:
        raise ConfigError("starter.json: app.build must be a positive integer")
    if not re.fullmatch(r"\d+\.\d+", str(app["minimumMacOS"])):
        raise ConfigError("starter.json: app.minimumMacOS must look like 26.0")
    if app["accent"] not in ACCENTS:
        raise ConfigError(f"starter.json: app.accent must be one of {', '.join(ACCENTS)}")
    names = app.get("displayName", {})
    for lang in LANGS:
        if not isinstance(names.get(lang, app["name"]), str):
            raise ConfigError(f"starter.json: app.displayName.{lang} must be a string")
    perms = config.get("permissions", [])
    bad = [p for p in perms if p not in PERMISSION_KEYS]
    if bad:
        raise ConfigError(f"starter.json: unknown permission(s) {', '.join(bad)}; known: {', '.join(PERMISSION_KEYS)}")
    anrede = config.get("texts", {}).get("anrede", "du")
    if anrede not in ("du", "sie"):
        raise ConfigError("starter.json: texts.anrede must be du or sie")
    links = app.get("links", [])
    if not isinstance(links, list):
        raise ConfigError("starter.json: app.links must be a list")
    for i, link in enumerate(links):
        title = link.get("title") if isinstance(link, dict) else None
        if not isinstance(title, dict) or not all(isinstance(title.get(l), str) and title.get(l) for l in LANGS):
            raise ConfigError(f"starter.json: app.links[{i}].title needs en and de")
        if not re.fullmatch(r"(https://|mailto:)\S+", str(link.get("url", ""))):
            raise ConfigError(f"starter.json: app.links[{i}].url must start with https:// or mailto:")


def swift_str(s):
    return json.dumps(s, ensure_ascii=False)


def app_config_swift(config, modules):
    app = config["app"]
    names = app.get("displayName", {})
    texts = config.get("texts", {})
    langs = [l for l in texts.get("languages", LANGS) if l in LANGS] or LANGS
    signing = config.get("signing", {})
    lines = [
        "// Generated by scripts/gen_config.py from starter.json. Do not edit; change starter.json and rebuild.",
        "",
        "nonisolated enum AppConfig {",
        f"    static let name = {swift_str(app['name'])}",
        f"    static let bundleId = {swift_str(app['bundleId'])}",
        "    static let displayName: (en: String, de: String) = ("
        f"en: {swift_str(names.get('en', app['name']))}, de: {swift_str(names.get('de', app['name']))})",
        f"    static let version = {swift_str(app['version'])}",
        f"    static let build = {int(app['build'])}",
        f"    static let minimumMacOS = {swift_str(str(app['minimumMacOS']))}",
        f"    static let accent: AccentName = .{app['accent']}",
        f"    static let symbol = {swift_str(app['symbol'])}",
        f"    static let copyright = {swift_str(app.get('copyright', ''))}",
        "    /// starter.json app.links (About pane): title per language and URL.",
        "    static let links: [(en: String, de: String, url: String)] = ["
        + ", ".join(f"(en: {swift_str(l['title']['en'])}, de: {swift_str(l['title']['de'])}, url: {swift_str(l['url'])})"
                    for l in app.get("links", []))
        + "]",
        f"    static let enabledModules: Set<String> = [{', '.join(swift_str(m) for m in modules)}]",
        f"    static let permissions: [String] = [{', '.join(swift_str(p) for p in config.get('permissions', []))}]",
        f"    static let languages: [Lang] = [{', '.join('.' + l for l in langs)}]",
        f"    static let anrede = {swift_str(texts.get('anrede', 'du'))}",
        f"    static let starterVersion = {swift_str(config.get('starter', {}).get('version', '0.0.0'))}",
        f"    static let signingIdentity = {swift_str(signing.get('identity', '-'))}",
        "}",
        "",
    ]
    return "\n".join(lines)


def usage_keys(config):
    keys = []
    for p in config.get("permissions", []):
        for k in PERMISSION_KEYS[p]:
            if k not in keys:
                keys.append(k)
    return keys


def entitlements(config):
    out = {}
    for p in config.get("permissions", []):
        for key in PERMISSION_ENTITLEMENTS.get(p, []):
            out[key] = True
    return out


def info_plist(config, modules, texts):
    app = config["app"]
    names = app.get("displayName", {})
    plist = {
        "CFBundleDevelopmentRegion": "en",
        "CFBundleDisplayName": names.get("en", app["name"]),
        "CFBundleExecutable": app["name"],
        "CFBundleIconFile": "AppIcon",
        "CFBundleIdentifier": app["bundleId"],
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleLocalizations": list(LANGS),
        "CFBundleName": app["name"],
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": app["version"],
        "CFBundleVersion": str(app["build"]),
        "LSApplicationCategoryType": app.get("category", "public.app-category.productivity"),
        "LSMinimumSystemVersion": str(app["minimumMacOS"]),
        "LSUIElement": "window" not in modules,
        "NSHighResolutionCapable": True,
        "NSHumanReadableCopyright": app.get("copyright", ""),
        "NSPrincipalClass": "NSApplication",
        "NSSupportsAutomaticGraphicsSwitching": True,
    }
    for key in usage_keys(config):
        entry = texts.get(key)
        if not isinstance(entry, dict) or not all(isinstance(entry.get(l), str) and entry.get(l).strip() for l in LANGS):
            raise ConfigError(f"App/Resources/InfoPlist.json: {key} needs non-empty \"en\" and \"de\" texts "
                              f"(a listed permission uses it)")
        plist[key] = entry["en"]
    return plist


def strings_escape(s):
    return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")


def infoplist_strings(config, texts, lang):
    app = config["app"]
    names = app.get("displayName", {})
    pairs = [("CFBundleDisplayName", names.get(lang, app["name"])), ("CFBundleName", app["name"])]
    for key in usage_keys(config):
        pairs.append((key, texts[key][lang]))
    out = ["/* Generated by scripts/gen_config.py from starter.json and App/Resources/InfoPlist.json. Do not edit. */"]
    out += [f"\"{k}\" = \"{strings_escape(v)}\";" for k, v in pairs]
    return "\n".join(out) + "\n"


def write_if_changed(path, data):
    """Keeps the file (and its mtime) when nothing changed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(data, str):
        data = data.encode("utf-8")
    if path.exists() and path.read_bytes() == data:
        return
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_bytes(data)
    os.replace(tmp, path)


def generate(root, out, override=None):
    root = Path(root)
    out = Path(out)
    config = load_json(root / "starter.json")
    validate(config)
    modules = resolve_modules(config, override)
    texts_path = root / "App" / "Resources" / "InfoPlist.json"
    texts = load_json(texts_path) if texts_path.exists() else {}
    write_if_changed(out / "AppConfig.swift", app_config_swift(config, modules))
    write_if_changed(out / "Info.plist", plistlib.dumps(info_plist(config, modules, texts), sort_keys=True))
    write_if_changed(out / "App.entitlements", plistlib.dumps(entitlements(config), sort_keys=True))
    for lang in LANGS:
        write_if_changed(out / "Resources" / f"{lang}.lproj" / "InfoPlist.strings", infoplist_strings(config, texts, lang))
    app = config["app"]
    env = {
        "APP_NAME": app["name"],
        "BUNDLE_ID": app["bundleId"],
        "APP_VERSION": app["version"],
        "MIN_MACOS": str(app["minimumMacOS"]),
        "MODULES_ENABLED": " ".join(modules),
        "MODULE_DIRS_ENABLED": " ".join(MODULE_DIRS[m] for m in modules),
        "MODULE_FLAGS": " ".join("-D MODUL_" + m.upper() for m in modules),
        "SIGN_IDENTITY": config.get("signing", {}).get("identity", "-") or "-",
    }
    write_if_changed(out / "app.env", "".join(f"{k}={shlex.quote(v)}\n" for k, v in env.items()))
    return modules


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    p.add_argument("--out", default=None, help="output dir (default <root>/build/gen)")
    p.add_argument("--modules", default=os.environ.get("MODULES"), help="comma list overriding starter.json modules")
    args = p.parse_args(argv)
    out = args.out or os.path.join(args.root, "build", "gen")
    try:
        modules = generate(args.root, out, args.modules)
    except ConfigError as e:
        print(f"gen_config: {e}", file=sys.stderr)
        return 2
    print(f"gen_config: modules {', '.join(modules)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
