.text

/**********************************************************************
  helper macros
 **********************************************************************/

/*
 * IN:
 *  x (input state), lo_t, hi_t (filters), mask, tmp
 * OUT:
 *  x (filtered state)
 */
#define filter_8bit_neon(x,lo_t,hi_t,mask,tmp) \
    and     tmp.16b,x.16b,mask.16b; \
    ushr    x.16b,x.16b,#4; \
    tbl     tmp.16b,{lo_t.16b},tmp.16b; \
    tbl     x.16b,{hi_t.16b},x.16b; \
    eor     x.16b,x.16b,tmp.16b

/**********************************************************************
  16-way camellia macros
 **********************************************************************/

/*
 * IN:
 *  v0..v7: byte-sliced AB state
 *  mem_cd: register pointer storing CD state
 *  key: index for key material
 * OUT:
 *  v0..v7: new byte-sliced CD state
 * Clobbers:
 *  x5 - key value
 *  v8..v15: broadcasted key values
 *  v16: mask_0f
 *  v17: inv_shift_row
 *  v18..v27: pre- and post-filters
 *  v28-v31 - tmps
 */
#define roundsm16(v0, v1, v2, v3, v4, v5, v6, v7, mem_cd, key) \
    /* Load 64-bit round key */ \
    ldr     x5,[key]; \
\
    /* S-FUNCTION (PRE-AES) */ \
\
    /* Inverse Shift Rows (pre-compensation) */ \
    tbl     v0.16b,{v0.16b},v17.16b; \
    tbl     v7.16b,{v7.16b},v17.16b; \
    tbl     v1.16b,{v1.16b},v17.16b; \
    tbl     v4.16b,{v4.16b},v17.16b; \
    tbl     v2.16b,{v2.16b},v17.16b; \
    tbl     v5.16b,{v5.16b},v17.16b; \
    tbl     v3.16b,{v3.16b},v17.16b; \
    tbl     v6.16b,{v6.16b},v17.16b; \
\
    /* Pre-Filter */ \
    filter_8bit_neon(v0,v18,v19,v16,v28); \
    filter_8bit_neon(v7,v18,v19,v16,v28); \
    filter_8bit_neon(v1,v18,v19,v16,v28); \
    filter_8bit_neon(v4,v18,v19,v16,v28); \
    filter_8bit_neon(v2,v18,v19,v16,v28); \
    filter_8bit_neon(v5,v18,v19,v16,v28); \
    eor  v31.16b, v31.16b, v31.16b; \
    filter_8bit_neon(v3,v20,v21,v16,v28); \
    filter_8bit_neon(v6,v20,v21,v16,v28); \
\
    /* AES CORE */ \
    aese v0.16b, v31.16b; \
    aese v7.16b, v31.16b; \
    aese v1.16b, v31.16b; \
    aese v4.16b, v31.16b; \
    aese v2.16b, v31.16b; \
    aese v5.16b, v31.16b; \
    aese v3.16b, v31.16b; \
    aese v6.16b, v31.16b; \
\
    /* Post-Filter */ \
    filter_8bit_neon(v0,v22,v23,v16,v28); \
    filter_8bit_neon(v7,v22,v23,v16,v28); \
    filter_8bit_neon(v3,v22,v23,v16,v28); \
    filter_8bit_neon(v6,v22,v23,v16,v28); \
\
    filter_8bit_neon(v2,v26,v27,v16,v28); \
    filter_8bit_neon(v5,v26,v27,v16,v28); \
\
    filter_8bit_neon(v1,v24,v25,v16,v28); \
    filter_8bit_neon(v4,v24,v25,v16,v28); \
\
    /* Interleaved P-function and key broadcasting */ \
    fmov    d31,x5; \
\
    eor     v0.16b,v0.16b,v5.16b; \
    movi    v29.16b,#3;\
    eor     v1.16b,v1.16b,v6.16b; \
    movi    v30.16b,#2; \
    eor     v2.16b,v2.16b,v7.16b; \
    eor     v3.16b,v3.16b,v4.16b; \
\
    tbl     v11.16b,{v31.16b},v29.16b;   /* threes */ \
    tbl     v10.16b,{v31.16b},v30.16b;   /* twos */ \
\
    eor     v4.16b,v4.16b,v2.16b; \
    movi    v29.16b,#1; \
    eor     v5.16b,v5.16b,v3.16b; \
    movi    v30.16b,#7; \
    eor     v6.16b,v6.16b,v0.16b; \
    eor     v7.16b,v7.16b,v1.16b; \
\
    tbl     v9.16b,{v31.16b},v29.16b;   /* ones */ \
    tbl     v15.16b,{v31.16b},v30.16b;   /* sevens */ \
\
    eor     v0.16b,v0.16b,v7.16b; \
    movi    v29.16b,#6; \
    eor     v1.16b,v1.16b,v4.16b; \
    movi    v30.16b,#5; \
    eor     v2.16b,v2.16b,v5.16b; \
    eor     v3.16b,v3.16b,v6.16b; \
\
    tbl     v14.16b,{v31.16b},v29.16b;   /* sixs */ \
    tbl     v13.16b,{v31.16b},v30.16b;   /* fives */ \
\
    eor     v4.16b,v4.16b,v3.16b; \
    movi    v29.16b,#4; \
    eor     v5.16b,v5.16b,v0.16b; \
    eor     v30.16b,v30.16b,v30.16b; \
    eor     v6.16b,v6.16b,v1.16b; \
    eor     v7.16b,v7.16b,v2.16b;   /* Now the high snd low parts are swapped */ \
\
    ldr     q28,[mem_cd]; \
\
    tbl     v12.16b,{v31.16b},v29.16b;   /* fours */ \
    tbl     v8.16b,{v31.16b},v30.16b;    /* zeros */ \
\
    /* Final XOR's (w. broadcasted KEY & CD state) */ \
    ldr     q29,[mem_cd,#16]; \
    ldr     q30,[mem_cd,#32]; \
    ldr     q31,[mem_cd,#48]; \
\
    eor     v4.16b,v4.16b,v11.16b; \
    eor     v4.16b,v4.16b,v28.16b; \
\
    eor     v5.16b,v5.16b,v10.16b; \
    eor     v5.16b,v5.16b,v29.16b; \
\
    ldr     q28,[mem_cd,#64]; \
\
    eor     v6.16b,v6.16b,v9.16b; \
    eor     v6.16b,v6.16b,v30.16b; \
\
    ldr     q29,[mem_cd,#80]; \
\
    eor     v7.16b,v7.16b,v8.16b; \
    eor     v7.16b,v7.16b,v31.16b; \
\
    ldr     q30,[mem_cd,#96]; \
\
    eor     v0.16b,v0.16b,v15.16b; \
    eor     v0.16b,v0.16b,v28.16b; \
\
    ldr     q31,[mem_cd,#112]; \
\
    eor     v1.16b,v1.16b,v14.16b; \
    eor     v1.16b,v1.16b,v29.16b; \
\
    eor     v2.16b,v2.16b,v13.16b; \
    eor     v2.16b,v2.16b,v30.16b; \
\
    eor     v3.16b,v3.16b,v12.16b; \
    eor     v3.16b,v3.16b,v31.16b;

/*
 * IN/OUT:
 *  v0..v7: byte-sliced AB state preloaded
 *  mem_ab: byte-sliced AB state in memory
 *  mem_cd: byte-sliced CD state in memory
 *  first_key_ptr: ptr to access first key
 *  store_ab: function to store state
 * Clobbers:
 *  x4 - second key pointer value
 */
#define two_roundsm16(v0, v1, v2, v3, v4, v5, v6, v7, mem_ab, mem_cd, first_key_ptr, store_ab) \
    roundsm16(v0, v1, v2, v3, v4, v5, v6, v7, mem_cd, first_key_ptr); \
\
    stp     q4,q5,[mem_cd]; \
    stp     q6,q7,[mem_cd,#32]; \
    stp     q0,q1,[mem_cd,#64]; \
    stp     q2,q3,[mem_cd,#96]; \
\
    add     x4,first_key_ptr,#8; \
    roundsm16(v4, v5, v6, v7, v0, v1, v2, v3, mem_ab, x4); \
\
    store_ab(v0, v1, v2, v3, v4, v5, v6, v7, mem_ab);

/*
 * Differs from two_roundsm16 by decrementing instead of incrementing key ptr.
 * IN/OUT:
 *  v0..v7: byte-sliced AB state preloaded
 *  mem_ab: byte-sliced AB state in memory
 *  mem_cd: byte-sliced CD state in memory
 *  first_key_ptr: ptr to access first key
 *  store_ab: function to store state
 * Clobbers:
 *  x4 - second key pointer value
 */
#define two_roundsm16_dec(v0, v1, v2, v3, v4, v5, v6, v7, mem_ab, mem_cd, first_key_ptr, store_ab) \
    roundsm16(v0, v1, v2, v3, v4, v5, v6, v7, mem_cd, first_key_ptr); \
\
    stp     q4,q5,[mem_cd]; \
    stp     q6,q7,[mem_cd,#32]; \
    stp     q0,q1,[mem_cd,#64]; \
    stp     q2,q3,[mem_cd,#96]; \
\
    sub     x4,first_key_ptr,#8; \
    roundsm16(v4, v5, v6, v7, v0, v1, v2, v3, mem_ab, x4); \
\
    store_ab(v0, v1, v2, v3, v4, v5, v6, v7, mem_ab);

#define dummy_store(v0, v1, v2, v3, v4, v5, v6, v7, mem_ab) /* do nothing */

#define store_ab_state(v0, v1, v2, v3, v4, v5, v6, v7, mem_ab) \
	/* Store new AB state */ \
    stp     q0,q1,[mem_ab]; \
    stp     q2,q3,[mem_ab,#32]; \
    stp     q4,q5,[mem_ab,#64]; \
    stp     q6,q7,[mem_ab,#96];

/*
 * IN:
 *  v0..3: byte-sliced 32-bit integers
 *  t0-t2: vector clobbers
 * OUT:
 *  v0..3: (IN <<< 1)
 */
#define rol32_1_16(v0, v1, v2, v3, t0, t1, t2) \
    ushr    t0.16b,v0.16b,#7; \
    add     v0.16b,v0.16b,v0.16b; \
    ushr    t1.16b,v1.16b,#7; \
    add     v1.16b,v1.16b,v1.16b; \
    ushr    t2.16b,v2.16b,#7; \
    add     v2.16b,v2.16b,v2.16b; \
    orr     v1.16b,t0.16b,v1.16b; \
    ushr    t0.16b,v3.16b,#7; \
    add     v3.16b,v3.16b,v3.16b; \
    orr     v2.16b,t1.16b,v2.16b; \
    orr     v3.16b,t2.16b,v3.16b; \
    orr     v0.16b,t0.16b,v0.16b;

/*
 * IN:
 *   v0..v7: byte-sliced AB state in registers
 *   r: byte-sliced AB state in memory
 *   l: byte-sliced CD state in memory
 *   key_a_ptr, key_b_ptr: pointers to keys
 * OUT:
 *   v0..v7: new byte-sliced CD state
 *   Updated AB nd CD states written to memory
 * Clobbers:
 *  x5-x7: storage for keys
 *  v8-v15,v16-19,v28-v31: temporary vectors
 */
#define fls16(v0, v1, v2, v3, v4, v5, v6, v7, mem_l, mem_r, key_a_ptr, key_b_ptr) \
    ldr     x5,[key_a_ptr]; /*x5={klr,kll}*/ \
    ldr     x6,[key_b_ptr]; /*x6={krr,krl}*/ \
	/* \
	 * t0 = kll; \
	 * t0 &= ll; \
	 * lr ^= rol32(t0, 1); \
	 */ \
    eor     v19.16b,v19.16b,v19.16b; \
    movi    v18.16b,#1; \
    fmov    s31, w5;       /* v31 lower = kll */ \
    movi    v17.16b,#2; \
    movi    v16.16b,#3; \
    tbl     v19.16b,{v31.16b},v19.16b; \
    tbl     v18.16b,{v31.16b},v18.16b; \
    tbl     v17.16b,{v31.16b},v17.16b; \
    tbl     v16.16b,{v31.16b},v16.16b; \
\
    ldp     q12,q13,[mem_r,#64]; /* pre-load right-hand state parts */ \
    and     v16.16b,v0.16b,v16.16b; \
    and     v17.16b,v1.16b,v17.16b; \
    ldp     q14,q15,[mem_r,#96]; /* pre-load right-hand state parts */ \
    and     v18.16b,v2.16b,v18.16b; \
    and     v19.16b,v3.16b,v19.16b; \
\
    rol32_1_16(v19,v18,v17,v16,v28,v29,v30); \
\
    eor     v4.16b,v16.16b,v4.16b; \
    eor     v5.16b,v17.16b,v5.16b; \
    eor     v6.16b,v18.16b,v6.16b; \
    eor     v7.16b,v19.16b,v7.16b; \
    stp     q4,q5,[mem_l,#64]; \
    stp     q6,q7,[mem_l,#96]; \
\
	/* \
	 * t2 = krr; \
	 * t2 |= rr; \
	 * rl ^= t2; \
	 */ \
\
    lsr     x7,x6,#32; \
    eor     v19.16b,v19.16b,v19.16b; \
    ldp     q8,q9,[mem_r]; /* pre-load right-hand state parts */ \
    movi    v18.16b,#1; \
    fmov    s31,w7; \
    movi    v17.16b,#2; \
    movi    v16.16b,#3; \
    ldp     q10,q11,[mem_r,#32]; /* pre-load right-hand state parts */ \
    tbl     v19.16b,{v31.16b},v19.16b; \
    tbl     v18.16b,{v31.16b},v18.16b; \
    tbl     v17.16b,{v31.16b},v17.16b; \
    tbl     v16.16b,{v31.16b},v16.16b; \
\
    orr     v16.16b,v12.16b,v16.16b; \
    orr     v17.16b,v13.16b,v17.16b; \
    orr     v18.16b,v14.16b,v18.16b; \
    orr     v19.16b,v15.16b,v19.16b; \
\
    eor     v8.16b,v8.16b,v16.16b; \
    eor     v9.16b,v9.16b,v17.16b; \
    eor     v10.16b,v10.16b,v18.16b; \
    eor     v11.16b,v11.16b,v19.16b; \
\
    stp     q8,q9,[mem_r]; /*Note, updated values stay in v8-v11*/ \
    stp     q10,q11,[mem_r,#32];\
\
	/* \
	 * t2 = krl; \
	 * t2 &= rl; \
	 * rr ^= rol32(t2, 1); \
	 */ \
\
    eor     v19.16b,v19.16b,v19.16b; \
    movi    v18.16b,#1; \
    fmov    s31,w6; \
    movi    v17.16b,#2; \
    movi    v16.16b,#3; \
    tbl     v19.16b,{v31.16b},v19.16b; \
    tbl     v18.16b,{v31.16b},v18.16b; \
    tbl     v17.16b,{v31.16b},v17.16b; \
    tbl     v16.16b,{v31.16b},v16.16b; \
\
    and     v16.16b,v8.16b,v16.16b; /*Re-use updated right state values*/ \
    and     v17.16b,v9.16b,v17.16b; \
    and     v18.16b,v10.16b,v18.16b; \
    and     v19.16b,v11.16b,v19.16b; \
\
    rol32_1_16(v19,v18,v17,v16,v28,v29,v30); \
\
    eor     v12.16b,v16.16b,v12.16b; \
    eor     v13.16b,v17.16b,v13.16b; \
    eor     v14.16b,v18.16b,v14.16b; \
    eor     v15.16b,v19.16b,v15.16b; \
    stp     q12,q13,[mem_r,#64]; \
    stp     q14,q15,[mem_r,#96]; \
\
	/* \
	 * t0 = klr; \
	 * t0 |= lr; \
	 * ll ^= t0; \
	 */ \
\
    lsr     x7,x5,#32; \
    eor     v19.16b,v19.16b,v19.16b; \
    movi    v18.16b,#1; \
    fmov    s31,w7; \
    movi    v17.16b,#2; \
    movi    v16.16b,#3; \
    tbl     v19.16b,{v31.16b},v19.16b; \
    tbl     v18.16b,{v31.16b},v18.16b; \
    tbl     v17.16b,{v31.16b},v17.16b; \
    tbl     v16.16b,{v31.16b},v16.16b; \
\
    orr     v16.16b,v4.16b,v16.16b; \
    orr     v17.16b,v5.16b,v17.16b; \
    orr     v18.16b,v6.16b,v18.16b; \
    orr     v19.16b,v7.16b,v19.16b; \
\
    eor     v0.16b,v0.16b,v16.16b; \
    eor     v1.16b,v1.16b,v17.16b; \
    eor     v2.16b,v2.16b,v18.16b; \
    eor     v3.16b,v3.16b,v19.16b; \
\
    stp     q0,q1,[mem_l]; \
    stp     q2,q3,[mem_l,#32];\

#define transpose_4x4(v0, v1, v2, v3, t1, t2) \
    zip2    t2.4s,v0.4s,v1.4s; \
    zip1    v0.4s,v0.4s,v1.4s; \
\
    zip1    t1.4s,v2.4s,v3.4s; \
    zip2    v2.4s,v2.4s,v3.4s; \
\
    zip2    v1.2d,v0.2d,t1.2d; \
    zip1    v0.2d,v0.2d,t1.2d; \
\
    zip2    v3.2d,t2.2d,v2.2d; \
    zip1    v2.2d,t2.2d,v2.2d;

/* 
 * IN: 
 *  a0-a3, b0-b3, c0-c3, d0-d3 (vector registers)
 * OUT:
 *  a0-a3, b0-b3, c0-c3, d0-d3 (transposed, in registers)
 * Clobbers:
 *  t0 (v16), t1 (v17) (vector registers), tmp (GPR for constant address)
*/
#define byteslice_16x16b_fast(a0, b0, c0, d0, a1, b1, c1, d1, a2, b2, c2, d2, \
                                   a3, b3, c3, d3, t0, t1, tmp) \
    transpose_4x4(a0, a1, a2, a3, t0, t1); \
    transpose_4x4(b0, b1, b2, b3, t0, t1); \
\
    transpose_4x4(c0, c1, c2, c3, t0, t1); \
    transpose_4x4(d0, d1, d2, d3, t0, t1); \
\
    adrp    tmp,.Lshufb_16x16b; \
    add     tmp,tmp,:lo12:.Lshufb_16x16b; \
    ldr     q16,[tmp]; \
\
    tbl     a0.16b,{a0.16b},t0.16b; \
    tbl     a1.16b,{a1.16b},t0.16b; \
    tbl     a2.16b,{a2.16b},t0.16b; \
    tbl     a3.16b,{a3.16b},t0.16b; \
    tbl     b0.16b,{b0.16b},t0.16b; \
    tbl     b1.16b,{b1.16b},t0.16b; \
    tbl     b2.16b,{b2.16b},t0.16b; \
    tbl     b3.16b,{b3.16b},t0.16b; \
    tbl     c0.16b,{c0.16b},t0.16b; \
    tbl     c1.16b,{c1.16b},t0.16b; \
    tbl     c2.16b,{c2.16b},t0.16b; \
    tbl     c3.16b,{c3.16b},t0.16b; \
    tbl     d0.16b,{d0.16b},t0.16b; \
    tbl     d1.16b,{d1.16b},t0.16b; \
    tbl     d2.16b,{d2.16b},t0.16b; \
    tbl     d3.16b,{d3.16b},t0.16b; \
\
    transpose_4x4(a0, b0, c0, d0, t0, t1); \
    transpose_4x4(a1, b1, c1, d1, t0, t1); \
\
    transpose_4x4(a2, b2, c2, d2, t0, t1); \
    transpose_4x4(a3, b3, c3, d3, t0, t1);

/*
 * IN:
 *  key_ptr (GPR), rio_ptr (GPR)
 * OUT:
 *  v0-v15 (whitened plaintext)
 * Clobbers:
 *  tmp_key (v16, vector), tmp_gpr (GPR for addr), v17-v31
 */
#define inpack16_pre(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, \
                     rio_ptr, key_ptr, tmp_key, tmp_gpr) \
    /* Load and prepare key */ \
    ldr     tmp_gpr,[key_ptr]; \
    fmov    d16,tmp_gpr; \
    ldp     q18,q19,[rio_ptr]; /* Pre-load some input */ \
    adrp    tmp_gpr,.Lpack_bswap; \
    add     tmp_gpr,tmp_gpr,:lo12:.Lpack_bswap; \
    ldr     q17,[tmp_gpr]; /* Load constant into a temporary */ \
    ldp     q20,q21,[rio_ptr,#32]; /* Pre-load some more input */ \
    tbl     tmp_key.16b,{tmp_key.16b},v17.16b; \
    \
    /* Load plaintext blocks and XOR with key */ \
    ldp     q22,q23,[rio_ptr,#64]; \
    eor     v15.16b,v18.16b,tmp_key.16b; \
    eor     v14.16b,v19.16b,tmp_key.16b; \
    ldp     q24,q25,[rio_ptr,#96]; \
    eor     v13.16b,v20.16b,tmp_key.16b; \
    eor     v12.16b,v21.16b,tmp_key.16b; \
    ldp     q26,q27,[rio_ptr,#128]; \
    eor     v11.16b,v22.16b,tmp_key.16b; \
    eor     v10.16b,v23.16b,tmp_key.16b; \
    ldp     q28,q29,[rio_ptr,#160]; \
    eor     v9.16b,v24.16b,tmp_key.16b; \
    eor     v8.16b,v25.16b,tmp_key.16b; \
    ldp     q30,q31,[rio_ptr,#192]; \
    eor     v7.16b,v26.16b,tmp_key.16b; \
    eor     v6.16b,v27.16b,tmp_key.16b; \
    ldp     q18,q19,[rio_ptr,#224]; \
    eor     v5.16b,v28.16b,tmp_key.16b; \
    eor     v4.16b,v29.16b,tmp_key.16b; \
    eor     v3.16b,v30.16b,tmp_key.16b; \
    eor     v2.16b,v31.16b,tmp_key.16b; \
    eor     v1.16b,v18.16b,tmp_key.16b; \
    eor     v0.16b,v19.16b,tmp_key.16b;

/*
 * IN:
 *  v0-v15 (whitened plaintext)
 *  mem_ab, mem_cd (GPRs)
 * OUT:
 *  Writes byte-sliced state to memory buffers.
 * Clobbers:
 *  v0-v15 (become byte-sliced), st0, st1 (vector temps - v16,v17), tmp (GPR temp)
 */
#define inpack16_post(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, \
                            mem_ab, mem_cd, st0, st1, tmp) \
    /* Perform the byte-slice transpose in-place on v0-v15 */ \
    byteslice_16x16b_fast(v0, v1, v2, v3, v4, v5, v6, v7, \
                          v8, v9, v10, v11, v12, v13, v14, v15, \
                          st0, st1, tmp); \
    \
    /* Store the results */ \
    stp     q0,q1,[mem_ab]; \
    stp     q2,q3,[mem_ab,#32]; \
    stp     q4,q5,[mem_ab,#64]; \
    stp     q6,q7,[mem_ab,#96]; \
    stp     q8,q9,[mem_cd]; \
    stp     q10,q11,[mem_cd,#32]; \
    stp     q12,q13,[mem_cd,#64]; \
    stp     q14,q15,[mem_cd,#96];

/* 
 * IN:
 *  v0-v15 (byte-sliced ciphertext), key_ptr (GPR)
 * OUT:
 *  v0-v15 (block-oriented, whitened ciphertext)
 * Clobbers:
 *  tmp_v0, tmp_v1, tmp_key (vector temps - v16:v18),
 *  tmp_gpr (GPR temp)
 */
#define outunpack16(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, \
                          key_ptr, tmp_v0, tmp_v1, tmp_key, tmp_gpr) \
    /* Perform inverse byte-slice (transpose) in-place */ \
    byteslice_16x16b_fast(v8, v12, v0, v4, v9, v13, v1, v5, v10, v14, v2, v6, \
                               v11, v15, v3, v7, \
                               tmp_v0, tmp_v1, tmp_gpr); \
    \
    /* Load and prepare final key */ \
    ldr     tmp_gpr,[key_ptr]; \
    fmov    d18,tmp_gpr; \
    adrp    tmp_gpr,.Lpack_bswap; \
    add     tmp_gpr,tmp_gpr,:lo12:.Lpack_bswap; \
    ldr     q16,[tmp_gpr]; /* Load constant into a temporary */ \
    tbl     tmp_key.16b,{tmp_key.16b},tmp_v0.16b; \
    \
    /* XOR with final key */ \
    eor     v0.16b,v0.16b,tmp_key.16b; \
    eor     v1.16b,v1.16b,tmp_key.16b; \
    eor     v2.16b,v2.16b,tmp_key.16b; \
    eor     v3.16b,v3.16b,tmp_key.16b; \
    eor     v4.16b,v4.16b,tmp_key.16b; \
    eor     v5.16b,v5.16b,tmp_key.16b; \
    eor     v6.16b,v6.16b,tmp_key.16b; \
    eor     v7.16b,v7.16b,tmp_key.16b; \
    eor     v8.16b,v8.16b,tmp_key.16b; \
    eor     v9.16b,v9.16b,tmp_key.16b; \
    eor     v10.16b,v10.16b,tmp_key.16b; \
    eor     v11.16b,v11.16b,tmp_key.16b; \
    eor     v12.16b,v12.16b,tmp_key.16b; \
    eor     v13.16b,v13.16b,tmp_key.16b; \
    eor     v14.16b,v14.16b,tmp_key.16b; \
    eor     v15.16b,v15.16b,tmp_key.16b;

/*
 * Inputs:
 *  v0-v15 (final block-oriented ciphertext), rio_ptr (GPR)
 */
#define write_output(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, rio_ptr) \
    stp     q7,q6,[rio_ptr]; \
    stp     q5,q4,[rio_ptr,#32]; \
    stp     q3,q2,[rio_ptr,#64]; \
    stp     q1,q0,[rio_ptr,#96]; \
    stp     q15,q14,[rio_ptr,#128]; \
    stp     q13,q12,[rio_ptr,#160]; \
    stp     q11,q10,[rio_ptr,#192]; \
    stp     q9,q8,[rio_ptr,#224];

/**********************************************************************
  Constants
 **********************************************************************/
.section .rodata
.type   camellia_neon_consts,%object
.align  7
camellia_neon_consts:
// === Constants for Encryption rounds ===
.Lpre_tf_lo_s1:
    .byte 0x45, 0xe8, 0x40, 0xed, 0x2e, 0x83, 0x2b, 0x86
    .byte 0x4b, 0xe6, 0x4e, 0xe3, 0x20, 0x8d, 0x25, 0x88
.Lpre_tf_hi_s1:
    .byte 0x00, 0x51, 0xf1, 0xa0, 0x8a, 0xdb, 0x7b, 0x2a
    .byte 0x09, 0x58, 0xf8, 0xa9, 0x83, 0xd2, 0x72, 0x23
.Lpre_tf_lo_s4:
    .byte 0x45, 0x40, 0x2e, 0x2b, 0x4b, 0x4e, 0x20, 0x25
    .byte 0x14, 0x11, 0x7f, 0x7a, 0x1a, 0x1f, 0x71, 0x74
.Lpre_tf_hi_s4:
    .byte 0x00, 0xf1, 0x8a, 0x7b, 0x09, 0xf8, 0x83, 0x72
    .byte 0xad, 0x5c, 0x27, 0xd6, 0xa4, 0x55, 0x2e, 0xdf
.Lpost_tf_lo_s1:
    .byte 0x3c, 0xcc, 0xcf, 0x3f, 0x32, 0xc2, 0xc1, 0x31
    .byte 0xdc, 0x2c, 0x2f, 0xdf, 0xd2, 0x22, 0x21, 0xd1
.Lpost_tf_hi_s1:
    .byte 0x00, 0xf9, 0x86, 0x7f, 0xd7, 0x2e, 0x51, 0xa8
    .byte 0xa4, 0x5d, 0x22, 0xdb, 0x73, 0x8a, 0xf5, 0x0c
.Lpost_tf_lo_s2:
    .byte 0x78, 0x99, 0x9f, 0x7e, 0x64, 0x85, 0x83, 0x62
    .byte 0xb9, 0x58, 0x5e, 0xbf, 0xa5, 0x44, 0x42, 0xa3
.Lpost_tf_hi_s2:
    .byte 0x00, 0xf3, 0x0d, 0xfe, 0xaf, 0x5c, 0xa2, 0x51
    .byte 0x49, 0xba, 0x44, 0xb7, 0xe6, 0x15, 0xeb, 0x18
.Lpost_tf_lo_s3:
    .byte 0x1e, 0x66, 0xe7, 0x9f, 0x19, 0x61, 0xe0, 0x98
    .byte 0x6e, 0x16, 0x97, 0xef, 0x69, 0x11, 0x90, 0xe8
.Lpost_tf_hi_s3:
    .byte 0x00, 0xfc, 0x43, 0xbf, 0xeb, 0x17, 0xa8, 0x54
    .byte 0x52, 0xae, 0x11, 0xed, 0xb9, 0x45, 0xfa, 0x06
.Linv_shift_row:
    .byte 0x00, 0x0d, 0x0a, 0x07, 0x04, 0x01, 0x0e, 0x0b
    .byte 0x08, 0x05, 0x02, 0x0f, 0x0c, 0x09, 0x06, 0x03
.Lmask_0f:
    .quad 0x0f0f0f0f0f0f0f0f, 0x0f0f0f0f0f0f0f0f
.Lpack_bswap:
    .byte   3, 2, 1, 0, 7, 6, 5, 4, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80
.Lshufb_16x16b:
    .byte   0, 4, 8, 12, 1, 5, 9, 13, 2, 6, 10, 14, 3, 7, 11, 15
// === byteswap mask ===
.Lbswap128_mask:
	.byte 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0
// === Constants for Key Schedule F-function ===
.Lsbox4_input_mask:
    // Selects bytes 1, 4 for input rotation (sbox4) within the 64-bit input
	.byte 0x00, 0xff, 0x00, 0x00, 0xff, 0x00, 0x00, 0x00;
.Linv_shift_row_and_unpcklbw:
    // Special shuffle mask used in key schedule's F-function (different from main rounds)
    .byte   0x00, 0xff, 0x0d, 0xff, 0x0a, 0xff, 0x07, 0xff
    .byte   0x04, 0xff, 0x01, 0xff, 0x0e, 0xff, 0x0b, 0xff
.Lsp0044440444044404mask:
    // Shuffle mask for combining results (part 1)
    .long   0xffff0404, 0x0404ff04
    .long   0x0d0dff0d, 0x0d0dff0d
.Lsp1110111010011110mask:
    // Shuffle mask for combining results (part 2)
    .long   0x000000ff, 0x000000ff
    .long   0x0bffff0b, 0x0b0b0bff
.Lsp0222022222000222mask:
    // Shuffle mask for combining results (part 3 - related to SBOX2 rotate)
    .long   0xff060606, 0xff060606
    .long   0x0c0cffff, 0xff0c0c0c
.Lsp3033303303303033mask:
    // Shuffle mask for combining results (part 4 - related to SBOX3 rotate)
    .long   0x04ff0404, 0x04ff0404
    .long   0xff0a0aff, 0x0aff0a0a
// === Sigmas for key setup ===
.Lsigma1:
	.long 0x3BCC908B, 0xA09E667F;
.Lsigma2:
	.long 0x4CAA73B2, 0xB67AE858;
.Lsigma3:
	.long 0xE94F82BE, 0xC6EF372F;
.Lsigma4:
	.long 0xF1D36F1C, 0x54FF53A5;
.Lsigma5:
	.long 0xDE682D1D, 0x10E527FA;
.Lsigma6:
	.long 0xB3E6C1FD, 0xB05688C2;
.size   camellia_neon_consts,.-camellia_neon_consts
.previous

/**********************************************************************
  16-way camellia main routines
 **********************************************************************/
.globl  camellia_encrypt_16blks_simd128
.type   camellia_encrypt_16blks_simd128,%function
.align  5
camellia_encrypt_16blks_simd128:
    // === PROLOGUE ===
    stp     x29,x30,[sp,#-144]!
    mov     x29,sp
    
    stp     q8,q9,[sp,#16]
    stp     q10,q11,[sp,#48]
    stp     q12,q13,[sp,#80]
    stp     q14,q15,[sp,#112]

    // === SETUP ===
    // Determine lastk
    ldr     w9,[x0,#272]
    mov     w8,#32
    mov     w10,#24
    cmp     w9,#16
    csel    w8,w10,w8,le         // x8 -> lastk: if key_length <= 16 then 24, else - 32 

    // === INPUT PROCESSING ===
    // Call inpack16_pre: reads vin(x2), key[0](=ctx_ptr: x0), writes v0-v15
    // clobbers: v16-v31 and x4
    inpack16_pre(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, \
                 x2, x0, v16, x4)

    // Set up temp buffer pointers using vout_ptr (x1)
    mov     x10,x1          // x10 -> vout
    add     x11,x1,#128     // x11 -> vout + 128

    // Call inpack16_post: byte-slices v0-v15, stores to mem_ab(x10), mem_cd(x11)
    // Clobbers: v16, v17 and x4
    inpack16_post(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, \
                  x10, x11, v16, v17, x4)

    // Load Constants into v16-v27
    adrp    x15,camellia_neon_consts
    add     x15,x15,:lo12:camellia_neon_consts
    ldp     q18,q19,[x15],#32    // pre_tf_lo/hi_s1
    ldp     q20,q21,[x15],#32    // pre_tf_lo/hi_s4
    ldp     q22,q23,[x15],#32    // post_tf_lo/hi_s1
    ldp     q24,q25,[x15],#32    // post_tf_lo/hi_s2
    ldp     q26,q27,[x15],#32    // post_tf_lo/hi_s3
    ldr     q17,[x15],#16        // inv_shift_row
    ldr     q16,[x15],#-176        // mask_0f

    // === MAIN ROUND LOOP ===
    mov     x12,#0      // x12 -> k = 0
    sub     x14,x8,#8   // x14 -> lastk - 8
.Lenc_loop:
    // Calculate base key pointer for this block: &key_table[k]
    lsl     x13,x12,#3  // x13 -> key_base_idx = k * 8
    add     x13,x0,x13  // x13 = &key_table[k] - assuming here key_table_base = ctx[0] -> x0

    // Round 1 (keys k+2, k+3)
    add     x4,x13,#16  // &key_table[k+2]
    two_roundsm16(v0,v1,v2,v3,v4,v5,v6,v7,x10,x11,x4,store_ab_state)

    // Round 2 (keys k+4, k+5)
    add     x4,x13,#32  // &key_table[k+4]
    two_roundsm16(v0,v1,v2,v3,v4,v5,v6,v7,x10,x11,x4,store_ab_state)

    // Round 3 (keys k+6, k+7)
    add     x4,x13,#48  // &key_table[k+6]
    two_roundsm16(v0,v1,v2,v3,v4,v5,v6,v7,x10,x11,x4,dummy_store)

    // Check loop condition
    cmp     x12,x14
    b.eq    .Lenc_done

    // x4 -> key pointer: &key_table[k+8]
    add     x4,x13,#64
    add     x3,x13,#72
    fls16(v0, v1, v2, v3, v4, v5, v6, v7, x10, x11, x4, x3) // uses x5-x7 and v16-v19 as clobbers

    // Increment k
    add     x12,x12,#8

    ldp     q18,q19,[x15],#160    // pre_tf_lo/hi_s1
    ldr     q17,[x15],#16           // inv_shift_row
    ldr     q16,[x15],#-176        // mask_0f
    b       .Lenc_loop

.Lenc_done:
    // Load final CD state from mem_cd(x11) into v8-v15
    ldp     q8,q9,[x11]
    ldp     q10,q11,[x11,#32]
    ldp     q12,q13,[x11,#64]
    ldp     q14,q15,[x11,#96]

    // Calculate final key pointer: &key_table[lastk] (lastk is in x8)
    lsl     x4,x8,#3    // lastk * 8
    add     x4,x0,x4    // &key_table[lastk]

    // Call outunpack16: Operates in-place on v0-v15
    outunpack16(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, \
                x4, v16, v17, v18, x5)

    write_output(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, x1)

    // === EPILOGUE ===
    ldp     q8,q9,[sp,#16]
    ldp     q10,q11,[sp,#48]
    ldp     q12,q13,[sp,#80]
    ldp     q14,q15,[sp,#112]

    ldp     x29,x30,[sp],#144
    ret
.size   camellia_encrypt_16blks_simd128,.-camellia_encrypt_16blks_simd128

.globl  camellia_decrypt_16blks_simd128
.type   camellia_decrypt_16blks_simd128,%function
.align  5
camellia_decrypt_16blks_simd128:
    // === PROLOGUE ===
    stp     x29,x30,[sp,#-144]!
    mov     x29,sp
    
    stp     q8,q9,[sp,#16]
    stp     q10,q11,[sp,#48]
    stp     q12,q13,[sp,#80]
    stp     q14,q15,[sp,#112]

    // === SETUP ===
    // Determine lastk
    ldr     w9,[x0,#272]
    mov     w8,#32
    mov     w10,#24
    cmp     w9,#16
    csel    w8,w10,w8,le         // x8 -> lastk: if key_length <= 16 then 24, else - 32 

    // === INPUT PROCESSING ===
    // Call inpack16_pre: reads vin(x2), key[0](=ctx_ptr: x0), writes v0-v15
    // clobbers: v16-v31 and x5
    lsl     x4,x8,#3
    add     x4,x0,x4
    inpack16_pre(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, \
                 x2, x4, v16, x5)

    // Set up temp buffer pointers using vout_ptr (x1)
    mov     x10,x1          // x10 -> vout
    add     x11,x1,#128     // x11 -> vout + 128

    // Call inpack16_post: byte-slices v0-v15, stores to mem_ab(x10), mem_cd(x11)
    // Clobbers: v16, v17 and x4
    inpack16_post(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, \
                  x10, x11, v16, v17, x4)

    // Load Constants into v16-v27
    adrp    x15,camellia_neon_consts
    add     x15,x15,:lo12:camellia_neon_consts
    ldp     q18,q19,[x15],#32    // pre_tf_lo/hi_s1
    ldp     q20,q21,[x15],#32    // pre_tf_lo/hi_s4
    ldp     q22,q23,[x15],#32    // post_tf_lo/hi_s1
    ldp     q24,q25,[x15],#32    // post_tf_lo/hi_s2
    ldp     q26,q27,[x15],#32    // post_tf_lo/hi_s3
    ldr     q17,[x15],#16        // inv_shift_row
    ldr     q16,[x15],#-176        // mask_0f

    // === MAIN ROUND LOOP ===
    sub     x12,x8,#8   // x14 -> lastk - 8
.Ldec_loop:
    // Calculate base key pointer for this block: &key_table[k]
    lsl     x13,x12,#3  // x13 -> key_base_idx = k * 8
    add     x13,x0,x13  // x13 = &key_table[k] - assuming here key_table_base = ctx[0] -> x0

    // Round 1 (keys k+6, k+7)
    add     x4,x13,#56  // &key_table[k+7]
    two_roundsm16_dec(v0,v1,v2,v3,v4,v5,v6,v7,x10,x11,x4,store_ab_state)

    // Round 2 (keys k+4, k+5)
    add     x4,x13,#40  // &key_table[k+5]
    two_roundsm16_dec(v0,v1,v2,v3,v4,v5,v6,v7,x10,x11,x4,store_ab_state)

    // Round 3 (keys k+2, k+3)
    add     x4,x13,#24  // &key_table[k+3]
    two_roundsm16_dec(v0,v1,v2,v3,v4,v5,v6,v7,x10,x11,x4,dummy_store)

    // Check loop condition
    //cmp     x12,x14
    cbz     x12,.Ldec_done

    // x4 -> key pointer: &key_table[k+8]
    add     x3,x13,#0
    add     x4,x13,#8
    fls16(v0, v1, v2, v3, v4, v5, v6, v7, x10, x11, x4, x3) // uses x5-x7 and v16-v19 as clobbers

    // Decrement k
    sub     x12,x12,#8

    ldp     q18,q19,[x15],#160    // pre_tf_lo/hi_s1
    ldr     q17,[x15],#16           // inv_shift_row
    ldr     q16,[x15],#-176        // mask_0f
    b       .Ldec_loop

.Ldec_done:
    // Load final CD state from mem_cd(x11) into v8-v15
    ldp     q8,q9,[x11]
    ldp     q10,q11,[x11,#32]
    ldp     q12,q13,[x11,#64]
    ldp     q14,q15,[x11,#96]

    // Calculate final key pointer: &key_table[lastk] (lastk is in x8)
    //lsl     x4,x8,#3    // lastk * 8
    //add     x4,x0,x4    // &key_table[lastk]

    // Call outunpack16: Operates in-place on v0-v15
    outunpack16(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, \
                x0, v16, v17, v18, x5)

    write_output(v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, x1)

    // === EPILOGUE ===
    ldp     q8,q9,[sp,#16]
    ldp     q10,q11,[sp,#48]
    ldp     q12,q13,[sp,#80]
    ldp     q14,q15,[sp,#112]

    ldp     x29,x30,[sp],#144
    ret
.size   camellia_decrypt_16blks_simd128,.-camellia_decrypt_16blks_simd128

/**********************************************************************
  "Optimised" key setup
 **********************************************************************/

// Neon macro for Camellia F-function (key schedule variant)
// Inputs:
//  v_ab:            Input vector register name (e.g., v2 or v3)
//  v_x:             Output/Working vector register name (e.g., v1 to v5)
//  v_t0 - v_t4:     Temporary vector register names (v6-v10)
//  inv_shift_row:  v17
//  sbox4mask:      v18
//  _0f0f0f0fmask:  v19
//  pre_s1lo_mask:  v20
//  pre_s1hi_mask:  v21
//  post_s1lo_mask: v22
//  post_s1hi_mask: v23
//  sp0044:         v24
//  sp1110:         v25
//  sp0222:         v26
//  sp3033:         v27
//  key:       GPR name holding key address (e.g., x1)
//  x_tmp:  Temporary GPR (e.g., x5)
// Output:
//   Lower 64 bits of v_x contain the result.
#define camellia_f(v_ab, v_x, v_t0, v_t1, v_t2, v_t3, v_t4, v_zero, \
                    inv_shift_row, sbox4mask, _0f0f0f0fmask, pre_s1lo_mask, pre_s1hi_mask, \
                    post_s1lo_mask, post_s1hi_mask, sp0044, sp1110, sp0222, sp3033, key, x_tmp) \
    ldr     x_tmp,[key]; \
    fmov    d6,x_tmp; /*referring to v_t0 (v6) as d6*/ \
\
    /* x = ab ^ key */ \
    eor     v_x.16b,v_ab.16b,v_t0.16b; \
\
	/* \
	 * S-function with AES subbytes \
	 */ \
\
    /* Apply input rotation for sbox4 */ \
    and     v_t0.16b,v_x.16b,sbox4mask.16b; \
    bic     v_x.16b,v_x.16b, sbox4mask.16b; \
    add     v_t1.16b,v_t0.16b,v_t0.16b; \
    ushr    v_t0.16b,v_t0.16b,#7; \
    orr     v_t0.16b,v_t0.16b,v_t1.16b; \
    and     v_t0.16b,v_t0.16b,sbox4mask.16b; \
    orr     v_x.16b,v_x.16b,v_t0.16b; \
\
    /* Prefilter sboxes */ \
    filter_8bit_neon(v_x, pre_s1lo_mask, pre_s1hi_mask, _0f0f0f0fmask, v_t2); \
\
    /* AES subbytes + AES shift rows */ \
    aese    v_x.16b,v_zero.16b; \
\
    /* Postfilter sboxes */ \
    filter_8bit_neon(v_x, post_s1lo_mask, post_s1hi_mask, _0f0f0f0fmask, v_t2); \
\
    tbl     v_t1.16b,{v_x.16b},inv_shift_row.16b; \
    tbl     v_t4.16b,{v_x.16b},sp0044.16b; \
    tbl     v_x.16b,{v_x.16b},sp1110.16b; \
    add     v_t2.16b,v_t1.16b,v_t1.16b; \
    ushr    v_t0.16b,v_t1.16b,#7; \
    shl     v_t3.16b,v_t1.16b,#7; \
    orr     v_t0.16b,v_t0.16b,v_t2.16b; \
    ushr    v_t1.16b,v_t1.16b,#1; \
    tbl     v_t0.16b,{v_t0.16b},sp0222.16b; \
    orr     v_t1.16b,v_t1.16b,v_t3.16b; \
\
    eor     v_t4.16b,v_x.16b,v_t4.16b; \
    tbl     v_t1.16b,{v_t1.16b},sp3033.16b; \
    eor     v_t0.16b,v_t0.16b,v_t4.16b; \
    eor     v_t0.16b,v_t0.16b,v_t1.16b; \
\
    ext     v_x.16b,v_t0.16b,v_zero.16b,#8; \
    eor     v_x.16b,v_t0.16b,v_x.16b;

#define vec_rol128(in, out, nrol, t0) \
    ext     out.16b,in.16b,in.16b,#8; \
    shl     t0.2d,in.2d,#(nrol); \
    ushr    out.2d,out.2d,#(64-(nrol)); \
    add     out.16b,out.16b,t0.16b;

#define vec_ror128(in, out, nror, t0) \
    ext     out.16b,in.16b,in.16b,#8; \
    ushr    t0.2d,in.2d,#(nror); \
    shl     out.2d,out.2d,#(64-(nror)); \
    add     out.16b,out.16b,t0.16b;

#define CTX x0              // Context pointer passed in x0
#define KL128 v0            // Input key in v0
#define KA128 v2            // Intermediate key KA generated in v2
#define KEY_TABLE_BASE 0    // Offset of key_table within CTX struct

// Helper macro to get subkey address
#define cmll_sub_addr(n, ctx_reg, tmp_reg) \
    add     tmp_reg,ctx_reg,#((n) * 8 + KEY_TABLE_BASE); \

.text
.globl  __camellia_setup128_neon
.type   __camellia_setup128_neon,%function
.align  5
__camellia_setup128_neon:
    stp     x29,x30,[sp,#-144]!
    mov     x29,sp
    stp     q8,q9,[sp,#16]
    stp     q10,q11,[sp,#48]
    stp     q12,q13,[sp,#80]
    stp     q14,q15,[sp,#112]

    // === CONSTANT LOADING ===
    // Load constants needed for camellia_f into v17-v27 + v16(bswap)
    adrp    x1,camellia_neon_consts
    add     x1,x1,:lo12:camellia_neon_consts
    ldp     q20,q21,[x1],#64    // pre_tf_lo/hi_s1
    ldp     q22,q23,[x1],#112   // post_tf_lo/hi_s1
    ldr     q19,[x1],#48        //mask_0f
    ldr     q16,[x1],#16        //bswap128
    ldr     d18,[x1],#8         //sbox4_input_mask
    ldr     q17,[x1],#16        //inv_shift_row_and_unpcklbw
    ldp     q24,q25,[x1],#32    //sp0044/sp1110
    ldp     q26,q27,[x1],#32    //sp0222/sp3033

    // Prepare zero vector
    eor     v31.16b,v31.16b,v31.16b
    
    // === INITIAL KEY HANDLING ===
    // Byte swap input key KL128 (v0) using v16
    tbl     KL128.16b,{KL128.16b},v16.16b
    
    // === GENERATE KA (into v2) ===
    // Split KL128 into halves (KL_R in v2 lower, KL_L in v3 lower)
    ext     v2.16b,KL128.16b,v31.16b,#8
    mov     v3.d[0],KL128.d[0]
    mov     v3.d[1],xzr

    // Get addresses of sigma constants
    adrp    x1,.Lsigma1
    add     x1,x1,:lo12:.Lsigma1 // x1 -> sigma1
    add     x2,x1,#8             // x2 -> sigma2
    add     x3,x1,#16            // x3 -> sigma3
    add     x4,x1,#24            // x4 -> sigma4

    // F(KL_R, sigma1) -> v4
    camellia_f(v2,v4,v6,v7,v8,v9,v10,v31,v17,v18,v19,v20,v21,v22,v23,v24,v25,v26,v27,x1,x5)
    eor     v3.16b,v3.16b,v4.16b       // KL_L ^= F(...)
    // F(KL_L, sigma2) -> v2
    camellia_f(v3,v2,v6,v7,v8,v9,v10,v31,v17,v18,v19,v20,v21,v22,v23,v24,v25,v26,v27,x2,x5)
    // v2 now holds KA_R' (in lower 64 bits)
    // F(KA_R', sigma3) -> v3
    camellia_f(v2,v3,v6,v7,v8,v9,v10,v31,v17,v18,v19,v20,v21,v22,v23,v24,v25,v26,v27,x3,x5)
    // v3 now holds KA_L' (in lower 64 bits)
    eor     v3.16b,v3.16b,v4.16b       // intermediate needed for next step
    // F(KA_L', sigma4) -> v4
    camellia_f(v3,v4,v6,v7,v8,v9,v10,v31,v17,v18,v19,v20,v21,v22,v23,v24,v25,v26,v27,x4,x5)

    // Combine KA_L'(v3) and KA_R'(v2 ^ v4) into KA128 (v2)
    eor     v1.16b,v2.16b,v4.16b        // KA_R' ^= T4
    mov     KA128.d[0],v3.d[0]        // v2 lower lane = v3 lower lane (KA_L')
    mov     KA128.d[1],v1.d[0]        // v2 upper lane = v1 lower lane (KA_R'^T4)

    // === GENERATE ROTATED SUBKEYS ===
    cmll_sub_addr(24, CTX, x1)     // Get address for subkey 24
    str     q2,[x1]                // Store KA128 early - TODO: do I need to?

    vec_rol128(KL128, v3, 15, v15)     // v3 = KL <<< 15
    vec_rol128(KA128, v4, 15, v15)     // v4 = KA <<< 15
    vec_rol128(KA128, v5, 30, v15)     // v5 = KA <<< 30
    vec_rol128(KL128, v6, 45, v15)     // v6 = KL <<< 45
    vec_rol128(KA128, v7, 45, v15)     // v7 = KA <<< 45
    vec_rol128(KL128, v8, 60, v15)     // v8 = KL <<< 60
    vec_rol128(KA128, v9, 60, v15)     // v9 = KA <<< 60
    vec_ror128(KL128, v10, 51, v15)    // v10 = KL >>> 51 (ror 128-77=51)

    // === ABSORB KW2 ===
    // Calculate kw2 (upper 64 of KL128) into v15
    mov     v15.d[0], KL128.d[0]
    mov     v15.d[1], xzr
    // XOR kw2 into intermediates
    eor     KA128.16b,KA128.16b,v15.16b    // KA128 ^= kw2
    eor     v3.16b,v3.16b,v15.16b          // v3 ^= kw2
    eor     v4.16b,v4.16b,v15.16b          // v4 ^= kw2

    // subl(1) ^= subr(1) & ~subr(9)
    bic     v13.16b,v15.16b,v5.16b
    ext     v11.16b,v31.16b,v13.16b,#4
    ext     v13.16b,v11.16b,v11.16b,#8  // because all other elements are zero anyway
    eor     v15.16b,v15.16b,v13.16b
    // dw = subl(1) & subl(9), subr(1) ^= CAMELLIA_RL1(dw);
    and     v14.16b,v15.16b,v5.16b   // v14 = v15 & v5 (dw = subl(1) & subl(9))
    shl     v11.4s,v14.4s,#1
    ushr    v14.4s,v14.4s,#31
    add     v14.16b,v11.16b,v14.16b
    ext     v14.16b,v31.16b,v14.16b,#8
    ext     v14.16b,v14.16b,v31.16b,#12
    eor     v15.16b,v14.16b,v15.16b

    // XOR final absorb value (v15) into subkeys
    eor     v6.16b,v6.16b,v15.16b
    eor     v8.16b,v8.16b,v15.16b
    eor     v9.16b,v9.16b,v15.16b

    // subl(1) ^= subr(1) & ~subr(17) (v10 = KL>>>51)
    bic     v13.16b,v15.16b,v10.16b  // v13 = v10 & ~v15
    ext     v11.16b,v31.16b,v13.16b,#4
    ext     v13.16b,v11.16b,v11.16b,#8
    eor     v15.16b,v15.16b,v13.16b
    // dw = subl(1) & subl(17), subr(1) ^= CAMELLIA_RL1(dw);
    and     v14.16b,v15.16b,v10.16b
    shl     v11.4s,v14.4s,#1
    ushr    v14.4s,v14.4s,#31
    add     v14.16b,v11.16b,v14.16b
    ext     v14.16b,v31.16b,v14.16b,#8
    ext     v14.16b,v14.16b,v31.16b,#12
    eor     v15.16b,v14.16b,v15.16b

    ext     v11.16b,KL128.16b,KL128.16b,#8
    rev64   KL128.4s,v11.4s
    ext     v12.16b,KA128.16b,KA128.16b,#8
    rev64   KA128.4s,v12.4s
    ext     v13.16b,v3.16b,v3.16b,#8
    rev64   v3.4s,v13.4s
    ext     v14.16b,v4.16b,v4.16b,#8
    rev64   v4.4s,v14.4s
    ext     v11.16b,v5.16b,v5.16b,#8
    rev64   v5.4s,v11.4s
    ext     v12.16b,v6.16b,v6.16b,#8
    rev64   v6.4s,v12.4s
    ext     v13.16b,v7.16b,v7.16b,#8
    rev64   v7.4s,v13.4s
    ext     v14.16b,v8.16b,v8.16b,#8
    rev64   v8.4s,v14.4s
    ext     v11.16b,v9.16b,v9.16b,#8
    rev64   v9.4s,v11.4s
    ext     v12.16b,v10.16b,v10.16b,#8
    rev64   v10.4s, v12.4s

    cmll_sub_addr(0, CTX, x1)
    str     q0,[x1]   //KL128
    ext     v13.16b,KL128.16b,KL128.16b,#8
    rev64   KL128.4s,v13.4s // Reverse back KL for later use

    cmll_sub_addr(2, CTX, x1)
    str     q2,[x1];    //KA128
    cmll_sub_addr(4, CTX, x2)
    str     q3,[x2];
    cmll_sub_addr(6, CTX, x3)
    str     q4,[x3]
    cmll_sub_addr(8, CTX, x4)
    str     q5,[x4]
    cmll_sub_addr(10, CTX, x5)
    str     q6,[x5]

    ext     v8.16b,v8.16b,v31.16b,#8
    cmll_sub_addr(12, CTX, x1)
    str     d7,[x1]
    cmll_sub_addr(13, CTX, x2)
    str     d8,[x2]
    cmll_sub_addr(14, CTX, x3)
    str     q9,[x3]
    cmll_sub_addr(16, CTX, x4)
    str     q10,[x4]

    cmll_sub_addr(24, CTX, x1)
    ldr q2,[x1]

    // Calculate rotated keys needed (note: KL128 and KA128 were reversed back above)
    vec_ror128(KL128, v3, 34, v7) // v3 = KL >>> 34 (ror 128-94)
    vec_ror128(KA128, v4, 34, v7) // v4 = KA >>> 34
    vec_ror128(KL128, v5, 17, v7) // v5 = KL >>> 17 (ror 128-111)
    vec_ror128(KA128, v6, 17, v7) // v6 = KA >>> 17

    eor     v3.16b,v3.16b,v15.16b
    eor     v4.16b,v4.16b,v15.16b
    eor     v5.16b,v5.16b,v15.16b
    ext     v15.16b,v31.16b,v15.16b,#8
    eor     v6.16b,v6.16b,v15.16b

    // Absorb kw4 into other subkeys
    ext     v15.16b,v31.16b,v6.16b,#8
    eor     v5.16b,v5.16b,v15.16b
    eor     v4.16b,v4.16b,v15.16b
    eor     v3.16b,v3.16b,v15.16b

    // subl(25) ^= subr(25) & ~subr(16)
    cmll_sub_addr(16, CTX, x1);
    ldr     q10,[x1]
    ext     v11.16b,v10.16b,v10.16b,#8
    rev64   v10.4s,v11.4s

    bic     v13.16b,v15.16b,v10.16b
    ext     v13.16b,v31.16b,v13.16b, #12
    eor     v15.16b,v15.16b,v13.16b

    // dw = subl(25) & subl(16), subr(25) ^= CAMELLIA_RL1(dw);
    and     v14.16b,v15.16b,v10.16b // v14 = v15 & v10 (dw)
    shl     v11.4s,v14.4s,#1
    ushr    v14.4s,v14.4s,#31
    add     v14.16b,v11.16b,v14.16b
    ext     v14.16b,v14.16b, v31.16b, #12
    ext     v14.16b,v31.16b, v14.16b, #8;
    eor     v15.16b,v14.16b, v15.16b; // v15 ^= rotated RL1(dw)

    ext     v11.16b,v3.16b,v3.16b,#8
    rev64   v3.4s,v11.4s
    ext     v12.16b,v4.16b,v4.16b,#8
    rev64   v4.4s,v12.4s
    ext     v13.16b,v5.16b,v5.16b,#8
    rev64   v5.4s,v13.4s
    ext     v14.16b,v6.16b,v6.16b,#8
    rev64   v6.4s,v14.4s

    cmll_sub_addr(18, CTX, x1)
    str     q3,[x1]
    cmll_sub_addr(20, CTX, x2)
    str     q4,[x2]
    cmll_sub_addr(22, CTX, x3)
    str     q5,[x3]
    cmll_sub_addr(24, CTX, x4)
    str     q6,[x4]

    cmll_sub_addr(14, CTX, x1)
    ldr     q3,[x1]
    ext     v11.16b,v3.16b,v3.16b,#8
    rev64   v3.4s,v11.4s
    cmll_sub_addr(12, CTX, x2)
    ldr     q4,[x2]
    ext     v12.16b,v4.16b,v4.16b,#8
    rev64   v4.4s,v12.4s
    cmll_sub_addr(10, CTX, x3)
    ldr     q5,[x3]
    ext     v13.16b,v5.16b,v5.16b,#8
    rev64   v5.4s,v13.4s
    cmll_sub_addr(8, CTX, x4)
    ldr     q6,[x4]
    ext     v14.16b,v6.16b,v6.16b,#8
    rev64   v6.4s,v14.4s

    eor     v3.16b,v3.16b,v15.16b
    eor     v4.16b,v4.16b,v15.16b
    eor     v5.16b,v5.16b,v15.16b

    // subl(25) ^= subr(25) & ~subr(8)
    bic     v13.16b,v15.16b,v6.16b // v13 = v6 & ~v15
    ext     v13.16b,v31.16b,v13.16b,#12
    eor     v15.16b,v13.16b,v15.16b
    // dw = subl(25) & subl(8), subr(25) ^= CAMELLIA_RL1(dw);
    and     v14.16b,v15.16b,v6.16b; // v14 = v15 & v6 (dw)
    shl     v11.4s,v14.4s,#1
    ushr    v14.4s,v14.4s,#31
    add     v14.16b,v11.16b,v14.16b
    ext     v14.16b,v14.16b,v31.16b,#12
    ext     v14.16b,v31.16b,v14.16b,#8;
    eor     v15.16b,v14.16b,v15.16b; // v15 ^= rotated RL1(dw)

    ext     v11.16b,v3.16b,v3.16b,#8
    rev64   v3.4s,v11.4s
    ext     v12.16b,v4.16b,v4.16b,#8
    rev64   v4.4s,v12.4s
    ext     v13.16b,v5.16b,v5.16b,#8
    rev64   v5.4s,v13.4s

    cmll_sub_addr(14, CTX, x1)
    str     q3,[x1]
    cmll_sub_addr(12, CTX, x2)
    str     q4,[x2];
    cmll_sub_addr(10, CTX, x3)
    str     q5,[x3];

    cmll_sub_addr(6, CTX, x1)
    ldr     q6,[x1]
    ext     v11.16b,v6.16b,v6.16b,#8
    rev64   v6.4s,v11.4s
    cmll_sub_addr(4, CTX, x2)
    ldr     q4,[x2]
    ext     v12.16b,v4.16b,v4.16b,#8
    rev64   v4.4s,v12.4s
    cmll_sub_addr(2, CTX, x3)
    ldr     q2,[x3]
    ext     v13.16b,v2.16b,v2.16b,#8
    rev64   v2.4s,v13.4s
    cmll_sub_addr(0, CTX, x4)
    ldr     q0,[x4]
    ext     v14.16b,v0.16b,v0.16b,#8
    rev64   v0.4s,v14.4s

    eor     v6.16b,v6.16b,v15.16b
    eor     v4.16b,v4.16b,v15.16b
    eor     v2.16b,v2.16b,v15.16b
    eor     v0.16b,v0.16b,v15.16b

    ext     v11.16b,v6.16b,v6.16b,#8
    rev64   v6.4s,v11.4s
    ext     v12.16b,v4.16b,v4.16b,#8
    rev64   v4.4s,v12.4s
    ext     v13.16b,v2.16b,v2.16b,#8
    rev64   v2.4s,v13.4s
    ext     v13.16b,v0.16b,v0.16b,#8
    rev64   v0.4s,v13.4s

    ext     v3.16b,v2.16b,v31.16b,#8
    ext     v5.16b,v4.16b,v31.16b,#8
    ext     v7.16b,v6.16b,v31.16b,#8

    // key XOR is end of F-function.

    eor     v0.16b,v2.16b,v0.16b
    eor     v2.16b,v4.16b,v2.16b

    cmll_sub_addr(0, CTX, x1)
    str d0,[x1]
    cmll_sub_addr(2, CTX, x2)
    str d3,[x2]
    eor     v3.16b,v5.16b,v3.16b
    eor     v4.16b,v6.16b,v4.16b
    eor     v5.16b,v7.16b,v5.16b
    cmll_sub_addr(3, CTX, x1)
    str     d2,[x1]
    cmll_sub_addr(4, CTX, x2)
    str     d3,[x2];
    cmll_sub_addr(5, CTX, x3)
    str     d4,[x3];
    cmll_sub_addr(6, CTX, x4)
    str     d5,[x4];

    cmll_sub_addr(7, CTX, x1)
    ldr     d7,[x1]
    cmll_sub_addr(8, CTX, x2)
    ldr     d8,[x2]
    cmll_sub_addr(9, CTX, x3)
    ldr     d9,[x3]
    cmll_sub_addr(10, CTX, x4)
    ldr     d10,[x4]
	/* tl = subl(10) ^ (subr(10) & ~subr(8)); */
    bic     v15.16b,v10.16b,v8.16b
    ext     v15.16b,v15.16b,v31.16b,#4
    eor     v0.16b,v15.16b,v10.16b
	/* dw = tl & subl(8), tr = subr(10) ^ CAMELLIA_RL1(dw); */
    and     v15.16b,v0.16b,v8.16b
    shl     v14.4s,v15.4s,#1
    ushr    v15.4s,v15.4s,#31
    add     v15.16b,v14.16b,v15.16b
    ext     v15.16b,v31.16b,v15.16b,#4
    ext     v15.16b,v15.16b,v31.16b,#8
    eor     v0.16b,v0.16b,v15.16b

    eor     v6.16b,v0.16b,v6.16b
    str     d6,[x1]

    cmll_sub_addr(11, CTX, x1)
    ldr     d11,[x1]
    cmll_sub_addr(12, CTX, x2)
    ldr     d12,[x2]
    cmll_sub_addr(13, CTX, x3)
    ldr     d13,[x3]
    cmll_sub_addr(14, CTX, x4)
    ldr     d14,[x4]
    cmll_sub_addr(15, CTX, x5)
    ldr     d15,[x5]
	/* tl = subl(7) ^ (subr(7) & ~subr(9)); */
    bic     v1.16b,v7.16b,v9.16b
    ext     v1.16b,v1.16b,v31.16b,#4
    eor     v0.16b,v1.16b,v7.16b
	/* dw = tl & subl(9), tr = subr(7) ^ CAMELLIA_RL1(dw); */
    and     v1.16b,v0.16b,v9.16b
    shl     v2.4s,v1.4s,#1
    ushr    v1.4s,v1.4s,#31
    add     v1.16b,v2.16b,v1.16b
    ext     v1.16b,v31.16b,v1.16b,#4
    ext     v1.16b,v1.16b,v31.16b,#8
    eor     v0.16b,v1.16b,v0.16b

    eor     v0.16b,v11.16b,v0.16b
    eor     v10.16b,v12.16b,v10.16b
    eor     v11.16b,v13.16b,v11.16b
    eor     v12.16b,v14.16b,v12.16b
    eor     v13.16b,v15.16b,v13.16b
    cmll_sub_addr(10, CTX, x1)
    str     d0,[x1]
    cmll_sub_addr(11, CTX, x2)
    str     d10,[x2];
    cmll_sub_addr(12, CTX, x3)
    str     d11,[x3];
    cmll_sub_addr(13, CTX, x4)
    str     d12,[x4];
    cmll_sub_addr(14, CTX, x5)
    str     d13,[x5];

    cmll_sub_addr(16, CTX, x1)
    ldr     d6,[x1]
    cmll_sub_addr(17, CTX, x2)
    ldr     d7,[x2]
    cmll_sub_addr(18, CTX, x3)
    ldr     d8,[x3]
    cmll_sub_addr(19, CTX, x4)
    ldr     d9,[x4]
    cmll_sub_addr(20, CTX, x5)
    ldr     d10,[x5]

	/* tl = subl(18) ^ (subr(18) & ~subr(16)); */
    bic     v1.16b,v8.16b,v6.16b
    ext     v1.16b,v1.16b,v31.16b,#4
    eor     v0.16b,v1.16b,v8.16b
	/* dw = tl & subl(16), tr = subr(18) ^ CAMELLIA_RL1(dw); */
    and     v1.16b,v0.16b,v6.16b
    shl     v2.4s,v1.4s,#1
    ushr    v1.4s,v1.4s,#31
    add     v1.16b,v2.16b,v1.16b
    ext     v1.16b,v31.16b,v1.16b,#4
    ext     v1.16b,v1.16b,v31.16b,#8
    eor     v0.16b,v1.16b,v0.16b

    eor     v0.16b,v14.16b,v0.16b
    cmll_sub_addr(15, CTX, x1)
    str     d0,[x1]

	/* tl = subl(15) ^ (subr(15) & ~subr(17)); */
    bic     v1.16b,v15.16b,v7.16b
    ext     v1.16b,v1.16b,v31.16b,#4
    eor     v0.16b,v15.16b,v1.16b
	/* dw = tl & subl(17), tr = subr(15) ^ CAMELLIA_RL1(dw); */
    and     v1.16b,v0.16b,v7.16b
    shl     v2.4s,v1.4s,#1
    ushr    v1.4s,v1.4s,#31
    add     v1.16b,v2.16b,v1.16b
    ext     v1.16b,v31.16b,v1.16b,#4
    ext     v1.16b,v1.16b,v31.16b,#8
    eor     v0.16b,v1.16b,v0.16b

    cmll_sub_addr(21, CTX, x1)
    ldr     d1,[x1]
    cmll_sub_addr(22, CTX, x2)
    ldr     d2,[x2]
    cmll_sub_addr(23, CTX, x3)
    ldr     d3,[x3]
    cmll_sub_addr(24, CTX, x4)
    ldr     d4,[x4]

    eor     v0.16b,v9.16b,v0.16b
    eor     v8.16b,v10.16b,v8.16b
    eor     v9.16b,v1.16b,v9.16b
    eor     v10.16b,v2.16b,v10.16b
    eor     v1.16b,v3.16b,v1.16b
    eor     v3.16b,v4.16b,v3.16b
    
    cmll_sub_addr(18, CTX, x1)
    str     d0,[x1]
    cmll_sub_addr(19, CTX, x2)
    str     d8,[x2]
    cmll_sub_addr(20, CTX, x3)
    str     d9,[x3]
    cmll_sub_addr(21, CTX, x4)
    str     d10,[x4]
    cmll_sub_addr(22, CTX, x5)
    str     d1,[x5]
    cmll_sub_addr(23, CTX, x1)
    str     d2,[x1]
    cmll_sub_addr(24, CTX, x2)
    str     d3,[x2]

    // === ZERO UNUSED KEYS ===
    mov     x1, #0
    cmll_sub_addr(1, CTX, x3)
    str x1,[x3]
    cmll_sub_addr(25, CTX, x4)
    str x1,[x4]

    // === EPILOGUE ===
    ldp     q8,q9,[sp,#16]
    ldp     q10,q11,[sp,#48]
    ldp     q12,q13,[sp,#80]
    ldp     q14,q15,[sp,#112]
    ldp     x29,x30,[sp],#144
    ret
.size __camellia_setup128_neon, .-__camellia_setup128_neon

#define KR128 v1    // Input key in v1
#define KB128 v3

.text
.globl  __camellia_setup256_neon
.type   __camellia_setup256_neon,%function
.align  5
__camellia_setup256_neon:
    stp     x29,x30,[sp,#-144]!
    mov     x29,sp
    stp     q8,q9,[sp,#16]
    stp     q10,q11,[sp,#48]
    stp     q12,q13,[sp,#80]
    stp     q14,q15,[sp,#112]

    // === CONSTANT LOADING ===
    // Load constants needed for camellia_f into v17-v27 + v16(bswap)
    adrp    x1,camellia_neon_consts
    add     x1,x1,:lo12:camellia_neon_consts
    ldp     q20,q21,[x1],#64    // pre_tf_lo/hi_s1
    ldp     q22,q23,[x1],#112   // post_tf_lo/hi_s1
    ldr     q19,[x1],#48        //mask_0f
    ldr     q16,[x1],#16        //bswap128
    ldr     d18,[x1],#8         //sbox4_input_mask
    ldr     q17,[x1],#16        //inv_shift_row_and_unpcklbw
    ldp     q24,q25,[x1],#32    //sp0044/sp1110
    ldp     q26,q27,[x1],#32    //sp0222/sp3033

    // Prepare zero vector
    eor     v31.16b,v31.16b,v31.16b
    
    tbl     KL128.16b,{KL128.16b},v16.16b
    tbl     KR128.16b,{KR128.16b},v16.16b
    
    eor     v3.16b,KL128.16b,KR128.16b
    ext     v5.16b,KR128.16b,v31.16b,#8     // here using v5 instead of ref. v6
    ext     v2.16b,v3.16b,v31.16b,#8
    ext     v3.16b,v31.16b,v3.16b,#8
    ext     v3.16b,v3.16b,v31.16b,#8

    // Get addresses of sigma constants
    adrp    x1,.Lsigma1
    add     x1,x1,:lo12:.Lsigma1 // x1 -> sigma1
    add     x2,x1,#8             // x2 -> sigma2
    add     x3,x1,#16            // x3 -> sigma3
    add     x4,x1,#24            // x4 -> sigma4
    add     x5,x1,#32            // x5 -> sigma5
    add     x6,x1,#40            // x6 -> sigma6

    camellia_f(v2,v4,v6,v7,v8,v9,v10,v31,v17,v18,v19,v20,v21,v22,v23,v24,v25,v26,v27,x1,x7)
    eor     v3.16b,v4.16b,v3.16b
    camellia_f(v3,v2,v6,v7,v8,v9,v10,v31,v17,v18,v19,v20,v21,v22,v23,v24,v25,v26,v27,x2,x7)
    eor     v2.16b,v5.16b,v2.16b
    camellia_f(v2,v3,v6,v7,v8,v9,v10,v31,v17,v18,v19,v20,v21,v22,v23,v24,v25,v26,v27,x3,x7)
    eor     v3.16b,v4.16b,v3.16b
    eor     v3.16b,KR128.16b,v3.16b
    camellia_f(v3,v4,v6,v7,v8,v9,v10,v31,v17,v18,v19,v20,v21,v22,v23,v24,v25,v26,v27,x4,x7)

    eor     v6.16b,v4.16b,v2.16b
    mov     KA128.d[0],v3.d[0]
    mov     KA128.d[1],v6.d[0]

	/*
	 * Generate KB
	 */
    eor     v3.16b,KA128.16b,KR128.16b
    ext     v4.16b,v3.16b,v31.16b,#8
    ext     v3.16b,v31.16b,v3.16b,#8
    ext     v3.16b,v3.16b,v31.16b,#8

    camellia_f(v4,v5,v6,v7,v8,v9,v10,v31,v17,v18,v19,v20,v21,v22,v23,v24,v25,v26,v27,x5,x7)
    eor     v3.16b,v5.16b,v3.16b

    camellia_f(v3,v5,v6,v7,v8,v9,v10,v31,v17,v18,v19,v20,v21,v22,v23,v24,v25,v26,v27,x6,x7)
    eor     v4.16b,v5.16b,v4.16b
    mov     KB128.d[1],v4.d[0]

    /*
     * Generate subkeys
     */
    cmll_sub_addr(32, CTX, x1)
    str     q3,[x1]     // KB128

    vec_rol128(KR128, v4, 15, v15)
    vec_rol128(KA128, v5, 15, v15)
    vec_rol128(KR128, v6, 30, v15)
    vec_rol128(KB128, v7, 30, v15)
    vec_rol128(KL128, v8, 45, v15)
    vec_rol128(KA128, v9, 45, v15)
    vec_rol128(KL128, v10, 60, v15)
    vec_rol128(KR128, v11, 60, v15)
    vec_rol128(KB128, v12, 60, v15)

	/* absorb kw2 to other subkeys */
    mov     v15.d[0],KL128.d[0]
    mov     v15.d[1],xzr
    eor     KB128.16b,KB128.16b,v15.16b
    eor     v4.16b,v15.16b,v4.16b
    eor     v5.16b,v15.16b,v5.16b

	/* subl(1) ^= subr(1) & ~subr(9); */
    bic     v13.16b,v15.16b,v6.16b
    ext     v13.16b,v31.16b,v13.16b,#4
    ext     v13.16b,v13.16b,v31.16b,#8
    eor     v15.16b,v13.16b,v15.16b
	/* dw = subl(1) & subl(9), subr(1) ^= CAMELLIA_RL1(dw); */
    and     v14.16b,v15.16b,v6.16b
    shl     v13.4s,v14.4s,#1
    ushr    v14.4s,v14.4s,#31
    add     v14.16b,v13.16b,v14.16b
    ext     v14.16b,v31.16b,v14.16b,#8
    ext     v14.16b,v14.16b,v31.16b,#12
    eor     v15.16b,v14.16b,v15.16b

    eor     v7.16b,v15.16b,v7.16b
    eor     v8.16b,v15.16b,v8.16b
    eor     v9.16b,v15.16b,v9.16b

    ext     v13.16b,KL128.16b,KL128.16b,#8
    rev64   KL128.4s,v13.4s
    ext     v14.16b,KB128.16b,KB128.16b,#8
    rev64   KB128.4s,v14.4s
    ext     v13.16b,v4.16b,v4.16b,#8
    rev64   v4.4s,v13.4s
    ext     v14.16b,v5.16b,v5.16b,#8
    rev64   v5.4s,v14.4s
    ext     v13.16b,v6.16b,v6.16b,#8
    rev64   v6.4s,v13.4s
    ext     v14.16b,v7.16b,v7.16b,#8
    rev64   v7.4s,v14.4s
    ext     v13.16b,v8.16b,v8.16b,#8
    rev64   v8.4s,v13.4s
    ext     v14.16b,v9.16b,v9.16b,#8
    rev64   v9.4s,v14.4s

    cmll_sub_addr(0, CTX, x1)
    str     q0,[x1]     // KL128
    ext     v13.16b,KL128.16b,KL128.16b,#8
    rev64   KL128.4s,v13.4s
    cmll_sub_addr(2, CTX, x2)
    str     q3,[x2]     // KB128
    cmll_sub_addr(4, CTX, x3)
    str     q4,[x3]
    cmll_sub_addr(6, CTX, x4)
    str     q5,[x4]
    cmll_sub_addr(8, CTX, x5)
    str     q6,[x5]
    cmll_sub_addr(10, CTX, x6)
    str     q7,[x6]
    cmll_sub_addr(12, CTX, x7)
    str     q8,[x7]
    cmll_sub_addr(14, CTX, x1)
    str     q9,[x1]

    cmll_sub_addr(32, CTX, x2)
    ldr     q3,[x2]     // KB128

	/* subl(1) ^= subr(1) & ~subr(17); */
    bic     v13.16b,v15.16b,v10.16b
    ext     v13.16b,v31.16b,v13.16b,#4
    ext     v13.16b,v13.16b,v31.16b,#8
    eor     v15.16b,v13.16b,v15.16b
	/* dw = subl(1) & subl(17), subr(1) ^= CAMELLIA_RL1(dw); */
    and     v14.16b,v15.16b,v10.16b
    shl     v13.4s,v14.4s,#1
    ushr    v14.4s,v14.4s,#31
    add     v14.16b,v13.16b,v14.16b
    ext     v14.16b,v31.16b,v14.16b,#8
    ext     v14.16b,v14.16b,v31.16b,#12
    eor     v15.16b,v14.16b,v15.16b

    eor     v11.16b,v15.16b,v11.16b
    eor     v12.16b,v15.16b,v12.16b

    vec_ror128(KL128, v4, 128-77, v14)
    vec_ror128(KA128, v5, 128-77, v14)
    vec_ror128(KR128, v6, 128-94, v14)
    vec_ror128(KA128, v7, 128-94, v14)
    vec_ror128(KL128, v8, 128-111, v14)
    vec_ror128(KB128, v9, 128-111, v14)

    eor     v4.16b,v15.16b,v4.16b

    ext     v13.16b,v10.16b,v10.16b,#8
    rev64   v10.4s,v13.4s
    ext     v14.16b,v11.16b,v11.16b,#8
    rev64   v11.4s,v14.4s
    ext     v13.16b,v12.16b,v12.16b,#8
    rev64   v12.4s,v13.4s
    ext     v14.16b,v4.16b,v4.16b,#8
    rev64   v4.4s,v14.4s

    cmll_sub_addr(16, CTX, x1)
    str     q10,[x1]
    cmll_sub_addr(18, CTX, x2)
    str     q11,[x2]
    cmll_sub_addr(20, CTX, x3)
    str     q12,[x3]
    cmll_sub_addr(22, CTX, x4)
    str     q4,[x4]

	/* subl(1) ^= subr(1) & ~subr(25); */
    bic     v13.16b,v15.16b,v5.16b
    ext     v13.16b,v31.16b,v13.16b,#4
    ext     v13.16b,v13.16b,v31.16b,#8
    eor     v15.16b,v13.16b,v15.16b
	/* dw = subl(1) & subl(25), subr(1) ^= CAMELLIA_RL1(dw); */
    and     v14.16b,v15.16b,v5.16b
    shl     v13.4s,v14.4s,#1
    ushr    v14.4s,v14.4s,#31
    add     v14.16b,v13.16b,v14.16b
    ext     v14.16b,v31.16b,v14.16b,#8
    ext     v14.16b,v14.16b,v31.16b,#12
    eor     v15.16b,v14.16b,v15.16b

    eor     v6.16b,v15.16b,v6.16b
    eor     v7.16b,v15.16b,v7.16b
    eor     v8.16b,v15.16b,v8.16b
    ext     v15.16b,v31.16b,v15.16b,#8
    eor     v9.16b,v15.16b,v9.16b

	/* absorb kw4 to other subkeys */
    ext     v15.16b,v31.16b,v9.16b,#8
    eor     v8.16b,v15.16b,v8.16b
    eor     v7.16b,v15.16b,v7.16b
    eor     v6.16b,v15.16b,v6.16b

	/* subl(33) ^= subr(33) & ~subr(24); */
    bic     v14.16b,v15.16b,v5.16b
    ext     v14.16b,v31.16b,v14.16b,#12
    eor     v15.16b,v14.16b,v15.16b
	/* dw = subl(33) & subl(24), subr(33) ^= CAMELLIA_RL1(dw); */
    and     v14.16b,v15.16b,v5.16b
    shl     v13.4s,v14.4s,#1
    ushr    v14.4s,v14.4s,#31
    add     v14.16b,v13.16b,v14.16b
    ext     v14.16b,v14.16b,v31.16b,#12
    ext     v14.16b,v31.16b,v14.16b,#8
    eor     v15.16b,v14.16b,v15.16b

    ext     v13.16b,v5.16b,v5.16b,#8
    rev64   v5.4s,v13.4s
    ext     v14.16b,v6.16b,v6.16b,#8
    rev64   v6.4s,v14.4s
    ext     v13.16b,v7.16b,v7.16b,#8
    rev64   v7.4s,v13.4s
    ext     v14.16b,v8.16b,v8.16b,#8
    rev64   v8.4s,v14.4s
    ext     v13.16b,v9.16b,v9.16b,#8
    rev64   v9.4s,v13.4s

    cmll_sub_addr(24, CTX, x1)
    str     q5,[x1]
    cmll_sub_addr(26, CTX, x2)
    str     q6,[x2]
    cmll_sub_addr(28, CTX, x3)
    str     q7,[x3]
    cmll_sub_addr(30, CTX, x4)
    str     q8,[x4]
    cmll_sub_addr(32, CTX, x5)
    str     q9,[x5]

    cmll_sub_addr(22, CTX, x1)
    ldr     q0,[x1]
    ext     v13.16b,v0.16b,v0.16b,#8
    rev64   v0.4s,v13.4s
    cmll_sub_addr(20, CTX, x2)
    ldr     q1,[x2]
    ext     v14.16b,v1.16b,v1.16b,#8
    rev64   v1.4s,v14.4s
    cmll_sub_addr(18, CTX, x3)
    ldr     q2,[x3]
    ext     v13.16b,v2.16b,v2.16b,#8
    rev64   v2.4s,v13.4s
    cmll_sub_addr(16, CTX, x4)
    ldr     q3,[x4]
    ext     v14.16b,v3.16b,v3.16b,#8
    rev64   v3.4s,v14.4s
    cmll_sub_addr(14, CTX, x5)
    ldr     q4,[x5]
    ext     v13.16b,v4.16b,v4.16b,#8
    rev64   v4.4s,v13.4s
    cmll_sub_addr(12, CTX, x6)
    ldr     q5,[x6]
    ext     v14.16b,v5.16b,v5.16b,#8
    rev64   v5.4s,v14.4s
    cmll_sub_addr(10, CTX, x7)
    ldr     q6,[x7]
    ext     v13.16b,v6.16b,v6.16b,#8
    rev64   v6.4s,v13.4s
    cmll_sub_addr(8, CTX, x1)
    ldr     q7,[x1]
    ext     v14.16b,v7.16b,v7.16b,#8
    rev64   v7.4s,v14.4s

    eor     v0.16b,v15.16b,v0.16b
    eor     v1.16b,v15.16b,v1.16b
    eor     v2.16b,v15.16b,v2.16b

	/* subl(33) ^= subr(33) & ~subr(24); */
    bic     v14.16b,v15.16b,v3.16b
    ext     v14.16b,v31.16b,v14.16b,#12
    eor     v15.16b,v14.16b,v15.16b
	/* dw = subl(33) & subl(24), subr(33) ^= CAMELLIA_RL1(dw); */
    and     v14.16b,v15.16b,v3.16b
    shl     v13.4s,v14.4s,#1
    ushr    v14.4s,v14.4s,#31
    add     v14.16b,v13.16b,v14.16b
    ext     v14.16b,v14.16b,v31.16b,#12
    ext     v14.16b,v31.16b,v14.16b,#8
    eor     v15.16b,v14.16b,v15.16b

    eor     v4.16b,v15.16b,v4.16b
    eor     v5.16b,v15.16b,v5.16b
    eor     v6.16b,v15.16b,v6.16b

    ext     v13.16b,v0.16b,v0.16b,#8
    rev64   v0.4s,v13.4s
    ext     v14.16b,v1.16b,v1.16b,#8
    rev64   v1.4s,v14.4s
    ext     v13.16b,v2.16b,v2.16b,#8
    rev64   v2.4s,v13.4s
    ext     v14.16b,v4.16b,v4.16b,#8
    rev64   v4.4s,v14.4s
    ext     v13.16b,v5.16b,v5.16b,#8
    rev64   v5.4s,v13.4s
    ext     v14.16b,v6.16b,v6.16b,#8
    rev64   v6.4s,v14.4s

    cmll_sub_addr(22, CTX, x1)
    str     q0,[x1]
    cmll_sub_addr(20, CTX, x2)
    str     q1,[x2]
    cmll_sub_addr(18, CTX, x3)
    str     q2,[x3]
    cmll_sub_addr(14, CTX, x4)
    str     q4,[x4]
    cmll_sub_addr(12, CTX, x5)
    str     q5,[x5]
    cmll_sub_addr(10, CTX, x6)
    str     q6,[x6]

    cmll_sub_addr(6, CTX, x1)
    ldr     q6,[x1]
    ext     v13.16b,v6.16b,v6.16b,#8
    rev64   v6.4s,v13.4s
    cmll_sub_addr(4, CTX, x2)
    ldr     q4,[x2]
    ext     v14.16b,v4.16b,v4.16b,#8
    rev64   v4.4s,v14.4s
    cmll_sub_addr(2, CTX, x3)
    ldr     q2,[x3]
    ext     v13.16b,v2.16b,v2.16b,#8
    rev64   v2.4s,v13.4s
    cmll_sub_addr(0, CTX, x4)
    ldr     q0,[x4]
    ext     v14.16b,v0.16b,v0.16b,#8
    rev64   v0.4s,v14.4s

	/* subl(33) ^= subr(33) & ~subr(24); */
    bic     v14.16b,v15.16b,v7.16b
    ext     v14.16b,v31.16b,v14.16b,#12
    eor     v15.16b,v14.16b,v15.16b
	/* dw = subl(33) & subl(24), subr(33) ^= CAMELLIA_RL1(dw); */
    and     v14.16b,v15.16b,v7.16b
    shl     v13.4s,v14.4s,#1
    ushr    v14.4s,v14.4s,#31
    add     v14.16b,v13.16b,v14.16b
    ext     v14.16b,v14.16b,v31.16b,#12
    ext     v14.16b,v31.16b,v14.16b,#8
    eor     v15.16b,v14.16b,v15.16b

    eor     v6.16b,v15.16b,v6.16b
    eor     v4.16b,v15.16b,v4.16b
    eor     v2.16b,v15.16b,v2.16b
    eor     v0.16b,v15.16b,v0.16b

    ext     v13.16b,v6.16b,v6.16b,#8
    rev64   v6.4s,v13.4s
    ext     v14.16b,v4.16b,v4.16b,#8
    rev64   v4.4s,v14.4s
    ext     v13.16b,v2.16b,v2.16b,#8
    rev64   v2.4s,v13.4s
    ext     v14.16b,v0.16b,v0.16b,#8
    rev64   v0.4s,v14.4s

    ext     v3.16b,v2.16b,v31.16b,#8
    ext     v5.16b,v4.16b,v31.16b,#8
    ext     v7.16b,v6.16b,v31.16b,#8

    /*
	 * key XOR is end of F-function.
	 */
    eor     v0.16b,v2.16b,v0.16b
    eor     v2.16b,v4.16b,v2.16b

    cmll_sub_addr(0, CTX, x1)
    str     d0,[x1]
    cmll_sub_addr(2, CTX, x2)
    str     d3,[x2]
    eor     v3.16b,v5.16b,v3.16b
    eor     v4.16b,v6.16b,v4.16b
    eor     v5.16b,v7.16b,v5.16b
    cmll_sub_addr(3, CTX, x3)
    str     d2,[x3]
    cmll_sub_addr(4, CTX, x4)
    str     d3,[x4]
    cmll_sub_addr(5, CTX, x5)
    str     d4,[x5]
    cmll_sub_addr(6, CTX, x6)
    str     d5,[x6]

    cmll_sub_addr(7, CTX, x1)
    ldr     d7,[x1]
    cmll_sub_addr(8, CTX, x2)
    ldr     d8,[x2]
    cmll_sub_addr(9, CTX, x3)
    ldr     d9,[x3]
    cmll_sub_addr(10, CTX, x4)
    ldr     d10,[x4]
	/* tl = subl(10) ^ (subr(10) & ~subr(8)); */
    bic     v15.16b,v10.16b,v8.16b
    ext     v15.16b,v15.16b,v31.16b,#4
    eor     v0.16b,v15.16b,v10.16b
	/* dw = tl & subl(8), tr = subr(10) ^ CAMELLIA_RL1(dw); */
    and     v15.16b,v8.16b,v0.16b
    shl     v14.4s,v15.4s,#1
    ushr    v15.4s,v15.4s,#31
    add     v15.16b,v14.16b,v15.16b
    ext     v15.16b,v31.16b,v15.16b,#4
    ext     v15.16b,v15.16b,v31.16b,#8
    eor     v0.16b,v15.16b,v0.16b

    eor     v6.16b,v0.16b,v6.16b
    cmll_sub_addr(7, CTX, x1)
    str     d6,[x1]

    cmll_sub_addr(11, CTX, x2)
    ldr     d11,[x2]
    cmll_sub_addr(12, CTX, x3)
    ldr     d12,[x3]
    cmll_sub_addr(13, CTX, x4)
    ldr     d13,[x4]
    cmll_sub_addr(14, CTX, x5)
    ldr     d14,[x5]
    cmll_sub_addr(15, CTX, x6)
    ldr     d15,[x6]
	/* tl = subl(7) ^ (subr(7) & ~subr(9)); */
    bic     v1.16b,v7.16b,v9.16b
    ext     v1.16b,v1.16b,v31.16b,#4
    eor     v0.16b,v1.16b,v7.16b
	/* dw = tl & subl(9), tr = subr(7) ^ CAMELLIA_RL1(dw); */
    and     v1.16b,v9.16b,v0.16b
    shl     v2.4s,v1.4s,#1
    ushr    v1.4s,v1.4s,#31
    add     v1.16b,v2.16b,v1.16b
    ext     v1.16b,v31.16b,v1.16b,#4
    ext     v1.16b,v1.16b,v31.16b,#8
    eor     v0.16b,v1.16b,v0.16b

    eor     v0.16b,v11.16b,v0.16b
    eor     v10.16b,v12.16b,v10.16b
    eor     v11.16b,v13.16b,v11.16b
    eor     v12.16b,v14.16b,v12.16b
    eor     v13.16b,v15.16b,v13.16b
    cmll_sub_addr(10, CTX, x1)
    str     d0,[x1]
    cmll_sub_addr(11, CTX, x2)
    str     d10,[x2]
    cmll_sub_addr(12, CTX, x3)
    str     d11,[x3]
    cmll_sub_addr(13, CTX, x4)
    str     d12,[x4]
    cmll_sub_addr(14, CTX, x5)
    str     d13,[x5]

    cmll_sub_addr(16, CTX, x1)
    ldr     d6,[x1]
    cmll_sub_addr(17, CTX, x2)
    ldr     d7,[x2]
    cmll_sub_addr(18, CTX, x3)
    ldr     d8,[x3]
    cmll_sub_addr(19, CTX, x4)
    ldr     d9,[x4]
    cmll_sub_addr(20, CTX, x5)
    ldr     d10,[x5]
	/* tl = subl(18) ^ (subr(18) & ~subr(16)); */
    bic     v1.16b,v8.16b,v6.16b
    ext     v1.16b,v1.16b,v31.16b,#4
    eor     v0.16b,v1.16b,v8.16b
	/* dw = tl & subl(16), tr = subr(18) ^ CAMELLIA_RL1(dw); */
    and     v1.16b,v6.16b,v0.16b
    shl     v2.4s,v1.4s,#1
    ushr    v1.4s,v1.4s,#31
    add     v1.16b,v2.16b,v1.16b
    ext     v1.16b,v31.16b,v1.16b,#4
    ext     v1.16b,v1.16b,v31.16b,#8
    eor     v0.16b,v1.16b,v0.16b

    eor     v0.16b,v14.16b,v0.16b
    cmll_sub_addr(15, CTX, x1)
    str     d0,[x1]

	/* tl = subl(15) ^ (subr(15) & ~subr(17)); */
    bic     v1.16b,v15.16b,v7.16b
    ext     v1.16b,v1.16b,v31.16b,#4
    eor     v0.16b,v1.16b,v15.16b
	/* dw = tl & subl(17), tr = subr(15) ^ CAMELLIA_RL1(dw); */
    and     v1.16b,v7.16b,v0.16b
    shl     v2.4s,v1.4s,#1
    ushr    v1.4s,v1.4s,#31
    add     v1.16b,v2.16b,v1.16b
    ext     v1.16b,v31.16b,v1.16b,#4
    ext     v1.16b,v1.16b,v31.16b,#8
    eor     v0.16b,v1.16b,v0.16b

    cmll_sub_addr(21, CTX, x1)
    ldr     d1,[x1]
    cmll_sub_addr(22, CTX, x2)
    ldr     d2,[x2]
    cmll_sub_addr(23, CTX, x3)
    ldr     d3,[x3]
    cmll_sub_addr(24, CTX, x4)
    ldr     d4,[x4]

    eor     v0.16b,v9.16b,v0.16b
    eor     v8.16b,v10.16b,v8.16b
    eor     v9.16b,v1.16b,v9.16b
    eor     v10.16b,v2.16b,v10.16b
    eor     v1.16b,v3.16b,v1.16b

    cmll_sub_addr(18, CTX, x1)
    str     d0,[x1]
    cmll_sub_addr(19, CTX, x2)
    str     d8,[x2]
    cmll_sub_addr(20, CTX, x3)
    str     d9,[x3]
    cmll_sub_addr(21, CTX, x4)
    str     d10,[x4]
    cmll_sub_addr(22, CTX, x5)
    str     d1,[x5]

    cmll_sub_addr(25, CTX, x1)
    ldr     d5,[x1]
    cmll_sub_addr(26, CTX, x2)
    ldr     d6,[x2]
    cmll_sub_addr(27, CTX, x3)
    ldr     d7,[x3]
    cmll_sub_addr(28, CTX, x4)
    ldr     d8,[x4]
    cmll_sub_addr(29, CTX, x5)
    ldr     d9,[x5]
    cmll_sub_addr(30, CTX, x6)
    ldr     d10,[x6]
    cmll_sub_addr(31, CTX, x7)
    ldr     d11,[x7]
    cmll_sub_addr(32, CTX, x1)
    ldr     d12,[x1]

	/* tl = subl(26) ^ (subr(26) & ~subr(24)); */
    bic     v15.16b,v6.16b,v4.16b
    ext     v15.16b,v15.16b,v31.16b,#4
    eor     v0.16b,v15.16b,v6.16b
	/* dw = tl & subl(26), tr = subr(24) ^ CAMELLIA_RL1(dw); */
    and     v15.16b,v4.16b,v0.16b
    shl     v14.4s,v15.4s,#1
    ushr    v15.4s,v15.4s,#31
    add     v15.16b,v14.16b,v15.16b
    ext     v15.16b,v31.16b,v15.16b,#4
    ext     v15.16b,v15.16b,v31.16b,#8
    eor     v0.16b,v15.16b,v0.16b

    eor     v2.16b,v0.16b,v2.16b
    cmll_sub_addr(23, CTX, x1)
    str     d2,[x1]

	/* tl = subl(23) ^ (subr(23) &  ~subr(25)); */
    bic     v15.16b,v3.16b,v5.16b
    ext     v15.16b,v15.16b,v31.16b,#4
    eor     v0.16b,v15.16b,v3.16b
	/* dw = tl & subl(26), tr = subr(24) ^ CAMELLIA_RL1(dw); */
    and     v15.16b,v5.16b,v0.16b
    shl     v14.4s,v15.4s,#1
    ushr    v15.4s,v15.4s,#31
    add     v15.16b,v14.16b,v15.16b
    ext     v15.16b,v31.16b,v15.16b,#4
    ext     v15.16b,v15.16b,v31.16b,#8
    eor     v0.16b,v15.16b,v0.16b

    eor     v0.16b,v7.16b,v0.16b
    eor     v6.16b,v8.16b,v6.16b
    eor     v7.16b,v9.16b,v7.16b
    eor     v8.16b,v10.16b,v8.16b
    eor     v9.16b,v11.16b,v9.16b
    eor     v11.16b,v12.16b,v11.16b

    cmll_sub_addr(26, CTX, x1)
    str     d0,[x1]
    cmll_sub_addr(27, CTX, x2)
    str     d6,[x2]
    cmll_sub_addr(28, CTX, x3)
    str     d7,[x3]
    cmll_sub_addr(29, CTX, x4)
    str     d8,[x4]
    cmll_sub_addr(30, CTX, x5)
    str     d9,[x5]
    cmll_sub_addr(31, CTX, x6)
    str     d10,[x6]
    cmll_sub_addr(32, CTX, x7)
    str     d11,[x7]

    mov     x1, #0
    cmll_sub_addr(1, CTX, x2)
    str     x1,[x2]
    cmll_sub_addr(33, CTX, x3)
    str     x1,[x3]

    // === EPILOGUE ===
    ldp     q8,q9,[sp,#16]
    ldp     q10,q11,[sp,#48]
    ldp     q12,q13,[sp,#80]
    ldp     q14,q15,[sp,#112]
    ldp     x29,x30,[sp],#144

    ret

.size __camellia_setup256_neon,.-__camellia_setup256_neon

.global camellia_keysetup_simd128
.type   camellia_keysetup_simd128, %function
.align  4
camellia_keysetup_simd128:
    // Input:
    //   x0: ctx (struct camellia_simd_ctx *)
    //   x1: key (const unsigned char *)
    //   x2: keylen (int) - 16, 24, or 32

    // Store key_length into ctx->key_length
    // Offset is 272 (68 * 4 bytes for key_table)
    str     w2,[x0,#272]

    // Load the first 128 bits of the key into v0
    ldr     q0,[x1]

    // Check key length
    cmp     w2,#24
    b.lt    .Lsetup_128    // keylen < 24 (i.e., 16)
    b.eq    .Lsetup_192    // keylen == 24

    // === 256-bit Case ===
    // Load the second 128 bits into v1
    ldr     q1,[x1,#16]
    // Tail call to setup256
    b       __camellia_setup256_neon

.Lsetup_192:
    // === 192-bit Case ===
    // Camellia 192 treats the second half as: [ K[16..23] | ~K[16..23] ]
    // Load the 64 bits of K_R into a GPR
    ldr     x3,[x1,#16]
    // Create the complement (~K_R)
    mvn     x4,x3
    // Assemble v1: Lower 64 = K_R, Upper 64 = ~K_R
    mov     v1.d[0],x3
    mov     v1.d[1],x4
    // Tail call to setup256
    b       __camellia_setup256_neon

.Lsetup_128:
    // === 128-bit Case ===
    // Tail call to setup128
    b       __camellia_setup128_neon

.size   camellia_keysetup_simd128, .-camellia_keysetup_simd128