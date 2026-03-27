//+build !noasm !appengine

// SSE4 vectorized bloom filter block operations.
// _check_block_sse4 replaced: was scalar (8 sequential imul/bt/branch),
// now uses PSHUFD+PMULLD+IEEE754 float trick for parallel bit-test.
// Processes salts[0..3] and salts[4..7] in two 128-bit passes.

#include "textflag.h"

// salts[0..3]
DATA salts_lo_sse4<>+0x00(SB)/8, $0x44974d9147b6137b
DATA salts_lo_sse4<>+0x08(SB)/8, $0xa2b7289d8824ad5b
GLOBL salts_lo_sse4<>(SB), (NOPTR+RODATA), $16

// salts[4..7]
DATA salts_hi_sse4<>+0x00(SB)/8, $0x2df1424b705495c7
DATA salts_hi_sse4<>+0x08(SB)/8, $0x5c6bfb319efc4947
GLOBL salts_hi_sse4<>(SB), (NOPTR+RODATA), $16

// IEEE 754 float 1.0 = 0x3F800000 (used for the 1<<n trick)
DATA float_one_sse4<>+0x00(SB)/8, $0x3f8000003f800000
DATA float_one_sse4<>+0x08(SB)/8, $0x3f8000003f800000
GLOBL float_one_sse4<>(SB), (NOPTR+RODATA), $16

TEXT ·_check_block_sse4(SB), NOSPLIT, $0-32

	MOVQ bitset32+0(FP), DI
	MOVQ len+8(FP), SI
	MOVQ hash+16(FP), DX

	// key = low 32 bits of hash
	MOVL DX, AX

	// bucket_index calculation (byte offset)
	MOVQ DX, CX
	SHRQ $32, CX
	LEAL 7(SI), R8
	TESTL SI, SI
	JNS  bucket_len_ok_sse4
	MOVL R8, SI
bucket_len_ok_sse4:
	MOVL SI, R8
	SARL $3, R8
	MOVLQSX R8, R8
	IMULQ CX, R8
	SHRQ $27, R8
	MOVQ $0x3FFFFFFE0, CX
	ANDQ R8, CX

	// Broadcast key to all 4 dword lanes
	MOVD AX, X0
	PSHUFD $0, X0, X0

	// Load IEEE 754 1.0f constant
	MOVOU float_one_sse4<>(SB), X5

	// --- Half 1: salts[0..3], block words 0..3 ---
	MOVOU salts_lo_sse4<>(SB), X1
	MOVOU X0, X2
	LONG $0x40380f66; BYTE $0xd1 // pmulld xmm2, xmm1 (SSE4.1)
	PSRLL $27, X2
	PSLLL $23, X2
	LONG $0xd5fe0f66             // paddd xmm2, xmm5
	LONG $0xd25b0ff3             // cvttps2dq xmm2, xmm2

	// Load block[0..3] and test
	MOVOU (DI)(CX*1), X3
	PAND  X2, X3
	PCMPEQL X2, X3

	// --- Half 2: salts[4..7], block words 4..7 ---
	MOVOU salts_hi_sse4<>(SB), X1
	LONG $0x40380f66; BYTE $0xc1 // pmulld xmm0, xmm1 (SSE4.1)
	PSRLL $27, X0
	PSLLL $23, X0
	LONG $0xc5fe0f66             // paddd xmm0, xmm5
	LONG $0xc05b0ff3             // cvttps2dq xmm0, xmm0

	// Load block[4..7] and test
	MOVOU 16(DI)(CX*1), X4
	PAND  X0, X4
	PCMPEQL X0, X4

	// Combine both halves: all 8 dwords must match
	PAND X3, X4
	PMOVMSKB X4, AX

	// All 16 bytes must be 0xFF
	CMPL AX, $0xFFFF
	SETEQ AX
	MOVB AX, result+24(FP)
	RET

// Keep existing _insert_block_sse4 and _insert_bulk_sse4 unchanged

DATA LCDATA1<>+0x000(SB)/8, $0x44974d9147b6137b
DATA LCDATA1<>+0x008(SB)/8, $0xa2b7289d8824ad5b
DATA LCDATA1<>+0x010(SB)/8, $0x3f8000003f800000
DATA LCDATA1<>+0x018(SB)/8, $0x3f8000003f800000
DATA LCDATA1<>+0x020(SB)/8, $0x2df1424b705495c7
DATA LCDATA1<>+0x028(SB)/8, $0x5c6bfb319efc4947
GLOBL LCDATA1<>(SB), 8, $48

TEXT ·_insert_block_sse4(SB), $0-24

	MOVQ bitset32+0(FP), DI
	MOVQ len+8(FP), SI
	MOVQ hash+16(FP), DX
	LEAQ LCDATA1<>(SB), BP

	LONG $0xc26e0f66                       // movd    xmm0, edx
	LONG $0x20eac148                       // shr    rdx, 32
	WORD $0x468d; BYTE $0x07               // lea    eax, [rsi + 7]
	WORD $0xf685                           // test    esi, esi
	WORD $0x490f; BYTE $0xc6               // cmovns    eax, esi
	WORD $0xf8c1; BYTE $0x03               // sar    eax, 3
	WORD $0x6348; BYTE $0xc8               // movsxd    rcx, eax
	LONG $0xcaaf0f48                       // imul    rcx, rdx
	LONG $0x1be9c148                       // shr    rcx, 27
	QUAD $0x0003ffffffe0b848; WORD $0x0000 // mov    rax, 17179869152
	WORD $0x2148; BYTE $0xc8               // and    rax, rcx
	LONG $0xc0700f66; BYTE $0x00           // pshufd    xmm0, xmm0, 0
	LONG $0x4d6f0f66; BYTE $0x00           // movdqa    xmm1, oword 0[rbp] /* [rip + .LCPI2_0] */
	LONG $0x40380f66; BYTE $0xc8           // pmulld    xmm1, xmm0
	LONG $0xd1720f66; BYTE $0x1b           // psrld    xmm1, 27
	LONG $0xf1720f66; BYTE $0x17           // pslld    xmm1, 23
	LONG $0x556f0f66; BYTE $0x10           // movdqa    xmm2, oword 16[rbp] /* [rip + .LCPI2_1] */
	LONG $0xcafe0f66                       // paddd    xmm1, xmm2
	LONG $0xc95b0ff3                       // cvttps2dq    xmm1, xmm1
	LONG $0x071c100f                       // movups    xmm3, oword [rdi + rax]
	WORD $0x560f; BYTE $0xd9               // orps    xmm3, xmm1
	LONG $0x074c100f; BYTE $0x10           // movups    xmm1, oword [rdi + rax + 16]
	LONG $0x071c110f                       // movups    oword [rdi + rax], xmm3
	LONG $0x40380f66; WORD $0x2045         // pmulld    xmm0, oword 32[rbp] /* [rip + .LCPI2_2] */
	LONG $0xd0720f66; BYTE $0x1b           // psrld    xmm0, 27
	LONG $0xf0720f66; BYTE $0x17           // pslld    xmm0, 23
	LONG $0xc2fe0f66                       // paddd    xmm0, xmm2
	LONG $0xc05b0ff3                       // cvttps2dq    xmm0, xmm0
	WORD $0x560f; BYTE $0xc1               // orps    xmm0, xmm1
	LONG $0x0744110f; BYTE $0x10           // movups    oword [rdi + rax + 16], xmm0
	RET

DATA LCDATA2<>+0x000(SB)/8, $0x44974d9147b6137b
DATA LCDATA2<>+0x008(SB)/8, $0xa2b7289d8824ad5b
DATA LCDATA2<>+0x010(SB)/8, $0x3f8000003f800000
DATA LCDATA2<>+0x018(SB)/8, $0x3f8000003f800000
DATA LCDATA2<>+0x020(SB)/8, $0x2df1424b705495c7
DATA LCDATA2<>+0x028(SB)/8, $0x5c6bfb319efc4947
GLOBL LCDATA2<>(SB), 8, $48

TEXT ·_insert_bulk_sse4(SB), $0-32

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
	LONG $0x456f0f66; BYTE $0x00           // movdqa    xmm0, oword 0[rbp] /* [rip + .LCPI3_0] */
	LONG $0x4d6f0f66; BYTE $0x10           // movdqa    xmm1, oword 16[rbp] /* [rip + .LCPI3_1] */
	LONG $0x556f0f66; BYTE $0x20           // movdqa    xmm2, oword 32[rbp] /* [rip + .LCPI3_2] */

LBB3_2:
	LONG $0xf20c8b4c               // mov    r9, qword [rdx + 8*rsi]
	LONG $0x6e0f4166; BYTE $0xd9   // movd    xmm3, r9d
	LONG $0x20e9c149               // shr    r9, 32
	LONG $0xc8af0f4c               // imul    r9, rax
	LONG $0x1be9c149               // shr    r9, 27
	WORD $0x214d; BYTE $0xc1       // and    r9, r8
	LONG $0xdb700f66; BYTE $0x00   // pshufd    xmm3, xmm3, 0
	LONG $0xe36f0f66               // movdqa    xmm4, xmm3
	LONG $0x40380f66; BYTE $0xe0   // pmulld    xmm4, xmm0
	LONG $0xd4720f66; BYTE $0x1b   // psrld    xmm4, 27
	LONG $0xf4720f66; BYTE $0x17   // pslld    xmm4, 23
	LONG $0xe1fe0f66               // paddd    xmm4, xmm1
	LONG $0xe45b0ff3               // cvttps2dq    xmm4, xmm4
	LONG $0x2c100f42; BYTE $0x0f   // movups    xmm5, oword [rdi + r9]
	WORD $0x560f; BYTE $0xec       // orps    xmm5, xmm4
	LONG $0x64100f42; WORD $0x100f // movups    xmm4, oword [rdi + r9 + 16]
	LONG $0x2c110f42; BYTE $0x0f   // movups    oword [rdi + r9], xmm5
	LONG $0x40380f66; BYTE $0xda   // pmulld    xmm3, xmm2
	LONG $0xd3720f66; BYTE $0x1b   // psrld    xmm3, 27
	LONG $0xf3720f66; BYTE $0x17   // pslld    xmm3, 23
	LONG $0xd9fe0f66               // paddd    xmm3, xmm1
	LONG $0xdb5b0ff3               // cvttps2dq    xmm3, xmm3
	WORD $0x560f; BYTE $0xdc       // orps    xmm3, xmm4
	LONG $0x5c110f42; WORD $0x100f // movups    oword [rdi + r9 + 16], xmm3
	WORD $0xff48; BYTE $0xc6       // inc    rsi
	WORD $0x3948; BYTE $0xf1       // cmp    rcx, rsi
	JNE  LBB3_2

LBB3_4:
	RET
