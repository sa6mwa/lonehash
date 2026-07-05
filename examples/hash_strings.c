#include "lonehash/lonehash.h"

#include <stdio.h>

int main(void) {
  lonehash_sha256 *sha = NULL;
  lonehash_md5 *md5 = NULL;
  unsigned char sha_digest[LONEHASH_SHA256_DIGEST_SIZE];
  unsigned char md5_digest[LONEHASH_MD5_DIGEST_SIZE];
  char sha_hex[LONEHASH_SHA256_HEX_SIZE];
  char md5_hex[LONEHASH_MD5_HEX_SIZE];
  const char *message = "abc";

  if (lonehash_sha256_create(&sha) != LONEHASH_OK ||
      lonehash_md5_create(&md5) != LONEHASH_OK) {
    lonehash_sha256_destroy(sha);
    lonehash_md5_destroy(md5);
    return 1;
  }

  sha->digest_buffer(sha, message, 3, sha_digest);
  md5->digest_buffer(md5, message, 3, md5_digest);
  sha->hex(sha, sha_digest, sha_hex);
  md5->hex(md5, md5_digest, md5_hex);

  printf("sha256 %s\n", sha_hex);
  printf("md5 %s\n", md5_hex);

  lonehash_sha256_destroy(sha);
  lonehash_md5_destroy(md5);
  return 0;
}
