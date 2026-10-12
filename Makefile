# mac-app-starter: one entry point for building, testing, rendering and packaging.
# No Xcode, no SwiftPM: scripts/build.sh calls swiftc once (see docs, BAUPLAN §2).
#
#   make build MODULES=window,menubar CONFIG=release
#   make shots ONLY=design.
#   make test ONLY=Settings

SHELL := /bin/zsh
.DEFAULT_GOAL := help
export MODULES CONFIG ONLY SHOTS_LANG SHOTS_APPEARANCE NO_BUILD

# Runs a script when it exists, otherwise says which strand still has to add it.
define run_script
	@if [[ -x "$(1)" ]]; then "$(1)" $(2); \
	elif [[ -f "$(1)" ]]; then python3 "$(1)" $(2); \
	else print "make: $(1) is not yet available (skipped)"; fi
endef

.PHONY: help doctor build run test check shots readme-shots icon dmg notarize rules hooks clean \
        check-rules check-texts check-design check-kit probe

help:
	@print "make doctor        check the toolchain (never installs anything)"
	@print "make build         debug build -> build/<Name>.app   (MODULES=a,b  CONFIG=release)"
	@print "make run           build and open the app"
	@print "make test          Swift tests (build/tests/run-tests) + Python tests   (ONLY=<prefix>)"
	@print "make check         rules, texts, design, kit checks + build + test (before every push)"
	@print "make shots         render every scene to build/shots (+ index.html)   (ONLY=<prefix>)"
	@print "make readme-shots  docs/screenshots/list.txt into docs/screenshots (max 1200 px wide)"
	@print "make icon          render App/Resources/AppIcon.icns"
	@print "make dmg           release build + designed DMG in build/dmg"
	@print "make rules         write CLAUDE.md part A and word lists from rules/"
	@print "make hooks         use scripts/hooks as git hooks"
	@print "make probe         template probe: init a copy, remove each module, build (slow, starter only)"
	@print "make clean         remove build/"

doctor:
	@scripts/doctor.sh

build:
	@scripts/build.sh

run:
	@scripts/run.sh

test:
	@scripts/test.sh

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
	$(call run_script,scripts/check_texts.py,$(CHECK_FLAGS))

check-design:
	$(call run_script,scripts/check_design.py,$(CHECK_FLAGS))

check-kit:
	$(call run_script,scripts/check_kit.py)

check: check-rules check-texts check-design check-kit build test

probe:
	@python3 -m unittest discover -s scripts/starter/tests -t scripts -p 'probe_*.py'

hooks:
	@if [[ -d scripts/hooks ]]; then git config core.hooksPath scripts/hooks && print "git hooks: scripts/hooks"; \
	else print "make: scripts/hooks is not yet available (skipped)"; fi

clean:
	rm -rf build
