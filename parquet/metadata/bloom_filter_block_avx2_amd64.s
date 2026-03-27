//+build !noasm !appengine

// AVX2 vectorized bloom filter block operations.
// _check_block_avx2 replaced: was scalar (8 sequential imul/bt/branch),
// now uses VPBROADCASTD+VPMULLD+VPSLLVD for parallel 8-salt bit-test.

#include "textflag.h"

// 8 SALT constants from the Parquet bloom filter spec
DATA salts_avx2<>+0x00(SB)/8, $0x44974d9147b6137b
DATA salts_avx2<>+0x08(SB)/8, $0xa2b7289d8824ad5b
DATA salts_avx2<>+0x10(SB)/8, $0x2df1424b705495c7
DATA salts_avx2<>+0x18(SB)/8, $0x5c6bfb319efc4947
GLOBL salts_avx2<>(SB), (NOPTR+RODATA), $32

DATA ones_avx2<>+0x00(SB)/4, $0x00000001
GLOBL ones_avx2<>(SB), (NOPTR+RODATA), $4

TEXT ·_check_block_avx2(SB), NOSPLIT, $0-32

	MOVQ bitset32+0(FP), DI
	MOVQ len+8(FP), SI
	MOVQ hash+16(FP), DX

	// key = low 32 bits of hash
	MOVL DX, AX

	// bucket_index = ((hash >> 32) * (len/8)) >> 32
	// byte_offset = bucket_index * 32
	MOVQ DX, CX
	SHRQ $32, CX
	LEAL 7(SI), R8
	TESTL SI, SI
	JNS  bucket_len_ok_avx2
	MOVL R8, SI
bucket_len_ok_avx2:
	MOVL SI, R8
	SARL $3, R8
	MOVLQSX R8, R8
	IMULQ CX, R8
	SHRQ $27, R8
	MOVQ $0x3FFFFFFE0, CX
	ANDQ R8, CX

	// Broadcast key to all 8 dword lanes
	MOVD AX, X0
	VPBROADCASTD X0, Y0

	// Multiply by 8 SALT constants in parallel
	VPMULLD salts_avx2<>(SB), Y0, Y0

	// Shift right by 27 to get bit positions (0-31)
	VPSRLD $27, Y0, Y0

	// Create bit masks: 1 << position for each lane
	VPBROADCASTD ones_avx2<>(SB), Y1
	VPSLLVD Y0, Y1, Y0

	// Load 8-word block and test all bits in parallel
	VMOVDQU (DI)(CX*1), Y1
	VPAND Y0, Y1, Y1
	VPCMPEQD Y0, Y1, Y1
	VPMOVMSKB Y1, AX

	VZEROUPPER

	// All 32 bytes must be 0xFF (all 8 dwords matched)
	CMPL AX, $-1
	SETEQ AX
	MOVB AX, result+24(FP)
	RET

// Keep existing _insert_block_avx2 and _insert_bulk_avx2 unchanged
// (they already use genuine AVX2 SIMD)

DATA LCDATA1<>+0x000(SB)/8, $0x44974d9147b6137b
DATA LCDATA1<>+0x008(SB)/8, $0xa2b7289d8824ad5b
DATA LCDATA1<>+0x010(SB)/8, $0x2df1424b705495c7
DATA LCDATA1<>+0x018(SB)/8, $0x5c6bfb319efc4947
DATA LCDATA1<>+0x020(SB)/8, $0x0000000000000001
GLOBL LCDATA1<>(SB), 8, $40

TEXT ·_insert_block_avx2(SB), $0-24

	MOVQ bitset32+0(FP), DI
	MOVQ len+8(FP), SI
	MOVQ hash+16(FP), DX
	LEAQ LCDATA1<>(SB), BP

	LONG $0xc26ef9c5                       // vmovd    xmm0, edx
	LONG $0x20eac148                       // shr    rdx, 32
	WORD $0x468d; BYTE $0x07               // lea    eax, [rsi + 7]
	WORD $0xf685                           // test    esi, esi
	WORD $0x490f; BYTE $0xc6               // cmovns    eax, esi
	WORD $0xf8c1; BYTE $0x03               // sar    eax, 3
	WORD $0x9848                           // cdqe
	LONG $0xc2af0f48                       // imul    rax, rdx
	LONG $0x1be8c148                       // shr    rax, 27
	QUAD $0x0003ffffffe0b948; WORD $0x0000 // mov    rcx, 17179869152
	LONG $0x587de2c4; BYTE $0xc0           // vpbroadcastd    ymm0, xmm0
	LONG $0x407de2c4; WORD $0x0045         // vpmulld    ymm0, ymm0, yword 0[rbp] /* [rip + .LCPI2_0] */
	WORD $0x2148; BYTE $0xc1               // and    rcx, rax
	LONG $0xd072fdc5; BYTE $0x1b           // vpsrld    ymm0, ymm0, 27
	LONG $0x587de2c4; WORD $0x204d         // vpbroadcastd    ymm1, dword 32[rbp] /* [rip + .LCPI2_1] */
	LONG $0x4775e2c4; BYTE $0xc0           // vpsllvd    ymm0, ymm1, ymm0
	LONG $0x04ebfdc5; BYTE $0x0f           // vpor    ymm0, ymm0, yword [rdi + rcx]
	LONG $0x047ffec5; BYTE $0x0f           // vmovdqu    yword [rdi + rcx], ymm0
	VZEROUPPER
	RET

DATA LCDATA2<>+0x000(SB)/8, $0x44974d9147b6137b
DATA LCDATA2<>+0x008(SB)/8, $0xa2b7289d8824ad5b
DATA LCDATA2<>+0x010(SB)/8, $0x2df1424b705495c7
DATA LCDATA2<>+0x018(SB)/8, $0x5c6bfb319efc4947
DATA LCDATA2<>+0x020(SB)/8, $0x0000000000000001
GLOBL LCDATA2<>(SB), 8, $40

TEXT ·_insert_bulk_avx2(SB), $0-32

	MOVQ bitset32+0(FP), DI
	MOVQ block_len+8(FP), SI
	MOVQ hashes+16(FP), DX
	MOVQ hash_len+24(FP), CX
	LEAQ LCDATA2<>(SB), BP

	WORD $0xc985                           // test    ecx, ecx
	JLE  LBB3_4
	WORD $0x468d; BYTE $0x07               // lea    eax, [rsi + 7]
	WORD $0xf685                           // test    esi, esi
	WORD $0x490f; BYTE $0xc6               // cmovns    eax, esi
	WORD $0xf8c1; BYTE $0x03               // sar    eax, 3
	WORD $0x9848                           // cdqe
	WORD $0xc989                           // mov    ecx, ecx
	WORD $0xf631                           // xor    esi, esi
	QUAD $0x0003ffffffe0b849; WORD $0x0000 // mov    r8, 17179869152
	LONG $0x456ffdc5; BYTE $0x00           // vmovdqa    ymm0, yword 0[rbp] /* [rip + .LCPI3_0] */
	LONG $0x587de2c4; WORD $0x204d         // vpbroadcastd    ymm1, dword 32[rbp] /* [rip + .LCPI3_1] */

LBB3_2:
	LONG $0xf20c8b4c               // mov    r9, qword [rdx + 8*rsi]
	LONG $0x6e79c1c4; BYTE $0xd1   // vmovd    xmm2, r9d
	LONG $0x20e9c149               // shr    r9, 32
	LONG $0xc8af0f4c               // imul    r9, rax
	LONG $0x1be9c149               // shr    r9, 27
	WORD $0x214d; BYTE $0xc1       // and    r9, r8
	LONG $0x587de2c4; BYTE $0xd2   // vpbroadcastd    ymm2, xmm2
	LONG $0x406de2c4; BYTE $0xd0   // vpmulld    ymm2, ymm2, ymm0
	LONG $0xd272edc5; BYTE $0x1b   // vpsrld    ymm2, ymm2, 27
	LONG $0x4775e2c4; BYTE $0xd2   // vpsllvd    ymm2, ymm1, ymm2
	LONG $0xeb6da1c4; WORD $0x0f14 // vpor    ymm2, ymm2, yword [rdi + r9]
	LONG $0x7f7ea1c4; WORD $0x0f14 // vmovdqu    yword [rdi + r9], ymm2
	WORD $0xff48; BYTE $0xc6       // inc    rsi
	WORD $0x3948; BYTE $0xf1       // cmp    rcx, rsi
	JNE  LBB3_2

LBB3_4:
	VZEROUPPER
	RET
