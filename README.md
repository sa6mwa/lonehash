# lonehash

`liblonehash` is a small C89 SHA-256 and MD5 library with caller-owned streaming
contexts and zero-allocation update/final hot paths.

Use SHA-256 for integrity and security-sensitive identifiers. MD5 is provided
for compatibility with existing formats only; it is not collision resistant.

The public API supports:

- streaming SHA-256 and MD5 over arbitrarily large inputs;
- one-shot bounded-buffer helpers;
- `FILE *` and path-based file helpers that use bounded stack buffers;
- lowercase hexadecimal digest formatting;
- CMake package exports and `pkg-config` metadata.

## C API

The installed [`lonehash/lonehash.h`](include/lonehash/lonehash.h) header is
the complete C API and carries Doxygen-style comments for clangd hover help. It
exposes receiver shells: create a context, call methods as
`context->operation(context, ...)`, then destroy it. A handle has mutable
state, so do not operate on the same handle concurrently; independently created
handles may be used independently.

`update()` appends a fragment. `final()` writes the raw digest and resets the
context on success, so the same handle is ready for another message.
`digest_buffer()`, `digest_file()`, and `digest_path()` are one-shot helpers:
they discard any current streaming input before hashing their input.
`digest_file()` reads from the stream's current position to EOF and neither
rewinds nor closes it; `digest_path()` opens and closes its path itself. All
fallible methods return `lonehash_status`; use `lonehash_status_string()` only
for a diagnostic string, not for program control flow.

```c
#include <lonehash/lonehash.h>

#include <stdio.h>

int main(void) {
  lonehash_sha256 *sha = NULL;
  unsigned char digest[LONEHASH_SHA256_DIGEST_SIZE];
  char hex[LONEHASH_SHA256_HEX_SIZE];

  if (lonehash_sha256_create(&sha) != LONEHASH_OK ||
      sha->update(sha, "hello", 5) != LONEHASH_OK ||
      sha->final(sha, digest) != LONEHASH_OK) {
    lonehash_sha256_destroy(sha);
    return 1;
  }
  sha->hex(sha, digest, hex);
  printf("%s\n", hex);
  lonehash_sha256_destroy(sha);
  return 0;
}
```

`lonehash_sha256_destroy(NULL)` and `lonehash_md5_destroy(NULL)` are no-ops.
After destroying a non-NULL handle, do not use or destroy that pointer again.

The implementations are original project code informed by small public-domain
or zero-restriction hash implementations, especially `oopsio/nanosha256`,
`BareRose/lonesha256`, and `mackron/md5`. Copyright for this distribution is
owned as stated in `LICENSE`.

The `lh` CLI is distributed separately from the library SDK. It follows the
basic `sha256sum`/`md5sum` output shape:

```sh
lh --sha256 FILE...
lh --md5 FILE...
printf abc | lh -s
```

## Build

```sh
make build
make test
make valgrind
```

Linux builds resolve the pinned Bootlin compiler collection automatically; the
shared cache location can be overridden with `CPKT_TOOLCHAIN_CACHE`.

The lifecycle command surface is available through:

```sh
make help
```

### Install and consume

The install tree exports `lonehash::static` and `lonehash::shared` CMake
targets, plus the `lonehash` pkg-config module. Choose the target explicitly:

```cmake
find_package(lonehash CONFIG REQUIRED)
target_link_libraries(app PRIVATE lonehash::shared)
```

For pkg-config:

```sh
cc app.c $(pkg-config --cflags --libs lonehash)
```

The lifecycle packages both static and shared SDK libraries. On Windows their
archive/import-library filenames are distinct; consumers should link through
the exported CMake target rather than hard-coding a library filename.

## CLI

`lh` defaults to SHA-256. It reads stdin when no files are supplied, and `-`
means stdin in a file list.

| Option | Meaning |
| --- | --- |
| `-s`, `--sha256` | Select SHA-256 (the default). |
| `-5`, `--md5` | Select MD5. |
| `-q`, `--quiet` | Print only the digest; requires stdin or exactly one file. |
| `-z` | Terminate output records with NUL instead of newline. |
| `--` | End option parsing. |
| `--help` | Print usage. |

Short options may be clustered, for example `lh -szq`. Without `--quiet`,
output follows `sha256sum`/`md5sum` form: `<hex>␠␠<name>`. I/O or output-write
failures produce a nonzero exit status.

## Lua

The Lua facade links against `liblonehash` through the public C API only.

```sh
make lua-rock
make lua-test
make lua-env
printf abc | ./build/release/lh.sh -sq
lua lua/examples/hash_strings.lua
```

Lua release artifacts are produced with:

```sh
make release-lua-artifacts
```

`make lua-env` prints the environment needed to run the installed local rock
directly, including the platform's library lookup path (`PATH` on Windows).
The facade requires Lua 5.5.0, matching the release rockspec.
The release includes a standalone `lonehash-lua-<version>.tar.gz` containing
the Lua facade, public header, rockspec template, and Lua build/staging scripts;
it builds against an installed `liblonehash` SDK discovered with `pkg-config`
or `LONEHASH_PREFIX`.

The Lua module exposes mutable `lonehash.sha256()` and `lonehash.md5()` objects
with `:reset()`, `:update(data)`, `:final()`, `:final_hex()`, `:digest(data)`,
`:digest_hex(data)`, `:file(path)`, and `:file_hex(path)`. `final()` and
`digest()` return raw digest bytes; `*_hex()` returns lowercase hexadecimal.
The top-level `sha256_*` and `md5_*` helpers are one-shot equivalents, and
`lonehash.version()` returns the linked library version.

## Release gates

```sh
make prerelease
make release
```

`prerelease` runs the complete release proof graph without cleaning first.
`release` starts from a clean build tree and then runs that same graph. After
the artifacts and their checksum manifest have been created, use this exact
upload set for a GitHub release:

```sh
make print-release-upload-assets
```

## Performance

Use release builds for throughput measurements:

```sh
make bench
./build/release/lh -sq FILE
```

`build/release/lh.sh` is a generated Lua development runner for testing the
source tree against the optimized `liblonehash.so`.
