CC_X86_64 = x86_64-linux-gnu-gcc
CC_I386 = i686-linux-gnu-gcc
CC_AARCH64 = aarch64-linux-gnu-gcc
CC_PPC64LE = powerpc64le-linux-gnu-gcc
CFLAGS = -O2 -Wall
CFLAGS_SIMD128_X86 = $(CFLAGS) -march=sandybridge -mtune=native -msse4.1 -maes
CFLAGS_SIMD256_X86 = $(CFLAGS) -march=haswell -mtune=native -mavx2 -maes
CFLAGS_SIMD256_X86_VAES = $(CFLAGS) -march=haswell -mtune=native -mavx2 -maes -mvaes
CFLAGS_SIMD256_X86_VAES_AVX512 = $(CFLAGS) -march=znver3 -mavx512f -mavx512vl -mavx512bw \
					-mavx512dq -mavx512vbmi -mavx512ifma -mavx512vpopcntdq \
					-mavx512vbmi2 -mavx512bitalg -mavx512vnni \
					-mprefer-vector-width=512 -mavx2 -maes -mvaes -mgfni
CFLAGS_SIMD128_ARM = $(CFLAGS) -march=armv8-a+crypto -mtune=cortex-a53
CFLAGS_SIMD128_PPC = $(CFLAGS) -mcpu=power8 -maltivec -mvsx -mcrypto
LDFLAGS =

PROGRAMS =
ifneq ($(shell which $(CC_X86_64)),)
	PROGRAMS += \
		test_simd128_intrinsics_x86_64 \
		test_simd256_intrinsics_x86_64 test_simd256_intrinsics_x86_64_vaes \
		test_simd256_intrinsics_x86_64_vaes_avx512 \
		test_simd256_intrinsics_x86_64_gfni_avx512 \
		test_simd128_asm_x86_64 test_simd256_asm_x86_64 \
		test_simd256_asm_x86_64_vaes test_simd256_asm_x86_64_gfni
endif
ifneq ($(shell which $(CC_I386)),)
	PROGRAMS += test_simd128_intrinsics_i386 test_simd256_intrinsics_i386
endif
ifneq ($(shell which $(CC_AARCH64)),)
	PROGRAMS += test_simd128_intrinsics_aarch64
endif
ifneq ($(shell which $(CC_PPC64LE)),)
	PROGRAMS += test_simd128_intrinsics_ppc64le
endif

all: $(PROGRAMS)

clean:
	rm *.o 2>/dev/null || true
	rm test_simd128_intrinsics_x86_64 2>/dev/null || true
	rm test_simd256_intrinsics_x86_64 2>/dev/null || true
	rm test_simd128_asm_x86_64 2>/dev/null || true
	rm test_simd256_asm_x86_64 2>/dev/null || true
	rm test_simd256_asm_x86_64_vaes 2>/dev/null || true
	rm test_simd256_asm_x86_64_gfni 2>/dev/null || true
	rm test_simd256_intrinsics_x86_64_vaes 2>/dev/null || true
	rm test_simd256_intrinsics_x86_64_vaes_avx512 2>/dev/null || true
	rm test_simd256_intrinsics_x86_64_gfni_avx512 2>/dev/null || true
	rm test_simd128_intrinsics_i386 2>/dev/null || true
	rm test_simd256_intrinsics_i386 2>/dev/null || true
	rm test_simd128_intrinsics_aarch64 2>/dev/null || true
	rm test_simd128_intrinsics_ppc64le 2>/dev/null || true

test_simd128_intrinsics_x86_64: camellia_simd128_with_x86_aesni.o \
				main_simd128.o \
				camellia_ref_x86-64.o
	$(CC_X86_64) $^ -o $@ $(LDFLAGS)

test_simd256_intrinsics_x86_64: camellia_simd128_with_x86_aesni_avx2.o \
				camellia_simd256_x86_aesni.o \
				main_simd256.o \
				camellia_ref_x86-64.o
	$(CC_X86_64) $^ -o $@ $(LDFLAGS)

test_simd256_intrinsics_x86_64_vaes: camellia_simd128_with_x86_aesni_avx2.o \
				     camellia_simd256_x86_vaes.o \
				     main_simd256.o \
				     camellia_ref_x86-64.o
	$(CC_X86_64) $^ -o $@ $(LDFLAGS)

test_simd256_intrinsics_x86_64_vaes_avx512: camellia_simd128_with_x86_aesni_avx512.o \
					    camellia_simd256_x86_vaes_avx512.o \
					    main_simd256.o \
					    camellia_ref_x86-64.o
	$(CC_X86_64) $^ -o $@ $(LDFLAGS)

test_simd256_intrinsics_x86_64_gfni_avx512: camellia_simd128_with_x86_aesni_avx512.o \
					    camellia_simd256_x86_gfni_avx512.o \
					    main_simd256.o \
					    camellia_ref_x86-64.o
	$(CC_X86_64) $^ -o $@ $(LDFLAGS)

test_simd128_asm_x86_64: camellia_simd128_x86-64_aesni_avx.o \
			 main_simd128.o \
			 camellia_ref_x86-64.o
	$(CC_X86_64) $^ -o $@ $(LDFLAGS)

test_simd256_asm_x86_64: camellia_simd128_x86-64_aesni_avx.o \
			 camellia_simd256_x86-64_aesni_avx2.o \
			 main_simd256.o \
			 camellia_ref_x86-64.o
	$(CC_X86_64) $^ -o $@ $(LDFLAGS)

test_simd256_asm_x86_64_vaes: camellia_simd128_x86-64_aesni_avx.o \
			      camellia_simd256_x86-64_vaes_avx2.o \
			      main_simd256.o \
			      camellia_ref_x86-64.o
	$(CC_X86_64) $^ -o $@ $(LDFLAGS)

test_simd256_asm_x86_64_gfni: camellia_simd128_x86-64_aesni_avx.o \
			      camellia_simd256_x86-64_gfni_avx2.o \
			      main_simd256.o \
			      camellia_ref_x86-64.o
	$(CC_X86_64) $^ -o $@ $(LDFLAGS)

test_simd128_intrinsics_i386: camellia_simd128_with_x86_aesni_i386.o \
			      main_simd128_i386.o \
			      camellia_ref_i386.o
	$(CC_I386) $^ -o $@ $(LDFLAGS)

test_simd256_intrinsics_i386: camellia_simd128_with_x86_aesni_avx2_i386.o \
			      camellia_simd256_x86_aesni_i386.o \
			      main_simd256_i386.o \
			      camellia_ref_i386.o
	$(CC_I386) $^ -o $@ $(LDFLAGS)

test_simd128_intrinsics_aarch64: camellia_simd128_with_aarch64_ce.o \
				 main_simd128_aarch64.o \
				 camellia_ref_aarch64.o
	$(CC_AARCH64) $^ -o $@ $(LDFLAGS)

test_simd128_intrinsics_ppc64le: camellia_simd128_with_ppc64le.o \
				 main_simd128_ppc64le.o \
				 camellia_ref_ppc64le.o
	$(CC_PPC64LE) $^ -o $@ $(LDFLAGS)


camellia_simd128_with_x86_aesni.o: camellia_simd128_with_aes_instruction_set.c
	$(CC_X86_64) $(CFLAGS_SIMD128_X86) -c $< -o $@

camellia_simd128_with_x86_aesni_avx512.o: camellia_simd128_with_aes_instruction_set.c
	$(CC_X86_64) $(CFLAGS_SIMD256_X86_VAES_AVX512) -c $< -o $@

camellia_simd128_with_x86_aesni_avx2.o: camellia_simd128_with_aes_instruction_set.c
	$(CC_X86_64) $(CFLAGS_SIMD256_X86) -c $< -o $@

camellia_simd256_x86_aesni.o: camellia_simd256_x86_aesni.c
	$(CC_X86_64) $(CFLAGS_SIMD256_X86) -c $< -o $@

camellia_simd256_x86_vaes.o: camellia_simd256_x86_aesni.c
	$(CC_X86_64) $(CFLAGS_SIMD256_X86_VAES) -DUSE_VAES -c $< -o $@

camellia_simd256_x86_vaes_avx512.o: camellia_simd256_x86_aesni.c
	$(CC_X86_64) $(CFLAGS_SIMD256_X86_VAES_AVX512) -DUSE_VAES -c $< -o $@

camellia_simd256_x86_gfni_avx512.o: camellia_simd256_x86_aesni.c
	$(CC_X86_64) $(CFLAGS_SIMD256_X86_VAES_AVX512) -DUSE_GFNI -c $< -o $@

camellia_simd128_x86-64_aesni_avx.o: camellia_simd128_x86-64_aesni_avx.S
	$(CC_X86_64) $(CFLAGS) -c $< -o $@

camellia_simd256_x86-64_aesni_avx2.o: camellia_simd256_x86-64_aesni_avx2.S
	$(CC_X86_64) $(CFLAGS) -c $< -o $@

camellia_simd256_x86-64_vaes_avx2.o: camellia_simd256_x86-64_aesni_avx2.S
	$(CC_X86_64) $(CFLAGS) -DUSE_VAES -c $< -o $@

camellia_simd256_x86-64_gfni_avx2.o: camellia_simd256_x86-64_aesni_avx2.S
	$(CC_X86_64) $(CFLAGS) -DUSE_GFNI -c $< -o $@

camellia_ref_x86-64.o: camellia-BSD-1.2.0/camellia.c
	$(CC_X86_64) $(CFLAGS) -c $< -o $@

main_simd128.o: main.c
	$(CC_X86_64) $(CFLAGS) -c $< -o $@

main_simd256.o: main.c
	$(CC_X86_64) $(CFLAGS) -DUSE_SIMD256 -c $< -o $@

camellia_simd128_with_x86_aesni_i386.o: camellia_simd128_with_aes_instruction_set.c
	$(CC_I386) $(CFLAGS_SIMD128_X86) -c $< -o $@

camellia_simd128_with_x86_aesni_avx2_i386.o: camellia_simd128_with_aes_instruction_set.c
	$(CC_I386) $(CFLAGS_SIMD256_X86) -c $< -o $@

camellia_simd256_x86_aesni_i386.o: camellia_simd256_x86_aesni.c
	$(CC_I386) $(CFLAGS_SIMD256_X86) -c $< -o $@

camellia_ref_i386.o: camellia-BSD-1.2.0/camellia.c
	$(CC_I386) $(CFLAGS) -c $< -o $@

main_simd128_i386.o: main.c
	$(CC_I386) $(CFLAGS) -c $< -o $@

main_simd256_i386.o: main.c
	$(CC_I386) $(CFLAGS) -DUSE_SIMD256 -c $< -o $@

camellia_simd128_with_aarch64_ce.o: camellia_simd128_with_aes_instruction_set.c
	$(CC_AARCH64) $(CFLAGS_SIMD128_ARM) -c $< -o $@

camellia_ref_aarch64.o: camellia-BSD-1.2.0/camellia.c
	$(CC_AARCH64) $(CFLAGS_SIMD128_ARM) -c $< -o $@

main_simd128_aarch64.o: main.c
	$(CC_AARCH64) $(CFLAGS_SIMD128_ARM) -c $< -o $@

camellia_simd128_with_ppc64le.o: camellia_simd128_with_aes_instruction_set.c
	$(CC_PPC64LE) $(CFLAGS_SIMD128_PPC) -c $< -o $@

camellia_ref_ppc64le.o: camellia-BSD-1.2.0/camellia.c
	$(CC_PPC64LE) $(CFLAGS_SIMD128_PPC) -c $< -o $@

main_simd128_ppc64le.o: main.c
	$(CC_PPC64LE) $(CFLAGS_SIMD128_PPC) -c $< -o $@
