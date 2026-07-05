#include "lonehash/lonehash.h"

#include <stdio.h>

int main(int argc, char **argv) {
  lonehash_sha256 *sha = NULL;
  unsigned char digest[LONEHASH_SHA256_DIGEST_SIZE];
  char hex[LONEHASH_SHA256_HEX_SIZE];

  if (argc != 2) {
    fprintf(stderr, "usage: hash_file FILE\n");
    return 2;
  }
  if (lonehash_sha256_create(&sha) != LONEHASH_OK) {
    return 1;
  }
  if (sha->digest_path(sha, argv[1], digest) != LONEHASH_OK) {
    fprintf(stderr, "failed to hash %s\n", argv[1]);
    lonehash_sha256_destroy(sha);
    return 1;
  }
  sha->hex(sha, digest, hex);
  printf("%s  %s\n", hex, argv[1]);
  lonehash_sha256_destroy(sha);
  return 0;
}
