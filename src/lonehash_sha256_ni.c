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

static void lh_sha256_ni_round4(__m128i *state0, __m128i *state1, __m128i msg,
                                lh_u32 k0, lh_u32 k1, lh_u32 k2, lh_u32 k3) {
  msg = _mm_add_epi32(msg, _mm_set_epi32((int)k3, (int)k2, (int)k1, (int)k0));
  *state1 = _mm_sha256rnds2_epu32(*state1, *state0, msg);
  msg = _mm_shuffle_epi32(msg, 0x0E);
  *state0 = _mm_sha256rnds2_epu32(*state0, *state1, msg);
}

static __m128i lh_sha256_ni_schedule(__m128i msg0, __m128i msg1, __m128i msg2,
                                     __m128i msg3) {
  __m128i tmp;

  msg0 = _mm_sha256msg1_epu32(msg0, msg1);
  tmp = _mm_alignr_epi8(msg3, msg2, 4);
  msg0 = _mm_add_epi32(msg0, tmp);
  msg0 = _mm_sha256msg2_epu32(msg0, msg3);
  return msg0;
}

void lonehash_sha256_ni_transform(lh_u32 state[8],
                                  const unsigned char block[64]) {
  __m128i state0;
  __m128i state1;
  __m128i abef_save;
  __m128i cdgh_save;
  __m128i msg0;
  __m128i msg1;
  __m128i msg2;
  __m128i msg3;
  __m128i mask;
  __m128i tmp;

  mask = _mm_set_epi8(12, 13, 14, 15, 8, 9, 10, 11, 4, 5, 6, 7, 0, 1, 2, 3);
  msg0 = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)(block)), mask);
  msg1 = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)(block + 16)), mask);
  msg2 = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)(block + 32)), mask);
  msg3 = _mm_shuffle_epi8(_mm_loadu_si128((const __m128i *)(block + 48)), mask);

  tmp = _mm_loadu_si128((const __m128i *)state);
  state1 = _mm_loadu_si128((const __m128i *)(state + 4));
  tmp = _mm_shuffle_epi32(tmp, 0xB1);
  state1 = _mm_shuffle_epi32(state1, 0x1B);
  state0 = _mm_alignr_epi8(tmp, state1, 8);
  state1 = _mm_blend_epi16(state1, tmp, 0xF0);
  abef_save = state0;
  cdgh_save = state1;

  lh_sha256_ni_round4(&state0, &state1, msg0, 0x428a2f98U, 0x71374491U,
                      0xb5c0fbcfU, 0xe9b5dba5U);
  lh_sha256_ni_round4(&state0, &state1, msg1, 0x3956c25bU, 0x59f111f1U,
                      0x923f82a4U, 0xab1c5ed5U);
  lh_sha256_ni_round4(&state0, &state1, msg2, 0xd807aa98U, 0x12835b01U,
                      0x243185beU, 0x550c7dc3U);
  lh_sha256_ni_round4(&state0, &state1, msg3, 0x72be5d74U, 0x80deb1feU,
                      0x9bdc06a7U, 0xc19bf174U);

  msg0 = lh_sha256_ni_schedule(msg0, msg1, msg2, msg3);
  lh_sha256_ni_round4(&state0, &state1, msg0, 0xe49b69c1U, 0xefbe4786U,
                      0x0fc19dc6U, 0x240ca1ccU);
  msg1 = lh_sha256_ni_schedule(msg1, msg2, msg3, msg0);
  lh_sha256_ni_round4(&state0, &state1, msg1, 0x2de92c6fU, 0x4a7484aaU,
                      0x5cb0a9dcU, 0x76f988daU);
  msg2 = lh_sha256_ni_schedule(msg2, msg3, msg0, msg1);
  lh_sha256_ni_round4(&state0, &state1, msg2, 0x983e5152U, 0xa831c66dU,
                      0xb00327c8U, 0xbf597fc7U);
  msg3 = lh_sha256_ni_schedule(msg3, msg0, msg1, msg2);
  lh_sha256_ni_round4(&state0, &state1, msg3, 0xc6e00bf3U, 0xd5a79147U,
                      0x06ca6351U, 0x14292967U);

  msg0 = lh_sha256_ni_schedule(msg0, msg1, msg2, msg3);
  lh_sha256_ni_round4(&state0, &state1, msg0, 0x27b70a85U, 0x2e1b2138U,
                      0x4d2c6dfcU, 0x53380d13U);
  msg1 = lh_sha256_ni_schedule(msg1, msg2, msg3, msg0);
  lh_sha256_ni_round4(&state0, &state1, msg1, 0x650a7354U, 0x766a0abbU,
                      0x81c2c92eU, 0x92722c85U);
  msg2 = lh_sha256_ni_schedule(msg2, msg3, msg0, msg1);
  lh_sha256_ni_round4(&state0, &state1, msg2, 0xa2bfe8a1U, 0xa81a664bU,
                      0xc24b8b70U, 0xc76c51a3U);
  msg3 = lh_sha256_ni_schedule(msg3, msg0, msg1, msg2);
  lh_sha256_ni_round4(&state0, &state1, msg3, 0xd192e819U, 0xd6990624U,
                      0xf40e3585U, 0x106aa070U);

  msg0 = lh_sha256_ni_schedule(msg0, msg1, msg2, msg3);
  lh_sha256_ni_round4(&state0, &state1, msg0, 0x19a4c116U, 0x1e376c08U,
                      0x2748774cU, 0x34b0bcb5U);
  msg1 = lh_sha256_ni_schedule(msg1, msg2, msg3, msg0);
  lh_sha256_ni_round4(&state0, &state1, msg1, 0x391c0cb3U, 0x4ed8aa4aU,
                      0x5b9cca4fU, 0x682e6ff3U);
  msg2 = lh_sha256_ni_schedule(msg2, msg3, msg0, msg1);
  lh_sha256_ni_round4(&state0, &state1, msg2, 0x748f82eeU, 0x78a5636fU,
                      0x84c87814U, 0x8cc70208U);
  msg3 = lh_sha256_ni_schedule(msg3, msg0, msg1, msg2);
  lh_sha256_ni_round4(&state0, &state1, msg3, 0x90befffaU, 0xa4506cebU,
                      0xbef9a3f7U, 0xc67178f2U);

  state0 = _mm_add_epi32(state0, abef_save);
  state1 = _mm_add_epi32(state1, cdgh_save);
  tmp = _mm_shuffle_epi32(state0, 0x1B);
  state1 = _mm_shuffle_epi32(state1, 0xB1);
  state0 = _mm_blend_epi16(tmp, state1, 0xF0);
  state1 = _mm_alignr_epi8(state1, tmp, 8);
  _mm_storeu_si128((__m128i *)state, state0);
  _mm_storeu_si128((__m128i *)(state + 4), state1);
}
