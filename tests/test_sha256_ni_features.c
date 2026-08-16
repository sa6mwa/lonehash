#include "../src/lonehash_sha256_ni.c"

#include <stdlib.h>

int main(void) {
  unsigned int ssse3;
  unsigned int sse41;
  unsigned int sha;

  ssse3 = 1U << 9;
  sse41 = 1U << 19;
  sha = 1U << 29;
  if (!lh_sha256_ni_features_available(ssse3 | sse41, sha) ||
      lh_sha256_ni_features_available(sse41, sha) ||
      lh_sha256_ni_features_available(ssse3, sha) ||
      lh_sha256_ni_features_available(ssse3 | sse41, 0U)) {
    return EXIT_FAILURE;
  }
  return EXIT_SUCCESS;
}
