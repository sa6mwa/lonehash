#include "lonehash/lonehash.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int failures = 0;

static void expect_string(const char *name, const char *got, const char *want) {
  if (strcmp(got, want) != 0) {
    fprintf(stderr, "%s: got %s want %s\n", name, got, want);
    failures++;
  }
}

static void expect_status(const char *name, lonehash_status got,
                          lonehash_status want) {
  if (got != want) {
    fprintf(stderr, "%s: got %s want %s\n", name, lonehash_status_string(got),
            lonehash_status_string(want));
    failures++;
  }
}

static void test_sha256_vectors(void) {
  lonehash_sha256 *sha;
  unsigned char digest[LONEHASH_SHA256_DIGEST_SIZE];
  char hex[LONEHASH_SHA256_HEX_SIZE];
  const char *abc;

  abc = "abc";
  expect_status("sha256 create", lonehash_sha256_create(&sha), LONEHASH_OK);
  expect_status("sha256 empty", sha->digest_buffer(sha, "", 0, digest),
                LONEHASH_OK);
  sha->hex(sha, digest, hex);
  expect_string("sha256 empty hex", hex,
                "e3b0c44298fc1c149afbf4c8996fb924"
                "27ae41e4649b934ca495991b7852b855");

  expect_status("sha256 reset", sha->reset(sha), LONEHASH_OK);
  expect_status("sha256 a", sha->update(sha, abc, 1), LONEHASH_OK);
  expect_status("sha256 b", sha->update(sha, abc + 1, 1), LONEHASH_OK);
  expect_status("sha256 c", sha->update(sha, abc + 2, 1), LONEHASH_OK);
  expect_status("sha256 final", sha->final(sha, digest), LONEHASH_OK);
  sha->hex(sha, digest, hex);
  expect_string("sha256 abc hex", hex,
                "ba7816bf8f01cfea414140de5dae2223"
                "b00361a396177a9cb410ff61f20015ad");
  lonehash_sha256_destroy(sha);
}

static void test_md5_vectors(void) {
  lonehash_md5 *md5;
  unsigned char digest[LONEHASH_MD5_DIGEST_SIZE];
  char hex[LONEHASH_MD5_HEX_SIZE];
  const char *abc;

  abc = "abc";
  expect_status("md5 create", lonehash_md5_create(&md5), LONEHASH_OK);
  expect_status("md5 empty", md5->digest_buffer(md5, "", 0, digest),
                LONEHASH_OK);
  md5->hex(md5, digest, hex);
  expect_string("md5 empty hex", hex, "d41d8cd98f00b204e9800998ecf8427e");

  expect_status("md5 reset", md5->reset(md5), LONEHASH_OK);
  expect_status("md5 a", md5->update(md5, abc, 1), LONEHASH_OK);
  expect_status("md5 b", md5->update(md5, abc + 1, 1), LONEHASH_OK);
  expect_status("md5 c", md5->update(md5, abc + 2, 1), LONEHASH_OK);
  expect_status("md5 final", md5->final(md5, digest), LONEHASH_OK);
  md5->hex(md5, digest, hex);
  expect_string("md5 abc hex", hex, "900150983cd24fb0d6963f7d28e17f72");
  lonehash_md5_destroy(md5);
}

static void test_file_helpers(void) {
  lonehash_sha256 *sha;
  lonehash_md5 *md5;
  unsigned char digest32[LONEHASH_SHA256_DIGEST_SIZE];
  unsigned char digest16[LONEHASH_MD5_DIGEST_SIZE];
  char sha_hex[LONEHASH_SHA256_HEX_SIZE];
  char md5_hex[LONEHASH_MD5_HEX_SIZE];
  FILE *file;
  const char *path = "lonehash-test-input.txt";

  file = fopen(path, "wb");
  if (file == NULL) {
    fprintf(stderr, "failed to create %s\n", path);
    failures++;
    return;
  }
  fputs("abc", file);
  fclose(file);

  expect_status("sha256 create file", lonehash_sha256_create(&sha),
                LONEHASH_OK);
  expect_status("md5 create file", lonehash_md5_create(&md5), LONEHASH_OK);
  expect_status("sha256 path", sha->digest_path(sha, path, digest32),
                LONEHASH_OK);
  expect_status("md5 path", md5->digest_path(md5, path, digest16), LONEHASH_OK);
  sha->hex(sha, digest32, sha_hex);
  md5->hex(md5, digest16, md5_hex);
  expect_string("sha256 path hex", sha_hex,
                "ba7816bf8f01cfea414140de5dae2223"
                "b00361a396177a9cb410ff61f20015ad");
  expect_string("md5 path hex", md5_hex, "900150983cd24fb0d6963f7d28e17f72");
  lonehash_sha256_destroy(sha);
  lonehash_md5_destroy(md5);
}

static void test_error_paths(void) {
  lonehash_sha256 *sha;
  lonehash_md5 *md5;
  unsigned char digest[LONEHASH_SHA256_DIGEST_SIZE];

  expect_status("sha256 null out", lonehash_sha256_create(NULL),
                LONEHASH_ERROR_NULL);
  expect_status("sha256 create errors", lonehash_sha256_create(&sha),
                LONEHASH_OK);
  expect_status("sha256 null update", sha->update(sha, NULL, 1),
                LONEHASH_ERROR_NULL);
  expect_status("sha256 buffered byte", sha->update(sha, "a", 1), LONEHASH_OK);
  expect_status("sha256 null zero update", sha->update(sha, NULL, 0),
                LONEHASH_OK);
  expect_status("sha256 after null zero final", sha->final(sha, digest),
                LONEHASH_OK);
  expect_status("sha256 null path", sha->digest_path(sha, NULL, NULL),
                LONEHASH_ERROR_NULL);
  lonehash_sha256_destroy(sha);
  lonehash_sha256_destroy(NULL);

  expect_status("md5 create errors", lonehash_md5_create(&md5), LONEHASH_OK);
  expect_status("md5 null update", md5->update(md5, NULL, 1),
                LONEHASH_ERROR_NULL);
  expect_status("md5 buffered byte", md5->update(md5, "a", 1), LONEHASH_OK);
  expect_status("md5 null zero update", md5->update(md5, NULL, 0), LONEHASH_OK);
  lonehash_md5_destroy(md5);
}

static void test_large_one_shot_update_matches_streaming(void) {
  lonehash_sha256 *sha_one;
  lonehash_sha256 *sha_stream;
  unsigned char *data;
  unsigned char one_digest[LONEHASH_SHA256_DIGEST_SIZE];
  unsigned char stream_digest[LONEHASH_SHA256_DIGEST_SIZE];
  char one_hex[LONEHASH_SHA256_HEX_SIZE];
  char stream_hex[LONEHASH_SHA256_HEX_SIZE];
  size_t size;
  size_t offset;
  size_t chunk;

  sha_one = NULL;
  sha_stream = NULL;
  size = (size_t)536870912UL;
  data = (unsigned char *)malloc(size);
  if (data == NULL) {
    fprintf(stderr, "large update regression allocation failed\n");
    failures++;
    return;
  }
  memset(data, 'a', size);

  if (lonehash_sha256_create(&sha_one) != LONEHASH_OK ||
      lonehash_sha256_create(&sha_stream) != LONEHASH_OK) {
    fprintf(stderr, "large update regression handle allocation failed\n");
    lonehash_sha256_destroy(sha_one);
    lonehash_sha256_destroy(sha_stream);
    free(data);
    failures++;
    return;
  }
  expect_status("sha256 large one-shot",
                sha_one->digest_buffer(sha_one, data, size, one_digest),
                LONEHASH_OK);

  offset = 0;
  chunk = 1048576UL;
  while (offset < size) {
    size_t n;

    n = size - offset;
    if (n > chunk) {
      n = chunk;
    }
    expect_status("sha256 large stream update",
                  sha_stream->update(sha_stream, data + offset, n),
                  LONEHASH_OK);
    offset += n;
  }
  expect_status("sha256 large stream final",
                sha_stream->final(sha_stream, stream_digest), LONEHASH_OK);
  sha_one->hex(sha_one, one_digest, one_hex);
  sha_stream->hex(sha_stream, stream_digest, stream_hex);
  expect_string("sha256 large one-shot vs stream", one_hex, stream_hex);

  lonehash_sha256_destroy(sha_one);
  lonehash_sha256_destroy(sha_stream);
  free(data);
}

int main(void) {
  test_sha256_vectors();
  test_md5_vectors();
  test_file_helpers();
  test_error_paths();
  test_large_one_shot_update_matches_streaming();
  return failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
