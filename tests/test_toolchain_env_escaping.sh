#!/usr/bin/env bash
set -euo pipefail

root=${1:?repository root is required}
tmp="$root/.cache/toolchain-env-escaping-test"
marker="$tmp/marker"
cache="$tmp/cache;touch $marker #"
toolchains="$root/scripts/cpkt-toolchains.sh"
toolchain_root=$("$toolchains" discover x86_64-linux-gnu | sed -n 's/^root=//p')
toolchain_name=$(basename "$toolchain_root")

rm -rf "$tmp"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$cache/roots"
ln -s "$toolchain_root" "$cache/roots/$toolchain_name"
exports=$(CPKT_TOOLCHAIN_CACHE="$cache" "$toolchains" env x86_64-linux-gnu)
eval "$exports"
test "$CPKT_TOOLCHAIN_ROOT" = "$cache/roots/$toolchain_name"
test ! -e "$marker"
