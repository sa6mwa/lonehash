#!/bin/sh
set -eu

if [ "${LONEHASH_VERSION_OVERRIDE:-}" != "" ]; then
  printf '%s\n' "$LONEHASH_VERSION_OVERRIDE"
  exit 0
fi

if [ -f VERSION ]; then
  sed -n '1p' VERSION
  exit 0
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  tag=$(git describe --exact-match --tags --match 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null || true)
  if [ "$tag" != "" ]; then
    printf '%s\n' "${tag#v}"
    exit 0
  fi
fi

printf '0.0.0\n'
