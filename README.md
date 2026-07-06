# lonehash

`liblonehash` is a small C89 SHA-256 and MD5 library with caller-owned streaming
contexts and zero-allocation update/final hot paths.

The public API supports:

- streaming SHA-256 and MD5 over arbitrarily large inputs;
- one-shot bounded-buffer helpers;
- `FILE *` and path-based file helpers that use bounded stack buffers;
- lowercase hexadecimal digest formatting;
- CMake package exports and `pkg-config` metadata.

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
cmake --preset debug
cmake --build --preset debug
ctest --preset debug
```

The lifecycle command surface is available through:

```sh
make help
```

## Lua

The Lua facade links against `liblonehash` through the public C API only.

```sh
make lua-test
printf abc | ./build/debug/lh.sh -sq
lua lua/examples/hash_strings.lua
```

Lua release artifacts are produced with:

```sh
make lua-artifacts
```

## Example

```c
#include <lonehash/lonehash.h>

lonehash_sha256 *sha;
unsigned char digest[LONEHASH_SHA256_DIGEST_SIZE];
char hex[LONEHASH_SHA256_HEX_SIZE];

lonehash_sha256_create(&sha);
sha->update(sha, "hello", 5);
sha->final(sha, digest);
sha->hex(sha, digest, hex);
lonehash_sha256_destroy(sha);
```
