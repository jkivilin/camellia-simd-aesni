# About
This is repository, you find x86 (AES-NI, VAES, GFNI), ARMv8 Crypto Extension
and PowerPC crypto instruction set accelerated vector implementations of
[Camellia cipher](https://info.isl.ntt.co.jp/crypt/eng/camellia/).
For x86, both Intel C intrinsics and x86-64 assembly implementations are provided,
with assembly yielding best performance and instrinsics implementation being
easier to port to other instruction sets. For ARMv8/AArch64 and PowerPC,
a 128-bit vector instrinsics implementation is provided.

# How it works
It happens to be that Camellia uses s-box construction is very similar to AES SubBytes.
With help of affine transforms, one can perform Camellia s-boxes with AES SubBytes and
implementations here use SubBytes from AES-NI and similar AES vector instructions.
Newer x86-64 processors also support Galois Field New Instructions (GFNI) which allow
implementing Camellia s-box more straightforward manner and yield even better performance.

Due to the structure of Camellia cipher, at least 16 blocks needs to be processed in parallel
for the best performance. Details can be found in [Block Ciphers: Fast Implementations on x86-64
Architecture](http://urn.fi/URN:NBN:fi:oulu-201305311409) (pages 42-50).

Because of the requirement for parallel input blocks, these implementations are
best suited for parallelizable cipher modes of operation, such as CTR, CBC decryption,
CFB decryption, XTS, OCB, etc.

# Implementations

## SIMD128
The SIMD128 (128-bit vector) implementation variants process 16 blocks in parallel.

- [camellia_simd128_with_aes_instruction_set.c](camellia_simd128_with_aes_instruction_set.c):
  - C intrinsics implementation for x86 with AES-NI, for ARMv8 with Crypto Extension and for PowerPC with AES crypto instruction set.
    - x86 implementation requires AES-NI and either SSE4.1 or AVX instruction set and gets best performance with x86-64 + AVX.
    - ARM implementation requires AArch64, NEON and ARMv8 crypto-extension instruction set.
    - PowerPC implementation requires VSX and AES crypto instruction set.
  - Includes vector intrinsics implementation of Camellia key-setup (for 128-bit, 192-bit and 256-bit keys).
  - On AMD Ryzen 3700X, when compiled for x86-64+AVX, this implementation is **~3.5 times faster** than
    reference.

- [camellia_simd128_x86-64_aesni_avx.S](camellia_simd128_x86-64_aesni_avx.S):
  - GCC assembly implementation for x86-64 with AES-NI and AVX.
  - Includes vector assembly implementation of Camellia key-setup (for 128-bit, 192-bit and 256-bit keys).
  - On AMD Ryzen 3700X, this implementation is **~4.1 times faster** than reference.
  - On Intel Haswell, CTR-mode adaptation runs at **5.93 cycles/byte**
    [*](https://github.com/jkivilin/supercop-blockciphers).

## SIMD256
The SIMD256 (256-bit vector) implementation variants process 32 blocks in parallel.
- [camellia_simd256_x86_aesni.c](camellia_simd256_x86_aesni.c):
  - Intel C intrinsics implentation for x86 with AES-NI or VAES or GFNI. Requires either AVX2 instruction set and gets best
  performance with x86-64 + AVX512 + GFNI.
  - On AMD Ryzen 7 3700X, when compiled for **x86-64+AVX2+AES-NI**, this implementation is **~5.9 times faster** than
    reference.
  - On AMD Ryzen 9 7900X, when compiled for **x86-64+AVX512+VAES**, this implementation is **~8.6 times faster** than
    reference.
  - On AMD Ryzen 9 7900X, when compiled for **x86-64+AVX512+GFNI**, this implementation is **~18.1 times faster** than
    reference.

- [camellia_simd256_x86-64_aesni_avx2.S](camellia_simd256_x86-64_aesni_avx2.S):
  - GCC assembly implementation for x86-64 with AES-NI and AVX2.
  - On AMD Ryzen 3700X, when compiled for **x86-64+AVX2+AES-NI**, this implementation is **~6.6 times faster** than
    reference.
  - On Intel Haswell, CTR-mode adaptation runs at **3.72 cycles/byte**
    [*](https://github.com/jkivilin/supercop-blockciphers).

# Compiling and testing

## Prerequisites
- OpenSSL: used for reference implementation.
- GNU make
- GCC x86-64
- Optionally GCC i686
- Optionally GCC aarch64
- Optionally GCC powerpc64
- Optionally GCC powerpc64le
- Ubuntu 22.04 packages: gcc gcc-i686-linux-gnu gcc-aarch64-linux-gnu gcc-powerpc64le-linux-gnu gcc-powerpc64-linux-gnu make

## Compiling
Clone repository and run 'make'…
<pre>
$ make
gcc -O2 -Wall -march=sandybridge -mtune=native -msse4.1 -maes -c camellia_simd128_with_aes_instruction_set.c -o camellia_simd128_with_x86_aesni.o
gcc -O2 -Wall -c main.c -o main_simd128.o
gcc -O2 -Wall -c camellia-BSD-1.2.0/camellia.c -o camellia_ref_x86-64.o
gcc camellia_simd128_with_x86_aesni.o main_simd128.o camellia_ref_x86-64.o -o test_simd128_intrinsics_x86_64
gcc -O2 -Wall -march=haswell -mtune=native -mavx2 -maes -c camellia_simd128_with_aes_instruction_set.c -o camellia_simd128_with_x86_aesni_avx2.o
gcc -O2 -Wall -march=haswell -mtune=native -mavx2 -maes -c camellia_simd256_x86_aesni.c -o camellia_simd256_x86_aesni.o
gcc -O2 -Wall -DUSE_SIMD256 -c main.c -o main_simd256.o
gcc camellia_simd128_with_x86_aesni_avx2.o camellia_simd256_x86_aesni.o main_simd256.o camellia_ref_x86-64.o -o test_simd256_intrinsics_x86_64
gcc -O2 -Wall -march=haswell -mtune=native -mavx2 -maes -mvaes -DUSE_VAES -c camellia_simd256_x86_aesni.c -o camellia_simd256_x86_vaes.o
gcc camellia_simd128_with_x86_aesni_avx2.o camellia_simd256_x86_vaes.o main_simd256.o camellia_ref_x86-64.o -o test_simd256_intrinsics_x86_64_vaes
gcc -O2 -Wall -march=znver3 -mavx512f -mavx512vl -mavx512bw -mavx512dq -mavx512vbmi -mavx512ifma -mavx512vpopcntdq -mavx512vbmi2 -mavx512bitalg -mavx512vnni -mprefer-vector-width=512 -mavx2 -maes -mvaes -mgfni -c camellia_simd128_with_aes_instruction_set.c -o camellia_simd128_with_x86_aesni_avx512.o
gcc -O2 -Wall -march=znver3 -mavx512f -mavx512vl -mavx512bw -mavx512dq -mavx512vbmi -mavx512ifma -mavx512vpopcntdq -mavx512vbmi2 -mavx512bitalg -mavx512vnni -mprefer-vector-width=512 -mavx2 -maes -mvaes -mgfni -DUSE_VAES -c camellia_simd256_x86_aesni.c -o camellia_simd256_x86_vaes_avx512.o
gcc camellia_simd128_with_x86_aesni_avx512.o camellia_simd256_x86_vaes_avx512.o main_simd256.o camellia_ref_x86-64.o -o test_simd256_intrinsics_x86_64_vaes_avx512
gcc -O2 -Wall -march=znver3 -mavx512f -mavx512vl -mavx512bw -mavx512dq -mavx512vbmi -mavx512ifma -mavx512vpopcntdq -mavx512vbmi2 -mavx512bitalg -mavx512vnni -mprefer-vector-width=512 -mavx2 -maes -mvaes -mgfni -DUSE_GFNI -c camellia_simd256_x86_aesni.c -o camellia_simd256_x86_gfni_avx512.o
gcc camellia_simd128_with_x86_aesni_avx512.o camellia_simd256_x86_gfni_avx512.o main_simd256.o camellia_ref_x86-64.o -o test_simd256_intrinsics_x86_64_gfni_avx512
gcc -O2 -Wall -c camellia_simd128_x86-64_aesni_avx.S -o camellia_simd128_x86-64_aesni_avx.o
gcc camellia_simd128_x86-64_aesni_avx.o main_simd128.o camellia_ref_x86-64.o -o test_simd128_asm_x86_64
gcc -O2 -Wall -c camellia_simd256_x86-64_aesni_avx2.S -o camellia_simd256_x86-64_aesni_avx2.o
gcc camellia_simd128_x86-64_aesni_avx.o camellia_simd256_x86-64_aesni_avx2.o main_simd256.o camellia_ref_x86-64.o -o test_simd256_asm_x86_64
i686-linux-gnu-gcc -O2 -Wall -march=sandybridge -mtune=native -msse4.1 -maes -c camellia_simd128_with_aes_instruction_set.c -o camellia_simd128_with_x86_aesni_i386.o
i686-linux-gnu-gcc -O2 -Wall -c main.c -o main_simd128_i386.o
i686-linux-gnu-gcc -O2 -Wall -c camellia-BSD-1.2.0/camellia.c -o camellia_ref_i386.o
i686-linux-gnu-gcc camellia_simd128_with_x86_aesni_i386.o main_simd128_i386.o camellia_ref_i386.o -o test_simd128_intrinsics_i386
i686-linux-gnu-gcc -O2 -Wall -march=haswell -mtune=native -mavx2 -maes -c camellia_simd128_with_aes_instruction_set.c -o camellia_simd128_with_x86_aesni_avx2_i386.o
i686-linux-gnu-gcc -O2 -Wall -march=haswell -mtune=native -mavx2 -maes -c camellia_simd256_x86_aesni.c -o camellia_simd256_x86_aesni_i386.o
i686-linux-gnu-gcc -O2 -Wall -DUSE_SIMD256 -c main.c -o main_simd256_i386.o
i686-linux-gnu-gcc camellia_simd128_with_x86_aesni_avx2_i386.o camellia_simd256_x86_aesni_i386.o main_simd256_i386.o camellia_ref_i386.o -o test_simd256_intrinsics_i386
aarch64-linux-gnu-gcc -O2 -Wall -march=armv8-a+crypto -mtune=cortex-a53 -c camellia_simd128_with_aes_instruction_set.c -o camellia_simd128_with_aarch64_ce.o
aarch64-linux-gnu-gcc -O2 -Wall -march=armv8-a+crypto -mtune=cortex-a53 -c main.c -o main_simd128_aarch64.o
aarch64-linux-gnu-gcc -O2 -Wall -march=armv8-a+crypto -mtune=cortex-a53 -c camellia-BSD-1.2.0/camellia.c -o camellia_ref_aarch64.o
aarch64-linux-gnu-gcc camellia_simd128_with_aarch64_ce.o main_simd128_aarch64.o camellia_ref_aarch64.o -o test_simd128_intrinsics_aarch64
powerpc64le-linux-gnu-gcc -O2 -Wall -mcpu=power8 -maltivec -mvsx -mcrypto -c camellia_simd128_with_aes_instruction_set.c -o camellia_simd128_with_ppc64le.o
powerpc64le-linux-gnu-gcc -O2 -Wall -mcpu=power8 -maltivec -mvsx -mcrypto -c main.c -o main_simd128_ppc64le.o
powerpc64le-linux-gnu-gcc -O2 -Wall -mcpu=power8 -maltivec -mvsx -mcrypto -c camellia-BSD-1.2.0/camellia.c -o camellia_ref_ppc64le.o
powerpc64le-linux-gnu-gcc camellia_simd128_with_ppc64le.o main_simd128_ppc64le.o camellia_ref_ppc64le.o -o test_simd128_intrinsics_ppc64le
powerpc64-linux-gnu-gcc -O2 -Wall -mcpu=power8 -maltivec -mvsx -mcrypto -c camellia_simd128_with_aes_instruction_set.c -o camellia_simd128_with_ppc64be.o
powerpc64-linux-gnu-gcc -O2 -Wall -mcpu=power8 -maltivec -mvsx -mcrypto -c main.c -o main_simd128_ppc64be.o
powerpc64-linux-gnu-gcc -O2 -Wall -mcpu=power8 -maltivec -mvsx -mcrypto -c camellia-BSD-1.2.0/camellia.c -o camellia_ref_ppc64be.o
powerpc64-linux-gnu-gcc camellia_simd128_with_ppc64be.o main_simd128_ppc64be.o camellia_ref_ppc64be.o -o test_simd128_intrinsics_ppc64be
</pre>

## Testing
Twelve executables are build. Run executables to verify implementation against test-vectors (with
128-bit, 192-bit and 256-bit key lengths) and benchmark against reference implementation from
OpenSSL (with 128-bit key length).

Executables are:
- `test_simd128_asm_x86_64`: SIMD128 only, for testing assembly x86-64/AES-NI/AVX implementation without AVX2.
- `test_simd128_intrinsics_i386`: SIMD128 only, for testing intrinsics implementation on i386/AES-NI/AVX without AVX2.
- `test_simd128_intrinsics_x86_64`: SIMD128 only, for testing intrinsics implementation on x86_64/AES-NI/AVX without AVX2.
- `test_simd128_intrinsics_aarch64`: SIMD128 only, for testing intrinsics implementation on ARMv8 AArch64 with Crypto Extensions.
- `test_simd128_intrinsics_ppc64be`: SIMD128 only, for testing intrinsics implementation on big-endian 64-bit PowerPC with crypto instruction set.
- `test_simd128_intrinsics_ppc64le`: SIMD128 only, for testing intrinsics implementation on little-endian 64-bit PowerPC with crypto instruction set.
- `test_simd256_asm_x86_64`: SIMD256 and SIMD128, for testing assembly x86-64/AES-NI/AVX2 implementations.
- `test_simd256_intrinsics_i386`: SIMD256 and SIMD128, for testing intrinsics implementations on i386/AES-NI/AVX2.
- `test_simd256_intrinsics_x86_64`: SIMD256 and SIMD128, for testing intrinsics implementation on x86_64/AES-NI/AVX2.
- `test_simd256_intrinsics_x86_64_vaes`: SIMD256 and SIMD128, for testing intrinsics implementation on x86_64/VAES/AVX2.
- `test_simd256_intrinsics_x86_64_vaes_avx512`: SIMD256 and SIMD128, for testing intrinsics implementation on x86_64/VAES/AVX512.
- `test_simd256_intrinsics_x86_64_gfni_avx512`: SIMD256 and SIMD128, for testing intrinsics implementation on x86_64/GFNI/AVX512.

For example, output of `test_simd256_asm_x86_64` and `test_simd256_intrinsics_x86_64_gfni_avx512` on AMD Ryzen 9 7900X:
<pre>
$ ./test_simd256_asm_x86_64
./test_simd256_asm_x86_64:
selftest: comparing camellia-128 test vectors against reference implementation...
selftest: comparing camellia-192 test vectors against reference implementation...
selftest: comparing camellia-256 test vectors against reference implementation...
selftest: checking 16-block parallel camellia-128/SIMD128 against test vectors...
selftest: checking 32-block parallel camellia-128/SIMD256 against test vectors...
selftest: checking 16-block parallel camellia-128/SIMD128 against large test vectors...
selftest: checking 32-block parallel camellia-128/SIMD256 against large test vectors...
           camellia-128 reference encryption:    318.910 Mebibytes/s,    334.402 Megabytes/s
           camellia-128 reference decryption:    319.163 Mebibytes/s,    334.667 Megabytes/s
 camellia-128 SIMD128 (16 blocks) encryption:   1356.480 Mebibytes/s,   1422.373 Megabytes/s
 camellia-128 SIMD128 (16 blocks) decryption:   1352.072 Mebibytes/s,   1417.750 Megabytes/s
 camellia-128 SIMD256 (32 blocks) encryption:   2281.139 Mebibytes/s,   2391.947 Megabytes/s
 camellia-128 SIMD256 (32 blocks) decryption:   2280.521 Mebibytes/s,   2391.299 Megabytes/s
$ ./test_simd256_intrinsics_x86_64_gfni_avx512
./test_simd256_intrinsics_x86_64_gfni_avx512:
selftest: comparing camellia-128 test vectors against reference implementation...
selftest: comparing camellia-192 test vectors against reference implementation...
selftest: comparing camellia-256 test vectors against reference implementation...
selftest: checking 16-block parallel camellia-128/SIMD128 against test vectors...
selftest: checking 32-block parallel camellia-128/SIMD256 against test vectors...
selftest: checking 16-block parallel camellia-128/SIMD128 against large test vectors...
selftest: checking 32-block parallel camellia-128/SIMD256 against large test vectors...
           camellia-128 reference encryption:    319.558 Mebibytes/s,    335.081 Megabytes/s
           camellia-128 reference decryption:    318.429 Mebibytes/s,    333.897 Megabytes/s
 camellia-128 SIMD128 (16 blocks) encryption:   1384.961 Mebibytes/s,   1452.237 Megabytes/s
 camellia-128 SIMD128 (16 blocks) decryption:   1406.697 Mebibytes/s,   1475.028 Megabytes/s
 camellia-128 SIMD256 (32 blocks) encryption:   5808.340 Mebibytes/s,   6090.486 Megabytes/s
 camellia-128 SIMD256 (32 blocks) decryption:   5798.628 Mebibytes/s,   6080.302 Megabytes/s
</pre>

For example, output of `test_simd256_intrinsics_aarch64` on ARM Cortex-A53 (648 Mhz):
<pre>
$ ./test_simd128_intrinsics_aarch64
./test_simd128_intrinsics_aarch64:
selftest: comparing camellia-128 against reference implementation...
selftest: comparing camellia-192 against reference implementation...
selftest: comparing camellia-256 against reference implementation...
selftest: checking 16-block parallel camellia-128/SIMD128 against test vectors...
selftest: checking 16-block parallel camellia-128/SIMD128 against large test vectors...
           camellia-128 reference encryption:     21.633 Mebibytes/s,     22.684 Megabytes/s
           camellia-128 reference decryption:     21.866 Mebibytes/s,     22.928 Megabytes/s
 camellia-128 SIMD128 (16 blocks) encryption:     37.133 Mebibytes/s,     38.937 Megabytes/s
 camellia-128 SIMD128 (16 blocks) decryption:     36.847 Mebibytes/s,     38.637 Megabytes/s
</pre>
