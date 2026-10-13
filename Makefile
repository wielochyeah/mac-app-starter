# mac-app-starter: one entry point for building, testing, rendering and packaging.
# No Xcode, no SwiftPM: scripts/build.sh calls swiftc once (docs/ARCHITEKTUR.md).
#
#   make build MODULES=window,menubar CONFIG=release
#   make shots ONLY=design.
#   make test ONLY=Settings
#
# Recipes run in /bin/sh, so everything that needs no Mac (make check-light) also runs on Linux. The variables
# below reach the scripts as environment, taken literally: $(value …) keeps make from running a "$(shell …)" inside
# a value, and each script checks its value against a strict pattern. CHECK_FLAGS takes only --ci and --streng.

SHELL := /bin/sh
.DEFAULT_GOAL := help
PASS_VARS := MODULES CONFIG ONLY SHOTS_LANG SHOTS_APPEARANCE NO_BUILD
$(foreach v,$(PASS_VARS),$(eval override $(v) := $$(value $(v))))
export $(PASS_VARS) STRICT

CHECK_FLAGS_UNKNOWN := $(filter-out --ci --streng,$(value CHECK_FLAGS))
ifneq ($(strip $(CHECK_FLAGS_UNKNOWN)),)
$(error CHECK_FLAGS kennt nur --ci und --streng, nicht: $(CHECK_FLAGS_UNKNOWN))
endif
CHECK_ARGS := $(foreach flag,$(value CHECK_FLAGS),"$(flag)")

# Runs a script when it exists, otherwise says that it is missing. $(2) holds only checked flags.
define run_script
	@if [ -x "$(1)" ]; then "$(1)" $(2); \
	elif [ -f "$(1)" ]; then python3 "$(1)" $(2); \
	else echo "make: $(1) fehlt (übersprungen)"; fi
endef

.PHONY: help doctor build run test test-python check check-light typecheck shots readme-shots icon dmg notarize \
        rules hooks probe clean check-rules check-texts check-design check-kit

help:
	@echo "make doctor        Werkzeuge prüfen (installiert nichts)"
	@echo "make build         Debug-Build nach build/<Name>.app   (MODULES=a,b  CONFIG=release)"
	@echo "make run           bauen und die App starten (nur für Menschen, nie beim Prüfen)"
	@echo "make test          Swift-Tests (build/tests/run-tests) und Python-Tests   (ONLY=<präfix>)"
	@echo "make test-python   nur die Python-Tests der Werkzeuge"
	@echo "make check         vor jedem Push: Regeln, Texte, Design, Kit, Build und Tests, Warnungen als Fehler"
	@echo "make check-light   alles aus make check, was ohne Mac läuft (Regeln, Texte, Design, Kit, Python-Tests)"
	@echo "make check-rules   CLAUDE.md Teil A und Wortlisten passen zu rules/"
	@echo "make check-texts   Texte in beiden Sprachen, keine Texte in Views   (CHECK_FLAGS=--ci oder --streng)"
	@echo "make check-design  nur Design-Tokens außerhalb von Kit/Design   (CHECK_FLAGS=--ci oder --streng)"
	@echo "make check-kit     Kit-Dateien, Bauunterlagen, Prüfungen in Makefile, Hooks und CI"
	@echo "make typecheck     jede Modul-Kombination der CI prüfen, ohne zu bauen   (MODULES=a,b für eine)"
	@echo "make shots         jede Szene nach build/shots (+ index.html)   (ONLY=<präfix>  SHOTS_LANG  SHOTS_APPEARANCE)"
	@echo "make readme-shots  Bilder aus docs/screenshots/list.txt nach docs/screenshots (höchstens 1200 px breit)"
	@echo "make icon          App-Symbol nach App/Resources/AppIcon.icns"
	@echo "make dmg           Release-Build und gestaltetes DMG nach build/dmg"
	@echo "make notarize      ein DMG aus make dmg erneut zur Notarisierung einreichen"
	@echo "make rules         CLAUDE.md Teil A und Wortlisten aus rules/ schreiben"
	@echo "make hooks         scripts/hooks als Git-Hooks einrichten, Commit-Identität melden"
	@echo "make probe         Probe der Vorlage: Kopie, init, make check, jedes Modul entfernen (langsam, nur im Starter)"
	@echo "make clean         build/ löschen"

doctor:
	@scripts/doctor.sh

build:
	@scripts/build.sh

run:
	@scripts/run.sh

test:
	@scripts/test.sh

test-python:
	@python3 scripts/test_python.py

typecheck:
	@scripts/typecheck.sh

shots:
	@scripts/render.sh

# Pictures of docs/screenshots/list.txt into docs/screenshots/, at most 1200 px wide (sips), icon and
# DMG previews drawn by the packaging tools (scripts/readme-shots.sh).
readme-shots:
	@scripts/readme-shots.sh

icon:
	$(call run_script,scripts/icon.sh)

dmg:
	$(call run_script,scripts/dmg.sh)

notarize:
	$(call run_script,scripts/notarize.sh)

rules:
	$(call run_script,scripts/rules_sync.py)

check-rules:
	$(call run_script,scripts/rules_sync.py,--check)

check-texts:
	$(call run_script,scripts/check_texts.py,$(CHECK_ARGS))

check-design:
	$(call run_script,scripts/check_design.py,$(CHECK_ARGS))

check-kit:
	$(call run_script,scripts/check_kit.py)

# make check builds and tests with warnings as errors (rule A-02); a plain make build stays tolerant.
check: override STRICT := 1
check: check-rules check-texts check-design check-kit build test

# What the pre-push hook runs without a Mac (scripts/hooks/pre-push): no Swift compiler, no build.
check-light: check-rules check-texts check-design check-kit test-python

probe:
	@python3 -m unittest discover -s scripts/starter/tests -t scripts -p 'probe_*.py'

hooks:
	@python3 scripts/git_setup.py

clean:
	rm -rf build
