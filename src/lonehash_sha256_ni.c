#include <cpuid.h>
#include <immintrin.h>

typedef unsigned int lh_u32;

int lonehash_sha256_ni_available(void) {
  unsigned int eax;
  unsigned int ebx;
  unsigned int ecx;
  unsigned int edx;

  if (!__get_cpuid_count(7, 0, &eax, &ebx, &ecx, &edx)) {
    return 0;
  }
  return (ebx & (1U << 29)) != 0U;
}

static lh_u32 lh_rotr32(lh_u32 x, unsigned int n) {
  return (x >> n) | (x << (32U - n));
}

static lh_u32 lh_load_be32(const unsigned char *p) {
  return ((lh_u32)p[0] << 24) | ((lh_u32)p[1] << 16) | ((lh_u32)p[2] << 8) |
         (lh_u32)p[3];
}

static void lh_sha256_ni_round4(__m128i *state0, __m128i *state1, lh_u32 wk0,
                                lh_u32 wk1, lh_u32 wk2, lh_u32 wk3) {
  __m128i msg;

  msg = _mm_set_epi32(0, 0, (int)wk1, (int)wk0);
  *state1 = _mm_sha256rnds2_epu32(*state1, *state0, msg);
  msg = _mm_set_epi32(0, 0, (int)wk3, (int)wk2);
  *state0 = _mm_sha256rnds2_epu32(*state0, *state1, msg);
}

void lonehash_sha256_ni_transform(lh_u32 state[8],
                                  const unsigned char block[64]) {
  static const lh_u32 k[64] = {
      0x428a2f98U, 0x71374491U, 0xb5c0fbcfU, 0xe9b5dba5U, 0x3956c25bU,
      0x59f111f1U, 0x923f82a4U, 0xab1c5ed5U, 0xd807aa98U, 0x12835b01U,
      0x243185beU, 0x550c7dc3U, 0x72be5d74U, 0x80deb1feU, 0x9bdc06a7U,
      0xc19bf174U, 0xe49b69c1U, 0xefbe4786U, 0x0fc19dc6U, 0x240ca1ccU,
      0x2de92c6fU, 0x4a7484aaU, 0x5cb0a9dcU, 0x76f988daU, 0x983e5152U,
      0xa831c66dU, 0xb00327c8U, 0xbf597fc7U, 0xc6e00bf3U, 0xd5a79147U,
      0x06ca6351U, 0x14292967U, 0x27b70a85U, 0x2e1b2138U, 0x4d2c6dfcU,
      0x53380d13U, 0x650a7354U, 0x766a0abbU, 0x81c2c92eU, 0x92722c85U,
      0xa2bfe8a1U, 0xa81a664bU, 0xc24b8b70U, 0xc76c51a3U, 0xd192e819U,
      0xd6990624U, 0xf40e3585U, 0x106aa070U, 0x19a4c116U, 0x1e376c08U,
      0x2748774cU, 0x34b0bcb5U, 0x391c0cb3U, 0x4ed8aa4aU, 0x5b9cca4fU,
      0x682e6ff3U, 0x748f82eeU, 0x78a5636fU, 0x84c87814U, 0x8cc70208U,
      0x90befffaU, 0xa4506cebU, 0xbef9a3f7U, 0xc67178f2U};
  lh_u32 w[64];
  __m128i state0;
  __m128i state1;
  __m128i abef_save;
  __m128i cdgh_save;
  __m128i tmp;
  unsigned int i;

  for (i = 0; i < 16U; ++i) {
    w[i] = lh_load_be32(block + (i * 4U));
  }
  for (i = 16U; i < 64U; ++i) {
    w[i] = w[i - 16U] +
           (lh_rotr32(w[i - 15U], 7) ^ lh_rotr32(w[i - 15U], 18) ^
            (w[i - 15U] >> 3)) +
           w[i - 7U] +
           (lh_rotr32(w[i - 2U], 17) ^ lh_rotr32(w[i - 2U], 19) ^
            (w[i - 2U] >> 10));
  }

  tmp = _mm_loadu_si128((const __m128i *)state);
  state1 = _mm_loadu_si128((const __m128i *)(state + 4));
  tmp = _mm_shuffle_epi32(tmp, 0xB1);
  state1 = _mm_shuffle_epi32(state1, 0x1B);
  state0 = _mm_alignr_epi8(tmp, state1, 8);
  state1 = _mm_blend_epi16(state1, tmp, 0xF0);
  abef_save = state0;
  cdgh_save = state1;

  for (i = 0; i < 64U; i += 4U) {
    lh_sha256_ni_round4(&state0, &state1, w[i] + k[i], w[i + 1U] + k[i + 1U],
                        w[i + 2U] + k[i + 2U], w[i + 3U] + k[i + 3U]);
  }

  state0 = _mm_add_epi32(state0, abef_save);
  state1 = _mm_add_epi32(state1, cdgh_save);
  tmp = _mm_shuffle_epi32(state0, 0x1B);
  state1 = _mm_shuffle_epi32(state1, 0xB1);
  state0 = _mm_blend_epi16(tmp, state1, 0xF0);
  state1 = _mm_alignr_epi8(state1, tmp, 8);
  _mm_storeu_si128((__m128i *)state, state0);
  _mm_storeu_si128((__m128i *)(state + 4), state1);
}
