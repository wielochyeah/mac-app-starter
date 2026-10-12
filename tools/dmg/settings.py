# dmgbuild settings for scripts/dmg.sh (port of VoiceBud packaging/dmg/settings.py, MIT,
# Copyright (c) 2026 Anas Riad). dmgbuild runs this file with a `defines` dict from -D options:
#   app=<path to .app>  background=<.tiff>  layout=<tools/dmg/layout.json>  volicon=<.icns, optional>
import json
import os.path

with open(defines["layout"], encoding="utf-8") as _f:
    _layout = json.load(_f)

app = defines["app"]
_app_name = os.path.basename(app.rstrip("/"))
_link = _layout["applicationsName"]
_w = _layout["window"]

files = [app]
# The link keeps the name "Applications" in every language: Finder does not localise a symlink's
# name, and a German "Programme" would confuse English users (VoiceBud shipped that).
symlinks = {_link: "/Applications"}
icon = defines.get("volicon") or None
background = defines["background"]
# No hide_extensions: it sets Finder info on the app, and a signed app with Finder info fails the
# strict signature check (people would see "damaged" instead of "Open Anyway"). Finder hides
# ".app" on its own.
window_rect = ((_w["x"], _w["y"]), (_w["width"], _w["height"] + _w["titlebar"]))
icon_locations = {_app_name: tuple(_layout["app"]), _link: tuple(_layout["applications"])}
default_view = "icon-view"
icon_size = _layout["iconSize"]
text_size = _layout["textSize"]
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
# Writable first: scripts/dmg.sh hides the background file, then compresses (ULMO, else UDZO).
format = "UDRW"
filesystem = "HFS+"
