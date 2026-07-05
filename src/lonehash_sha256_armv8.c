#include <arm_neon.h>

#if defined(__linux__)
#include <sys/auxv.h>
#if defined(__has_include)
#if __has_include(<asm/hwcap.h>)
#include <asm/hwcap.h>
#endif
#endif
#endif

#if defined(__APPLE__)
#include <stddef.h>
#include <sys/sysctl.h>
#endif

#ifndef AT_HWCAP
#define AT_HWCAP 16
#endif

#ifndef HWCAP_SHA2
#define HWCAP_SHA2 (1UL << 6)
#endif

typedef unsigned int lh_u32;

int lonehash_sha256_armv8_available(void) {
#if defined(__linux__)
  return (getauxval(AT_HWCAP) & HWCAP_SHA2) != 0UL;
#elif defined(__APPLE__)
  int enabled;
  size_t enabled_size;

  enabled = 0;
  enabled_size = sizeof(enabled);
  if (sysctlbyname("hw.optional.arm.FEAT_SHA256", &enabled, &enabled_size, 0,
                   0) == 0) {
    return enabled != 0;
  }
  enabled = 0;
  enabled_size = sizeof(enabled);
  if (sysctlbyname("hw.optional.armv8_sha256", &enabled, &enabled_size, 0, 0) ==
      0) {
    return enabled != 0;
  }
  return 1;
#else
  return 0;
#endif
}

static uint32x4_t lh_load_be32x4(const unsigned char *p) {
  uint8x16_t bytes;

  bytes = vld1q_u8(p);
  bytes = vrev32q_u8(bytes);
  return vreinterpretq_u32_u8(bytes);
}

static void lh_sha256_armv8_round4(uint32x4_t *state0, uint32x4_t *state1,
                                   uint32x4_t msg, const lh_u32 *k) {
  uint32x4_t state0_old;
  uint32x4_t wk;

  state0_old = *state0;
  wk = vaddq_u32(msg, vld1q_u32(k));
  *state0 = vsha256hq_u32(*state0, *state1, wk);
  *state1 = vsha256h2q_u32(*state1, state0_old, wk);
}

static uint32x4_t lh_sha256_armv8_schedule(uint32x4_t msg0, uint32x4_t msg1,
                                           uint32x4_t msg2, uint32x4_t msg3) {
  msg0 = vsha256su0q_u32(msg0, msg1);
  msg0 = vsha256su1q_u32(msg0, msg2, msg3);
  return msg0;
}

void lonehash_sha256_armv8_transform(lh_u32 state[8],
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
  uint32x4_t state0;
  uint32x4_t state1;
  uint32x4_t state0_save;
  uint32x4_t state1_save;
  uint32x4_t msg0;
  uint32x4_t msg1;
  uint32x4_t msg2;
  uint32x4_t msg3;

  msg0 = lh_load_be32x4(block);
  msg1 = lh_load_be32x4(block + 16);
  msg2 = lh_load_be32x4(block + 32);
  msg3 = lh_load_be32x4(block + 48);

  state0 = vld1q_u32(state);
  state1 = vld1q_u32(state + 4);
  state0_save = state0;
  state1_save = state1;

  lh_sha256_armv8_round4(&state0, &state1, msg0, k);
  lh_sha256_armv8_round4(&state0, &state1, msg1, k + 4);
  lh_sha256_armv8_round4(&state0, &state1, msg2, k + 8);
  lh_sha256_armv8_round4(&state0, &state1, msg3, k + 12);

  msg0 = lh_sha256_armv8_schedule(msg0, msg1, msg2, msg3);
  lh_sha256_armv8_round4(&state0, &state1, msg0, k + 16);
  msg1 = lh_sha256_armv8_schedule(msg1, msg2, msg3, msg0);
  lh_sha256_armv8_round4(&state0, &state1, msg1, k + 20);
  msg2 = lh_sha256_armv8_schedule(msg2, msg3, msg0, msg1);
  lh_sha256_armv8_round4(&state0, &state1, msg2, k + 24);
  msg3 = lh_sha256_armv8_schedule(msg3, msg0, msg1, msg2);
  lh_sha256_armv8_round4(&state0, &state1, msg3, k + 28);

  msg0 = lh_sha256_armv8_schedule(msg0, msg1, msg2, msg3);
  lh_sha256_armv8_round4(&state0, &state1, msg0, k + 32);
  msg1 = lh_sha256_armv8_schedule(msg1, msg2, msg3, msg0);
  lh_sha256_armv8_round4(&state0, &state1, msg1, k + 36);
  msg2 = lh_sha256_armv8_schedule(msg2, msg3, msg0, msg1);
  lh_sha256_armv8_round4(&state0, &state1, msg2, k + 40);
  msg3 = lh_sha256_armv8_schedule(msg3, msg0, msg1, msg2);
  lh_sha256_armv8_round4(&state0, &state1, msg3, k + 44);

  msg0 = lh_sha256_armv8_schedule(msg0, msg1, msg2, msg3);
  lh_sha256_armv8_round4(&state0, &state1, msg0, k + 48);
  msg1 = lh_sha256_armv8_schedule(msg1, msg2, msg3, msg0);
  lh_sha256_armv8_round4(&state0, &state1, msg1, k + 52);
  msg2 = lh_sha256_armv8_schedule(msg2, msg3, msg0, msg1);
  lh_sha256_armv8_round4(&state0, &state1, msg2, k + 56);
  msg3 = lh_sha256_armv8_schedule(msg3, msg0, msg1, msg2);
  lh_sha256_armv8_round4(&state0, &state1, msg3, k + 60);

  state0 = vaddq_u32(state0, state0_save);
  state1 = vaddq_u32(state1, state1_save);
  vst1q_u32(state, state0);
  vst1q_u32(state + 4, state1);
}
