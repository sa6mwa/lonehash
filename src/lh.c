#include "lonehash/lonehash.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef enum lh_algorithm { LH_ALG_MD5 = 1, LH_ALG_SHA256 = 2 } lh_algorithm;

static const char *lh_basename(const char *path) {
  const char *slash;
  const char *backslash;

  slash = strrchr(path, '/');
  backslash = strrchr(path, '\\');
  if (slash == NULL || (backslash != NULL && backslash > slash)) {
    slash = backslash;
  }
  return slash == NULL ? path : slash + 1;
}

static void lh_usage(FILE *out, const char *prog) {
  fprintf(out, "usage: %s [--sha256|-s] [--md5|-5] [-q] [-z] [FILE]...\n",
          prog);
}

static int lh_parse_short_options(const char *arg, lh_algorithm *alg,
                                  int *quiet, int *nul, char *bad) {
  const char *p;

  p = arg + 1;
  while (*p != '\0') {
    if (*p == '5') {
      *alg = LH_ALG_MD5;
    } else if (*p == 's') {
      *alg = LH_ALG_SHA256;
    } else if (*p == 'q') {
      *quiet = 1;
    } else if (*p == 'z') {
      *nul = 1;
    } else {
      *bad = *p;
      return 1;
    }
    ++p;
  }
  return 0;
}

static int lh_digest_stream(lh_algorithm alg, FILE *file, char *hex) {
  lonehash_sha256 *sha = NULL;
  lonehash_md5 *md5 = NULL;
  unsigned char sha_digest[LONEHASH_SHA256_DIGEST_SIZE];
  unsigned char md5_digest[LONEHASH_MD5_DIGEST_SIZE];
  lonehash_status status;

  if (alg == LH_ALG_MD5) {
    status = lonehash_md5_create(&md5);
    if (status == LONEHASH_OK) {
      status = md5->digest_file(md5, file, md5_digest);
    }
    if (status == LONEHASH_OK) {
      md5->hex(md5, md5_digest, hex);
    }
    lonehash_md5_destroy(md5);
  } else {
    status = lonehash_sha256_create(&sha);
    if (status == LONEHASH_OK) {
      status = sha->digest_file(sha, file, sha_digest);
    }
    if (status == LONEHASH_OK) {
      sha->hex(sha, sha_digest, hex);
    }
    lonehash_sha256_destroy(sha);
  }

  return status == LONEHASH_OK ? 0 : 1;
}

static int lh_digest_path(lh_algorithm alg, const char *path, char *hex) {
  FILE *file;
  int rc;

  if (strcmp(path, "-") == 0) {
    return lh_digest_stream(alg, stdin, hex);
  }

  file = fopen(path, "rb");
  if (file == NULL) {
    return 1;
  }
  rc = lh_digest_stream(alg, file, hex);
  if (fclose(file) != 0) {
    rc = 1;
  }
  return rc;
}

static void lh_print_sum(const char *hex, const char *name, int nul) {
  fputs(hex, stdout);
  fputs("  ", stdout);
  fputs(name, stdout);
  fputc(nul ? '\0' : '\n', stdout);
}

static void lh_print_quiet_sum(const char *hex, int nul) {
  fputs(hex, stdout);
  if (!nul) {
    fputc('\n', stdout);
  }
}

int main(int argc, char **argv) {
  lh_algorithm alg;
  int quiet;
  int nul;
  int first_file;
  int i;
  int failed;
  const char *prog;
  char hex[LONEHASH_SHA256_HEX_SIZE];

  prog = argc > 0 ? lh_basename(argv[0]) : "lh";
  alg = LH_ALG_SHA256;
  if (strcmp(prog, "md5sum") == 0) {
    alg = LH_ALG_MD5;
  } else if (strcmp(prog, "sha256sum") == 0) {
    alg = LH_ALG_SHA256;
  }

  quiet = 0;
  nul = 0;
  first_file = argc;
  for (i = 1; i < argc; ++i) {
    if (strcmp(argv[i], "--") == 0) {
      first_file = i + 1;
      break;
    } else if (strcmp(argv[i], "--help") == 0) {
      lh_usage(stdout, prog);
      return 0;
    } else if (strcmp(argv[i], "--md5") == 0 || strcmp(argv[i], "-5") == 0) {
      alg = LH_ALG_MD5;
    } else if (strcmp(argv[i], "--sha256") == 0 || strcmp(argv[i], "-s") == 0) {
      alg = LH_ALG_SHA256;
    } else if (strcmp(argv[i], "--quiet") == 0 || strcmp(argv[i], "-q") == 0) {
      quiet = 1;
    } else if (strcmp(argv[i], "-z") == 0) {
      nul = 1;
    } else if (argv[i][0] == '-' && argv[i][1] != '\0' &&
               strcmp(argv[i], "-") != 0) {
      char bad;

      bad = '\0';
      if (lh_parse_short_options(argv[i], &alg, &quiet, &nul, &bad) != 0) {
        fprintf(stderr, "%s: unknown option: -%c\n", prog, bad);
        lh_usage(stderr, prog);
        return 2;
      }
    } else {
      first_file = i;
      break;
    }
  }

  failed = 0;
  if (first_file >= argc) {
    if (lh_digest_stream(alg, stdin, hex) != 0) {
      fprintf(stderr, "%s: stdin: read failed\n", prog);
      return 1;
    }
    if (quiet) {
      lh_print_quiet_sum(hex, nul);
    } else {
      lh_print_sum(hex, "-", nul);
    }
    return 0;
  }

  if (quiet && argc - first_file != 1) {
    fprintf(stderr, "%s: --quiet requires stdin or exactly one FILE\n", prog);
    return 2;
  }

  for (i = first_file; i < argc; ++i) {
    if (lh_digest_path(alg, argv[i], hex) != 0) {
      fprintf(stderr, "%s: %s: read failed\n", prog, argv[i]);
      failed = 1;
    } else if (quiet) {
      lh_print_quiet_sum(hex, nul);
    } else {
      lh_print_sum(hex, strcmp(argv[i], "-") == 0 ? "-" : argv[i], nul);
    }
  }

  return failed ? 1 : 0;
}
