# About
This is repository, you find x86 AES and ARMv8 Crypto Extension accelerated vector
implementations of [Camellia cipher](https://info.isl.ntt.co.jp/crypt/eng/camellia/).
For x86, both Intel C intrinsics and x86-64 assembly implementations are provided,
with assembly yielding best performance and instrinsics implementation being
easier to port to other instruction sets. For ARM AArch64, 128-bit vector
instrinsics implementation is provided.

# How it works
It happens to be that Camellia uses s-box construction is very similar to AES SubBytes.
With help of affine transforms, one can perform Camellia s-boxes with AES SubBytes and
implementations here use SubBytes from AES-NI instruction. Due to the structure of
Camellia cipher, at least 16 blocks needs to be processed in parallel for the best
performance. Details can be found in [Block Ciphers: Fast Implementations on x86-64
Architecture](http://urn.fi/URN:NBN:fi:oulu-201305311409) (pages 42-50).

Because of the requirement for parallel input blocks, these implementations are
best suited for parallelizable cipher modes of operation, such as CTR, CBC decryption,
CFB decryption, XTS, OCB, etc.

# Implementations

## SIMD128
The SIMD128 (128-bit vector) implementation variants process 16 blocks in parallel.

- [camellia_simd128_with_aes_instruction_set.c](camellia_simd128_with_aes_instruction_set.c):
  - C intrinsics implementation for x86 with AES-NI and for ARMv8 with Crypto Extension.
    - x86 implementation requires AES-NI and either SSE4.1 or AVX instruction set and gets best performance with x86-64 + AVX.
    - ARM implementation requires AArch64, NEON and ARMv8 crypto-extension instruction set.
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
  - Intel C intrinsics implentation for x86 with AES-NI. Requires either AVX2 instruction set and gets best
  performance with x86-64 + AVX2.
  - On AMD Ryzen 3700X, when compiled for x86-64+AVX2, this implementation is **~5.9 times faster** than
    reference.

- [camellia_simd256_x86-64_aesni_avx2.S](camellia_simd256_x86-64_aesni_avx2.S):
  - GCC assembly implementation for x86-64 with AES-NI and AVX2.
  - On AMD Ryzen 3700X, when compiled for x86-64+AVX2, this implementation is **~6.6 times faster** than
    reference.
  - On Intel Haswell, CTR-mode adaptation runs at **3.72 cycles/byte**
    [*](https://github.com/jkivilin/supercop-blockciphers).

# Compiling and testing

## Prerequisites
- OpenSSL: used for reference implementation.
- GNU make
- GCC x86-64
- Optionally GCC i386
- Optionally GCC AArch64
- Ubuntu 20.04 packages: gcc gcc-i686-linux-gnu gcc-aarch64-linux-gnu libssl-dev libssl-dev:i386 make

## Compiling
Clone repository and run 'make'…
<pre>
$ make
gcc -O2 -Wall -march=sandybridge -mtune=native -msse4.1 -maes -c camellia_simd128_x86_aesni.c -o camellia_simd128_x86_aesni.o
gcc -O2 -Wall -c main.c -o main_simd128.o
gcc camellia_simd128_x86_aesni.o main_simd128.o -o test_simd128_intrinsics_x86_64 -lcrypto
gcc -O2 -Wall -march=sandybridge -mtune=native -mavx2 -maes -c camellia_simd128_x86_aesni.c -o camellia_simd128_x86_aesni_avx2.o
gcc -O2 -Wall -march=sandybridge -mtune=native -mavx2 -maes -c camellia_simd256_x86_aesni.c -o camellia_simd256_x86_aesni.o
gcc -O2 -Wall -DUSE_SIMD256 -c main.c -o main_simd256.o
gcc camellia_simd128_x86_aesni_avx2.o camellia_simd256_x86_aesni.o main_simd256.o -o test_simd256_intrinsics_x86_64 -lcrypto
gcc -O2 -Wall -c camellia_simd128_x86-64_aesni_avx.S -o camellia_simd128_x86-64_aesni_avx.o
gcc camellia_simd128_x86-64_aesni_avx.o main_simd128.o -o test_simd128_asm_x86_64 -lcrypto
gcc -O2 -Wall -c camellia_simd256_x86-64_aesni_avx2.S -o camellia_simd256_x86-64_aesni_avx2.o
gcc camellia_simd128_x86-64_aesni_avx.o camellia_simd256_x86-64_aesni_avx2.o main_simd256.o -o test_simd256_asm_x86_64 -lcrypto
i686-linux-gnu-gcc -O2 -Wall -march=sandybridge -mtune=native -msse4.1 -maes -c camellia_simd128_x86_aesni.c -o camellia_simd128_x86_aesni_i386.o
i686-linux-gnu-gcc -O2 -Wall -c main.c -o main_simd128_i386.o
i686-linux-gnu-gcc camellia_simd128_x86_aesni_i386.o main_simd128_i386.o -o test_simd128_intrinsics_i386 -lcrypto
i686-linux-gnu-gcc -O2 -Wall -march=sandybridge -mtune=native -mavx2 -maes -c camellia_simd128_x86_aesni.c -o camellia_simd128_x86_aesni_avx2_i386.o
i686-linux-gnu-gcc -O2 -Wall -march=sandybridge -mtune=native -mavx2 -maes -c camellia_simd256_x86_aesni.c -o camellia_simd256_x86_aesni_i386.o
i686-linux-gnu-gcc -O2 -Wall -DUSE_SIMD256 -c main.c -o main_simd256_i386.o
i686-linux-gnu-gcc camellia_simd128_x86_aesni_avx2_i386.o camellia_simd256_x86_aesni_i386.o main_simd256_i386.o -o test_simd256_intrinsics_i386 -lcrypto
aarch64-linux-gnu-gcc -O2 -Wall -march=armv8-a+crypto -mtune=cortex-a53 -c camellia_simd128_with_aes_instruction_set.c -o camellia_simd128_with_aarch64_ce.o
aarch64-linux-gnu-gcc -O2 -Wall -c main.c -o main_simd128_aarch64.o
aarch64-linux-gnu-gcc camellia_simd128_with_aarch64_ce.o main_simd128_aarch64.o -o test_simd128_intrinsics_aarch64 -lcrypto
</pre>

## Testing
Six executables are build. Run executables to verify implementation against test-vectors (with
128-bit, 192-bit and 256-bit key lengths) and benchmark against reference implementation from
OpenSSL (with 128-bit key length).

Executables are:
- `test_simd128_asm_x86_64`: SIMD128 only, for testing assembly x86-64/AVX implementation without AVX2.
- `test_simd128_intrinsics_i386`: SIMD128 only, for testing intrinsics implementation on i386/AVX without AVX2.
- `test_simd128_intrinsics_x86_64`: SIMD128 only, for testing intrinsics implementation on x86_64/AVX without AVX2.
- `test_simd128_intrinsics_aarch64`: SIMD128 only, for testing intrinsics implementation on ARMv8 AArch64 with Crypto Extensions.
- `test_simd256_asm_x86_64`: SIMD256 and SIMD128, for testing assembly x86-64/AVX/AVX2 implementations.
- `test_simd256_intrinsics_i386`: SIMD256 and SIMD128, for testing intrinsics implementations on i386/AVX/AVX2.
- `test_simd256_intrinsics_x86_64`: SIMD256 and SIMD128, for testing intrinsics implementation on x86_64/AVX/AVX2.

For example, output of `test_simd256_asm_x86_64` and `test_simd256_intrinsics_x86_64` on AMD Ryzen 3700X:
<pre>
$ ./test_simd256_asm_x86_64
./test_simd256_asm_x86_64:
selftest: comparing camellia-128 against reference implementation...
selftest: comparing camellia-192 against reference implementation...
selftest: comparing camellia-256 against reference implementation...
selftest: checking 16-block parallel camellia-128/SIMD128 against test vectors...
selftest: checking 32-block parallel camellia-128/SIMD256 against test vectors...
selftest: checking 16-block parallel camellia-128/SIMD128 against large test vectors...
selftest: checking 32-block parallel camellia-128/SIMD256 against large test vectors...
           camellia-128 reference encryption:    237.327 Mebibytes/s,    248.855 Megabytes/s
           camellia-128 reference decryption:    236.818 Mebibytes/s,    248.322 Megabytes/s
 camellia-128 SIMD128 (16 blocks) encryption:    982.391 Mebibytes/s,   1030.112 Megabytes/s
 camellia-128 SIMD128 (16 blocks) decryption:    976.979 Mebibytes/s,   1024.437 Megabytes/s
 camellia-128 SIMD256 (32 blocks) encryption:   1590.665 Mebibytes/s,   1667.934 Megabytes/s
 camellia-128 SIMD256 (32 blocks) decryption:   1596.805 Mebibytes/s,   1674.372 Megabytes/s
$ ./test_simd256_intrinsics_x86_64
./test_simd256_intrinsics_x86_64:
selftest: comparing camellia-128 against reference implementation...
selftest: comparing camellia-192 against reference implementation...
selftest: comparing camellia-256 against reference implementation...
selftest: checking 16-block parallel camellia-128/SIMD128 against test vectors...
selftest: checking 32-block parallel camellia-128/SIMD256 against test vectors...
selftest: checking 16-block parallel camellia-128/SIMD128 against large test vectors...
selftest: checking 32-block parallel camellia-128/SIMD256 against large test vectors...
           camellia-128 reference encryption:    236.199 Mebibytes/s,    247.673 Megabytes/s
           camellia-128 reference decryption:    234.039 Mebibytes/s,    245.408 Megabytes/s
 camellia-128 SIMD128 (16 blocks) encryption:    842.394 Mebibytes/s,    883.314 Megabytes/s
 camellia-128 SIMD128 (16 blocks) decryption:    844.640 Mebibytes/s,    885.669 Megabytes/s
 camellia-128 SIMD256 (32 blocks) encryption:   1457.799 Mebibytes/s,   1528.613 Megabytes/s
 camellia-128 SIMD256 (32 blocks) decryption:   1462.731 Mebibytes/s,   1533.785 Megabytes/s
</pre>
