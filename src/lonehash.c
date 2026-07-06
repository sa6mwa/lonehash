#include "lonehash/lonehash.h"

#include <limits.h>
#include <stdlib.h>
#include <string.h>

#define LH_U32_MASK 0xffffffffU
#define LH_FILE_BUFFER_SIZE 32768

#if UINT_MAX != 0xffffffffU
#error "lonehash requires a 32-bit unsigned int"
#endif

typedef unsigned int lh_u32;

#if LONEHASH_HAVE_SHA_NI
int lonehash_sha256_ni_available(void);
void lonehash_sha256_ni_transform(lh_u32 state[8],
                                  const unsigned char block[64]);
#endif
#if LONEHASH_HAVE_ARM_SHA2
int lonehash_sha256_armv8_available(void);
void lonehash_sha256_armv8_transform(lh_u32 state[8],
                                     const unsigned char block[64]);
#endif

typedef struct lh_sha256_impl {
  lh_u32 state[8];
  lh_u32 bit_count_low;
  lh_u32 bit_count_high;
  unsigned char buffer[LONEHASH_SHA256_BLOCK_SIZE];
  unsigned int buffer_len;
} lh_sha256_impl;

typedef struct lh_md5_impl {
  lh_u32 state[4];
  lh_u32 bit_count_low;
  lh_u32 bit_count_high;
  unsigned char buffer[LONEHASH_MD5_BLOCK_SIZE];
  unsigned int buffer_len;
} lh_md5_impl;

static lh_u32 lh_wrap(lh_u32 x) { return x & LH_U32_MASK; }

static lh_u32 lh_load_be32(const unsigned char *p) {
  return ((lh_u32)p[0] << 24) | ((lh_u32)p[1] << 16) | ((lh_u32)p[2] << 8) |
         (lh_u32)p[3];
}

static lh_u32 lh_load_le32(const unsigned char *p) {
  return (lh_u32)p[0] | ((lh_u32)p[1] << 8) | ((lh_u32)p[2] << 16) |
         ((lh_u32)p[3] << 24);
}

static void lh_store_be32(unsigned char *p, lh_u32 x) {
  x = lh_wrap(x);
  p[0] = (unsigned char)(x >> 24);
  p[1] = (unsigned char)(x >> 16);
  p[2] = (unsigned char)(x >> 8);
  p[3] = (unsigned char)x;
}

static void lh_store_le32(unsigned char *p, lh_u32 x) {
  x = lh_wrap(x);
  p[0] = (unsigned char)x;
  p[1] = (unsigned char)(x >> 8);
  p[2] = (unsigned char)(x >> 16);
  p[3] = (unsigned char)(x >> 24);
}

static lh_u32 lh_rotr(lh_u32 x, unsigned int n) {
  x = lh_wrap(x);
  return lh_wrap((x >> n) | (x << (32U - n)));
}

static lh_u32 lh_rotl(lh_u32 x, unsigned int n) {
  x = lh_wrap(x);
  return lh_wrap((x << n) | (x >> (32U - n)));
}

static void lh_add_bits(lh_u32 *low, lh_u32 *high, size_t len) {
  lh_u32 before;
  lh_u32 bytes_low;
  lh_u32 bytes_high;
  size_t n;

  bytes_low = 0;
  bytes_high = 0;
  n = len;
  while (n >= 0x20000000UL) {
    bytes_high = lh_wrap(bytes_high + 1UL);
    n -= 0x20000000UL;
  }
  bytes_low = (lh_u32)n;

  before = *low;
  *low = lh_wrap(*low + lh_wrap(bytes_low << 3));
  *high = lh_wrap(*high + bytes_high);
  *high = lh_wrap(*high + (bytes_low >> 29));
  if (*low < before) {
    *high = lh_wrap(*high + 1UL);
  }
}

static int lh_valid_sha256(lonehash_sha256 *self) {
  return self != NULL && self->impl != NULL;
}

static int lh_valid_md5(lonehash_md5 *self) {
  return self != NULL && self->impl != NULL;
}

const char *lonehash_status_string(lonehash_status status) {
  switch (status) {
  case LONEHASH_OK:
    return "ok";
  case LONEHASH_ERROR_NULL:
    return "null argument";
  case LONEHASH_ERROR_ALLOC:
    return "allocation failed";
  case LONEHASH_ERROR_IO:
    return "i/o error";
  default:
    return "unknown error";
  }
}

static const lh_u32 lh_sha256_k[64] = {
    0x428a2f98UL, 0x71374491UL, 0xb5c0fbcfUL, 0xe9b5dba5UL, 0x3956c25bUL,
    0x59f111f1UL, 0x923f82a4UL, 0xab1c5ed5UL, 0xd807aa98UL, 0x12835b01UL,
    0x243185beUL, 0x550c7dc3UL, 0x72be5d74UL, 0x80deb1feUL, 0x9bdc06a7UL,
    0xc19bf174UL, 0xe49b69c1UL, 0xefbe4786UL, 0x0fc19dc6UL, 0x240ca1ccUL,
    0x2de92c6fUL, 0x4a7484aaUL, 0x5cb0a9dcUL, 0x76f988daUL, 0x983e5152UL,
    0xa831c66dUL, 0xb00327c8UL, 0xbf597fc7UL, 0xc6e00bf3UL, 0xd5a79147UL,
    0x06ca6351UL, 0x14292967UL, 0x27b70a85UL, 0x2e1b2138UL, 0x4d2c6dfcUL,
    0x53380d13UL, 0x650a7354UL, 0x766a0abbUL, 0x81c2c92eUL, 0x92722c85UL,
    0xa2bfe8a1UL, 0xa81a664bUL, 0xc24b8b70UL, 0xc76c51a3UL, 0xd192e819UL,
    0xd6990624UL, 0xf40e3585UL, 0x106aa070UL, 0x19a4c116UL, 0x1e376c08UL,
    0x2748774cUL, 0x34b0bcb5UL, 0x391c0cb3UL, 0x4ed8aa4aUL, 0x5b9cca4fUL,
    0x682e6ff3UL, 0x748f82eeUL, 0x78a5636fUL, 0x84c87814UL, 0x8cc70208UL,
    0x90befffaUL, 0xa4506cebUL, 0xbef9a3f7UL, 0xc67178f2UL};

#define LH_SHA256_CH(x, y, z) (((x) & (y)) ^ (~(x) & (z)))
#define LH_SHA256_MAJ(x, y, z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define LH_SHA256_BSIG0(x)                                                     \
  (lh_rotr((x), 2) ^ lh_rotr((x), 13) ^ lh_rotr((x), 22))
#define LH_SHA256_BSIG1(x)                                                     \
  (lh_rotr((x), 6) ^ lh_rotr((x), 11) ^ lh_rotr((x), 25))
#define LH_SHA256_SSIG0(x) (lh_rotr((x), 7) ^ lh_rotr((x), 18) ^ ((x) >> 3))
#define LH_SHA256_SSIG1(x) (lh_rotr((x), 17) ^ lh_rotr((x), 19) ^ ((x) >> 10))
#define LH_SHA256_ROUND(a, b, c, d, e, f, g, h, word, constant)                \
  do {                                                                         \
    lh_u32 t1_;                                                                \
    lh_u32 t2_;                                                                \
    t1_ = (h) + LH_SHA256_BSIG1(e) + LH_SHA256_CH((e), (f), (g)) +             \
          (constant) + (word);                                                 \
    t2_ = LH_SHA256_BSIG0(a) + LH_SHA256_MAJ((a), (b), (c));                   \
    (d) += t1_;                                                                \
    (h) = t1_ + t2_;                                                           \
  } while (0)
#define LH_SHA256_W(i)                                                         \
  (w[(i) & 15U] += LH_SHA256_SSIG1(w[((i) - 2U) & 15U]) +                      \
                   w[((i) - 7U) & 15U] +                                       \
                   LH_SHA256_SSIG0(w[((i) - 15U) & 15U]))
#define LH_SHA256_ROUND_LOAD(i, a, b, c, d, e, f, g, h)                        \
  LH_SHA256_ROUND((a), (b), (c), (d), (e), (f), (g), (h), w[(i)],              \
                  lh_sha256_k[(i)])
#define LH_SHA256_ROUND_SCHED(i, a, b, c, d, e, f, g, h)                       \
  LH_SHA256_ROUND((a), (b), (c), (d), (e), (f), (g), (h), LH_SHA256_W(i),      \
                  lh_sha256_k[(i)])

static void lh_sha256_transform_scalar(lh_sha256_impl *ctx,
                                       const unsigned char block[64]) {
  lh_u32 w[16];
  lh_u32 a, b, c, d, e, f, g, h;
  unsigned int i;

  for (i = 0; i < 16; ++i) {
    w[i] = lh_load_be32(block + (i * 4U));
  }

  a = ctx->state[0];
  b = ctx->state[1];
  c = ctx->state[2];
  d = ctx->state[3];
  e = ctx->state[4];
  f = ctx->state[5];
  g = ctx->state[6];
  h = ctx->state[7];

  LH_SHA256_ROUND_LOAD(0, a, b, c, d, e, f, g, h);
  LH_SHA256_ROUND_LOAD(1, h, a, b, c, d, e, f, g);
  LH_SHA256_ROUND_LOAD(2, g, h, a, b, c, d, e, f);
  LH_SHA256_ROUND_LOAD(3, f, g, h, a, b, c, d, e);
  LH_SHA256_ROUND_LOAD(4, e, f, g, h, a, b, c, d);
  LH_SHA256_ROUND_LOAD(5, d, e, f, g, h, a, b, c);
  LH_SHA256_ROUND_LOAD(6, c, d, e, f, g, h, a, b);
  LH_SHA256_ROUND_LOAD(7, b, c, d, e, f, g, h, a);
  LH_SHA256_ROUND_LOAD(8, a, b, c, d, e, f, g, h);
  LH_SHA256_ROUND_LOAD(9, h, a, b, c, d, e, f, g);
  LH_SHA256_ROUND_LOAD(10, g, h, a, b, c, d, e, f);
  LH_SHA256_ROUND_LOAD(11, f, g, h, a, b, c, d, e);
  LH_SHA256_ROUND_LOAD(12, e, f, g, h, a, b, c, d);
  LH_SHA256_ROUND_LOAD(13, d, e, f, g, h, a, b, c);
  LH_SHA256_ROUND_LOAD(14, c, d, e, f, g, h, a, b);
  LH_SHA256_ROUND_LOAD(15, b, c, d, e, f, g, h, a);
  LH_SHA256_ROUND_SCHED(16, a, b, c, d, e, f, g, h);
  LH_SHA256_ROUND_SCHED(17, h, a, b, c, d, e, f, g);
  LH_SHA256_ROUND_SCHED(18, g, h, a, b, c, d, e, f);
  LH_SHA256_ROUND_SCHED(19, f, g, h, a, b, c, d, e);
  LH_SHA256_ROUND_SCHED(20, e, f, g, h, a, b, c, d);
  LH_SHA256_ROUND_SCHED(21, d, e, f, g, h, a, b, c);
  LH_SHA256_ROUND_SCHED(22, c, d, e, f, g, h, a, b);
  LH_SHA256_ROUND_SCHED(23, b, c, d, e, f, g, h, a);
  LH_SHA256_ROUND_SCHED(24, a, b, c, d, e, f, g, h);
  LH_SHA256_ROUND_SCHED(25, h, a, b, c, d, e, f, g);
  LH_SHA256_ROUND_SCHED(26, g, h, a, b, c, d, e, f);
  LH_SHA256_ROUND_SCHED(27, f, g, h, a, b, c, d, e);
  LH_SHA256_ROUND_SCHED(28, e, f, g, h, a, b, c, d);
  LH_SHA256_ROUND_SCHED(29, d, e, f, g, h, a, b, c);
  LH_SHA256_ROUND_SCHED(30, c, d, e, f, g, h, a, b);
  LH_SHA256_ROUND_SCHED(31, b, c, d, e, f, g, h, a);
  LH_SHA256_ROUND_SCHED(32, a, b, c, d, e, f, g, h);
  LH_SHA256_ROUND_SCHED(33, h, a, b, c, d, e, f, g);
  LH_SHA256_ROUND_SCHED(34, g, h, a, b, c, d, e, f);
  LH_SHA256_ROUND_SCHED(35, f, g, h, a, b, c, d, e);
  LH_SHA256_ROUND_SCHED(36, e, f, g, h, a, b, c, d);
  LH_SHA256_ROUND_SCHED(37, d, e, f, g, h, a, b, c);
  LH_SHA256_ROUND_SCHED(38, c, d, e, f, g, h, a, b);
  LH_SHA256_ROUND_SCHED(39, b, c, d, e, f, g, h, a);
  LH_SHA256_ROUND_SCHED(40, a, b, c, d, e, f, g, h);
  LH_SHA256_ROUND_SCHED(41, h, a, b, c, d, e, f, g);
  LH_SHA256_ROUND_SCHED(42, g, h, a, b, c, d, e, f);
  LH_SHA256_ROUND_SCHED(43, f, g, h, a, b, c, d, e);
  LH_SHA256_ROUND_SCHED(44, e, f, g, h, a, b, c, d);
  LH_SHA256_ROUND_SCHED(45, d, e, f, g, h, a, b, c);
  LH_SHA256_ROUND_SCHED(46, c, d, e, f, g, h, a, b);
  LH_SHA256_ROUND_SCHED(47, b, c, d, e, f, g, h, a);
  LH_SHA256_ROUND_SCHED(48, a, b, c, d, e, f, g, h);
  LH_SHA256_ROUND_SCHED(49, h, a, b, c, d, e, f, g);
  LH_SHA256_ROUND_SCHED(50, g, h, a, b, c, d, e, f);
  LH_SHA256_ROUND_SCHED(51, f, g, h, a, b, c, d, e);
  LH_SHA256_ROUND_SCHED(52, e, f, g, h, a, b, c, d);
  LH_SHA256_ROUND_SCHED(53, d, e, f, g, h, a, b, c);
  LH_SHA256_ROUND_SCHED(54, c, d, e, f, g, h, a, b);
  LH_SHA256_ROUND_SCHED(55, b, c, d, e, f, g, h, a);
  LH_SHA256_ROUND_SCHED(56, a, b, c, d, e, f, g, h);
  LH_SHA256_ROUND_SCHED(57, h, a, b, c, d, e, f, g);
  LH_SHA256_ROUND_SCHED(58, g, h, a, b, c, d, e, f);
  LH_SHA256_ROUND_SCHED(59, f, g, h, a, b, c, d, e);
  LH_SHA256_ROUND_SCHED(60, e, f, g, h, a, b, c, d);
  LH_SHA256_ROUND_SCHED(61, d, e, f, g, h, a, b, c);
  LH_SHA256_ROUND_SCHED(62, c, d, e, f, g, h, a, b);
  LH_SHA256_ROUND_SCHED(63, b, c, d, e, f, g, h, a);

  ctx->state[0] = lh_wrap(ctx->state[0] + a);
  ctx->state[1] = lh_wrap(ctx->state[1] + b);
  ctx->state[2] = lh_wrap(ctx->state[2] + c);
  ctx->state[3] = lh_wrap(ctx->state[3] + d);
  ctx->state[4] = lh_wrap(ctx->state[4] + e);
  ctx->state[5] = lh_wrap(ctx->state[5] + f);
  ctx->state[6] = lh_wrap(ctx->state[6] + g);
  ctx->state[7] = lh_wrap(ctx->state[7] + h);
}

static void lh_sha256_transform(lh_sha256_impl *ctx,
                                const unsigned char block[64]) {
#if LONEHASH_HAVE_SHA_NI
  static int use_sha_ni = -1;

  if (use_sha_ni < 0) {
    use_sha_ni = lonehash_sha256_ni_available();
  }
  if (use_sha_ni) {
    lonehash_sha256_ni_transform(ctx->state, block);
    return;
  }
#endif
#if LONEHASH_HAVE_ARM_SHA2
  static int use_arm_sha2 = -1;

  if (use_arm_sha2 < 0) {
    use_arm_sha2 = lonehash_sha256_armv8_available();
  }
  if (use_arm_sha2) {
    lonehash_sha256_armv8_transform(ctx->state, block);
    return;
  }
#endif
  lh_sha256_transform_scalar(ctx, block);
}

static lonehash_status lh_sha256_reset(lonehash_sha256 *self) {
  lh_sha256_impl *ctx;

  if (!lh_valid_sha256(self)) {
    return LONEHASH_ERROR_NULL;
  }
  ctx = (lh_sha256_impl *)self->impl;
  ctx->state[0] = 0x6a09e667UL;
  ctx->state[1] = 0xbb67ae85UL;
  ctx->state[2] = 0x3c6ef372UL;
  ctx->state[3] = 0xa54ff53aUL;
  ctx->state[4] = 0x510e527fUL;
  ctx->state[5] = 0x9b05688cUL;
  ctx->state[6] = 0x1f83d9abUL;
  ctx->state[7] = 0x5be0cd19UL;
  ctx->bit_count_low = 0;
  ctx->bit_count_high = 0;
  ctx->buffer_len = 0;
  return LONEHASH_OK;
}

static lonehash_status lh_sha256_update(lonehash_sha256 *self, const void *data,
                                        size_t len) {
  lh_sha256_impl *ctx;
  const unsigned char *p;
  size_t take;

  if (!lh_valid_sha256(self) || (data == NULL && len != 0)) {
    return LONEHASH_ERROR_NULL;
  }
  if (len == 0) {
    return LONEHASH_OK;
  }
  ctx = (lh_sha256_impl *)self->impl;
  p = (const unsigned char *)data;
  lh_add_bits(&ctx->bit_count_low, &ctx->bit_count_high, len);

  if (ctx->buffer_len != 0U) {
    take = 64U - ctx->buffer_len;
    if (take > len) {
      take = len;
    }
    memcpy(ctx->buffer + ctx->buffer_len, p, take);
    ctx->buffer_len += (unsigned int)take;
    p += take;
    len -= take;
    if (ctx->buffer_len == 64U) {
      lh_sha256_transform(ctx, ctx->buffer);
      ctx->buffer_len = 0;
    }
  }

  while (len >= 64U) {
    lh_sha256_transform(ctx, p);
    p += 64U;
    len -= 64U;
  }

  if (len > 0) {
    memcpy(ctx->buffer, p, len);
    ctx->buffer_len = (unsigned int)len;
  }
  return LONEHASH_OK;
}

static lonehash_status lh_sha256_final(lonehash_sha256 *self,
                                       unsigned char digest[32]) {
  lh_sha256_impl *ctx;
  unsigned int i;

  if (!lh_valid_sha256(self) || digest == NULL) {
    return LONEHASH_ERROR_NULL;
  }
  ctx = (lh_sha256_impl *)self->impl;
  i = ctx->buffer_len;
  ctx->buffer[i++] = 0x80U;
  if (i > 56U) {
    while (i < 64U) {
      ctx->buffer[i++] = 0;
    }
    lh_sha256_transform(ctx, ctx->buffer);
    i = 0;
  }
  while (i < 56U) {
    ctx->buffer[i++] = 0;
  }
  lh_store_be32(ctx->buffer + 56, ctx->bit_count_high);
  lh_store_be32(ctx->buffer + 60, ctx->bit_count_low);
  lh_sha256_transform(ctx, ctx->buffer);

  for (i = 0; i < 8U; ++i) {
    lh_store_be32(digest + (i * 4U), ctx->state[i]);
  }
  memset(ctx, 0, sizeof(*ctx));
  return LONEHASH_OK;
}

static const lh_u32 lh_md5_s[64] = {
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9,  14, 20, 5, 9,  14, 20, 5, 9,  14, 20, 5, 9,  14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21};

static const lh_u32 lh_md5_k[64] = {
    0xd76aa478UL, 0xe8c7b756UL, 0x242070dbUL, 0xc1bdceeeUL, 0xf57c0fafUL,
    0x4787c62aUL, 0xa8304613UL, 0xfd469501UL, 0x698098d8UL, 0x8b44f7afUL,
    0xffff5bb1UL, 0x895cd7beUL, 0x6b901122UL, 0xfd987193UL, 0xa679438eUL,
    0x49b40821UL, 0xf61e2562UL, 0xc040b340UL, 0x265e5a51UL, 0xe9b6c7aaUL,
    0xd62f105dUL, 0x02441453UL, 0xd8a1e681UL, 0xe7d3fbc8UL, 0x21e1cde6UL,
    0xc33707d6UL, 0xf4d50d87UL, 0x455a14edUL, 0xa9e3e905UL, 0xfcefa3f8UL,
    0x676f02d9UL, 0x8d2a4c8aUL, 0xfffa3942UL, 0x8771f681UL, 0x6d9d6122UL,
    0xfde5380cUL, 0xa4beea44UL, 0x4bdecfa9UL, 0xf6bb4b60UL, 0xbebfbc70UL,
    0x289b7ec6UL, 0xeaa127faUL, 0xd4ef3085UL, 0x04881d05UL, 0xd9d4d039UL,
    0xe6db99e5UL, 0x1fa27cf8UL, 0xc4ac5665UL, 0xf4292244UL, 0x432aff97UL,
    0xab9423a7UL, 0xfc93a039UL, 0x655b59c3UL, 0x8f0ccc92UL, 0xffeff47dUL,
    0x85845dd1UL, 0x6fa87e4fUL, 0xfe2ce6e0UL, 0xa3014314UL, 0x4e0811a1UL,
    0xf7537e82UL, 0xbd3af235UL, 0x2ad7d2bbUL, 0xeb86d391UL};

static void lh_md5_transform(lh_md5_impl *ctx, const unsigned char block[64]) {
  lh_u32 m[16];
  lh_u32 a, b, c, d, f, temp;
  unsigned int i, g;

  for (i = 0; i < 16U; ++i) {
    m[i] = lh_load_le32(block + (i * 4U));
  }

  a = ctx->state[0];
  b = ctx->state[1];
  c = ctx->state[2];
  d = ctx->state[3];

  for (i = 0; i < 16U; ++i) {
    f = (b & c) | ((~b) & d);
    g = i;
    temp = d;
    d = c;
    c = b;
    b = lh_wrap(b + lh_rotl(lh_wrap(a + f + lh_md5_k[i] + m[g]),
                            (unsigned int)lh_md5_s[i]));
    a = temp;
  }

  for (i = 16U; i < 32U; ++i) {
    f = (d & b) | ((~d) & c);
    g = (5U * i + 1U) & 15U;
    temp = d;
    d = c;
    c = b;
    b = lh_wrap(b + lh_rotl(lh_wrap(a + f + lh_md5_k[i] + m[g]),
                            (unsigned int)lh_md5_s[i]));
    a = temp;
  }

  for (i = 32U; i < 48U; ++i) {
    f = b ^ c ^ d;
    g = (3U * i + 5U) & 15U;
    temp = d;
    d = c;
    c = b;
    b = lh_wrap(b + lh_rotl(lh_wrap(a + f + lh_md5_k[i] + m[g]),
                            (unsigned int)lh_md5_s[i]));
    a = temp;
  }

  for (i = 48U; i < 64U; ++i) {
    f = c ^ (b | (~d));
    g = (7U * i) & 15U;
    temp = d;
    d = c;
    c = b;
    b = lh_wrap(b + lh_rotl(lh_wrap(a + f + lh_md5_k[i] + m[g]),
                            (unsigned int)lh_md5_s[i]));
    a = temp;
  }

  ctx->state[0] = lh_wrap(ctx->state[0] + a);
  ctx->state[1] = lh_wrap(ctx->state[1] + b);
  ctx->state[2] = lh_wrap(ctx->state[2] + c);
  ctx->state[3] = lh_wrap(ctx->state[3] + d);
}

static lonehash_status lh_md5_reset(lonehash_md5 *self) {
  lh_md5_impl *ctx;

  if (!lh_valid_md5(self)) {
    return LONEHASH_ERROR_NULL;
  }
  ctx = (lh_md5_impl *)self->impl;
  ctx->state[0] = 0x67452301UL;
  ctx->state[1] = 0xefcdab89UL;
  ctx->state[2] = 0x98badcfeUL;
  ctx->state[3] = 0x10325476UL;
  ctx->bit_count_low = 0;
  ctx->bit_count_high = 0;
  ctx->buffer_len = 0;
  return LONEHASH_OK;
}

static lonehash_status lh_md5_update(lonehash_md5 *self, const void *data,
                                     size_t len) {
  lh_md5_impl *ctx;
  const unsigned char *p;
  size_t take;

  if (!lh_valid_md5(self) || (data == NULL && len != 0)) {
    return LONEHASH_ERROR_NULL;
  }
  if (len == 0) {
    return LONEHASH_OK;
  }
  ctx = (lh_md5_impl *)self->impl;
  p = (const unsigned char *)data;
  lh_add_bits(&ctx->bit_count_low, &ctx->bit_count_high, len);

  if (ctx->buffer_len != 0U) {
    take = 64U - ctx->buffer_len;
    if (take > len) {
      take = len;
    }
    memcpy(ctx->buffer + ctx->buffer_len, p, take);
    ctx->buffer_len += (unsigned int)take;
    p += take;
    len -= take;
    if (ctx->buffer_len == 64U) {
      lh_md5_transform(ctx, ctx->buffer);
      ctx->buffer_len = 0;
    }
  }

  while (len >= 64U) {
    lh_md5_transform(ctx, p);
    p += 64U;
    len -= 64U;
  }

  if (len > 0) {
    memcpy(ctx->buffer, p, len);
    ctx->buffer_len = (unsigned int)len;
  }
  return LONEHASH_OK;
}

static lonehash_status lh_md5_final(lonehash_md5 *self,
                                    unsigned char digest[16]) {
  lh_md5_impl *ctx;
  unsigned int i;

  if (!lh_valid_md5(self) || digest == NULL) {
    return LONEHASH_ERROR_NULL;
  }
  ctx = (lh_md5_impl *)self->impl;
  i = ctx->buffer_len;
  ctx->buffer[i++] = 0x80U;
  if (i > 56U) {
    while (i < 64U) {
      ctx->buffer[i++] = 0;
    }
    lh_md5_transform(ctx, ctx->buffer);
    i = 0;
  }
  while (i < 56U) {
    ctx->buffer[i++] = 0;
  }
  lh_store_le32(ctx->buffer + 56, ctx->bit_count_low);
  lh_store_le32(ctx->buffer + 60, ctx->bit_count_high);
  lh_md5_transform(ctx, ctx->buffer);

  for (i = 0; i < 4U; ++i) {
    lh_store_le32(digest + (i * 4U), ctx->state[i]);
  }
  memset(ctx, 0, sizeof(*ctx));
  return LONEHASH_OK;
}

static void lh_hex(const unsigned char *digest, size_t len, char *hex) {
  static const char alphabet[] = "0123456789abcdef";
  size_t i;

  for (i = 0; i < len; ++i) {
    hex[i * 2U] = alphabet[digest[i] >> 4];
    hex[i * 2U + 1U] = alphabet[digest[i] & 15U];
  }
  hex[len * 2U] = '\0';
}

static lonehash_status lh_sha256_digest_buffer(lonehash_sha256 *self,
                                               const void *data, size_t len,
                                               unsigned char digest[32]) {
  lonehash_status status;

  if (!lh_valid_sha256(self) || digest == NULL || (data == NULL && len != 0)) {
    return LONEHASH_ERROR_NULL;
  }
  status = self->reset(self);
  if (status != LONEHASH_OK) {
    return status;
  }
  status = self->update(self, data, len);
  if (status != LONEHASH_OK) {
    return status;
  }
  return self->final(self, digest);
}

static lonehash_status lh_md5_digest_buffer(lonehash_md5 *self,
                                            const void *data, size_t len,
                                            unsigned char digest[16]) {
  lonehash_status status;

  if (!lh_valid_md5(self) || digest == NULL || (data == NULL && len != 0)) {
    return LONEHASH_ERROR_NULL;
  }
  status = self->reset(self);
  if (status != LONEHASH_OK) {
    return status;
  }
  status = self->update(self, data, len);
  if (status != LONEHASH_OK) {
    return status;
  }
  return self->final(self, digest);
}

static lonehash_status lh_sha256_digest_file(lonehash_sha256 *self, FILE *file,
                                             unsigned char digest[32]) {
  unsigned char buffer[LH_FILE_BUFFER_SIZE];
  lonehash_status status;
  size_t n;

  if (!lh_valid_sha256(self) || file == NULL || digest == NULL) {
    return LONEHASH_ERROR_NULL;
  }
  status = self->reset(self);
  if (status != LONEHASH_OK) {
    return status;
  }
  while ((n = fread(buffer, 1, sizeof(buffer), file)) > 0) {
    status = self->update(self, buffer, n);
    if (status != LONEHASH_OK) {
      return status;
    }
  }
  if (ferror(file)) {
    return LONEHASH_ERROR_IO;
  }
  return self->final(self, digest);
}

static lonehash_status lh_md5_digest_file(lonehash_md5 *self, FILE *file,
                                          unsigned char digest[16]) {
  unsigned char buffer[LH_FILE_BUFFER_SIZE];
  lonehash_status status;
  size_t n;

  if (!lh_valid_md5(self) || file == NULL || digest == NULL) {
    return LONEHASH_ERROR_NULL;
  }
  status = self->reset(self);
  if (status != LONEHASH_OK) {
    return status;
  }
  while ((n = fread(buffer, 1, sizeof(buffer), file)) > 0) {
    status = self->update(self, buffer, n);
    if (status != LONEHASH_OK) {
      return status;
    }
  }
  if (ferror(file)) {
    return LONEHASH_ERROR_IO;
  }
  return self->final(self, digest);
}

static lonehash_status lh_sha256_digest_path(lonehash_sha256 *self,
                                             const char *path,
                                             unsigned char digest[32]) {
  FILE *file;
  lonehash_status status;

  if (!lh_valid_sha256(self) || path == NULL || digest == NULL) {
    return LONEHASH_ERROR_NULL;
  }
  file = fopen(path, "rb");
  if (file == NULL) {
    return LONEHASH_ERROR_IO;
  }
  status = self->digest_file(self, file, digest);
  if (fclose(file) != 0 && status == LONEHASH_OK) {
    status = LONEHASH_ERROR_IO;
  }
  return status;
}

static lonehash_status lh_md5_digest_path(lonehash_md5 *self, const char *path,
                                          unsigned char digest[16]) {
  FILE *file;
  lonehash_status status;

  if (!lh_valid_md5(self) || path == NULL || digest == NULL) {
    return LONEHASH_ERROR_NULL;
  }
  file = fopen(path, "rb");
  if (file == NULL) {
    return LONEHASH_ERROR_IO;
  }
  status = self->digest_file(self, file, digest);
  if (fclose(file) != 0 && status == LONEHASH_OK) {
    status = LONEHASH_ERROR_IO;
  }
  return status;
}

static void lh_sha256_hex(const lonehash_sha256 *self,
                          const unsigned char digest[32], char hex[65]) {
  (void)self;
  if (digest == NULL || hex == NULL) {
    return;
  }
  lh_hex(digest, 32U, hex);
}

static void lh_md5_hex(const lonehash_md5 *self, const unsigned char digest[16],
                       char hex[33]) {
  (void)self;
  if (digest == NULL || hex == NULL) {
    return;
  }
  lh_hex(digest, 16U, hex);
}

lonehash_status lonehash_sha256_create(lonehash_sha256 **out) {
  lonehash_sha256 *self;
  lh_sha256_impl *impl;

  if (out == NULL) {
    return LONEHASH_ERROR_NULL;
  }
  *out = NULL;
  self = (lonehash_sha256 *)calloc(1, sizeof(*self));
  if (self == NULL) {
    return LONEHASH_ERROR_ALLOC;
  }
  impl = (lh_sha256_impl *)calloc(1, sizeof(*impl));
  if (impl == NULL) {
    free(self);
    return LONEHASH_ERROR_ALLOC;
  }
  self->reset = lh_sha256_reset;
  self->update = lh_sha256_update;
  self->final = lh_sha256_final;
  self->digest_buffer = lh_sha256_digest_buffer;
  self->digest_file = lh_sha256_digest_file;
  self->digest_path = lh_sha256_digest_path;
  self->hex = lh_sha256_hex;
  self->impl = impl;
  *out = self;
  return self->reset(self);
}

void lonehash_sha256_destroy(lonehash_sha256 *self) {
  if (self == NULL) {
    return;
  }
  if (self->impl != NULL) {
    memset(self->impl, 0, sizeof(lh_sha256_impl));
    free(self->impl);
  }
  memset(self, 0, sizeof(*self));
  free(self);
}

lonehash_status lonehash_md5_create(lonehash_md5 **out) {
  lonehash_md5 *self;
  lh_md5_impl *impl;

  if (out == NULL) {
    return LONEHASH_ERROR_NULL;
  }
  *out = NULL;
  self = (lonehash_md5 *)calloc(1, sizeof(*self));
  if (self == NULL) {
    return LONEHASH_ERROR_ALLOC;
  }
  impl = (lh_md5_impl *)calloc(1, sizeof(*impl));
  if (impl == NULL) {
    free(self);
    return LONEHASH_ERROR_ALLOC;
  }
  self->reset = lh_md5_reset;
  self->update = lh_md5_update;
  self->final = lh_md5_final;
  self->digest_buffer = lh_md5_digest_buffer;
  self->digest_file = lh_md5_digest_file;
  self->digest_path = lh_md5_digest_path;
  self->hex = lh_md5_hex;
  self->impl = impl;
  *out = self;
  return self->reset(self);
}

void lonehash_md5_destroy(lonehash_md5 *self) {
  if (self == NULL) {
    return;
  }
  if (self->impl != NULL) {
    memset(self->impl, 0, sizeof(lh_md5_impl));
    free(self->impl);
  }
  memset(self, 0, sizeof(*self));
  free(self);
}
