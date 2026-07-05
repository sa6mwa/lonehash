#include "lonehash/lonehash.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define BENCH_SIZE (1024U * 1024U)
#define BENCH_ROUNDS 128U

static double elapsed_seconds(clock_t start, clock_t stop) {
  return (double)(stop - start) / (double)CLOCKS_PER_SEC;
}

int main(void) {
  lonehash_sha256 *sha = NULL;
  lonehash_md5 *md5 = NULL;
  unsigned char *buffer;
  unsigned char digest32[LONEHASH_SHA256_DIGEST_SIZE];
  unsigned char digest16[LONEHASH_MD5_DIGEST_SIZE];
  clock_t start;
  clock_t stop;
  unsigned int i;
  double seconds;

  buffer = (unsigned char *)malloc(BENCH_SIZE);
  if (buffer == NULL) {
    return 1;
  }
  memset(buffer, 0xA5, BENCH_SIZE);
  if (lonehash_sha256_create(&sha) != LONEHASH_OK ||
      lonehash_md5_create(&md5) != LONEHASH_OK) {
    free(buffer);
    lonehash_sha256_destroy(sha);
    lonehash_md5_destroy(md5);
    return 1;
  }

  start = clock();
  for (i = 0; i < BENCH_ROUNDS; ++i) {
    sha->digest_buffer(sha, buffer, BENCH_SIZE, digest32);
  }
  stop = clock();
  seconds = elapsed_seconds(start, stop);
  printf("sha256 bytes=%u seconds=%.6f mbps=%.3f\n", BENCH_SIZE * BENCH_ROUNDS,
         seconds,
         ((double)BENCH_SIZE * (double)BENCH_ROUNDS) / (1024.0 * 1024.0) /
             seconds);

  start = clock();
  for (i = 0; i < BENCH_ROUNDS; ++i) {
    md5->digest_buffer(md5, buffer, BENCH_SIZE, digest16);
  }
  stop = clock();
  seconds = elapsed_seconds(start, stop);
  printf("md5 bytes=%u seconds=%.6f mbps=%.3f\n", BENCH_SIZE * BENCH_ROUNDS,
         seconds,
         ((double)BENCH_SIZE * (double)BENCH_ROUNDS) / (1024.0 * 1024.0) /
             seconds);

  lonehash_sha256_destroy(sha);
  lonehash_md5_destroy(md5);
  free(buffer);
  return 0;
}
