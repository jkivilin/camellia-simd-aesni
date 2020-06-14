/*
 * Copyright (C) 2020 Jussi Kivilinna <jussi.kivilinna@iki.fi>
 *
 * SPDX-License-Identifier: MIT
 */

/*
 * AVX2 implementation of Camellia cipher, using AES-NI for sbox
 * calculations. This implementation takes 32 input blocks and process
 * them in parallel.
 *
 * This work was originally presented in Master's Thesis,
 *   "Block Ciphers: Fast Implementations on x86-64 Architecture" (pages 42-50)
 *   http://jultika.oulu.fi/Record/nbnfioulu-201305311409
 */

#include <stdint.h>
#include <x86intrin.h>
#include "camellia_simd.h"

/**********************************************************************
  AT&T x86 asm to intrinsics conversion macros
 **********************************************************************/
#define vpand256(a, b, o)       (o = _mm256_and_si256(b, a))
#define vpandn256(a, b, o)      (o = _mm256_andnot_si256(b, a))
#define vpxor256(a, b, o)       (o = _mm256_xor_si256(b, a))
#define vpor256(a, b, o)        (o = _mm256_or_si256(b, a))

#define vpsrld256(s, a, o)      (o = _mm256_srli_epi32(a, s))
#define vpsrldq256(s, a, o)     (o = _mm256_srli_si256(a, s))

#define vpaddb256(a, b, o)      (o = _mm256_add_epi8(b, a))

#define vpcmpgtb256(a, b, o)    (o = _mm256_cmpgt_epi8(b, a))
#define vpabsb256(a, o)         (o = _mm256_abs_epi8(a))

#define vpshufb256(m, a, o)     (o = _mm256_shuffle_epi8(a, m))

#define vpunpckhdq256(a, b, o)  (o = _mm256_unpackhi_epi32(b, a))
#define vpunpckldq256(a, b, o)  (o = _mm256_unpacklo_epi32(b, a))
#define vpunpckhqdq256(a, b, o) (o = _mm256_unpackhi_epi64(b, a))
#define vpunpcklqdq256(a, b, o) (o = _mm256_unpacklo_epi64(b, a))

/* AES-NI encrypt last round => ShiftRows + SubBytes + XOR round key  */
#if defined(USE_AVX512VL) && defined(USE_VAES)
 /* VAES/AVX512VL have 256-bit wide AES instructions. */
 #define vaesenclast256(a, b, o) (o = _mm256_aesenclast_epi128(b, a))
#else
 /* AES-NI/AVX2 only have 128-bit wide AES instructions. */
 #define vaesenclast128(a, b, o) (o = _mm_aesenclast_si128(b, a))
#endif

#define vmovdqa256(a, o)        (o = a)
#define vmovd128_si256(a, o)    (o = _mm256_set_epi32(0, 0, 0, a, 0, 0, 0, a))
#define vmovq128_si256(a, o)    (o = _mm256_set_epi64x(0, a, 0, a))

/* Following operations may have unaligned memory input/output */
#define vmovdqu256_memst(a, o)  _mm256_storeu_si256((__m256i *)(o), a)
#define vpxor256_memld(a, b, o) \
	vpxor256(b, _mm256_loadu_si256((const __m256i *)(a)), o)

/* Macros for exposing SubBytes from AES-NI instruction set. */
#if defined(vaesenclast256)
 #define aes_subbytes_and_shuf_and_xor(zero, a, o) \
         vaesenclast256(zero, a, o)
#elif defined(vaesenclast128)
 /* Split 256-bit vector into two 128-bit and perform AES-NI on those, then
  * merge result. */
 #define aes_subbytes_and_shuf_and_xor(zero, a, o) ({ \
	    __m128i __aes_hi = _mm256_extracti128_si256(a, 1); \
	    __m128i __aes_lo = _mm256_castsi256_si128(a); \
	    __m128i __aes_zero = _mm256_castsi256_si128(zero); \
	    __m256i __aes_lo256; \
	    vaesenclast128(__aes_zero, __aes_hi, __aes_hi); \
	    vaesenclast128(__aes_zero, __aes_lo, __aes_lo); \
	    __aes_lo256 = _mm256_castsi128_si256(__aes_lo); \
	    o = _mm256_inserti128_si256(__aes_lo256, __aes_hi, 1); \
	  })
#endif
#define aes_load_inv_shufmask(shufmask_reg) \
	vmovdqa256(inv_shift_row, shufmask_reg)
#define aes_inv_shuf(shufmask_reg, a, o) \
	vpshufb256(shufmask_reg, a, o)

/**********************************************************************
  helper macros
 **********************************************************************/
#define filter_8bit(x, lo_t, hi_t, mask4bit, tmp0) \
	vpand256(x, mask4bit, tmp0); \
	vpandn256(x, mask4bit, x); \
	vpsrld256(4, x, x); \
	\
	vpshufb256(tmp0, lo_t, tmp0); \
	vpshufb256(x, hi_t, x); \
	vpxor256(tmp0, x, x);

#define transpose_4x4(x0, x1, x2, x3, t1, t2) \
	vpunpckhdq256(x1, x0, t2); \
	vpunpckldq256(x1, x0, x0); \
	\
	vpunpckldq256(x3, x2, t1); \
	vpunpckhdq256(x3, x2, x2); \
	\
	vpunpckhqdq256(t1, x0, x1); \
	vpunpcklqdq256(t1, x0, x0); \
	\
	vpunpckhqdq256(x2, t2, x3); \
	vpunpcklqdq256(x2, t2, x2);

#define load_zero(o) (o = _mm256_set_epi64x(0, 0, 0, 0))

/**********************************************************************
  16-way camellia macros
 **********************************************************************/

/*
 * IN:
 *   x0..x7: byte-sliced AB state
 *   mem_cd: register pointer storing CD state
 *   key: index for key material
 * OUT:
 *   x0..x7: new byte-sliced CD state
 */
#define roundsm16(x0, x1, x2, x3, x4, x5, x6, x7, t0, t1, t2, t3, t4, t5, t6, \
		  t7, mem_cd, key) \
	/* \
	 * S-function with AES subbytes \
	 */ \
	aes_load_inv_shufmask(t4); \
	vmovdqa256(mask_0f, t7); \
	vmovdqa256(pre_tf_lo_s1, t0); \
	vmovdqa256(pre_tf_hi_s1, t1); \
	\
	/* AES inverse shift rows */ \
	aes_inv_shuf(t4, x0, x0); \
	aes_inv_shuf(t4, x7, x7); \
	aes_inv_shuf(t4, x1, x1); \
	aes_inv_shuf(t4, x4, x4); \
	aes_inv_shuf(t4, x2, x2); \
	aes_inv_shuf(t4, x5, x5); \
	aes_inv_shuf(t4, x3, x3); \
	aes_inv_shuf(t4, x6, x6); \
	\
	/* prefilter sboxes 1, 2 and 3 */ \
	vmovdqa256(pre_tf_lo_s4, t2); \
	vmovdqa256(pre_tf_hi_s4, t3); \
	filter_8bit(x0, t0, t1, t7, t6); \
	filter_8bit(x7, t0, t1, t7, t6); \
	filter_8bit(x1, t0, t1, t7, t6); \
	filter_8bit(x4, t0, t1, t7, t6); \
	filter_8bit(x2, t0, t1, t7, t6); \
	filter_8bit(x5, t0, t1, t7, t6); \
	\
	/* prefilter sbox 4 */ \
	load_zero(t4); \
	filter_8bit(x3, t2, t3, t7, t6); \
	filter_8bit(x6, t2, t3, t7, t6); \
	\
	/* AES subbytes + AES shift rows */ \
	vmovdqa256(post_tf_lo_s1, t0); \
	vmovdqa256(post_tf_hi_s1, t1); \
	aes_subbytes_and_shuf_and_xor(t4, x0, x0); \
	aes_subbytes_and_shuf_and_xor(t4, x7, x7); \
	aes_subbytes_and_shuf_and_xor(t4, x1, x1); \
	aes_subbytes_and_shuf_and_xor(t4, x4, x4); \
	aes_subbytes_and_shuf_and_xor(t4, x2, x2); \
	aes_subbytes_and_shuf_and_xor(t4, x5, x5); \
	aes_subbytes_and_shuf_and_xor(t4, x3, x3); \
	aes_subbytes_and_shuf_and_xor(t4, x6, x6); \
	\
	/* postfilter sboxes 1 and 4 */ \
	vmovdqa256(post_tf_lo_s3, t2); \
	vmovdqa256(post_tf_hi_s3, t3); \
	filter_8bit(x0, t0, t1, t7, t6); \
	filter_8bit(x7, t0, t1, t7, t6); \
	filter_8bit(x3, t0, t1, t7, t6); \
	filter_8bit(x6, t0, t1, t7, t6); \
	\
	/* postfilter sbox 3 */ \
	vmovdqa256(post_tf_lo_s2, t4); \
	vmovdqa256(post_tf_hi_s2, t5); \
	filter_8bit(x2, t2, t3, t7, t6); \
	filter_8bit(x5, t2, t3, t7, t6); \
	\
	load_zero(t6); \
	vmovq128_si256((key), t0); \
	\
	/* postfilter sbox 2 */ \
	filter_8bit(x1, t4, t5, t7, t2); \
	filter_8bit(x4, t4, t5, t7, t2); \
	\
	vpsrldq256(5, t0, t5); \
	vpsrldq256(1, t0, t1); \
	vpsrldq256(2, t0, t2); \
	vpsrldq256(3, t0, t3); \
	vpsrldq256(4, t0, t4); \
	vpshufb256(t6, t0, t0); \
	vpshufb256(t6, t1, t1); \
	vpshufb256(t6, t2, t2); \
	vpshufb256(t6, t3, t3); \
	vpshufb256(t6, t4, t4); \
	vpsrldq256(2, t5, t7); \
	vpshufb256(t6, t7, t7); \
	\
	/* P-function */ \
	vpxor256(x5, x0, x0); \
	vpxor256(x6, x1, x1); \
	vpxor256(x7, x2, x2); \
	vpxor256(x4, x3, x3); \
	\
	vpxor256(x2, x4, x4); \
	vpxor256(x3, x5, x5); \
	vpxor256(x0, x6, x6); \
	vpxor256(x1, x7, x7); \
	\
	vpxor256(x7, x0, x0); \
	vpxor256(x4, x1, x1); \
	vpxor256(x5, x2, x2); \
	vpxor256(x6, x3, x3); \
	\
	vpxor256(x3, x4, x4); \
	vpxor256(x0, x5, x5); \
	vpxor256(x1, x6, x6); \
	vpxor256(x2, x7, x7); /* note: high and low parts swapped */ \
	\
	/* Add key material and result to CD (x becomes new CD) */ \
	\
	vpxor256(t3, x4, x4); \
	vpxor256(mem_cd[0], x4, x4); \
	\
	vpxor256(t2, x5, x5); \
	vpxor256(mem_cd[1], x5, x5); \
	\
	vpsrldq256(1, t5, t3); \
	vpshufb256(t6, t5, t5); \
	vpshufb256(t6, t3, t6); \
	\
	vpxor256(t1, x6, x6); \
	vpxor256(mem_cd[2], x6, x6); \
	\
	vpxor256(t0, x7, x7); \
	vpxor256(mem_cd[3], x7, x7); \
	\
	vpxor256(t7, x0, x0); \
	vpxor256(mem_cd[4], x0, x0); \
	\
	vpxor256(t6, x1, x1); \
	vpxor256(mem_cd[5], x1, x1); \
	\
	vpxor256(t5, x2, x2); \
	vpxor256(mem_cd[6], x2, x2); \
	\
	vpxor256(t4, x3, x3); \
	vpxor256(mem_cd[7], x3, x3);

/*
 * IN/OUT:
 *  x0..x7: byte-sliced AB state preloaded
 *  mem_ab: byte-sliced AB state in memory
 *  mem_cb: byte-sliced CD state in memory
 */
#define two_roundsm16(x0, x1, x2, x3, x4, x5, x6, x7, y0, y1, y2, y3, y4, y5, \
		      y6, y7, mem_ab, mem_cd, i, dir, store_ab) \
	roundsm16(x0, x1, x2, x3, x4, x5, x6, x7, y0, y1, y2, y3, y4, y5, \
		  y6, y7, mem_cd, ctx->key_table[(i)]); \
	\
	vmovdqa256(x4, mem_cd[0]); \
	vmovdqa256(x5, mem_cd[1]); \
	vmovdqa256(x6, mem_cd[2]); \
	vmovdqa256(x7, mem_cd[3]); \
	vmovdqa256(x0, mem_cd[4]); \
	vmovdqa256(x1, mem_cd[5]); \
	vmovdqa256(x2, mem_cd[6]); \
	vmovdqa256(x3, mem_cd[7]); \
	\
	roundsm16(x4, x5, x6, x7, x0, x1, x2, x3, y0, y1, y2, y3, y4, y5, \
		  y6, y7, mem_ab, ctx->key_table[(i) + (dir)]); \
	\
	store_ab(x0, x1, x2, x3, x4, x5, x6, x7, mem_ab);

#define dummy_store(x0, x1, x2, x3, x4, x5, x6, x7, mem_ab) /* do nothing */

#define store_ab_state(x0, x1, x2, x3, x4, x5, x6, x7, mem_ab) \
	/* Store new AB state */ \
	vmovdqa256(x0, mem_ab[0]); \
	vmovdqa256(x1, mem_ab[1]); \
	vmovdqa256(x2, mem_ab[2]); \
	vmovdqa256(x3, mem_ab[3]); \
	vmovdqa256(x4, mem_ab[4]); \
	vmovdqa256(x5, mem_ab[5]); \
	vmovdqa256(x6, mem_ab[6]); \
	vmovdqa256(x7, mem_ab[7]);

#define enc_rounds16(x0, x1, x2, x3, x4, x5, x6, x7, y0, y1, y2, y3, y4, y5, \
		      y6, y7, mem_ab, mem_cd, i) \
	two_roundsm16(x0, x1, x2, x3, x4, x5, x6, x7, y0, y1, y2, y3, y4, y5, \
		      y6, y7, mem_ab, mem_cd, (i) + 2, 1, store_ab_state); \
	two_roundsm16(x0, x1, x2, x3, x4, x5, x6, x7, y0, y1, y2, y3, y4, y5, \
		      y6, y7, mem_ab, mem_cd, (i) + 4, 1, store_ab_state); \
	two_roundsm16(x0, x1, x2, x3, x4, x5, x6, x7, y0, y1, y2, y3, y4, y5, \
		      y6, y7, mem_ab, mem_cd, (i) + 6, 1, dummy_store);

#define dec_rounds16(x0, x1, x2, x3, x4, x5, x6, x7, y0, y1, y2, y3, y4, y5, \
		      y6, y7, mem_ab, mem_cd, i) \
	two_roundsm16(x0, x1, x2, x3, x4, x5, x6, x7, y0, y1, y2, y3, y4, y5, \
		      y6, y7, mem_ab, mem_cd, (i) + 7, -1, store_ab_state); \
	two_roundsm16(x0, x1, x2, x3, x4, x5, x6, x7, y0, y1, y2, y3, y4, y5, \
		      y6, y7, mem_ab, mem_cd, (i) + 5, -1, store_ab_state); \
	two_roundsm16(x0, x1, x2, x3, x4, x5, x6, x7, y0, y1, y2, y3, y4, y5, \
		      y6, y7, mem_ab, mem_cd, (i) + 3, -1, dummy_store);

/*
 * IN:
 *  v0..3: byte-sliced 32-bit integers
 * OUT:
 *  v0..3: (IN <<< 1)
 */
#define rol32_1_16(v0, v1, v2, v3, t0, t1, t2, zero) \
	vpcmpgtb256(v0, zero, t0); \
	vpaddb256(v0, v0, v0); \
	vpabsb256(t0, t0); \
	\
	vpcmpgtb256(v1, zero, t1); \
	vpaddb256(v1, v1, v1); \
	vpabsb256(t1, t1); \
	\
	vpcmpgtb256(v2, zero, t2); \
	vpaddb256(v2, v2, v2); \
	vpabsb256(t2, t2); \
	\
	vpor256(t0, v1, v1); \
	\
	vpcmpgtb256(v3, zero, t0); \
	vpaddb256(v3, v3, v3); \
	vpabsb256(t0, t0); \
	\
	vpor256(t1, v2, v2); \
	vpor256(t2, v3, v3); \
	vpor256(t0, v0, v0);

/*
 * IN:
 *   r: byte-sliced AB state in memory
 *   l: byte-sliced CD state in memory
 * OUT:
 *   x0..x7: new byte-sliced CD state
 */
#define fls16(l, l0, l1, l2, l3, l4, l5, l6, l7, r, t0, t1, t2, t3, tt0, \
	      tt1, tt2, tt3, kl, kr) \
	/* \
	 * t0 = kll; \
	 * t0 &= ll; \
	 * lr ^= rol32(t0, 1); \
	 */ \
	load_zero(tt0); \
	vmovd128_si256(*(kl) & 0xffffffff, t0); \
	vpshufb256(tt0, t0, t3); \
	vpsrldq256(1, t0, t0); \
	vpshufb256(tt0, t0, t2); \
	vpsrldq256(1, t0, t0); \
	vpshufb256(tt0, t0, t1); \
	vpsrldq256(1, t0, t0); \
	vpshufb256(tt0, t0, t0); \
	\
	vpand256(l0, t0, t0); \
	vpand256(l1, t1, t1); \
	vpand256(l2, t2, t2); \
	vpand256(l3, t3, t3); \
	\
	rol32_1_16(t3, t2, t1, t0, tt1, tt2, tt3, tt0); \
	\
	vpxor256(l4, t0, l4); \
	vmovdqa256(l4, l[4]); \
	vpxor256(l5, t1, l5); \
	vmovdqa256(l5, l[5]); \
	vpxor256(l6, t2, l6); \
	vmovdqa256(l6, l[6]); \
	vpxor256(l7, t3, l7); \
	vmovdqa256(l7, l[7]); \
	\
	/* \
	 * t2 = krr; \
	 * t2 |= rr; \
	 * rl ^= t2; \
	 */ \
	\
	vmovd128_si256(*(kr) >> 32, t0); \
	vpshufb256(tt0, t0, t3); \
	vpsrldq256(1, t0, t0); \
	vpshufb256(tt0, t0, t2); \
	vpsrldq256(1, t0, t0); \
	vpshufb256(tt0, t0, t1); \
	vpsrldq256(1, t0, t0); \
	vpshufb256(tt0, t0, t0); \
	\
	vpor256(r[4], t0, t0); \
	vpor256(r[5], t1, t1); \
	vpor256(r[6], t2, t2); \
	vpor256(r[7], t3, t3); \
	\
	vpxor256(r[0], t0, t0); \
	vpxor256(r[1], t1, t1); \
	vpxor256(r[2], t2, t2); \
	vpxor256(r[3], t3, t3); \
	vmovdqa256(t0, r[0]); \
	vmovdqa256(t1, r[1]); \
	vmovdqa256(t2, r[2]); \
	vmovdqa256(t3, r[3]); \
	\
	/* \
	 * t2 = krl; \
	 * t2 &= rl; \
	 * rr ^= rol32(t2, 1); \
	 */ \
	vmovd128_si256(*(kr) & 0xffffffff, t0); \
	vpshufb256(tt0, t0, t3); \
	vpsrldq256(1, t0, t0); \
	vpshufb256(tt0, t0, t2); \
	vpsrldq256(1, t0, t0); \
	vpshufb256(tt0, t0, t1); \
	vpsrldq256(1, t0, t0); \
	vpshufb256(tt0, t0, t0); \
	\
	vpand256(r[0], t0, t0); \
	vpand256(r[1], t1, t1); \
	vpand256(r[2], t2, t2); \
	vpand256(r[3], t3, t3); \
	\
	rol32_1_16(t3, t2, t1, t0, tt1, tt2, tt3, tt0); \
	\
	vpxor256(r[4], t0, t0); \
	vpxor256(r[5], t1, t1); \
	vpxor256(r[6], t2, t2); \
	vpxor256(r[7], t3, t3); \
	vmovdqa256(t0, r[4]); \
	vmovdqa256(t1, r[5]); \
	vmovdqa256(t2, r[6]); \
	vmovdqa256(t3, r[7]); \
	\
	/* \
	 * t0 = klr; \
	 * t0 |= lr; \
	 * ll ^= t0; \
	 */ \
	\
	vmovd128_si256(*(kl) >> 32, t0); \
	vpshufb256(tt0, t0, t3); \
	vpsrldq256(1, t0, t0); \
	vpshufb256(tt0, t0, t2); \
	vpsrldq256(1, t0, t0); \
	vpshufb256(tt0, t0, t1); \
	vpsrldq256(1, t0, t0); \
	vpshufb256(tt0, t0, t0); \
	\
	vpor256(l4, t0, t0); \
	vpor256(l5, t1, t1); \
	vpor256(l6, t2, t2); \
	vpor256(l7, t3, t3); \
	\
	vpxor256(l0, t0, l0); \
	vmovdqa256(l0, l[0]); \
	vpxor256(l1, t1, l1); \
	vmovdqa256(l1, l[1]); \
	vpxor256(l2, t2, l2); \
	vmovdqa256(l2, l[2]); \
	vpxor256(l3, t3, l3); \
	vmovdqa256(l3, l[3]);

#define byteslice_16x16b_fast(a0, b0, c0, d0, a1, b1, c1, d1, a2, b2, c2, d2, \
			      a3, b3, c3, d3, st0, st1) \
	vmovdqa256(d2, st0); \
	vmovdqa256(d3, st1); \
	transpose_4x4(a0, a1, a2, a3, d2, d3); \
	transpose_4x4(b0, b1, b2, b3, d2, d3); \
	vmovdqa256(st0, d2); \
	vmovdqa256(st1, d3); \
	\
	vmovdqa256(a0, st0); \
	vmovdqa256(a1, st1); \
	transpose_4x4(c0, c1, c2, c3, a0, a1); \
	transpose_4x4(d0, d1, d2, d3, a0, a1); \
	\
	vmovdqa256(shufb_16x16b, a0); \
	vmovdqa256(st1, a1); \
	vpshufb256(a0, a2, a2); \
	vpshufb256(a0, a3, a3); \
	vpshufb256(a0, b0, b0); \
	vpshufb256(a0, b1, b1); \
	vpshufb256(a0, b2, b2); \
	vpshufb256(a0, b3, b3); \
	vpshufb256(a0, a1, a1); \
	vpshufb256(a0, c0, c0); \
	vpshufb256(a0, c1, c1); \
	vpshufb256(a0, c2, c2); \
	vpshufb256(a0, c3, c3); \
	vpshufb256(a0, d0, d0); \
	vpshufb256(a0, d1, d1); \
	vpshufb256(a0, d2, d2); \
	vpshufb256(a0, d3, d3); \
	vmovdqa256(d3, st1); \
	vmovdqa256(st0, d3); \
	vpshufb256(a0, d3, a0); \
	vmovdqa256(d2, st0); \
	\
	transpose_4x4(a0, b0, c0, d0, d2, d3); \
	transpose_4x4(a1, b1, c1, d1, d2, d3); \
	vmovdqa256(st0, d2); \
	vmovdqa256(st1, d3); \
	\
	vmovdqa256(b0, st0); \
	vmovdqa256(b1, st1); \
	transpose_4x4(a2, b2, c2, d2, b0, b1); \
	transpose_4x4(a3, b3, c3, d3, b0, b1); \
	vmovdqa256(st0, b0); \
	vmovdqa256(st1, b1); \
	/* does not adjust output bytes inside vectors */

/* load blocks to registers and apply pre-whitening */
#define inpack16_pre(x0, x1, x2, x3, x4, x5, x6, x7, y0, y1, y2, y3, y4, y5, \
		     y6, y7, rio, key) \
	vmovq128_si256((key), x0); \
	vpshufb256(pack_bswap, x0, x0); \
	\
	vpxor256_memld((rio) + 0 * 32, x0, y7); \
	vpxor256_memld((rio) + 1 * 32, x0, y6); \
	vpxor256_memld((rio) + 2 * 32, x0, y5); \
	vpxor256_memld((rio) + 3 * 32, x0, y4); \
	vpxor256_memld((rio) + 4 * 32, x0, y3); \
	vpxor256_memld((rio) + 5 * 32, x0, y2); \
	vpxor256_memld((rio) + 6 * 32, x0, y1); \
	vpxor256_memld((rio) + 7 * 32, x0, y0); \
	vpxor256_memld((rio) + 8 * 32, x0, x7); \
	vpxor256_memld((rio) + 9 * 32, x0, x6); \
	vpxor256_memld((rio) + 10 * 32, x0, x5); \
	vpxor256_memld((rio) + 11 * 32, x0, x4); \
	vpxor256_memld((rio) + 12 * 32, x0, x3); \
	vpxor256_memld((rio) + 13 * 32, x0, x2); \
	vpxor256_memld((rio) + 14 * 32, x0, x1); \
	vpxor256_memld((rio) + 15 * 32, x0, x0);

/* byteslice pre-whitened blocks and store to temporary memory */
#define inpack16_post(x0, x1, x2, x3, x4, x5, x6, x7, y0, y1, y2, y3, y4, y5, \
		      y6, y7, mem_ab, mem_cd) \
	byteslice_16x16b_fast(x0, x1, x2, x3, x4, x5, x6, x7, y0, y1, y2, y3, \
			      y4, y5, y6, y7, mem_ab[0], mem_cd[0]); \
	\
	vmovdqa256(x0, mem_ab[0]); \
	vmovdqa256(x1, mem_ab[1]); \
	vmovdqa256(x2, mem_ab[2]); \
	vmovdqa256(x3, mem_ab[3]); \
	vmovdqa256(x4, mem_ab[4]); \
	vmovdqa256(x5, mem_ab[5]); \
	vmovdqa256(x6, mem_ab[6]); \
	vmovdqa256(x7, mem_ab[7]); \
	vmovdqa256(y0, mem_cd[0]); \
	vmovdqa256(y1, mem_cd[1]); \
	vmovdqa256(y2, mem_cd[2]); \
	vmovdqa256(y3, mem_cd[3]); \
	vmovdqa256(y4, mem_cd[4]); \
	vmovdqa256(y5, mem_cd[5]); \
	vmovdqa256(y6, mem_cd[6]); \
	vmovdqa256(y7, mem_cd[7]);

/* de-byteslice, apply post-whitening and store blocks */
#define outunpack16(x0, x1, x2, x3, x4, x5, x6, x7, y0, y1, y2, y3, y4, \
		    y5, y6, y7, key, stack_tmp0, stack_tmp1) \
	byteslice_16x16b_fast(y0, y4, x0, x4, y1, y5, x1, x5, y2, y6, x2, x6, \
			      y3, y7, x3, x7, stack_tmp0, stack_tmp1); \
	\
	vmovdqa256(x0, stack_tmp0); \
	\
	vmovq128_si256((key), x0); \
	vpshufb256(pack_bswap, x0, x0); \
	\
	vpxor256(x0, y7, y7); \
	vpxor256(x0, y6, y6); \
	vpxor256(x0, y5, y5); \
	vpxor256(x0, y4, y4); \
	vpxor256(x0, y3, y3); \
	vpxor256(x0, y2, y2); \
	vpxor256(x0, y1, y1); \
	vpxor256(x0, y0, y0); \
	vpxor256(x0, x7, x7); \
	vpxor256(x0, x6, x6); \
	vpxor256(x0, x5, x5); \
	vpxor256(x0, x4, x4); \
	vpxor256(x0, x3, x3); \
	vpxor256(x0, x2, x2); \
	vpxor256(x0, x1, x1); \
	vpxor256(stack_tmp0, x0, x0);

#define write_output(x0, x1, x2, x3, x4, x5, x6, x7, y0, y1, y2, y3, y4, y5, \
		     y6, y7, rio) \
	vmovdqu256_memst(x0, (rio) + 0 * 32); \
	vmovdqu256_memst(x1, (rio) + 1 * 32); \
	vmovdqu256_memst(x2, (rio) + 2 * 32); \
	vmovdqu256_memst(x3, (rio) + 3 * 32); \
	vmovdqu256_memst(x4, (rio) + 4 * 32); \
	vmovdqu256_memst(x5, (rio) + 5 * 32); \
	vmovdqu256_memst(x6, (rio) + 6 * 32); \
	vmovdqu256_memst(x7, (rio) + 7 * 32); \
	vmovdqu256_memst(y0, (rio) + 8 * 32); \
	vmovdqu256_memst(y1, (rio) + 9 * 32); \
	vmovdqu256_memst(y2, (rio) + 10 * 32); \
	vmovdqu256_memst(y3, (rio) + 11 * 32); \
	vmovdqu256_memst(y4, (rio) + 12 * 32); \
	vmovdqu256_memst(y5, (rio) + 13 * 32); \
	vmovdqu256_memst(y6, (rio) + 14 * 32); \
	vmovdqu256_memst(y7, (rio) + 15 * 32);

/**********************************************************************
  macros for defining constant vectors
 **********************************************************************/
#define M256I_BYTE(a0, a1, a2, a3, a4, a5, a6, a7, b0, b1, b2, b3, b4, b5, b6, b7, \
		   c0, c1, c2, c3, c4, c5, c6, c7, d0, d1, d2, d3, d4, d5, d6, d7) \
	{ \
	  (((a0) & 0xffULL) << 0) | \
	  (((a1) & 0xffULL) << 8) | \
	  (((a2) & 0xffULL) << 16) | \
	  (((a3) & 0xffULL) << 24) | \
	  (((a4) & 0xffULL) << 32) | \
	  (((a5) & 0xffULL) << 40) | \
	  (((a6) & 0xffULL) << 48) | \
	  (((a7) & 0xffULL) << 56), \
	  (((b0) & 0xffULL) << 0) | \
	  (((b1) & 0xffULL) << 8) | \
	  (((b2) & 0xffULL) << 16) | \
	  (((b3) & 0xffULL) << 24) | \
	  (((b4) & 0xffULL) << 32) | \
	  (((b5) & 0xffULL) << 40) | \
	  (((b6) & 0xffULL) << 48) | \
	  (((b7) & 0xffULL) << 56), \
	  (((c0) & 0xffULL) << 0) | \
	  (((c1) & 0xffULL) << 8) | \
	  (((c2) & 0xffULL) << 16) | \
	  (((c3) & 0xffULL) << 24) | \
	  (((c4) & 0xffULL) << 32) | \
	  (((c5) & 0xffULL) << 40) | \
	  (((c6) & 0xffULL) << 48) | \
	  (((c7) & 0xffULL) << 56), \
	  (((d0) & 0xffULL) << 0) | \
	  (((d1) & 0xffULL) << 8) | \
	  (((d2) & 0xffULL) << 16) | \
	  (((d3) & 0xffULL) << 24) | \
	  (((d4) & 0xffULL) << 32) | \
	  (((d5) & 0xffULL) << 40) | \
	  (((d6) & 0xffULL) << 48) | \
	  (((d7) & 0xffULL) << 56) \
	}

#define M256I_U32(a0, a1, b0, b1, c0, c1, d0, d1) \
	{ \
	  (((a0) & 0xffffffffULL) << 0) | \
	  (((a1) & 0xffffffffULL) << 32), \
	  (((b0) & 0xffffffffULL) << 0) | \
	  (((b1) & 0xffffffffULL) << 32), \
	  (((c0) & 0xffffffffULL) << 0) | \
	  (((c1) & 0xffffffffULL) << 32), \
	  (((d0) & 0xffffffffULL) << 0) | \
	  (((d1) & 0xffffffffULL) << 32) \
	}

#define SHUFB_BYTES(idx) \
	(((0 + (idx)) << 0)  | ((4 + (idx)) << 8) | \
	 ((8 + (idx)) << 16) | ((12 + (idx)) << 24))

typedef uint64_t uint64_unaligned_t __attribute__((aligned(1), may_alias));

static const __m256i shufb_16x16b =
  M256I_U32(SHUFB_BYTES(0), SHUFB_BYTES(1), SHUFB_BYTES(2), SHUFB_BYTES(3),
	    SHUFB_BYTES(0), SHUFB_BYTES(1), SHUFB_BYTES(2), SHUFB_BYTES(3));

static const __m256i pack_bswap =
  M256I_U32(0x00010203, 0x04050607, 0x0f0f0f0f, 0x0f0f0f0f,
	    0x00010203, 0x04050607, 0x0f0f0f0f, 0x0f0f0f0f);

/*
 * pre-SubByte transform
 *
 * pre-lookup for sbox1, sbox2, sbox3:
 *   swap_bitendianness(
 *       isom_map_camellia_to_aes(
 *           camellia_f(
 *               swap_bitendianess(in)
 *           )
 *       )
 *   )
 *
 * (note: '⊕ 0xc5' inside camellia_f())
 */
static const __m256i pre_tf_lo_s1 =
  M256I_BYTE(0x45, 0xe8, 0x40, 0xed, 0x2e, 0x83, 0x2b, 0x86,
	     0x4b, 0xe6, 0x4e, 0xe3, 0x20, 0x8d, 0x25, 0x88,
	     0x45, 0xe8, 0x40, 0xed, 0x2e, 0x83, 0x2b, 0x86,
	     0x4b, 0xe6, 0x4e, 0xe3, 0x20, 0x8d, 0x25, 0x88);

static const __m256i pre_tf_hi_s1 =
  M256I_BYTE(0x00, 0x51, 0xf1, 0xa0, 0x8a, 0xdb, 0x7b, 0x2a,
	     0x09, 0x58, 0xf8, 0xa9, 0x83, 0xd2, 0x72, 0x23,
	     0x00, 0x51, 0xf1, 0xa0, 0x8a, 0xdb, 0x7b, 0x2a,
	     0x09, 0x58, 0xf8, 0xa9, 0x83, 0xd2, 0x72, 0x23);

/*
 * pre-SubByte transform
 *
 * pre-lookup for sbox4:
 *   swap_bitendianness(
 *       isom_map_camellia_to_aes(
 *           camellia_f(
 *               swap_bitendianess(in <<< 1)
 *           )
 *       )
 *   )
 *
 * (note: '⊕ 0xc5' inside camellia_f())
 */
static const __m256i pre_tf_lo_s4 =
  M256I_BYTE(0x45, 0x40, 0x2e, 0x2b, 0x4b, 0x4e, 0x20, 0x25,
	     0x14, 0x11, 0x7f, 0x7a, 0x1a, 0x1f, 0x71, 0x74,
	     0x45, 0x40, 0x2e, 0x2b, 0x4b, 0x4e, 0x20, 0x25,
	     0x14, 0x11, 0x7f, 0x7a, 0x1a, 0x1f, 0x71, 0x74);

static const __m256i pre_tf_hi_s4 =
  M256I_BYTE(0x00, 0xf1, 0x8a, 0x7b, 0x09, 0xf8, 0x83, 0x72,
	     0xad, 0x5c, 0x27, 0xd6, 0xa4, 0x55, 0x2e, 0xdf,
	     0x00, 0xf1, 0x8a, 0x7b, 0x09, 0xf8, 0x83, 0x72,
	     0xad, 0x5c, 0x27, 0xd6, 0xa4, 0x55, 0x2e, 0xdf);

/*
 * post-SubByte transform
 *
 * post-lookup for sbox1, sbox4:
 *  swap_bitendianness(
 *      camellia_h(
 *          isom_map_aes_to_camellia(
 *              swap_bitendianness(
 *                  aes_inverse_affine_transform(in)
 *              )
 *          )
 *      )
 *  )
 *
 * (note: '⊕ 0x6e' inside camellia_h())
 */
static const __m256i post_tf_lo_s1 =
  M256I_BYTE(0x3c, 0xcc, 0xcf, 0x3f, 0x32, 0xc2, 0xc1, 0x31,
	     0xdc, 0x2c, 0x2f, 0xdf, 0xd2, 0x22, 0x21, 0xd1,
	     0x3c, 0xcc, 0xcf, 0x3f, 0x32, 0xc2, 0xc1, 0x31,
	     0xdc, 0x2c, 0x2f, 0xdf, 0xd2, 0x22, 0x21, 0xd1);

static const __m256i post_tf_hi_s1 =
  M256I_BYTE(0x00, 0xf9, 0x86, 0x7f, 0xd7, 0x2e, 0x51, 0xa8,
	     0xa4, 0x5d, 0x22, 0xdb, 0x73, 0x8a, 0xf5, 0x0c,
	     0x00, 0xf9, 0x86, 0x7f, 0xd7, 0x2e, 0x51, 0xa8,
	     0xa4, 0x5d, 0x22, 0xdb, 0x73, 0x8a, 0xf5, 0x0c);

/*
 * post-SubByte transform
 *
 * post-lookup for sbox2:
 *  swap_bitendianness(
 *      camellia_h(
 *          isom_map_aes_to_camellia(
 *              swap_bitendianness(
 *                  aes_inverse_affine_transform(in)
 *              )
 *          )
 *      )
 *  ) <<< 1
 *
 * (note: '⊕ 0x6e' inside camellia_h())
 */
static const __m256i post_tf_lo_s2 =
  M256I_BYTE(0x78, 0x99, 0x9f, 0x7e, 0x64, 0x85, 0x83, 0x62,
	     0xb9, 0x58, 0x5e, 0xbf, 0xa5, 0x44, 0x42, 0xa3,
	     0x78, 0x99, 0x9f, 0x7e, 0x64, 0x85, 0x83, 0x62,
	     0xb9, 0x58, 0x5e, 0xbf, 0xa5, 0x44, 0x42, 0xa3);

static const __m256i post_tf_hi_s2 =
  M256I_BYTE(0x00, 0xf3, 0x0d, 0xfe, 0xaf, 0x5c, 0xa2, 0x51,
	     0x49, 0xba, 0x44, 0xb7, 0xe6, 0x15, 0xeb, 0x18,
	     0x00, 0xf3, 0x0d, 0xfe, 0xaf, 0x5c, 0xa2, 0x51,
	     0x49, 0xba, 0x44, 0xb7, 0xe6, 0x15, 0xeb, 0x18);

/*
 * post-SubByte transform
 *
 * post-lookup for sbox3:
 *  swap_bitendianness(
 *      camellia_h(
 *          isom_map_aes_to_camellia(
 *              swap_bitendianness(
 *                  aes_inverse_affine_transform(in)
 *              )
 *          )
 *      )
 *  ) >>> 1
 *
 * (note: '⊕ 0x6e' inside camellia_h())
 */
static const __m256i post_tf_lo_s3 =
  M256I_BYTE(0x1e, 0x66, 0xe7, 0x9f, 0x19, 0x61, 0xe0, 0x98,
	     0x6e, 0x16, 0x97, 0xef, 0x69, 0x11, 0x90, 0xe8,
	     0x1e, 0x66, 0xe7, 0x9f, 0x19, 0x61, 0xe0, 0x98,
	     0x6e, 0x16, 0x97, 0xef, 0x69, 0x11, 0x90, 0xe8);

static const __m256i post_tf_hi_s3 =
  M256I_BYTE(0x00, 0xfc, 0x43, 0xbf, 0xeb, 0x17, 0xa8, 0x54,
	     0x52, 0xae, 0x11, 0xed, 0xb9, 0x45, 0xfa, 0x06,
	     0x00, 0xfc, 0x43, 0xbf, 0xeb, 0x17, 0xa8, 0x54,
	     0x52, 0xae, 0x11, 0xed, 0xb9, 0x45, 0xfa, 0x06);

/* For isolating SubBytes from AESENCLAST, inverse shift row */
static const __m256i inv_shift_row =
  M256I_BYTE(0x00, 0x0d, 0x0a, 0x07, 0x04, 0x01, 0x0e, 0x0b,
	     0x08, 0x05, 0x02, 0x0f, 0x0c, 0x09, 0x06, 0x03,
	     0x00, 0x0d, 0x0a, 0x07, 0x04, 0x01, 0x0e, 0x0b,
	     0x08, 0x05, 0x02, 0x0f, 0x0c, 0x09, 0x06, 0x03);

/* 4-bit mask */
static const __m256i mask_0f =
  M256I_U32(0x0f0f0f0f, 0x0f0f0f0f, 0x0f0f0f0f, 0x0f0f0f0f,
	    0x0f0f0f0f, 0x0f0f0f0f, 0x0f0f0f0f, 0x0f0f0f0f);


/* Encrypts 32 input block from IN and writes result to OUT. IN and OUT may
 * unaligned pointers. */
void camellia_encrypt_32blks_simd256(struct camellia_simd_ctx *ctx, void *vout,
				     const void *vin)
{
  char *out = vout;
  const char *in = vin;
  __m256i x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15;
  __m256i ab[8];
  __m256i cd[8];
  __m256i tmp0, tmp1;
  unsigned int lastk;

  if (ctx->key_length > 16)
    lastk = 32;
  else
    lastk = 24;

  inpack16_pre(x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14,
	       x15, in, ctx->key_table[0]);

  inpack16_post(x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14,
		x15, ab, cd);

  enc_rounds16(x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14,
	       x15, ab, cd, 0);

  fls16(ab, x0, x1, x2, x3, x4, x5, x6, x7, cd, x8, x9, x10, x11, x12, x13, x14,
	x15, &ctx->key_table[8], &ctx->key_table[9]);

  enc_rounds16(x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14,
	       x15, ab, cd, 8);

  fls16(ab, x0, x1, x2, x3, x4, x5, x6, x7, cd, x8, x9, x10, x11, x12, x13, x14,
	x15, &ctx->key_table[16], &ctx->key_table[17]);

  enc_rounds16(x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14,
	       x15, ab, cd, 16);

  if (lastk == 32) {
    fls16(ab, x0, x1, x2, x3, x4, x5, x6, x7, cd, x8, x9, x10, x11, x12, x13,
	  x14, x15, &ctx->key_table[24], &ctx->key_table[25]);

    enc_rounds16(x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13,
		  x14, x15, ab, cd, 24);
  }

  /* load CD for output */
  vmovdqa256(cd[0], x8);
  vmovdqa256(cd[1], x9);
  vmovdqa256(cd[2], x10);
  vmovdqa256(cd[3], x11);
  vmovdqa256(cd[4], x12);
  vmovdqa256(cd[5], x13);
  vmovdqa256(cd[6], x14);
  vmovdqa256(cd[7], x15);

  outunpack16(x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14,
	      x15, ctx->key_table[lastk], tmp0, tmp1);

  write_output(x7, x6, x5, x4, x3, x2, x1, x0, x15, x14, x13, x12, x11, x10, x9,
	       x8, out);
}

/* Decrypts 32 input block from IN and writes result to OUT. IN and OUT may
 * unaligned pointers. */
void camellia_decrypt_32blks_simd256(struct camellia_simd_ctx *ctx, void *vout,
				     const void *vin)
{
  char *out = vout;
  const char *in = vin;
  __m256i x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15;
  __m256i ab[8];
  __m256i cd[8];
  __m256i tmp0, tmp1;
  unsigned int firstk;

  if (ctx->key_length > 16)
    firstk = 32;
  else
    firstk = 24;

  inpack16_pre(x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14,
	       x15, in, ctx->key_table[firstk]);

  inpack16_post(x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14,
		x15, ab, cd);

  if (firstk == 32) {
    dec_rounds16(x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13,
		 x14, x15, ab, cd, 24);

    fls16(ab, x0, x1, x2, x3, x4, x5, x6, x7, cd, x8, x9, x10, x11, x12, x13,
	  x14, x15, &ctx->key_table[25], &ctx->key_table[24]);
  }

  dec_rounds16(x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14,
	       x15, ab, cd, 16);

  fls16(ab, x0, x1, x2, x3, x4, x5, x6, x7, cd, x8, x9, x10, x11, x12, x13, x14,
	x15, &ctx->key_table[17], &ctx->key_table[16]);

  dec_rounds16(x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14,
	       x15, ab, cd, 8);

  fls16(ab, x0, x1, x2, x3, x4, x5, x6, x7, cd, x8, x9, x10, x11, x12, x13, x14,
	x15, &ctx->key_table[9], &ctx->key_table[8]);

  dec_rounds16(x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14,
	       x15, ab, cd, 0);

  /* load CD for output */
  vmovdqa256(cd[0], x8);
  vmovdqa256(cd[1], x9);
  vmovdqa256(cd[2], x10);
  vmovdqa256(cd[3], x11);
  vmovdqa256(cd[4], x12);
  vmovdqa256(cd[5], x13);
  vmovdqa256(cd[6], x14);
  vmovdqa256(cd[7], x15);

  outunpack16(x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14,
	      x15, ctx->key_table[0], tmp0, tmp1);

  write_output(x7, x6, x5, x4, x3, x2, x1, x0, x15, x14, x13, x12, x11, x10, x9,
	       x8, out);
}
