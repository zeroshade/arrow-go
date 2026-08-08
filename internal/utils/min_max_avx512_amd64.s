//+build !noasm !appengine

#include "textflag.h"



DATA lcdata_i8<>+0x00(SB)/8, $0x8080808080808080  // INT8_MIN broadcast (for XOR trick)
DATA lcdata_i8<>+0x08(SB)/8, $0x8080808080808080
DATA lcdata_i8<>+0x10(SB)/8, $0x7f7f7f7f7f7f7f7f  // INT8_MAX broadcast (for XOR trick)
DATA lcdata_i8<>+0x18(SB)/8, $0x7f7f7f7f7f7f7f7f
GLOBL lcdata_i8<>(SB), (RODATA|NOPTR), $32

TEXT ·_int8_max_min_avx512(SB), NOSPLIT, $0-32
	MOVQ values+0(FP), DI
	MOVQ length+8(FP), SI
	MOVQ minout+16(FP), DX
	MOVQ maxout+24(FP), CX

	TESTQ SI, SI
	JLE   int8_empty

	CMPQ SI, $64
	JB   int8_scalar_setup

	VPTERNLOGD $0xFF, Z0, Z0, Z0
	VPABSB     Z0, Z0
	VMOVDQA64  Z0, Z1
	VMOVDQA64  Z0, Z2
	VMOVDQA64  Z0, Z3
	VPTERNLOGD $0xFF, Z4, Z4, Z4
	VPXORD     Z0, Z4, Z4
	VMOVDQA64  Z4, Z5
	VMOVDQA64  Z4, Z6
	VMOVDQA64  Z4, Z7

	XORQ  AX, AX
	MOVQ  SI, R8
	ANDQ  $-256, R8  // R8 = number of elements in full 4×64 chunks

	CMPQ R8, $0
	JE   int8_tail64

int8_loop256:
	VMOVDQU8 (DI)(AX*1), Z8
	VMOVDQU8 64(DI)(AX*1), Z9
	VMOVDQU8 128(DI)(AX*1), Z10
	VMOVDQU8 192(DI)(AX*1), Z11
	VPMINSB  Z8, Z0, Z0
	VPMINSB  Z9, Z1, Z1
	VPMINSB  Z10, Z2, Z2
	VPMINSB  Z11, Z3, Z3
	VPMAXSB  Z8, Z4, Z4
	VPMAXSB  Z9, Z5, Z5
	VPMAXSB  Z10, Z6, Z6
	VPMAXSB  Z11, Z7, Z7
	ADDQ     $256, AX
	CMPQ     AX, R8
	JB       int8_loop256

	// Merge 4 min accumulators → Z0, 4 max → Z4
	VPMINSB Z1, Z0, Z0
	VPMINSB Z2, Z0, Z0
	VPMINSB Z3, Z0, Z0
	VPMAXSB Z5, Z4, Z4
	VPMAXSB Z6, Z4, Z4
	VPMAXSB Z7, Z4, Z4

int8_tail64:
	// Process remaining 64-byte chunks
	MOVQ  SI, R9
	ANDQ  $-64, R9
	CMPQ  AX, R9
	JAE   int8_hreduce

int8_tail64_loop:
	VMOVDQU8 (DI)(AX*1), Z8
	VPMINSB  Z8, Z0, Z0
	VPMAXSB  Z8, Z4, Z4
	ADDQ     $64, AX
	CMPQ     AX, R9
	JB       int8_tail64_loop

int8_hreduce:
	// Horizontal reduction: ZMM → YMM → XMM
	VEXTRACTI32X8 $1, Z4, Y5
	VPMAXSB       Y5, Y4, Y4
	VEXTRACTI128  $1, Y4, X5
	VPMAXSB       X5, X4, X4
	// XMM horizontal max via phminposuw trick: XOR with 0x7F to flip, find min, XOR back
	LEAQ    lcdata_i8<>(SB), R13
	VMOVDQU 16(R13), X6
	VPXOR   X4, X6, X4
	VPSRLW  $8, X4, X5
	VPMINUB X5, X4, X4
	VPHMINPOSUW X4, X4
	VMOVD   X4, R10
	XORB    $0x7F, R10       // XOR back to get true max

	VEXTRACTI32X8 $1, Z0, Y1
	VPMINSB       Y1, Y0, Y0
	VEXTRACTI128  $1, Y0, X1
	VPMINSB       X1, X0, X0
	// XMM horizontal min: XOR with 0x80 to make unsigned, phminposuw, XOR back
	VMOVDQU 0(R13), X2
	VPXOR   X0, X2, X0
	VPSRLW  $8, X0, X1
	VPMINUB X1, X0, X0
	VPHMINPOSUW X0, X0
	VMOVD   X0, R11
	XORB    $0x80, R11       // XOR back to get true min

	CMPQ AX, SI
	JE   int8_done

	// Scalar tail
int8_scalar_tail:
	MOVBLSX (DI)(AX*1), R9
	CMPB    R11, R9
	CMOVLGT R9, R11          // if R11 > R9 (min > val), min = val
	CMPB    R10, R9
	CMOVLLT R9, R10          // if R10 < R9 (max < val), max = val
	INCQ    AX
	CMPQ    AX, SI
	JB      int8_scalar_tail
	JMP     int8_done

int8_scalar_setup:
	MOVQ $0x7F, R11  // min = INT8_MAX
	MOVQ $0x80, R10  // max = INT8_MIN (as unsigned byte)
	XORQ AX, AX
	JMP  int8_scalar_tail

int8_empty:
	MOVB $0x7F, (DX)   // *minout = INT8_MAX
	MOVB $0x80, (CX)   // *maxout = INT8_MIN
	VZEROUPPER
	RET

int8_done:
	MOVB R10, (CX)  // *maxout
	MOVB R11, (DX)  // *minout
	VZEROUPPER
	RET


TEXT ·_uint8_max_min_avx512(SB), NOSPLIT, $0-32
	MOVQ values+0(FP), DI
	MOVQ length+8(FP), SI
	MOVQ minout+16(FP), DX
	MOVQ maxout+24(FP), CX

	TESTQ SI, SI
	JLE   uint8_empty

	CMPQ SI, $64
	JB   uint8_scalar_setup

	// Init min to 0xFF (UINT8_MAX), max to 0x00
	VPTERNLOGD $0xFF, Z0, Z0, Z0  // all ones = 0xFF
	VMOVDQA64  Z0, Z1
	VMOVDQA64  Z0, Z2
	VMOVDQA64  Z0, Z3
	VPXORD     Z4, Z4, Z4         // all zeros
	VMOVDQA64  Z4, Z5
	VMOVDQA64  Z4, Z6
	VMOVDQA64  Z4, Z7

	XORQ AX, AX
	MOVQ SI, R8
	ANDQ $-256, R8
	CMPQ R8, $0
	JE   uint8_tail64

uint8_loop256:
	VMOVDQU8 (DI)(AX*1), Z8
	VMOVDQU8 64(DI)(AX*1), Z9
	VMOVDQU8 128(DI)(AX*1), Z10
	VMOVDQU8 192(DI)(AX*1), Z11
	VPMINUB  Z8, Z0, Z0
	VPMINUB  Z9, Z1, Z1
	VPMINUB  Z10, Z2, Z2
	VPMINUB  Z11, Z3, Z3
	VPMAXUB  Z8, Z4, Z4
	VPMAXUB  Z9, Z5, Z5
	VPMAXUB  Z10, Z6, Z6
	VPMAXUB  Z11, Z7, Z7
	ADDQ     $256, AX
	CMPQ     AX, R8
	JB       uint8_loop256

	VPMINUB Z1, Z0, Z0
	VPMINUB Z2, Z0, Z0
	VPMINUB Z3, Z0, Z0
	VPMAXUB Z5, Z4, Z4
	VPMAXUB Z6, Z4, Z4
	VPMAXUB Z7, Z4, Z4

uint8_tail64:
	MOVQ SI, R9
	ANDQ $-64, R9
	CMPQ AX, R9
	JAE  uint8_hreduce

uint8_tail64_loop:
	VMOVDQU8 (DI)(AX*1), Z8
	VPMINUB  Z8, Z0, Z0
	VPMAXUB  Z8, Z4, Z4
	ADDQ     $64, AX
	CMPQ     AX, R9
	JB       uint8_tail64_loop

uint8_hreduce:
	// Max horizontal
	VEXTRACTI32X8 $1, Z4, Y5
	VPMAXUB       Y5, Y4, Y4
	VEXTRACTI128  $1, Y4, X5
	VPMAXUB       X5, X4, X4
	VPTERNLOGD    $0xFF, X6, X6, X6  // all ones
	VPXOR         X4, X6, X4         // NOT to use phminposuw for max
	VPSRLW        $8, X4, X5
	VPMINUB       X5, X4, X4
	VPHMINPOSUW   X4, X4
	VMOVD         X4, R10
	NOTB          R10

	// Min horizontal
	VEXTRACTI32X8 $1, Z0, Y1
	VPMINUB       Y1, Y0, Y0
	VEXTRACTI128  $1, Y0, X1
	VPMINUB       X1, X0, X0
	VPSRLW        $8, X0, X1
	VPMINUB       X1, X0, X0
	VPHMINPOSUW   X0, X0
	VMOVD         X0, R11

	CMPQ AX, SI
	JE   uint8_done

uint8_scalar_tail:
	MOVBQZX (DI)(AX*1), R9
	CMPB    R11, R9
	CMOVQHI R9, R11
	CMPB    R10, R9
	CMOVQCS R9, R10
	INCQ    AX
	CMPQ    AX, SI
	JB      uint8_scalar_tail
	JMP     uint8_done

uint8_scalar_setup:
	MOVQ $0xFF, R11
	XORQ R10, R10
	XORQ AX, AX
	JMP  uint8_scalar_tail

uint8_empty:
	MOVB $0xFF, (DX)
	MOVB $0x00, (CX)
	VZEROUPPER
	RET

uint8_done:
	MOVB R10, (CX)
	MOVB R11, (DX)
	VZEROUPPER
	RET


TEXT ·_int16_max_min_avx512(SB), NOSPLIT, $0-32
	MOVQ values+0(FP), DI
	MOVQ length+8(FP), SI
	MOVQ minout+16(FP), DX
	MOVQ maxout+24(FP), CX

	TESTQ SI, SI
	JLE   int16_empty
	CMPQ  SI, $32
	JB    int16_scalar_setup

	VPTERNLOGD $0xFF, Z0, Z0, Z0
	VPSRLW     $1, Z0, Z0           // 0x7FFF = INT16_MAX
	VMOVDQA64  Z0, Z1
	VMOVDQA64  Z0, Z2
	VMOVDQA64  Z0, Z3
	VPSLLW     $15, Z0, Z4          // shift left 15 -> 0x8000 then combine
	VPTERNLOGD $0xFF, Z4, Z4, Z4
	VPXORD     Z0, Z4, Z4           // 0x8000 = INT16_MIN
	VMOVDQA64  Z4, Z5
	VMOVDQA64  Z4, Z6
	VMOVDQA64  Z4, Z7

	XORQ AX, AX
	MOVQ SI, R8
	ANDQ $-128, R8
	CMPQ R8, $0
	JE   int16_tail32

int16_loop128:
	VMOVDQU16 (DI)(AX*2), Z8
	VMOVDQU16 64(DI)(AX*2), Z9
	VMOVDQU16 128(DI)(AX*2), Z10
	VMOVDQU16 192(DI)(AX*2), Z11
	VPMINSW   Z8, Z0, Z0
	VPMINSW   Z9, Z1, Z1
	VPMINSW   Z10, Z2, Z2
	VPMINSW   Z11, Z3, Z3
	VPMAXSW   Z8, Z4, Z4
	VPMAXSW   Z9, Z5, Z5
	VPMAXSW   Z10, Z6, Z6
	VPMAXSW   Z11, Z7, Z7
	ADDQ      $128, AX
	CMPQ      AX, R8
	JB        int16_loop128

	VPMINSW Z1, Z0, Z0
	VPMINSW Z2, Z0, Z0
	VPMINSW Z3, Z0, Z0
	VPMAXSW Z5, Z4, Z4
	VPMAXSW Z6, Z4, Z4
	VPMAXSW Z7, Z4, Z4

int16_tail32:
	MOVQ SI, R9
	ANDQ $-32, R9
	CMPQ AX, R9
	JAE  int16_hreduce

int16_tail32_loop:
	VMOVDQU16 (DI)(AX*2), Z8
	VPMINSW   Z8, Z0, Z0
	VPMAXSW   Z8, Z4, Z4
	ADDQ      $32, AX
	CMPQ      AX, R9
	JB        int16_tail32_loop

int16_hreduce:
	VEXTRACTI32X8 $1, Z4, Y5
	VPMAXSW       Y5, Y4, Y4
	VEXTRACTI128  $1, Y4, X5
	VPMAXSW       X5, X4, X4
	VPHMINPOSUW   X4, X5
	VPTERNLOGD $0xFF, X6, X6, X6
	VPSRLW     $1, X6, X6         // 0x7FFF
	VPXOR      X4, X6, X4
	VPHMINPOSUW X4, X4
	VMOVD      X4, R10
	XORW       $0x7FFF, R10

	VEXTRACTI32X8 $1, Z0, Y1
	VPMINSW       Y1, Y0, Y0
	VEXTRACTI128  $1, Y0, X1
	VPMINSW       X1, X0, X0
	// XOR with 0x8000 to make unsigned for phminposuw
	VPTERNLOGD $0xFF, X2, X2, X2
	VPSLLW     $15, X2, X2        // 0x8000
	VPXOR      X0, X2, X0
	VPHMINPOSUW X0, X0
	VMOVD      X0, R11
	XORW       $0x8000, R11

	CMPQ AX, SI
	JE   int16_done

int16_scalar_tail:
	MOVWLSX (DI)(AX*2), R9
	CMPW    R11, R9
	CMOVLGT R9, R11
	CMPW    R10, R9
	CMOVLLT R9, R10
	INCQ    AX
	CMPQ    AX, SI
	JB      int16_scalar_tail
	JMP     int16_done

int16_scalar_setup:
	MOVQ $0x7FFF, R11
	MOVQ $0x8000, R10
	XORQ AX, AX
	JMP  int16_scalar_tail

int16_empty:
	MOVW $0x7FFF, (DX)
	MOVW $0x8000, (CX)
	VZEROUPPER
	RET

int16_done:
	MOVW R10, (CX)
	MOVW R11, (DX)
	VZEROUPPER
	RET


TEXT ·_uint16_max_min_avx512(SB), NOSPLIT, $0-32
	MOVQ values+0(FP), DI
	MOVQ length+8(FP), SI
	MOVQ minout+16(FP), DX
	MOVQ maxout+24(FP), CX

	TESTQ SI, SI
	JLE   uint16_empty
	CMPQ  SI, $32
	JB    uint16_scalar_setup

	VPTERNLOGD $0xFF, Z0, Z0, Z0  // all ones = 0xFFFF per word
	VMOVDQA64  Z0, Z1
	VMOVDQA64  Z0, Z2
	VMOVDQA64  Z0, Z3
	VPXORD     Z4, Z4, Z4
	VMOVDQA64  Z4, Z5
	VMOVDQA64  Z4, Z6
	VMOVDQA64  Z4, Z7

	XORQ AX, AX
	MOVQ SI, R8
	ANDQ $-128, R8
	CMPQ R8, $0
	JE   uint16_tail32

uint16_loop128:
	VMOVDQU16 (DI)(AX*2), Z8
	VMOVDQU16 64(DI)(AX*2), Z9
	VMOVDQU16 128(DI)(AX*2), Z10
	VMOVDQU16 192(DI)(AX*2), Z11
	VPMINUW   Z8, Z0, Z0
	VPMINUW   Z9, Z1, Z1
	VPMINUW   Z10, Z2, Z2
	VPMINUW   Z11, Z3, Z3
	VPMAXUW   Z8, Z4, Z4
	VPMAXUW   Z9, Z5, Z5
	VPMAXUW   Z10, Z6, Z6
	VPMAXUW   Z11, Z7, Z7
	ADDQ      $128, AX
	CMPQ      AX, R8
	JB        uint16_loop128

	VPMINUW Z1, Z0, Z0
	VPMINUW Z2, Z0, Z0
	VPMINUW Z3, Z0, Z0
	VPMAXUW Z5, Z4, Z4
	VPMAXUW Z6, Z4, Z4
	VPMAXUW Z7, Z4, Z4

uint16_tail32:
	MOVQ SI, R9
	ANDQ $-32, R9
	CMPQ AX, R9
	JAE  uint16_hreduce

uint16_tail32_loop:
	VMOVDQU16 (DI)(AX*2), Z8
	VPMINUW   Z8, Z0, Z0
	VPMAXUW   Z8, Z4, Z4
	ADDQ      $32, AX
	CMPQ      AX, R9
	JB        uint16_tail32_loop

uint16_hreduce:
	VEXTRACTI32X8 $1, Z4, Y5
	VPMAXUW       Y5, Y4, Y4
	VEXTRACTI128  $1, Y4, X5
	VPMAXUW       X5, X4, X4
	VPTERNLOGD    $0xFF, X6, X6, X6
	VPXOR         X4, X6, X4
	VPHMINPOSUW   X4, X4
	VMOVD         X4, R10
	NOTW          R10

	VEXTRACTI32X8 $1, Z0, Y1
	VPMINUW       Y1, Y0, Y0
	VEXTRACTI128  $1, Y0, X1
	VPMINUW       X1, X0, X0
	VPHMINPOSUW   X0, X0
	VMOVD         X0, R11

	CMPQ AX, SI
	JE   uint16_done

uint16_scalar_tail:
	MOVWQZX (DI)(AX*2), R9
	CMPW    R11, R9
	CMOVQHI R9, R11
	CMPW    R10, R9
	CMOVQCS R9, R10
	INCQ    AX
	CMPQ    AX, SI
	JB      uint16_scalar_tail
	JMP     uint16_done

uint16_scalar_setup:
	MOVQ $0xFFFF, R11
	XORQ R10, R10
	XORQ AX, AX
	JMP  uint16_scalar_tail

uint16_empty:
	MOVW $0xFFFF, (DX)
	MOVW $0x0000, (CX)
	VZEROUPPER
	RET

uint16_done:
	MOVW R10, (CX)
	MOVW R11, (DX)
	VZEROUPPER
	RET


TEXT ·_int32_max_min_avx512(SB), NOSPLIT, $0-32
	MOVQ values+0(FP), DI
	MOVQ length+8(FP), SI
	MOVQ minout+16(FP), DX
	MOVQ maxout+24(FP), CX

	TESTQ SI, SI
	JLE   int32_empty
	CMPQ  SI, $16
	JB    int32_scalar_setup

	VPTERNLOGD $0xFF, Z0, Z0, Z0
	VPSRLD     $1, Z0, Z0
	VMOVDQA64  Z0, Z1
	VMOVDQA64  Z0, Z2
	VMOVDQA64  Z0, Z3
	VPTERNLOGD $0xFF, Z4, Z4, Z4
	VPXORD     Z0, Z4, Z4  // INT32_MIN = 0x80000000
	VMOVDQA64  Z4, Z5
	VMOVDQA64  Z4, Z6
	VMOVDQA64  Z4, Z7

	XORQ AX, AX
	MOVQ SI, R8
	ANDQ $-64, R8
	CMPQ R8, $0
	JE   int32_tail16

int32_loop64:
	VMOVDQU32 (DI)(AX*4), Z8
	VMOVDQU32 64(DI)(AX*4), Z9
	VMOVDQU32 128(DI)(AX*4), Z10
	VMOVDQU32 192(DI)(AX*4), Z11
	VPMINSD   Z8, Z0, Z0
	VPMINSD   Z9, Z1, Z1
	VPMINSD   Z10, Z2, Z2
	VPMINSD   Z11, Z3, Z3
	VPMAXSD   Z8, Z4, Z4
	VPMAXSD   Z9, Z5, Z5
	VPMAXSD   Z10, Z6, Z6
	VPMAXSD   Z11, Z7, Z7
	ADDQ      $64, AX
	CMPQ      AX, R8
	JB        int32_loop64

	VPMINSD Z1, Z0, Z0
	VPMINSD Z2, Z0, Z0
	VPMINSD Z3, Z0, Z0
	VPMAXSD Z5, Z4, Z4
	VPMAXSD Z6, Z4, Z4
	VPMAXSD Z7, Z4, Z4

int32_tail16:
	MOVQ SI, R9
	ANDQ $-16, R9
	CMPQ AX, R9
	JAE  int32_hreduce

int32_tail16_loop:
	VMOVDQU32 (DI)(AX*4), Z8
	VPMINSD   Z8, Z0, Z0
	VPMAXSD   Z8, Z4, Z4
	ADDQ      $16, AX
	CMPQ      AX, R9
	JB        int32_tail16_loop

int32_hreduce:
	VEXTRACTI32X8 $1, Z4, Y5
	VPMAXSD       Y5, Y4, Y4
	VEXTRACTI128  $1, Y4, X5
	VPMAXSD       X5, X4, X4
	VPSHUFD       $0x4E, X4, X5  // swap high/low 64-bit halves
	VPMAXSD       X5, X4, X4
	VPSHUFD       $0xE5, X4, X5  // broadcast element 1
	VPMAXSD       X5, X4, X4
	VMOVD         X4, R10

	VEXTRACTI32X8 $1, Z0, Y1
	VPMINSD       Y1, Y0, Y0
	VEXTRACTI128  $1, Y0, X1
	VPMINSD       X1, X0, X0
	VPSHUFD       $0x4E, X0, X1
	VPMINSD       X1, X0, X0
	VPSHUFD       $0xE5, X0, X1
	VPMINSD       X1, X0, X0
	VMOVD         X0, R11

	CMPQ AX, SI
	JE   int32_done

int32_scalar_tail:
	MOVL    (DI)(AX*4), R9
	CMPL    R11, R9
	CMOVLGT R9, R11
	CMPL    R10, R9
	CMOVLLT R9, R10
	INCQ    AX
	CMPQ    AX, SI
	JB      int32_scalar_tail
	JMP     int32_done

int32_scalar_setup:
	MOVL $0x7FFFFFFF, R11
	MOVL $0x80000000, R10
	XORQ AX, AX
	JMP  int32_scalar_tail

int32_empty:
	MOVL $0x7FFFFFFF, (DX)
	MOVL $0x80000000, (CX)
	VZEROUPPER
	RET

int32_done:
	MOVL R10, (CX)
	MOVL R11, (DX)
	VZEROUPPER
	RET


TEXT ·_uint32_max_min_avx512(SB), NOSPLIT, $0-32
	MOVQ values+0(FP), DI
	MOVQ length+8(FP), SI
	MOVQ minout+16(FP), DX
	MOVQ maxout+24(FP), CX

	TESTQ SI, SI
	JLE   uint32_empty
	CMPQ  SI, $16
	JB    uint32_scalar_setup

	VPTERNLOGD $0xFF, Z0, Z0, Z0  // UINT32_MAX
	VMOVDQA64  Z0, Z1
	VMOVDQA64  Z0, Z2
	VMOVDQA64  Z0, Z3
	VPXORD     Z4, Z4, Z4         // 0
	VMOVDQA64  Z4, Z5
	VMOVDQA64  Z4, Z6
	VMOVDQA64  Z4, Z7

	XORQ AX, AX
	MOVQ SI, R8
	ANDQ $-64, R8
	CMPQ R8, $0
	JE   uint32_tail16

uint32_loop64:
	VMOVDQU32 (DI)(AX*4), Z8
	VMOVDQU32 64(DI)(AX*4), Z9
	VMOVDQU32 128(DI)(AX*4), Z10
	VMOVDQU32 192(DI)(AX*4), Z11
	VPMINUD   Z8, Z0, Z0
	VPMINUD   Z9, Z1, Z1
	VPMINUD   Z10, Z2, Z2
	VPMINUD   Z11, Z3, Z3
	VPMAXUD   Z8, Z4, Z4
	VPMAXUD   Z9, Z5, Z5
	VPMAXUD   Z10, Z6, Z6
	VPMAXUD   Z11, Z7, Z7
	ADDQ      $64, AX
	CMPQ      AX, R8
	JB        uint32_loop64

	VPMINUD Z1, Z0, Z0
	VPMINUD Z2, Z0, Z0
	VPMINUD Z3, Z0, Z0
	VPMAXUD Z5, Z4, Z4
	VPMAXUD Z6, Z4, Z4
	VPMAXUD Z7, Z4, Z4

uint32_tail16:
	MOVQ SI, R9
	ANDQ $-16, R9
	CMPQ AX, R9
	JAE  uint32_hreduce

uint32_tail16_loop:
	VMOVDQU32 (DI)(AX*4), Z8
	VPMINUD   Z8, Z0, Z0
	VPMAXUD   Z8, Z4, Z4
	ADDQ      $16, AX
	CMPQ      AX, R9
	JB        uint32_tail16_loop

uint32_hreduce:
	VEXTRACTI32X8 $1, Z4, Y5
	VPMAXUD       Y5, Y4, Y4
	VEXTRACTI128  $1, Y4, X5
	VPMAXUD       X5, X4, X4
	VPSHUFD       $0x4E, X4, X5
	VPMAXUD       X5, X4, X4
	VPSHUFD       $0xE5, X4, X5
	VPMAXUD       X5, X4, X4
	VMOVD         X4, R10

	VEXTRACTI32X8 $1, Z0, Y1
	VPMINUD       Y1, Y0, Y0
	VEXTRACTI128  $1, Y0, X1
	VPMINUD       X1, X0, X0
	VPSHUFD       $0x4E, X0, X1
	VPMINUD       X1, X0, X0
	VPSHUFD       $0xE5, X0, X1
	VPMINUD       X1, X0, X0
	VMOVD         X0, R11

	CMPQ AX, SI
	JE   uint32_done

uint32_scalar_tail:
	MOVL    (DI)(AX*4), R9
	CMPL    R11, R9
	CMOVQHI R9, R11
	CMPL    R10, R9
	CMOVQCS R9, R10
	INCQ    AX
	CMPQ    AX, SI
	JB      uint32_scalar_tail
	JMP     uint32_done

uint32_scalar_setup:
	MOVL $0xFFFFFFFF, R11
	XORL R10, R10
	XORQ AX, AX
	JMP  uint32_scalar_tail

uint32_empty:
	MOVL $0xFFFFFFFF, (DX)
	MOVL $0x00000000, (CX)
	VZEROUPPER
	RET

uint32_done:
	MOVL R10, (CX)
	MOVL R11, (DX)
	VZEROUPPER
	RET


TEXT ·_int64_max_min_avx512(SB), NOSPLIT, $0-32
	MOVQ values+0(FP), DI
	MOVQ length+8(FP), SI
	MOVQ minout+16(FP), DX
	MOVQ maxout+24(FP), CX

	TESTQ SI, SI
	JLE   int64_empty
	CMPQ  SI, $8
	JB    int64_scalar_setup

	VPTERNLOGD $0xFF, Z0, Z0, Z0
	VPSRLQ     $1, Z0, Z0          // INT64_MAX = 0x7FFFFFFFFFFFFFFF
	VMOVDQA64  Z0, Z1
	VMOVDQA64  Z0, Z2
	VMOVDQA64  Z0, Z3
	VPTERNLOGD $0xFF, Z4, Z4, Z4
	VPXORQ     Z0, Z4, Z4          // INT64_MIN = 0x8000000000000000
	VMOVDQA64  Z4, Z5
	VMOVDQA64  Z4, Z6
	VMOVDQA64  Z4, Z7

	XORQ AX, AX
	MOVQ SI, R8
	ANDQ $-32, R8
	CMPQ R8, $0
	JE   int64_tail8

int64_loop32:
	VMOVDQU64 (DI)(AX*8), Z8
	VMOVDQU64 64(DI)(AX*8), Z9
	VMOVDQU64 128(DI)(AX*8), Z10
	VMOVDQU64 192(DI)(AX*8), Z11
	VPMINSQ   Z8, Z0, Z0
	VPMINSQ   Z9, Z1, Z1
	VPMINSQ   Z10, Z2, Z2
	VPMINSQ   Z11, Z3, Z3
	VPMAXSQ   Z8, Z4, Z4
	VPMAXSQ   Z9, Z5, Z5
	VPMAXSQ   Z10, Z6, Z6
	VPMAXSQ   Z11, Z7, Z7
	ADDQ      $32, AX
	CMPQ      AX, R8
	JB        int64_loop32

	VPMINSQ Z1, Z0, Z0
	VPMINSQ Z2, Z0, Z0
	VPMINSQ Z3, Z0, Z0
	VPMAXSQ Z5, Z4, Z4
	VPMAXSQ Z6, Z4, Z4
	VPMAXSQ Z7, Z4, Z4

int64_tail8:
	MOVQ SI, R9
	ANDQ $-8, R9
	CMPQ AX, R9
	JAE  int64_hreduce

int64_tail8_loop:
	VMOVDQU64 (DI)(AX*8), Z8
	VPMINSQ   Z8, Z0, Z0
	VPMAXSQ   Z8, Z4, Z4
	ADDQ      $8, AX
	CMPQ      AX, R9
	JB        int64_tail8_loop

int64_hreduce:
	VEXTRACTI64X4 $1, Z4, Y5
	VPMAXSQ       Y5, Y4, Y4
	VEXTRACTI128  $1, Y4, X5
	VPMAXSQ       X5, X4, X4
	VPSHUFD       $0x4E, X4, X5     // swap 64-bit halves
	VPMAXSQ       X5, X4, X4
	VMOVQ         X4, R10

	VEXTRACTI64X4 $1, Z0, Y1
	VPMINSQ       Y1, Y0, Y0
	VEXTRACTI128  $1, Y0, X1
	VPMINSQ       X1, X0, X0
	VPSHUFD       $0x4E, X0, X1
	VPMINSQ       X1, X0, X0
	VMOVQ         X0, R11

	CMPQ AX, SI
	JE   int64_done

int64_scalar_tail:
	MOVQ    (DI)(AX*8), R9
	CMPQ    R11, R9
	CMOVQGT R9, R11
	CMPQ    R10, R9
	CMOVQLT R9, R10
	INCQ    AX
	CMPQ    AX, SI
	JB      int64_scalar_tail
	JMP     int64_done

int64_scalar_setup:
	MOVQ $0x7FFFFFFFFFFFFFFF, R11
	MOVQ $0x8000000000000000, R10
	XORQ AX, AX
	JMP  int64_scalar_tail

int64_empty:
	MOVQ $0x7FFFFFFFFFFFFFFF, R9
	MOVQ R9, (DX)
	MOVQ $0x8000000000000000, R9
	MOVQ R9, (CX)
	VZEROUPPER
	RET

int64_done:
	MOVQ R10, (CX)
	MOVQ R11, (DX)
	VZEROUPPER
	RET


TEXT ·_uint64_max_min_avx512(SB), NOSPLIT, $0-32
	MOVQ values+0(FP), DI
	MOVQ length+8(FP), SI
	MOVQ minout+16(FP), DX
	MOVQ maxout+24(FP), CX

	TESTQ SI, SI
	JLE   uint64_empty
	CMPQ  SI, $8
	JB    uint64_scalar_setup

	VPTERNLOGD $0xFF, Z0, Z0, Z0  // UINT64_MAX
	VMOVDQA64  Z0, Z1
	VMOVDQA64  Z0, Z2
	VMOVDQA64  Z0, Z3
	VPXORQ     Z4, Z4, Z4         // 0
	VMOVDQA64  Z4, Z5
	VMOVDQA64  Z4, Z6
	VMOVDQA64  Z4, Z7

	XORQ AX, AX
	MOVQ SI, R8
	ANDQ $-32, R8
	CMPQ R8, $0
	JE   uint64_tail8

uint64_loop32:
	VMOVDQU64 (DI)(AX*8), Z8
	VMOVDQU64 64(DI)(AX*8), Z9
	VMOVDQU64 128(DI)(AX*8), Z10
	VMOVDQU64 192(DI)(AX*8), Z11
	VPMINUQ   Z8, Z0, Z0
	VPMINUQ   Z9, Z1, Z1
	VPMINUQ   Z10, Z2, Z2
	VPMINUQ   Z11, Z3, Z3
	VPMAXUQ   Z8, Z4, Z4
	VPMAXUQ   Z9, Z5, Z5
	VPMAXUQ   Z10, Z6, Z6
	VPMAXUQ   Z11, Z7, Z7
	ADDQ      $32, AX
	CMPQ      AX, R8
	JB        uint64_loop32

	VPMINUQ Z1, Z0, Z0
	VPMINUQ Z2, Z0, Z0
	VPMINUQ Z3, Z0, Z0
	VPMAXUQ Z5, Z4, Z4
	VPMAXUQ Z6, Z4, Z4
	VPMAXUQ Z7, Z4, Z4

uint64_tail8:
	MOVQ SI, R9
	ANDQ $-8, R9
	CMPQ AX, R9
	JAE  uint64_hreduce

uint64_tail8_loop:
	VMOVDQU64 (DI)(AX*8), Z8
	VPMINUQ   Z8, Z0, Z0
	VPMAXUQ   Z8, Z4, Z4
	ADDQ      $8, AX
	CMPQ      AX, R9
	JB        uint64_tail8_loop

uint64_hreduce:
	VEXTRACTI64X4 $1, Z4, Y5
	VPMAXUQ       Y5, Y4, Y4
	VEXTRACTI128  $1, Y4, X5
	VPMAXUQ       X5, X4, X4
	VPSHUFD       $0x4E, X4, X5
	VPMAXUQ       X5, X4, X4
	VMOVQ         X4, R10

	VEXTRACTI64X4 $1, Z0, Y1
	VPMINUQ       Y1, Y0, Y0
	VEXTRACTI128  $1, Y0, X1
	VPMINUQ       X1, X0, X0
	VPSHUFD       $0x4E, X0, X1
	VPMINUQ       X1, X0, X0
	VMOVQ         X0, R11

	CMPQ AX, SI
	JE   uint64_done

uint64_scalar_tail:
	MOVQ    (DI)(AX*8), R9
	CMPQ    R11, R9
	CMOVQHI R9, R11
	CMPQ    R10, R9
	CMOVQCS R9, R10
	INCQ    AX
	CMPQ    AX, SI
	JB      uint64_scalar_tail
	JMP     uint64_done

uint64_scalar_setup:
	MOVQ $-1, R11     // UINT64_MAX
	XORQ R10, R10     // 0
	XORQ AX, AX
	JMP  uint64_scalar_tail

uint64_empty:
	MOVQ $-1, R9
	MOVQ R9, (DX)
	MOVQ $0, (CX)
	VZEROUPPER
	RET

uint64_done:
	MOVQ R10, (CX)
	MOVQ R11, (DX)
	VZEROUPPER
	RET
