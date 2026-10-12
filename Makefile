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
	@print "make readme-shots  copy docs/screenshots/list.txt entries from build/shots"
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

readme-shots:
	@if [[ ! -f docs/screenshots/list.txt ]]; then print "make: docs/screenshots/list.txt is not yet available (skipped)"; \
	else mkdir -p docs/screenshots; missing=0; \
	  while IFS= read -r line; do line="$${line%%#*}"; line="$${line//[[:space:]]/}"; [[ -z "$$line" ]] && continue; \
	    if [[ -f "build/shots/$$line" ]]; then cp "build/shots/$$line" "docs/screenshots/$${line//\//-}"; print "copied $$line"; \
	    else print -u2 "missing build/shots/$$line (make shots)"; missing=1; fi; \
	  done < docs/screenshots/list.txt; exit $$missing; fi

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
	$(call run_script,scripts/check_texts.py)

check-design:
	$(call run_script,scripts/check_design.py)

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
