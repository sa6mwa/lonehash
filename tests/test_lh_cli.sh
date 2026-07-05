#!/bin/sh
set -eu

lh=$1
tmp=${TMPDIR:-/tmp}/lonehash-cli-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

printf abc >"$tmp/abc.txt"

sha=$("$lh" --sha256 "$tmp/abc.txt")
test "$sha" = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  $tmp/abc.txt"

md5=$("$lh" --md5 "$tmp/abc.txt")
test "$md5" = "900150983cd24fb0d6963f7d28e17f72  $tmp/abc.txt"

stdin_sha=$(printf abc | "$lh" -s)
test "$stdin_sha" = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  -"

printf abc | "$lh" -5 -z >"$tmp/nul.out"
bytes=$(wc -c <"$tmp/nul.out" | tr -d ' ')
test "$bytes" = "36"
tail_byte=$(od -An -tx1 -N1 -j35 "$tmp/nul.out" | tr -d ' \n')
test "$tail_byte" = "00"
