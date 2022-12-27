/*
 * Copyright (C) 2020 Jussi Kivilinna <jussi.kivilinna@iki.fi>
 *
 * SPDX-License-Identifier: MIT
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <time.h>
#include <openssl/evp.h>
#include "camellia_simd.h"

static const uint8_t test_vector_plaintext[] = {
  0x01,0x23,0x45,0x67,0x89,0xab,0xcd,0xef,
  0xfe,0xdc,0xba,0x98,0x76,0x54,0x32,0x10
};

static const uint8_t test_vector_key_128[] = {
  0x01,0x23,0x45,0x67,0x89,0xab,0xcd,0xef,
  0xfe,0xdc,0xba,0x98,0x76,0x54,0x32,0x10
};

static const uint8_t test_vector_ciphertext_128[] = {
  0x67,0x67,0x31,0x38,0x54,0x96,0x69,0x73,
  0x08,0x57,0x06,0x56,0x48,0xea,0xbe,0x43
};

static const uint8_t test_vector_key_192[] = {
  0x01,0x23,0x45,0x67,0x89,0xab,0xcd,0xef,
  0xfe,0xdc,0xba,0x98,0x76,0x54,0x32,0x10,
  0x00,0x11,0x22,0x33,0x44,0x55,0x66,0x77
};

static const uint8_t test_vector_ciphertext_192[] = {
  0xb4,0x99,0x34,0x01,0xb3,0xe9,0x96,0xf8,
  0x4e,0xe5,0xce,0xe7,0xd7,0x9b,0x09,0xb9
};

static const uint8_t test_vector_key_256[] = {
  0x01,0x23,0x45,0x67,0x89,0xab,0xcd,0xef,
  0xfe,0xdc,0xba,0x98,0x76,0x54,0x32,0x10,
  0x00,0x11,0x22,0x33,0x44,0x55,0x66,0x77,
  0x88,0x99,0xaa,0xbb,0xcc,0xdd,0xee,0xff
};

static const uint8_t test_vector_ciphertext_256[] = {
  0x9a,0xcc,0x23,0x7d,0xff,0x16,0xd7,0x6c,
  0x20,0xef,0x7c,0x91,0x9e,0x3a,0x75,0x09
};

typedef struct
{
  EVP_CIPHER_CTX *enc_ctx;
  EVP_CIPHER_CTX *dec_ctx;
} CAMELLIA_KEY;

static void Camellia_set_key(const void *key, int nbits, CAMELLIA_KEY *ctx)
{
  const EVP_CIPHER *algo;

  if (ctx->enc_ctx == NULL)
    ctx->enc_ctx = EVP_CIPHER_CTX_new();
  assert(ctx->enc_ctx != NULL);

  if (ctx->dec_ctx == NULL)
    ctx->dec_ctx = EVP_CIPHER_CTX_new();
  assert(ctx->dec_ctx != NULL);

  if (nbits == 128)
    algo = EVP_get_cipherbyname("camellia-128-ecb");
  else if (nbits == 192)
    algo = EVP_get_cipherbyname("camellia-192-ecb");
  else
    algo = EVP_get_cipherbyname("camellia-256-ecb");

  assert(algo != NULL);
  assert(EVP_EncryptInit_ex(ctx->enc_ctx, algo, NULL, key, NULL) == 1);
  assert(EVP_DecryptInit_ex(ctx->dec_ctx, algo, NULL, key, NULL) == 1);
  assert(EVP_CIPHER_CTX_set_padding(ctx->enc_ctx, 0) == 1);
  assert(EVP_CIPHER_CTX_set_padding(ctx->dec_ctx, 0) == 1);
}

static void Camellia_encrypt_nblks(const void *src, void *dst, int nblks,
				   CAMELLIA_KEY *ctx)
{
  int outlen;
  assert(EVP_EncryptUpdate(ctx->enc_ctx, dst, &outlen, src, nblks * 16) == 1);
  assert(outlen == nblks * 16);
}

static void Camellia_decrypt_nblks(const void *src, void *dst, int nblks,
				   CAMELLIA_KEY *ctx)
{
  int outlen;
  assert(EVP_DecryptUpdate(ctx->dec_ctx, dst, &outlen, src, nblks * 16) == 1);
  assert(outlen == nblks * 16);
}

static void Camellia_encrypt(const void *src, void *dst, CAMELLIA_KEY *ctx)
{
  Camellia_encrypt_nblks(src, dst, 1, ctx);
}

static void Camellia_decrypt(const void *src, void *dst, CAMELLIA_KEY *ctx)
{
  Camellia_decrypt_nblks(src, dst, 1, ctx);
}

static void fill_blks(uint8_t *fill, const uint8_t *blk, unsigned int nblks)
{
  while (nblks) {
    memcpy(fill, blk, 16);
    fill += 16;
    nblks--;
  }
}

static __attribute__((unused)) const char *blk2str(const uint8_t *blk)
{
  static char buf[64];
  unsigned int i;
  unsigned int pos;

  for (i = 0, pos = 0; i < 16; i++) {
    pos += snprintf(&buf[pos], sizeof(buf) - pos, "%02x%s", blk[i],
		    i < 15 ? ":" : "");
    if (pos >= sizeof(buf))
      break;
  }

  return buf;
}

static void do_selftest(void)
{
  struct camellia_simd_ctx ctx_simd;
  CAMELLIA_KEY ctx_ref = { 0 };
  uint8_t key[32];
  uint8_t tmp[32 * 16];
  uint8_t plaintext_simd[32 * 16];
  uint8_t ref_large_plaintext[32 * 16];
  uint8_t ref_large_ciphertext_128[32 * 16];
  uint8_t ref_large_ciphertext_256[32 * 16];
  unsigned int i, j;

  /* Check test vectors against reference implementation. */
  printf("selftest: comparing camellia-%d test vectors against reference implementation...\n", 128);
  Camellia_set_key(test_vector_key_128, 128, &ctx_ref);
  Camellia_encrypt(test_vector_plaintext, tmp, &ctx_ref);
  assert(memcmp(tmp, test_vector_ciphertext_128, 16) == 0);
  Camellia_decrypt(tmp, tmp, &ctx_ref);
  assert(memcmp(tmp, test_vector_plaintext, 16) == 0);

  printf("selftest: comparing camellia-%d test vectors against reference implementation...\n", 192);
  Camellia_set_key(test_vector_key_192, 192, &ctx_ref);
  Camellia_encrypt(test_vector_plaintext, tmp, &ctx_ref);
  assert(memcmp(tmp, test_vector_ciphertext_192, 16) == 0);
  Camellia_decrypt(tmp, tmp, &ctx_ref);
  assert(memcmp(tmp, test_vector_plaintext, 16) == 0);

  printf("selftest: comparing camellia-%d test vectors against reference implementation...\n", 256);
  Camellia_set_key(test_vector_key_256, 256, &ctx_ref);
  Camellia_encrypt(test_vector_plaintext, tmp, &ctx_ref);
  assert(memcmp(tmp, test_vector_ciphertext_256, 16) == 0);
  Camellia_decrypt(tmp, tmp, &ctx_ref);
  assert(memcmp(tmp, test_vector_plaintext, 16) == 0);

  /* Check 16-block SIMD128 implementation against known test vectors. */
  printf("selftest: checking 16-block parallel camellia-128/SIMD128 against test vectors...\n");
  fill_blks(plaintext_simd, test_vector_plaintext, 16);

  memset(tmp, 0xaa, sizeof(tmp));
  memset(&ctx_simd, 0xff, sizeof(ctx_simd));
  camellia_keysetup_simd128(&ctx_simd, test_vector_key_128, 128 / 8);

  camellia_encrypt_16blks_simd128(&ctx_simd, tmp, plaintext_simd);

  for (i = 0; i < 16; i++) {
    assert(memcmp(&tmp[i * 16], test_vector_ciphertext_128, 16) == 0);
  }
  camellia_decrypt_16blks_simd128(&ctx_simd, tmp, tmp);
  assert(memcmp(tmp, plaintext_simd, 16 * 16) == 0);

  memset(tmp, 0xaa, sizeof(tmp));
  memset(&ctx_simd, 0xff, sizeof(ctx_simd));
  camellia_keysetup_simd128(&ctx_simd, test_vector_key_192, 192 / 8);
  camellia_encrypt_16blks_simd128(&ctx_simd, tmp, plaintext_simd);
  for (i = 0; i < 16; i++) {
    assert(memcmp(&tmp[i * 16], test_vector_ciphertext_192, 16) == 0);
  }
  camellia_decrypt_16blks_simd128(&ctx_simd, tmp, tmp);
  assert(memcmp(tmp, plaintext_simd, 16 * 16) == 0);

  memset(tmp, 0xaa, sizeof(tmp));
  memset(&ctx_simd, 0xff, sizeof(ctx_simd));
  camellia_keysetup_simd128(&ctx_simd, test_vector_key_256, 256 / 8);
  camellia_encrypt_16blks_simd128(&ctx_simd, tmp, plaintext_simd);
  for (i = 0; i < 16; i++) {
    assert(memcmp(&tmp[i * 16], test_vector_ciphertext_256, 16) == 0);
  }
  camellia_decrypt_16blks_simd128(&ctx_simd, tmp, tmp);
  assert(memcmp(tmp, plaintext_simd, 16 * 16) == 0);

#ifdef USE_SIMD256
  /* Check 32-block SIMD256 implementation against known test vectors. */
  printf("selftest: checking 32-block parallel camellia-128/SIMD256 against test vectors...\n");
  fill_blks(plaintext_simd, test_vector_plaintext, 32);

  memset(tmp, 0xaa, sizeof(tmp));
  memset(&ctx_simd, 0xff, sizeof(ctx_simd));
  camellia_keysetup_simd128(&ctx_simd, test_vector_key_128, 128 / 8);

  camellia_encrypt_32blks_simd256(&ctx_simd, tmp, plaintext_simd);

  for (i = 0; i < 32; i++) {
    assert(memcmp(&tmp[i * 16], test_vector_ciphertext_128, 16) == 0);
  }
  camellia_decrypt_32blks_simd256(&ctx_simd, tmp, tmp);
  assert(memcmp(tmp, plaintext_simd, 32 * 16) == 0);

  memset(tmp, 0xaa, sizeof(tmp));
  memset(&ctx_simd, 0xff, sizeof(ctx_simd));
  camellia_keysetup_simd128(&ctx_simd, test_vector_key_192, 192 / 8);
  camellia_encrypt_32blks_simd256(&ctx_simd, tmp, plaintext_simd);
  for (i = 0; i < 32; i++) {
    assert(memcmp(&tmp[i * 16], test_vector_ciphertext_192, 16) == 0);
  }
  camellia_decrypt_32blks_simd256(&ctx_simd, tmp, tmp);
  assert(memcmp(tmp, plaintext_simd, 32 * 16) == 0);

  memset(tmp, 0xaa, sizeof(tmp));
  memset(&ctx_simd, 0xff, sizeof(ctx_simd));
  camellia_keysetup_simd128(&ctx_simd, test_vector_key_256, 256 / 8);
  camellia_encrypt_32blks_simd256(&ctx_simd, tmp, plaintext_simd);
  for (i = 0; i < 32; i++) {
    assert(memcmp(&tmp[i * 16], test_vector_ciphertext_256, 16) == 0);
  }
  camellia_decrypt_32blks_simd256(&ctx_simd, tmp, tmp);
  assert(memcmp(tmp, plaintext_simd, 32 * 16) == 0);
#endif

  /* Generate large test vectors. */
  for (i = 0; i < sizeof(key); i++)
    key[i] = ((i + 1231) * 3221) & 0xff;
  for (i = 0; i < sizeof(ref_large_plaintext); i++)
    ref_large_plaintext[i] = ((i + 3221) * 1231) & 0xff;
  Camellia_set_key(key, 128, &ctx_ref);
  for (i = 0; i < 32; i++) {
    Camellia_encrypt(&ref_large_plaintext[i * 16],
		     &ref_large_ciphertext_128[i * 16], &ctx_ref);
    for (j = 1; j < (1 << 16); j++) {
      Camellia_encrypt(&ref_large_ciphertext_128[i * 16],
		       &ref_large_ciphertext_128[i * 16], &ctx_ref);
    }
  }
  Camellia_set_key(key, 256, &ctx_ref);
  for (i = 0; i < 32; i++) {
    Camellia_encrypt(&ref_large_plaintext[i * 16],
		     &ref_large_ciphertext_256[i * 16], &ctx_ref);
    for (j = 1; j < (1 << 16); j++) {
      Camellia_encrypt(&ref_large_ciphertext_256[i * 16],
		       &ref_large_ciphertext_256[i * 16], &ctx_ref);
    }
  }

  /* Test 16-block SIMD128 implementation against large test vectors. */
  printf("selftest: checking 16-block parallel camellia-128/SIMD128 against large test vectors...\n");
  camellia_keysetup_simd128(&ctx_simd, key, 128 / 8);
  memcpy(tmp, ref_large_plaintext, 16 * 16);
  for (i = 0; i < (1 << 16); i++) {
    camellia_encrypt_16blks_simd128(&ctx_simd, tmp, tmp);
  }
  assert(memcmp(tmp, ref_large_ciphertext_128, 16 * 16) == 0);
  for (i = 0; i < (1 << 16); i++) {
    camellia_decrypt_16blks_simd128(&ctx_simd, tmp, tmp);
  }
  assert(memcmp(tmp, ref_large_plaintext, 16 * 16) == 0);

  camellia_keysetup_simd128(&ctx_simd, key, 256 / 8);
  memcpy(tmp, ref_large_plaintext, 16 * 16);
  for (i = 0; i < (1 << 16); i++) {
    camellia_encrypt_16blks_simd128(&ctx_simd, tmp, tmp);
  }
  assert(memcmp(tmp, ref_large_ciphertext_256, 16 * 16) == 0);
  for (i = 0; i < (1 << 16); i++) {
    camellia_decrypt_16blks_simd128(&ctx_simd, tmp, tmp);
  }
  assert(memcmp(tmp, ref_large_plaintext, 16 * 16) == 0);

#ifdef USE_SIMD256
  /* Test 32-block SIMD256 implementation against large test vectors. */
  printf("selftest: checking 32-block parallel camellia-128/SIMD256 against large test vectors...\n");
  camellia_keysetup_simd128(&ctx_simd, key, 128 / 8);
  memcpy(tmp, ref_large_plaintext, 32 * 16);
  for (i = 0; i < (1 << 16); i++) {
    camellia_encrypt_32blks_simd256(&ctx_simd, tmp, tmp);
  }
  assert(memcmp(tmp, ref_large_ciphertext_128, 32 * 16) == 0);
  for (i = 0; i < (1 << 16); i++) {
    camellia_decrypt_32blks_simd256(&ctx_simd, tmp, tmp);
  }
  assert(memcmp(tmp, ref_large_plaintext, 32 * 16) == 0);

  camellia_keysetup_simd128(&ctx_simd, key, 256 / 8);
  memcpy(tmp, ref_large_plaintext, 32 * 16);
  for (i = 0; i < (1 << 16); i++) {
    camellia_encrypt_32blks_simd256(&ctx_simd, tmp, tmp);
  }
  assert(memcmp(tmp, ref_large_ciphertext_256, 32 * 16) == 0);
  for (i = 0; i < (1 << 16); i++) {
    camellia_decrypt_32blks_simd256(&ctx_simd, tmp, tmp);
  }
  assert(memcmp(tmp, ref_large_plaintext, 32 * 16) == 0);
#endif

  EVP_CIPHER_CTX_free(ctx_ref.enc_ctx);
  EVP_CIPHER_CTX_free(ctx_ref.dec_ctx);
}

static uint64_t curr_clock_nsecs(void)
{
  struct timespec ts;

  clock_gettime(CLOCK_MONOTONIC, &ts);

  return (uint64_t)ts.tv_sec * 1000 * 1000 * 1000 + ts.tv_nsec;
}

static void print_result(const char *variant, uint64_t num_bytes,
			 uint64_t elapsed_nsecs)
{
  double mebi_per_sec, mega_per_sec;

  mebi_per_sec = num_bytes * 1e9 / (1024.0 * 1024 * elapsed_nsecs);
  mega_per_sec = num_bytes * 1e9 / (1e6 * elapsed_nsecs);
  printf("%44s: %10.3f Mebibytes/s, %10.3f Megabytes/s\n",
	 variant, mebi_per_sec, mega_per_sec);
  fflush(stdout);
}

static void do_speedtest(void)
{
  const uint64_t test_nsecs = 1ULL * 1000 * 1000 * 1000;
  struct camellia_simd_ctx ctx_simd;
  CAMELLIA_KEY ctx_ref = { 0 };
  uint8_t tmp[16 * 32 * 16] __attribute__((aligned(64)));
  uint64_t start_time;
  uint64_t end_time;
  uint64_t total_bytes;
  unsigned int i, j;

  for (i = 0; i < sizeof(tmp); i++)
    tmp[i] = ((i + 3221) * 1231) & 0xff;

  /* Test speed of reference implementation. */
  total_bytes = 0;
  Camellia_set_key(test_vector_key_128, 128, &ctx_ref);

  start_time = curr_clock_nsecs();
  do {
    Camellia_encrypt_nblks(tmp, tmp, sizeof(tmp) / 16, &ctx_ref);
    total_bytes += sizeof(tmp) - sizeof(tmp) % 16;
    end_time = curr_clock_nsecs();
  } while (start_time + test_nsecs > end_time);

  print_result("camellia-128 reference encryption",
	       total_bytes, end_time - start_time);

  total_bytes = 0;
  Camellia_set_key(test_vector_key_128, 128, &ctx_ref);

  start_time = curr_clock_nsecs();
  do {
    Camellia_decrypt_nblks(tmp, tmp, sizeof(tmp) / 16, &ctx_ref);
    total_bytes += sizeof(tmp) - sizeof(tmp) % 16;
    end_time = curr_clock_nsecs();
  } while (start_time + test_nsecs > end_time);

  print_result("camellia-128 reference decryption",
	       total_bytes, end_time - start_time);

  /* Test speed of 16-block SIMD128 implementation. */
  total_bytes = 0;
  camellia_keysetup_simd128(&ctx_simd, test_vector_key_128, 128 / 8);

  start_time = curr_clock_nsecs();
  do {
    for (j = 0; j < sizeof(tmp); ) {
      camellia_encrypt_16blks_simd128(&ctx_simd, &tmp[j], &tmp[j]);
      j += 16 * 16;
      total_bytes += 16 * 16;
    }
    end_time = curr_clock_nsecs();
  } while (start_time + test_nsecs > end_time);

  print_result("camellia-128 SIMD128 (16 blocks) encryption",
	       total_bytes, end_time - start_time);

  total_bytes = 0;
  camellia_keysetup_simd128(&ctx_simd, test_vector_key_128, 128 / 8);

  start_time = curr_clock_nsecs();
  do {
    for (j = 0; j < sizeof(tmp); ) {
      camellia_decrypt_16blks_simd128(&ctx_simd, &tmp[j], &tmp[j]);
      j += 16 * 16;
      total_bytes += 16 * 16;
    }
    end_time = curr_clock_nsecs();
  } while (start_time + test_nsecs > end_time);

  print_result("camellia-128 SIMD128 (16 blocks) decryption",
	       total_bytes, end_time - start_time);

#ifdef USE_SIMD256
  /* Test speed of 32-block SIMD256 implementation. */
  total_bytes = 0;
  camellia_keysetup_simd128(&ctx_simd, test_vector_key_128, 128 / 8);

  start_time = curr_clock_nsecs();
  do {
    for (j = 0; j < sizeof(tmp); ) {
      camellia_encrypt_32blks_simd256(&ctx_simd, &tmp[j], &tmp[j]);
      j += 32 * 16;
      total_bytes += 32 * 16;
    }
    end_time = curr_clock_nsecs();
  } while (start_time + test_nsecs > end_time);

  print_result("camellia-128 SIMD256 (32 blocks) encryption",
	       total_bytes, end_time - start_time);

  total_bytes = 0;
  camellia_keysetup_simd128(&ctx_simd, test_vector_key_128, 128 / 8);

  start_time = curr_clock_nsecs();
  do {
    for (j = 0; j < sizeof(tmp); ) {
      camellia_decrypt_32blks_simd256(&ctx_simd, &tmp[j], &tmp[j]);
      j += 32 * 16;
      total_bytes += 32 * 16;
    }
    end_time = curr_clock_nsecs();
  } while (start_time + test_nsecs > end_time);

  print_result("camellia-128 SIMD256 (32 blocks) decryption",
	       total_bytes, end_time - start_time);
#endif

  EVP_CIPHER_CTX_free(ctx_ref.enc_ctx);
  EVP_CIPHER_CTX_free(ctx_ref.dec_ctx);
}

int main(int argc, const char *argv[])
{
  OpenSSL_add_all_algorithms();

  printf("%s:\n", argv[0]);

  do_selftest();

  do_speedtest();

  return 0;
}
