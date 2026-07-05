#include "lonehash/lonehash.h"

int main(void) {
  lonehash_sha256 *sha = 0;
  lonehash_md5 *md5 = 0;
  if (lonehash_sha256_create(&sha) != LONEHASH_OK) {
    return 1;
  }
  if (lonehash_md5_create(&md5) != LONEHASH_OK) {
    lonehash_sha256_destroy(sha);
    return 1;
  }
  lonehash_sha256_destroy(sha);
  lonehash_md5_destroy(md5);
  return 0;
}
