#!/bin/sh
set -eu

if [ "${LONEHASH_VERSION_OVERRIDE:-}" != "" ]; then
  printf '%s\n' "$LONEHASH_VERSION_OVERRIDE"
  exit 0
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  for tag in $(git tag --points-at HEAD --list 'v[0-9]*.[0-9]*.[0-9]*'); do
    if [ "$(git cat-file -t "refs/tags/$tag")" = commit ]; then
      printf '%s\n' "${tag#v}"
      exit 0
    fi
  done
  printf '0.0.0\n'
  exit 0
fi

if [ -f VERSION ]; then
  sed -n '1p' VERSION
  exit 0
fi

printf '0.0.0\n'
