#!/usr/bin/env bash
set -euo pipefail

root=${1:?repository root is required}
cd "$root"

cmake --list-presets | grep -F '"debug"' >/dev/null
cmake --list-presets | grep -F '"valgrind"' >/dev/null
cmake --list-presets | grep -F '"x86_64-linux-gnu-release"' >/dev/null
make help | grep -F 'deps-debug' >/dev/null
make help | grep -F 'valgrind' >/dev/null
make help | grep -F 'release-lua-artifacts' >/dev/null

toolchain=$(scripts/cpkt-toolchains.sh discover x86_64-linux-gnu)
printf '%s\n' "$toolchain" | grep -Fx 'source=bootlin' >/dev/null
if printf '%s\n' "$toolchain" | grep '^cc=/usr/' >/dev/null; then
  echo 'lifecycle resolver selected a host compiler' >&2
  exit 1
fi
