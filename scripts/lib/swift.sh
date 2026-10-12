# Shared by scripts/build.sh and scripts/test.sh (sourced, zsh). Expects $ROOT and build/gen/app.env.
#
# Language mode (BAUPLAN §2.3): Swift 6 with -default-isolation MainActor (SE-0466), verified with
# Apple Swift 6.3.3 + MacOSX26.5.sdk. Custom Codable types used as SettingKey values must be declared
# `nonisolated struct …` (main-actor isolated conformances cannot satisfy a Sendable type parameter).

swift_sources() {
  # Prints one source path per line: Kit, Features, enabled modules, generated AppConfig.
  local d
  print -l "$ROOT"/App/Sources/Kit/**/*.swift(N) "$ROOT"/App/Sources/Features/**/*.swift(N)
  for d in ${=MODULE_DIRS_ENABLED}; do
    print -l "$ROOT"/App/Sources/Modules/$d/**/*.swift(N)
  done
  print -r -- "$ROOT/build/gen/AppConfig.swift"
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
  if [[ "$config" == release ]]; then
    print -l -- -O -wmo -D RELEASE
  else
    print -l -- -Onone -g -D DEBUG
  fi
}
