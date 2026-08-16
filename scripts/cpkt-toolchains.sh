#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'cpkt-toolchains: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
usage: cpkt-toolchains.sh <command> [target-id]

Commands:
  targets              List cpkt target ids known to this lifecycle.
  discover [target]    Print compiler, sysroot, runtime, source, and cache paths.
  ensure <target|all>  Install missing downloadable toolchains, then report.
  env <target>         Print shell exports for compilers, tools, sysroot, and runtime archives.

Cache:
  ${CPKT_TOOLCHAIN_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/c.pkt.systems/toolchains}

Download policy:
  Linux uses only pinned Bootlin stable compiler collections. Apple/Darwin
  toolchains are discovery-only because Apple SDK access is not public.
USAGE
}

cache_root() {
  if [ -n "${CPKT_TOOLCHAIN_CACHE:-}" ]; then
    printf '%s\n' "$CPKT_TOOLCHAIN_CACHE"
  elif [ -n "${XDG_CACHE_HOME:-}" ]; then
    printf '%s\n' "$XDG_CACHE_HOME/c.pkt.systems/toolchains"
  elif [ -n "${HOME:-}" ]; then
    printf '%s\n' "$HOME/.cache/c.pkt.systems/toolchains"
  else
    die "HOME or XDG_CACHE_HOME is required when CPKT_TOOLCHAIN_CACHE is unset"
  fi
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    die "sha256sum or shasum is required"
  fi
}

download_file() {
  url=$1
  dst=$2
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --connect-timeout 20 --output "$dst" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$dst" "$url"
  else
    die "curl or wget is required to download toolchains"
  fi
}

with_cache_lock() {
  lock_path=$1
  shift
  command -v flock >/dev/null 2>&1 || die "flock is required to provision shared toolchains"
  mkdir -p "$(dirname "$lock_path")"
  exec 9>"$lock_path"
  flock -w "${CPKT_TOOLCHAIN_LOCK_TIMEOUT:-600}" 9 || die "timed out waiting for shared toolchain lock: $lock_path"
  "$@"
  flock -u 9
  exec 9>&-
}

target_ids() {
  cat <<'TARGETS'
x86_64-linux-gnu
x86_64-linux-musl
aarch64-linux-gnu
aarch64-linux-musl
armhf-linux-gnu
armhf-linux-musl
arm64-apple-darwin
TARGETS
}

require_target() {
  case "$1" in
    x86_64-linux-gnu|x86_64-linux-musl|aarch64-linux-gnu|aarch64-linux-musl|armhf-linux-gnu|armhf-linux-musl|arm64-apple-darwin) ;;
    *) die "unsupported target: $1" ;;
  esac
}

bootlin_meta() {
  case "$1" in
    x86_64-linux-gnu)
      printf '%s|%s|%s|%s|%s\n' \
        x86-64 x86-64--glibc--stable-2025.08-1 \
        760acd5c3159448b618e237b61935335baada74fe0cdc0d7611826cb49b41c8c \
        x86_64-linux x86_64-buildroot-linux-gnu/sysroot
      ;;
    x86_64-linux-musl)
      printf '%s|%s|%s|%s|%s\n' \
        x86-64 x86-64--musl--stable-2025.08-1 \
        09fca3aa89540f1b01b5f4210d488cbeb00f522044c53e9989b1dd8a38076912 \
        x86_64-linux x86_64-buildroot-linux-musl/sysroot
      ;;
    aarch64-linux-gnu)
      printf '%s|%s|%s|%s|%s\n' \
        aarch64 aarch64--glibc--stable-2025.08-1 \
        dfb47eee874eef9e8a7fc042eee4e0a183f444b6bcde6a82fef8f009918389c9 \
        aarch64-linux aarch64-buildroot-linux-gnu/sysroot
      ;;
    aarch64-linux-musl)
      printf '%s|%s|%s|%s|%s\n' \
        aarch64 aarch64--musl--stable-2025.08-1 \
        defba831ffa1175236f137069333e21ed46d4d19feb5080a90cf248b6fc2cb08 \
        aarch64-linux aarch64-buildroot-linux-musl/sysroot
      ;;
    armhf-linux-gnu)
      printf '%s|%s|%s|%s|%s\n' \
        armv7-eabihf armv7-eabihf--glibc--stable-2025.08-1 \
        97d6fbaf19832002f3d6aa8fd31b2d29c1dc7b0752f4ae8ed35860fd33c1f9b4 \
        arm-linux arm-buildroot-linux-gnueabihf/sysroot
      ;;
    armhf-linux-musl)
      printf '%s|%s|%s|%s|%s\n' \
        armv7-eabihf armv7-eabihf--musl--stable-2025.08-1 \
        2f3a34458c3a8b961bd09f89669130fcdc4c1dbc6e31ada720527e4ad3741c11 \
        arm-linux arm-buildroot-linux-musleabihf/sysroot
      ;;
    arm64-apple-darwin)
      return 1
      ;;
  esac
}

compiler_file() {
  compiler=$1
  file_name=$2
  "$compiler" -print-file-name="$file_name"
}

existing_compiler_file() {
  compiler=$1
  file_name=$2
  path=$(compiler_file "$compiler" "$file_name")
  [ "$path" != "$file_name" ] && [ -f "$path" ] || return 1
  dir=$(CDPATH= cd -- "$(dirname -- "$path")" && pwd -P)
  printf '%s/%s\n' "$dir" "$(basename -- "$path")"
}

complete_gnu_collection() {
  root=$1
  prefix=$2
  sysroot=$3
  [ -x "$root/bin/$prefix-gcc" ] &&
    [ -x "$root/bin/$prefix-g++" ] &&
    [ -x "$root/bin/$prefix-ld" ] &&
    [ -x "$root/bin/$prefix-ar" ] &&
    [ -x "$root/bin/$prefix-ranlib" ] &&
    [ -x "$root/bin/$prefix-strip" ] &&
    [ -x "$root/bin/$prefix-nm" ] &&
    [ -x "$root/bin/$prefix-objcopy" ] &&
    [ -x "$root/bin/$prefix-objdump" ] &&
    [ -x "$root/bin/$prefix-addr2line" ] &&
    [ -x "$root/bin/$prefix-readelf" ] &&
    { [ -f "$sysroot/include/stdio.h" ] || [ -f "$sysroot/usr/include/stdio.h" ]; } &&
    { [ -e "$sysroot/usr/lib/libc.so" ] || [ -e "$sysroot/lib/libc.so" ] || [ -e "$sysroot/lib/libc.so.6" ]; } &&
    existing_compiler_file "$root/bin/$prefix-g++" libstdc++.a >/dev/null &&
    existing_compiler_file "$root/bin/$prefix-g++" libgcc.a >/dev/null
}

complete_apple_collection() {
  osxcross_root=${OSXCROSS_ROOT:-${HOME:-}/.local/cross/osxcross}
  osxcross_host=${CPKT_OSXCROSS_HOST:-arm64-apple-darwin25}
  [ -x "$osxcross_root/bin/$osxcross_host-clang" ] &&
    [ -x "$osxcross_root/bin/$osxcross_host-clang++" ] &&
    [ -x "$osxcross_root/bin/$osxcross_host-ld" ] &&
    [ -x "$osxcross_root/bin/$osxcross_host-ar" ] &&
    [ -x "$osxcross_root/bin/$osxcross_host-nm" ] &&
    [ -x "$osxcross_root/bin/$osxcross_host-otool" ]
}

install_bootlin() {
  target=$1
  meta=$(bootlin_meta "$target") || die "$target is not downloadable by this lifecycle"
  IFS='|' read -r _bootlin_arch toolchain_name _sha256 _boot_prefix _boot_sysroot <<EOF
$meta
EOF
  with_cache_lock "$(cache_root)/locks/bootlin-$toolchain_name.lock" install_bootlin_locked "$target"
}

install_bootlin_locked() {
  target=$1
  meta=$(bootlin_meta "$target") || die "$target is not downloadable by this lifecycle"
  IFS='|' read -r bootlin_arch toolchain_name sha256 boot_prefix boot_sysroot <<EOF
$meta
EOF
  root=$(cache_root)
  archive_name=$toolchain_name.tar.xz
  archive_dir=$root/archives
  root_dir=$root/roots/$toolchain_name
  archive_path=$archive_dir/$archive_name
  url=https://toolchains.bootlin.com/downloads/releases/toolchains/$bootlin_arch/tarballs/$archive_name

  if complete_gnu_collection "$root_dir" "$boot_prefix" "$root_dir/$boot_sysroot"; then
    printf '%s\n' "$root_dir"
    return 0
  fi

  mkdir -p "$archive_dir" "$root/roots"
  if [ ! -f "$archive_path" ]; then
    tmp_archive=$archive_path.tmp.$$
    trap 'rm -f "$tmp_archive"' EXIT HUP INT TERM
    download_file "$url" "$tmp_archive"
    actual=$(sha256_file "$tmp_archive")
    if [ "$actual" != "$sha256" ]; then
      die "checksum mismatch for $archive_name: expected $sha256, got $actual"
    fi
    mv "$tmp_archive" "$archive_path"
    trap - EXIT HUP INT TERM
  else
    actual=$(sha256_file "$archive_path")
    if [ "$actual" != "$sha256" ]; then
      printf 'cpkt-toolchains: discarding corrupt cached archive: %s\n' "$archive_path" >&2
      rm -f -- "$archive_path"
      tmp_archive=$archive_path.tmp.$$
      trap 'rm -f "$tmp_archive"' EXIT HUP INT TERM
      download_file "$url" "$tmp_archive"
      actual=$(sha256_file "$tmp_archive")
      [ "$actual" = "$sha256" ] || die "checksum mismatch for $archive_name: expected $sha256, got $actual"
      mv "$tmp_archive" "$archive_path"
      trap - EXIT HUP INT TERM
    fi
  fi

  tmp_extract=$root/roots/.extract-$toolchain_name.$$
  trap 'rm -rf "$tmp_extract"' EXIT HUP INT TERM
  mkdir -p "$tmp_extract"
  tar -C "$tmp_extract" -xf "$archive_path"
  [ -d "$tmp_extract/$toolchain_name/bin" ] || die "unexpected archive layout for $archive_name"
  rm -rf "$root_dir"
  mv "$tmp_extract/$toolchain_name" "$root_dir"
  rm -rf "$tmp_extract"
  trap - EXIT HUP INT TERM
  complete_gnu_collection "$root_dir" "$boot_prefix" "$root_dir/$boot_sysroot" || die "incomplete extracted toolchain: $root_dir"
  printf '%s\n' "$root_dir"
}

bootlin_candidate() {
  target=$1
  meta=$(bootlin_meta "$target") || return 1
  IFS='|' read -r bootlin_arch toolchain_name sha256 boot_prefix boot_sysroot <<EOF
$meta
EOF
  r=$(cache_root)/roots/$toolchain_name
  if complete_gnu_collection "$r" "$boot_prefix" "$r/$boot_sysroot"; then
    printf 'bootlin|%s|%s|%s\n' "$r" "$boot_prefix" "$r/$boot_sysroot"
    return 0
  fi
  return 1
}

apple_candidate() {
  complete_apple_collection || return 1
  r=${OSXCROSS_ROOT:-$HOME/.local/cross/osxcross}
  p=${CPKT_OSXCROSS_HOST:-arm64-apple-darwin25}
  printf 'osxcross|%s|%s|\n' "$r" "$p"
}

resolved_candidate() {
  target=$1
  require_target "$target"
  case "$target" in
    arm64-apple-darwin) apple_candidate ;;
    *) bootlin_candidate "$target" ;;
  esac
}

report_target() {
  target=$1
  require_target "$target"
  printf 'target=%s\n' "$target"
  printf 'cache=%s\n' "$(cache_root)"
  if candidate=$(resolved_candidate "$target"); then
    IFS='|' read -r source root prefix sysroot <<EOF
$candidate
EOF
    printf 'status=ready\n'
    printf 'source=%s\n' "$source"
    printf 'root=%s\n' "$root"
    printf 'prefix=%s\n' "$prefix"
    printf 'sysroot=%s\n' "$sysroot"
    if [ "$target" = arm64-apple-darwin ]; then
      printf 'cc=%s\n' "$root/bin/$prefix-clang"
      printf 'cxx=%s\n' "$root/bin/$prefix-clang++"
    else
      printf 'cc=%s\n' "$root/bin/$prefix-gcc"
      printf 'cxx=%s\n' "$root/bin/$prefix-g++"
    fi
    printf 'ld=%s\n' "$root/bin/$prefix-ld"
    printf 'ar=%s\n' "$root/bin/$prefix-ar"
    printf 'ranlib=%s\n' "$root/bin/$prefix-ranlib"
    printf 'strip=%s\n' "$root/bin/$prefix-strip"
    printf 'nm=%s\n' "$root/bin/$prefix-nm"
    printf 'objcopy=%s\n' "$root/bin/$prefix-objcopy"
    printf 'objdump=%s\n' "$root/bin/$prefix-objdump"
    printf 'addr2line=%s\n' "$root/bin/$prefix-addr2line"
    if [ "$target" != arm64-apple-darwin ]; then
      printf 'readelf=%s\n' "$root/bin/$prefix-readelf"
    else
      printf 'otool=%s\n' "$root/bin/$prefix-otool"
    fi
    if [ "$target" != arm64-apple-darwin ]; then
      printf 'libstdcxx_a=%s\n' "$(existing_compiler_file "$root/bin/$prefix-g++" libstdc++.a)"
      printf 'libgcc_a=%s\n' "$(existing_compiler_file "$root/bin/$prefix-g++" libgcc.a)"
    else
      printf 'cxx_runtime=libc++\n'
      printf 'static_cxx_runtime_archives=not-applicable\n'
    fi
  else
    printf 'status=missing\n'
    if bootlin_meta "$target" >/dev/null 2>&1; then
      meta=$(bootlin_meta "$target")
      IFS='|' read -r bootlin_arch toolchain_name sha256 boot_prefix boot_sysroot <<EOF
$meta
EOF
      printf 'downloadable=yes\n'
      printf 'archive=%s.tar.xz\n' "$toolchain_name"
      printf 'url=%s\n' "https://toolchains.bootlin.com/downloads/releases/toolchains/$bootlin_arch/tarballs/$toolchain_name.tar.xz"
    else
      printf 'downloadable=no\n'
      printf 'note=Apple/Darwin toolchains require a local osxcross/Xcode SDK setup.\n'
    fi
  fi
}

ensure_target() {
  target=$1
  require_target "$target"
  if resolved_candidate "$target" >/dev/null 2>&1; then
    report_target "$target"
    return 0
  fi
  case "$target" in
    arm64-apple-darwin) apple_candidate >/dev/null || die "arm64-apple-darwin requires a complete local osxcross SDK toolchain" ;;
    *) install_bootlin "$target" >/dev/null ;;
  esac
  report_target "$target"
}

print_env() {
  target=$1
  candidate=$(resolved_candidate "$target") || die "target is missing; run: cpkt-toolchains.sh ensure $target"
  IFS='|' read -r source root prefix sysroot <<EOF
$candidate
EOF
  printf 'export CPKT_TARGET=%s\n' "$target"
  printf 'export CPKT_TOOLCHAIN_SOURCE=%s\n' "$source"
  printf 'export CPKT_TOOLCHAIN_ROOT=%s\n' "$root"
  printf 'export CPKT_TOOLCHAIN_PREFIX=%s\n' "$prefix"
  printf 'export CPKT_SYSROOT=%s\n' "$sysroot"
  if [ "$target" = arm64-apple-darwin ]; then
    printf 'export CC=%s\n' "$root/bin/$prefix-clang"
    printf 'export CXX=%s\n' "$root/bin/$prefix-clang++"
  else
    printf 'export CC=%s\n' "$root/bin/$prefix-gcc"
    printf 'export CXX=%s\n' "$root/bin/$prefix-g++"
  fi
  printf 'export LD=%s\n' "$root/bin/$prefix-ld"
  printf 'export AR=%s\n' "$root/bin/$prefix-ar"
  printf 'export RANLIB=%s\n' "$root/bin/$prefix-ranlib"
  printf 'export STRIP=%s\n' "$root/bin/$prefix-strip"
  printf 'export NM=%s\n' "$root/bin/$prefix-nm"
  if [ "$target" != arm64-apple-darwin ]; then
    printf 'export READELF=%s\n' "$root/bin/$prefix-readelf"
  else
    printf 'export OTOOL=%s\n' "$root/bin/$prefix-otool"
  fi
  if [ "$target" != arm64-apple-darwin ]; then
    printf 'export CPKT_LIBSTDCXX_A=%s\n' "$(existing_compiler_file "$root/bin/$prefix-g++" libstdc++.a)"
    printf 'export CPKT_LIBGCC_A=%s\n' "$(existing_compiler_file "$root/bin/$prefix-g++" libgcc.a)"
  else
    printf 'export CPKT_CXX_RUNTIME=libc++\n'
    printf 'export CPKT_STATIC_CXX_RUNTIME_ARCHIVES=not-applicable\n'
  fi
}

cmd=${1:-}
case "$cmd" in
  -h|--help|"")
    usage
    ;;
  targets)
    target_ids
    ;;
  discover)
    if [ "$#" -ge 2 ]; then
      report_target "$2"
    else
      first=1
      target_ids | while IFS= read -r target; do
        if [ "$first" -eq 0 ]; then printf '\n'; fi
        first=0
        report_target "$target"
      done
    fi
    ;;
  ensure)
    [ "$#" -eq 2 ] || die "usage: cpkt-toolchains.sh ensure <target|all>"
    if [ "$2" = all ]; then
      target_ids | while IFS= read -r target; do
        case "$target" in
          arm64-apple-darwin) report_target "$target" ;;
          *) ensure_target "$target" ;;
        esac
        printf '\n'
      done
    else
      ensure_target "$2"
    fi
    ;;
  env)
    [ "$#" -eq 2 ] || die "usage: cpkt-toolchains.sh env <target>"
    print_env "$2"
    ;;
  *)
    die "unknown command: $cmd"
    ;;
esac
