#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$("$root/scripts/release_version.sh")
dist="${LONEHASH_DIST_DIR:-$root/dist}"
manifest="$dist/lonehash-$version-CHECKSUMS"
tmp="$root/.cache/package-verify"

fail() {
  echo "$1" >&2
  exit 1
}

scan_path() {
  artifact=$1
  path=$2
  needle=$3
  label=$4
  if [ "$needle" != "" ] && grep -a -n "$needle" "$path" >/dev/null 2>&1; then
    echo "release artifact leaks $label" >&2
    echo "artifact=$artifact" >&2
    echo "path=$path" >&2
    exit 1
  fi
}

scan_tree() {
  artifact=$1
  dir=$2
  find "$dir" -type f -print | while IFS= read -r file; do
    scan_path "$artifact" "$file" "$root" "repository path"
    scan_path "$artifact" "$file" "${HOME:-}" "HOME path"
    scan_path "$artifact" "$file" "file://$root" "repository file URL"
    if [ "${HOME:-}" != "" ]; then
      scan_path "$artifact" "$file" "file://$HOME" "HOME file URL"
    fi
  done
  find "$dir" -type l -print | while IFS= read -r link; do
    target=$(readlink "$link")
    case "$target" in
      "$root"*|"$HOME"*)
        echo "release symlink leaks local path" >&2
        echo "artifact=$artifact" >&2
        echo "path=$link" >&2
        echo "target=$target" >&2
        exit 1
        ;;
    esac
  done
}

assert_single_root() {
  artifact=$1
  dir=$2
  want=$3
  roots=$(find "$dir" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)
  if [ "$roots" != "$want" ]; then
    echo "release archive has unexpected root" >&2
    echo "artifact=$artifact" >&2
    echo "want=$want" >&2
    echo "got=$roots" >&2
    exit 1
  fi
}

scan_elf_runtime_paths() {
  artifact=$1
  dir=$2
  readelf_tool=${READELF:-readelf}
  command -v "$readelf_tool" >/dev/null 2>&1 || return 0
  find "$dir" -type f -print | while IFS= read -r file; do
    if "$readelf_tool" -h "$file" >/dev/null 2>&1; then
      dynamic=$("$readelf_tool" -d "$file" 2>/dev/null || true)
      printf '%s\n' "$dynamic" | grep -E 'RPATH|RUNPATH' | while IFS= read -r line; do
        scan_path "$artifact" "$file" "$root" "repository path"
        scan_path "$artifact" "$file" "${HOME:-}" "HOME path"
        case "$line" in
          *'[$ORIGIN'*|*'[]'*) ;;
          *'[/usr/lib'*|*'[/lib'*|*'[/System/Library'*) ;;
          *'[/tmp'*|*'/build/'*|*'/.cache/'*|*'['/*)
            echo "release artifact has non-relocatable ELF runtime path" >&2
            echo "artifact=$artifact" >&2
            echo "path=$file" >&2
            echo "dynamic=$line" >&2
            exit 1
            ;;
        esac
      done
    fi
  done
}

darwin_otool() {
  if [ -n "${OTOOL:-}" ]; then
    printf '%s\n' "$OTOOL"
  elif command -v otool >/dev/null 2>&1; then
    command -v otool
  elif [ -n "${HOME:-}" ] &&
    [ -x "$HOME/.local/cross/osxcross/bin/${CPKT_OSXCROSS_HOST:-arm64-apple-darwin25}-otool" ]; then
    printf '%s/.local/cross/osxcross/bin/%s-otool\n' "$HOME" \
      "${CPKT_OSXCROSS_HOST:-arm64-apple-darwin25}"
  else
    return 1
  fi
}

scan_darwin_runtime_paths() {
  artifact=$1
  dir=$2
  otool_tool=$(darwin_otool) || fail "Darwin artifact requires target otool: $artifact"
  find "$dir" -type f -print | while IFS= read -r file; do
    file "$file" | grep 'Mach-O' >/dev/null 2>&1 || continue
    if "$otool_tool" -L "$file" >/dev/null 2>&1; then
      loads=$("$otool_tool" -L "$file" | sed '1d')
      printf '%s\n' "$loads" | grep "$root\|${HOME:-__no_home__}\|/usr/local/\|/tmp/\|/.cache/\|/build/" >/dev/null 2>&1 && {
        echo "release artifact has non-relocatable Darwin dependency path" >&2
        echo "artifact=$artifact" >&2
        echo "path=$file" >&2
        exit 1
      }
      rpaths=$("$otool_tool" -l "$file" | awk '/LC_RPATH/{r=1} r && / path /{print $2; r=0}')
      printf '%s\n' "$rpaths" | while IFS= read -r rpath; do
        case "$rpath" in
          ""|@loader_path*|@executable_path*) ;;
          *)
            echo "release artifact has non-relocatable Darwin rpath" >&2
            echo "artifact=$artifact" >&2
            echo "path=$file" >&2
            echo "rpath=$rpath" >&2
            exit 1
            ;;
        esac
      done
    fi
  done
}

write_consumer_source() {
  dir=$1
  mkdir -p "$dir"
  cat >"$dir/main.c" <<'EOF'
#include <lonehash/lonehash.h>

#include <string.h>

int main(void) {
  lonehash_sha256 *sha = 0;
  unsigned char digest[LONEHASH_SHA256_DIGEST_SIZE];
  char hex[LONEHASH_SHA256_HEX_SIZE];
  int ok;

  if (lonehash_sha256_create(&sha) != LONEHASH_OK) {
    return 1;
  }
  ok = sha->digest_buffer(sha, "abc", 3, digest) == LONEHASH_OK;
  sha->hex(sha, digest, hex);
  lonehash_sha256_destroy(sha);
  return ok && strcmp(hex,
                      "ba7816bf8f01cfea414140de5dae2223"
                      "b00361a396177a9cb410ff61f20015ad") == 0
             ? 0
             : 1;
}
EOF
}

verify_host_consumers() {
  artifact=$1
  prefix=$2
  consumer="$tmp/consumer-${artifact%.tar.gz}"
  write_consumer_source "$consumer/pkgconfig"
  cc -o "$consumer/pkgconfig/shared" "$consumer/pkgconfig/main.c" \
    $(PKG_CONFIG_PATH="$prefix/lib/pkgconfig" pkg-config --cflags --libs lonehash)
  LD_LIBRARY_PATH="$prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    "$consumer/pkgconfig/shared"
  cc -o "$consumer/pkgconfig/static" "$consumer/pkgconfig/main.c" \
    $(PKG_CONFIG_PATH="$prefix/lib/pkgconfig" pkg-config --cflags --libs --static lonehash)

  mkdir -p "$consumer/cmake"
  cp "$consumer/pkgconfig/main.c" "$consumer/cmake/main.c"
  cat >"$consumer/cmake/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.20)
project(lonehash_package_consumer C)
find_package(lonehash CONFIG REQUIRED)
add_executable(consumer main.c)
target_link_libraries(consumer PRIVATE lonehash::shared)
EOF
  cmake -S "$consumer/cmake" -B "$consumer/cmake-build" -G Ninja \
    -DCMAKE_PREFIX_PATH="$prefix"
  cmake --build "$consumer/cmake-build"
  LD_LIBRARY_PATH="$prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    "$consumer/cmake-build/consumer"
}

verify_custom_install_dirs() {
  smoke="$tmp/custom-install-dirs"
  prefix="$smoke/prefix"
  cmake -S "$root" -B "$smoke/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DLONEHASH_BUILD_EXAMPLES=OFF \
    -DLONEHASH_BUILD_TESTS=OFF \
    -DLONEHASH_BUILD_BENCHMARKS=OFF \
    -DLONEHASH_BUILD_CLI=OFF \
    -DCMAKE_INSTALL_LIBDIR=lib64 \
    -DCMAKE_INSTALL_INCLUDEDIR=include/lonehash-sdk
  cmake --build "$smoke/build"
  cmake --install "$smoke/build" --prefix "$prefix"
  test -f "$prefix/lib64/pkgconfig/lonehash.pc"
  grep 'includedir=${prefix}/include/lonehash-sdk' \
    "$prefix/lib64/pkgconfig/lonehash.pc" >/dev/null
  grep 'libdir=${prefix}/lib64' "$prefix/lib64/pkgconfig/lonehash.pc" >/dev/null
  write_consumer_source "$smoke/pkgconfig"
  cc -o "$smoke/pkgconfig/consumer" "$smoke/pkgconfig/main.c" \
    $(PKG_CONFIG_PATH="$prefix/lib64/pkgconfig" pkg-config --cflags --libs lonehash)
  LD_LIBRARY_PATH="$prefix/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    "$smoke/pkgconfig/consumer"
}

if [ ! -f "$manifest" ]; then
  fail "missing checksum manifest: $manifest"
fi

(cd "$dist" && sha256sum -c "$(basename "$manifest")")

rm -rf "$tmp"
mkdir -p "$tmp"

scan_path "$(basename "$manifest")" "$manifest" "$root" "repository path"
scan_path "$(basename "$manifest")" "$manifest" "${HOME:-}" "HOME path"
verify_custom_install_dirs

find "$dist" -maxdepth 1 -type f -printf '%f\n' | sort | while IFS= read -r file; do
  case "$file" in
    lonehash-"$version"-CHECKSUMS) continue ;;
    lonehash-"$version"*.tar.gz|lonehash-lua-"$version".tar.gz|lonehash-"$version"-1.rockspec|lonehash-"$version"-1.src.rock|lh-"$version"*.tar.gz)
      grep "  $file\$" "$manifest" >/dev/null ||
        fail "release artifact is not listed in checksum manifest: $file"
      ;;
    lonehash-*.tar.gz|lonehash-lua-*.tar.gz|lonehash-*-1.rockspec|lonehash-*-1.src.rock|lh-*.tar.gz)
      fail "stale release artifact for different version: $file"
      ;;
  esac
done

while read -r _hash artifact; do
  extract="$tmp/extract-${artifact}"
  mkdir -p "$extract"
  case "$artifact" in
    lonehash-lua-"$version".tar.gz)
      root_name="lonehash-lua-$version"
      tar -C "$extract" -xzf "$dist/$artifact"
      assert_single_root "$artifact" "$extract" "$root_name"
      test -f "$extract/$root_name/lonehash-$version-1.rockspec"
      test -f "$extract/$root_name/include/lonehash/lonehash.h"
      test -f "$extract/$root_name/lua/lonehash.lua"
      test -f "$extract/$root_name/lua/lonehash/core.c"
      test -f "$extract/$root_name/lua/lh.lua"
      scan_tree "$artifact" "$extract/$root_name"
      ;;
    lonehash-"$version"-1.rockspec)
      scan_path "$artifact" "$dist/$artifact" "$root" "repository path"
      scan_path "$artifact" "$dist/$artifact" "${HOME:-}" "HOME path"
      scan_path "$artifact" "$dist/$artifact" "file://$root" "repository file URL"
      if [ "${HOME:-}" != "" ]; then
        scan_path "$artifact" "$dist/$artifact" "file://$HOME" "HOME file URL"
      fi
      ;;
    lonehash-"$version"-1.src.rock)
      rock_dir="$extract/${artifact%.src.rock}"
      mkdir -p "$rock_dir"
      unzip -q "$dist/$artifact" -d "$rock_dir"
      test -f "$rock_dir/lonehash-$version-1.rockspec"
      test -f "$rock_dir/lonehash-lua-$version.tar.gz"
      scan_tree "$artifact" "$rock_dir"
      nested="$rock_dir/nested"
      mkdir -p "$nested"
      tar -C "$nested" -xzf "$rock_dir/lonehash-lua-$version.tar.gz"
      test -f "$nested/lonehash-lua-$version/lua/lonehash/core.c"
      scan_tree "$artifact nested source" "$nested/lonehash-lua-$version"
      ;;
    lonehash-"$version".tar.gz)
      root_name="lonehash-$version"
      tar -C "$extract" -xzf "$dist/$artifact"
      assert_single_root "$artifact" "$extract" "$root_name"
      test -f "$extract/$root_name/CMakeLists.txt"
      test -f "$extract/$root_name/VERSION"
      test -f "$extract/$root_name/RELEASE_MANIFEST"
      test "$(sed -n '1p' "$extract/$root_name/VERSION")" = "$version"
      scan_tree "$artifact" "$extract/$root_name"
      ;;
    lonehash-"$version"-*.tar.gz)
      root_name=${artifact%.tar.gz}
      tar -C "$extract" -xzf "$dist/$artifact"
      assert_single_root "$artifact" "$extract" "$root_name"
      prefix="$extract/$root_name"
      test -f "$prefix/include/lonehash/lonehash.h"
      test -f "$prefix/lib/pkgconfig/lonehash.pc"
      test -f "$prefix/lib/cmake/lonehash/lonehashConfig.cmake"
      test -f "$prefix/share/doc/lonehash/LICENSE"
      grep "#define LONEHASH_VERSION \"$version\"" \
        "$prefix/include/lonehash/lonehash.h" >/dev/null
      grep "Version: $version" "$prefix/lib/pkgconfig/lonehash.pc" >/dev/null
      if [ -e "$prefix/bin/lh" ]; then
        fail "library SDK unexpectedly contains lh CLI: $artifact"
      fi
      find "$prefix" \( -name '*.lua' -o -name '*.rockspec' -o -name '*.rock' \) \
        -print -quit | grep . >/dev/null &&
        fail "library SDK unexpectedly contains Lua payload: $artifact"
      scan_tree "$artifact" "$prefix"
      case "$artifact" in
        *-arm64-apple-darwin.tar.gz) scan_darwin_runtime_paths "$artifact" "$prefix" ;;
        *) scan_elf_runtime_paths "$artifact" "$prefix" ;;
      esac
      case "$artifact" in
        lonehash-"$version"-host.tar.gz) verify_host_consumers "$artifact" "$prefix" ;;
      esac
      ;;
    lh-"$version"-*.tar.gz)
      root_name=${artifact%.tar.gz}
      tar -C "$extract" -xzf "$dist/$artifact"
      assert_single_root "$artifact" "$extract" "$root_name"
      prefix="$extract/$root_name"
      test -x "$prefix/bin/lh"
      test -f "$prefix/share/doc/lonehash/README.md"
      test -f "$prefix/share/doc/lonehash/LICENSE"
      if [ -e "$prefix/include" ] || [ -e "$prefix/lib" ]; then
        fail "lh CLI package contains library SDK directories: $artifact"
      fi
      scan_tree "$artifact" "$prefix"
      case "$artifact" in
        *-arm64-apple-darwin.tar.gz) scan_darwin_runtime_paths "$artifact" "$prefix" ;;
        *) scan_elf_runtime_paths "$artifact" "$prefix" ;;
      esac
      ;;
    *)
      fail "unexpected checksum artifact: $artifact"
      ;;
  esac
done <"$manifest"
