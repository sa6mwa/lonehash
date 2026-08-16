#!/usr/bin/env bash
set -euo pipefail

root=${1:?repository root is required}
cd "$root"

cmake --list-presets | grep -F '"debug"' >/dev/null
cmake --list-presets | grep -F '"debug-lua"' >/dev/null
cmake --list-presets | grep -F '"valgrind"' >/dev/null
cmake --list-presets | grep -F '"x86_64-linux-gnu-release"' >/dev/null
make help | grep -F 'deps-debug' >/dev/null
make help | grep -F 'valgrind' >/dev/null
make help | grep -F 'release-lua-artifacts' >/dev/null
make help | grep -F 'lua-rock' >/dev/null
make help | grep -F 'print-release-upload-assets' >/dev/null
grep -F 'prerelease: release-pipeline' Makefile >/dev/null
grep -F 'release: clean release-pipeline' Makefile >/dev/null
grep -F 'release-pipeline: test-all lua-rock lua-test package-source-smoke release-matrix' Makefile >/dev/null
grep -F '"lua == 5.5.0"' lonehash.rockspec.in >/dev/null
test -x scripts/stage_lua_rock_sources.sh

toolchain=$(scripts/cpkt-toolchains.sh discover x86_64-linux-gnu)
printf '%s\n' "$toolchain" | grep -Fx 'source=bootlin' >/dev/null
if printf '%s\n' "$toolchain" | grep '^cc=/usr/' >/dev/null; then
  echo 'lifecycle resolver selected a host compiler' >&2
  exit 1
fi
