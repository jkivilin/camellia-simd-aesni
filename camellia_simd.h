/*
 * Copyright (C) 2020 Jussi Kivilinna <jussi.kivilinna@iki.fi>
 *
 * SPDX-License-Identifier: MIT
 */

#ifndef _CAMELLIA_SIMD_H_
#define _CAMELLIA_SIMD_H_

#include <stdint.h>

#define CAMELLIA_TABLE_BYTE_LEN 272

struct camellia_simd_ctx
{
  uint64_t key_table[CAMELLIA_TABLE_BYTE_LEN / sizeof(uint64_t)];
  int key_length;
};

/* SIMD128 vector implementation of key-setup. Supported key lengths are
 * 16, 24 and 32 bytes (128-bit, 192-bit and 256-bit). KEYLEN takes length
 * in bytes. KEY is pointer to key buffer and may be unaligned. */
int camellia_keysetup_simd128(struct camellia_simd_ctx *ctx, const void *key,
			      unsigned int keylen);

/* SIMD128 vector implementation of Camellia. These are 128-bit vector
 * variants (on x86, AES-NI + SSE4.1/AVX). IN is pointer to 16 plaintext
 * blocks and OUT is pointer to 16 ciphertext blocks. OUT and IN may be
 * unaligned. */
void camellia_encrypt_16blks_simd128(struct camellia_simd_ctx *ctx, void *out,
				     const void *in);
void camellia_decrypt_16blks_simd128(struct camellia_simd_ctx *ctx, void *out,
				  const void *in);

/* SIMD256 vector implementation of Camellia. These are 256-bit vector
 * variants (on x86, AES-NI / AVX2). IN is pointer to 32 plaintext
 * blocks and OUT is pointer to 32 ciphertext blocks. OUT and IN may be
 * unaligned. */
void camellia_encrypt_32blks_simd256(struct camellia_simd_ctx *ctx, void *out,
				     const void *in);
void camellia_decrypt_32blks_simd256(struct camellia_simd_ctx *ctx, void *out,
				     const void *in);

#endif /* _CAMELLIA_SIMD_H_ */
