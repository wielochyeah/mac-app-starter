# Shared by scripts/build.sh, scripts/test.sh and scripts/typecheck.sh (sourced, zsh). Expects $ROOT and the app.env
# of scripts/gen_config.py (build/gen, or $GEN_DIR).
#
# Language mode (BAUPLAN §2.3): Swift 6 with -default-isolation MainActor (SE-0466), verified with
# Apple Swift 6.3.3 + MacOSX26.5.sdk. Custom Codable types used as SettingKey values must be declared
# `nonisolated struct …` (main-actor isolated conformances cannot satisfy a Sendable type parameter).
#
# STRICT=1 (make check, make typecheck, the CI) turns warnings into errors (rule A-02): -warnings-as-errors for the
# compiler, and any other "warning:" line (the linker's) fails the step too. A plain make build stays tolerant.

swift_sources() {
  # Prints one source path per line: Kit, Features, enabled modules, generated AppConfig.
  local d
  print -l "$ROOT"/App/Sources/Kit/**/*.swift(N) "$ROOT"/App/Sources/Features/**/*.swift(N)
  for d in ${=MODULE_DIRS_ENABLED}; do
    print -l "$ROOT"/App/Sources/Modules/$d/**/*.swift(N)
  done
  print -r -- "${GEN_DIR:-$ROOT/build/gen}/AppConfig.swift"
}

use_sdk() {
  # Exports SDKROOT (pick-sdk.sh keeps an SDKROOT that is already set). It must be in the
  # environment, not only passed as -sdk: the linker step otherwise records xcrun's default SDK
  # (a leftover 27.0 beta here) as the build SDK in LC_BUILD_VERSION.
  local log="$ROOT/build/.pick-sdk.log"
  mkdir -p "$ROOT/build"
  if ! SDKROOT="$("$ROOT/scripts/pick-sdk.sh" 2>"$log")"; then cat "$log" >&2; return 1; fi
  export SDKROOT
}

swift_flags() {
  # Prints the common swiftc flags, one per line. $1 = debug|release. Call use_sdk first.
  local config="$1"
  print -l -- -sdk "$SDKROOT" \
    -swift-version 6 -default-isolation MainActor \
    -target "arm64-apple-macosx$MIN_MACOS" \
    -module-name AppModule -parse-as-library \
    -module-cache-path "$ROOT/build/cache/modules" \
    -j "$(sysctl -n hw.ncpu)" \
    ${=MODULE_FLAGS} \
    -framework AppKit -framework SwiftUI -framework ServiceManagement -framework Carbon -lsqlite3
  if [[ " $MODULES_ENABLED " == *" ai "* ]]; then print -l -- -framework FoundationModels; fi
  if [[ "${STRICT:-}" == 1 ]]; then print -l -- -warnings-as-errors; fi
  if [[ "$config" == release ]]; then
    print -l -- -O -wmo -D RELEASE
  else
    print -l -- -Onone -g -D DEBUG
  fi
}

run_swiftc() {
  # swiftc "$@" with its output shown. Under STRICT=1 a "warning:" line fails the step even when swiftc succeeded.
  local log rc=0
  log="$(mktemp "${TMPDIR:-/tmp}/starter-swiftc.XXXXXX")"
  swiftc "$@" > "$log" 2>&1 || rc=$?
  cat "$log"
  if (( rc == 0 )) && [[ "${STRICT:-}" == 1 ]] && grep -q "warning:" "$log"; then
    print -u2 "swiftc: Warnungen gelten in make check als Fehler (A-02); die Stellen stehen oben."
    rc=1
  fi
  rm -f "$log"
  return $rc
}

require_value() {
  # require_value <NAME> <value> <zsh regex> <example>: stops with a message when a make variable has another form.
  if [[ -n "$2" && ! "$2" =~ $3 ]]; then
    print -u2 "$1=„$2“ hat nicht die erwartete Form (etwa $1=$4)."
    exit 2
  fi
}
