CC_X86_64 = gcc
CC_I386 = i686-linux-gnu-gcc
CC_AARCH64 = aarch64-linux-gnu-gcc
CFLAGS = -O2 -Wall
CFLAGS_SIMD128_X86 = $(CFLAGS) -march=sandybridge -mtune=native -msse4.1 -maes
CFLAGS_SIMD256_X86 = $(CFLAGS) -march=sandybridge -mtune=native -mavx2 -maes
CFLAGS_SIMD128_ARM = $(CFLAGS) -march=armv8-a+crypto -mtune=cortex-a53
LDFLAGS = -lcrypto

all: test_simd128_intrinsics_x86_64 test_simd256_intrinsics_x86_64 \
     test_simd128_asm_x86_64 test_simd256_asm_x86_64 \
     test_simd128_intrinsics_i386 test_simd256_intrinsics_i386 \
     test_simd128_intrinsics_aarch64

clean:
	rm camellia_simd128_with_x86_aesni.o \
	   camellia_simd128_with_x86_aesni_avx2.o \
	   camellia_simd256_x86_aesni.o \
	   camellia_simd128_x86-64_aesni_avx.o \
	   camellia_simd256_x86-64_aesni_avx2.o \
	   main_simd128.o \
	   main_simd256.o || true
	rm test_simd128_intrinsics_x86_64 test_simd256_intrinsics_x86_64 \
	   test_simd128_asm_x86_64 test_simd256_asm_x86_64 || true
	rm camellia_simd128_with_x86_aesni_i386.o \
	   camellia_simd128_with_x86_aesni_avx2_i386.o \
	   camellia_simd256_x86_aesni_i386.o \
	   main_simd128_i386.o \
	   main_simd256_i386.o || true
	rm test_simd128_intrinsics_i386 test_simd256_intrinsics_i386 || true
	rm camellia_simd128_with_aarch64_ce.o \
	   main_simd128_aarch64.o || true
	rm test_simd128_intrinsics_aarch64 || true

test_simd128_intrinsics_x86_64: camellia_simd128_with_x86_aesni.o \
				main_simd128.o
	$(CC_X86_64) $^ -o $@ $(LDFLAGS)

test_simd256_intrinsics_x86_64: camellia_simd128_with_x86_aesni_avx2.o \
				camellia_simd256_x86_aesni.o \
				main_simd256.o
	$(CC_X86_64) $^ -o $@ $(LDFLAGS)

test_simd128_asm_x86_64: camellia_simd128_x86-64_aesni_avx.o \
			 main_simd128.o
	$(CC_X86_64) $^ -o $@ $(LDFLAGS)

test_simd256_asm_x86_64: camellia_simd128_x86-64_aesni_avx.o \
			 camellia_simd256_x86-64_aesni_avx2.o \
			 main_simd256.o
	$(CC_X86_64) $^ -o $@ $(LDFLAGS)

test_simd128_intrinsics_i386: camellia_simd128_with_x86_aesni_i386.o \
			      main_simd128_i386.o
	$(CC_I386) $^ -o $@ $(LDFLAGS)

test_simd256_intrinsics_i386: camellia_simd128_with_x86_aesni_avx2_i386.o \
			      camellia_simd256_x86_aesni_i386.o \
			      main_simd256_i386.o
	$(CC_I386) $^ -o $@ $(LDFLAGS)

test_simd128_intrinsics_aarch64: camellia_simd128_with_aarch64_ce.o \
				 main_simd128_aarch64.o
	$(CC_AARCH64) $^ -o $@ $(LDFLAGS)

camellia_simd128_with_x86_aesni.o: camellia_simd128_with_aes_instruction_set.c
	$(CC_X86_64) $(CFLAGS_SIMD128_X86) -c $< -o $@

camellia_simd128_with_x86_aesni_avx2.o: camellia_simd128_with_aes_instruction_set.c
	$(CC_X86_64) $(CFLAGS_SIMD256_X86) -c $< -o $@

camellia_simd256_x86_aesni.o: camellia_simd256_x86_aesni.c
	$(CC_X86_64) $(CFLAGS_SIMD256_X86) -c $< -o $@

camellia_simd128_x86-64_aesni_avx.o: camellia_simd128_x86-64_aesni_avx.S
	$(CC_X86_64) $(CFLAGS) -c $< -o $@

camellia_simd256_x86-64_aesni_avx2.o: camellia_simd256_x86-64_aesni_avx2.S
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

main_simd128_i386.o: main.c
	$(CC_I386) $(CFLAGS) -c $< -o $@

main_simd256_i386.o: main.c
	$(CC_I386) $(CFLAGS) -DUSE_SIMD256 -c $< -o $@

camellia_simd128_with_aarch64_ce.o: camellia_simd128_with_aes_instruction_set.c
	$(CC_AARCH64) $(CFLAGS_SIMD128_ARM) -c $< -o $@

main_simd128_aarch64.o: main.c
	$(CC_AARCH64) $(CFLAGS) -c $< -o $@
