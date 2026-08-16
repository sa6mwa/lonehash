#!/usr/bin/env bash
set -euo pipefail

root=${1:?repository root is required}
tmp="$root/.cache/apple-toolchain-discovery-test"
host=test-apple
bin="$tmp/bin"

rm -rf "$tmp"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$bin"
for tool in clang clang++ ld ar nm otool install_name_tool; do
  : >"$bin/$host-$tool"
  chmod +x "$bin/$host-$tool"
done
if OSXCROSS_ROOT="$tmp" CPKT_OSXCROSS_HOST="$host" \
  "$root/scripts/cpkt-toolchains.sh" discover arm64-apple-darwin | \
  grep '^status=ready$' >/dev/null; then
  echo 'incomplete Darwin toolchain was reported as ready' >&2
  exit 1
fi
for tool in ranlib strip; do
  : >"$bin/$host-$tool"
  chmod +x "$bin/$host-$tool"
done
OSXCROSS_ROOT="$tmp" CPKT_OSXCROSS_HOST="$host" \
  "$root/scripts/cpkt-toolchains.sh" discover arm64-apple-darwin | \
  grep '^status=ready$' >/dev/null
