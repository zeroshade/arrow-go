	.text
	.intel_syntax noprefix
	.file	"min_max.c"
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0                          # -- Begin function int8_max_min_avx512
.LCPI0_0:
	.zero	64,128
.LCPI0_1:
	.zero	64,127
.LCPI0_4:
	.byte	128                             # 0x80
.LCPI0_5:
	.byte	127                             # 0x7f
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4, 0x0
.LCPI0_2:
	.zero	16,128
.LCPI0_3:
	.zero	16,127
	.section	.rodata.cst4,"aM",@progbits,4
	.p2align	2, 0x0
.LCPI0_6:
	.zero	4,128
.LCPI0_7:
	.zero	4,127
	.text
	.globl	int8_max_min_avx512
	.p2align	4, 0x90
	.type	int8_max_min_avx512,@function
int8_max_min_avx512:                    # @int8_max_min_avx512
# %bb.0:
	test	rsi, rsi
	jle	.LBB0_1
# %bb.3:
	push	rbp
	mov	rbp, rsp
	and	rsp, -8
	cmp	rsi, 32
	jae	.LBB0_5
# %bb.4:
	mov	r10b, -128
	mov	r8b, 127
	xor	eax, eax
	jmp	.LBB0_15
.LBB0_1:
	mov	r8b, 127
	mov	r9b, -128
	mov	byte ptr [rcx], r9b
	mov	byte ptr [rdx], r8b
	ret
.LBB0_5:
	movabs	r9, 9223372036854775552
	cmp	rsi, 256
	jae	.LBB0_7
# %bb.6:
	mov	r10b, -128
	mov	r8b, 127
	xor	eax, eax
	jmp	.LBB0_12
.LBB0_7:
	mov	rax, rsi
	and	rax, r9
	vpbroadcastb	zmm0, byte ptr [rip + .LCPI0_4] # zmm0 = [128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128,128]
	vpbroadcastb	zmm4, byte ptr [rip + .LCPI0_5] # zmm4 = [127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127]
	xor	r8d, r8d
	vmovdqa64	zmm5, zmm4
	vmovdqa64	zmm6, zmm4
	vmovdqa64	zmm7, zmm4
	vmovdqa64	zmm1, zmm0
	vmovdqa64	zmm2, zmm0
	vmovdqa64	zmm3, zmm0
	.p2align	4, 0x90
.LBB0_8:                                # =>This Inner Loop Header: Depth=1
	vmovdqu64	zmm8, zmmword ptr [rdi + r8]
	vmovdqu64	zmm9, zmmword ptr [rdi + r8 + 64]
	vmovdqu64	zmm10, zmmword ptr [rdi + r8 + 128]
	vmovdqu64	zmm11, zmmword ptr [rdi + r8 + 192]
	vpminsb	zmm4, zmm4, zmm8
	vpminsb	zmm5, zmm5, zmm9
	vpminsb	zmm6, zmm6, zmm10
	vpminsb	zmm7, zmm7, zmm11
	vpmaxsb	zmm0, zmm0, zmm8
	vpmaxsb	zmm1, zmm1, zmm9
	vpmaxsb	zmm2, zmm2, zmm10
	vpmaxsb	zmm3, zmm3, zmm11
	add	r8, 256
	cmp	rax, r8
	jne	.LBB0_8
# %bb.9:
	vpminsb	zmm4, zmm4, zmm5
	vpminsb	zmm5, zmm6, zmm7
	vpminsb	zmm4, zmm4, zmm5
	vextracti64x4	ymm5, zmm4, 1
	vpminsb	ymm4, ymm4, ymm5
	vextracti128	xmm5, ymm4, 1
	vpminsb	xmm4, xmm4, xmm5
	vpxord	xmm4, xmm4, dword ptr [rip + .LCPI0_6]{1to4}
	vpsrlw	xmm5, xmm4, 8
	vpminub	xmm4, xmm4, xmm5
	vphminposuw	xmm4, xmm4
	vmovd	r8d, xmm4
	add	r8b, -128
	vpmaxsb	zmm0, zmm0, zmm1
	vpmaxsb	zmm1, zmm2, zmm3
	vpmaxsb	zmm0, zmm0, zmm1
	vextracti64x4	ymm1, zmm0, 1
	vpmaxsb	ymm0, ymm0, ymm1
	vextracti128	xmm1, ymm0, 1
	vpmaxsb	xmm0, xmm0, xmm1
	vpxord	xmm0, xmm0, dword ptr [rip + .LCPI0_7]{1to4}
	vpsrlw	xmm1, xmm0, 8
	vpminub	xmm0, xmm0, xmm1
	vphminposuw	xmm0, xmm0
	vmovd	r10d, xmm0
	xor	r10b, 127
	cmp	rax, rsi
	jne	.LBB0_11
# %bb.10:
	mov	r9d, r10d
	jmp	.LBB0_16
.LBB0_11:
	test	sil, -32
	je	.LBB0_15
.LBB0_12:
	mov	r11, rax
	add	r9, 224
	mov	rax, r9
	and	rax, rsi
	vpbroadcastb	ymm1, r8d
	vpbroadcastb	ymm0, r10d
	.p2align	4, 0x90
.LBB0_13:                               # =>This Inner Loop Header: Depth=1
	vmovdqu	ymm2, ymmword ptr [rdi + r11]
	vpminsb	ymm1, ymm1, ymm2
	vpmaxsb	ymm0, ymm0, ymm2
	add	r11, 32
	cmp	rax, r11
	jne	.LBB0_13
# %bb.14:
	vextracti128	xmm2, ymm1, 1
	vpminsb	xmm1, xmm1, xmm2
	vpxord	xmm1, xmm1, dword ptr [rip + .LCPI0_6]{1to4}
	vpsrlw	xmm2, xmm1, 8
	vpminub	xmm1, xmm1, xmm2
	vphminposuw	xmm1, xmm1
	vmovd	r8d, xmm1
	vextracti128	xmm1, ymm0, 1
	vpmaxsb	xmm0, xmm0, xmm1
	vpxord	xmm0, xmm0, dword ptr [rip + .LCPI0_7]{1to4}
	add	r8b, -128
	vpsrlw	xmm1, xmm0, 8
	vpminub	xmm0, xmm0, xmm1
	vphminposuw	xmm0, xmm0
	vmovd	r10d, xmm0
	xor	r10b, 127
	mov	r9d, r10d
	cmp	rax, rsi
	je	.LBB0_16
	.p2align	4, 0x90
.LBB0_15:                               # =>This Inner Loop Header: Depth=1
	movzx	r9d, byte ptr [rdi + rax]
	movzx	r8d, r8b
	cmp	r8b, r9b
	cmovge	r8d, r9d
	movzx	r10d, r10b
	cmp	r10b, r9b
	cmovg	r9d, r10d
	inc	rax
	mov	r10d, r9d
	cmp	rsi, rax
	jne	.LBB0_15
.LBB0_16:
	mov	rsp, rbp
	pop	rbp
	mov	byte ptr [rcx], r9b
	mov	byte ptr [rdx], r8b
	vzeroupper
	ret
.Lfunc_end0:
	.size	int8_max_min_avx512, .Lfunc_end0-int8_max_min_avx512
                                        # -- End function
	.globl	uint8_max_min_avx512            # -- Begin function uint8_max_min_avx512
	.p2align	4, 0x90
	.type	uint8_max_min_avx512,@function
uint8_max_min_avx512:                   # @uint8_max_min_avx512
# %bb.0:
	push	rbp
	mov	rbp, rsp
	and	rsp, -8
	test	rsi, rsi
	jle	.LBB1_1
# %bb.2:
	cmp	rsi, 32
	jae	.LBB1_4
# %bb.3:
	mov	r8b, -1
	xor	eax, eax
	xor	r10d, r10d
	jmp	.LBB1_14
.LBB1_1:
	mov	r8b, -1
	xor	r9d, r9d
	jmp	.LBB1_15
.LBB1_4:
	movabs	r9, 9223372036854775552
	cmp	rsi, 256
	jae	.LBB1_6
# %bb.5:
	mov	r8b, -1
	xor	r10d, r10d
	xor	eax, eax
	jmp	.LBB1_11
.LBB1_6:
	mov	rax, rsi
	and	rax, r9
	vpxor	xmm0, xmm0, xmm0
	vpternlogd	zmm4, zmm4, zmm4, 255
	xor	r8d, r8d
	vpternlogd	zmm5, zmm5, zmm5, 255
	vpternlogd	zmm6, zmm6, zmm6, 255
	vpternlogd	zmm7, zmm7, zmm7, 255
	vpxor	xmm1, xmm1, xmm1
	vpxor	xmm2, xmm2, xmm2
	vpxor	xmm3, xmm3, xmm3
	.p2align	4, 0x90
.LBB1_7:                                # =>This Inner Loop Header: Depth=1
	vmovdqu64	zmm8, zmmword ptr [rdi + r8]
	vmovdqu64	zmm9, zmmword ptr [rdi + r8 + 64]
	vmovdqu64	zmm10, zmmword ptr [rdi + r8 + 128]
	vmovdqu64	zmm11, zmmword ptr [rdi + r8 + 192]
	vpminub	zmm4, zmm4, zmm8
	vpminub	zmm5, zmm5, zmm9
	vpminub	zmm6, zmm6, zmm10
	vpminub	zmm7, zmm7, zmm11
	vpmaxub	zmm0, zmm0, zmm8
	vpmaxub	zmm1, zmm1, zmm9
	vpmaxub	zmm2, zmm2, zmm10
	vpmaxub	zmm3, zmm3, zmm11
	add	r8, 256
	cmp	rax, r8
	jne	.LBB1_7
# %bb.8:
	vpminub	zmm4, zmm4, zmm5
	vpminub	zmm5, zmm6, zmm7
	vpminub	zmm4, zmm4, zmm5
	vextracti64x4	ymm5, zmm4, 1
	vpminub	ymm4, ymm4, ymm5
	vextracti128	xmm5, ymm4, 1
	vpminub	xmm4, xmm4, xmm5
	vpsrlw	xmm5, xmm4, 8
	vpminub	xmm4, xmm4, xmm5
	vphminposuw	xmm4, xmm4
	vmovd	r8d, xmm4
	vpmaxub	zmm0, zmm0, zmm1
	vpmaxub	zmm1, zmm2, zmm3
	vpmaxub	zmm0, zmm0, zmm1
	vextracti64x4	ymm1, zmm0, 1
	vpmaxub	ymm0, ymm0, ymm1
	vextracti128	xmm1, ymm0, 1
	vpmaxub	xmm0, xmm0, xmm1
	vpternlogq	xmm0, xmm0, xmm0, 15
	vpsrlw	xmm1, xmm0, 8
	vpminub	xmm0, xmm0, xmm1
	vphminposuw	xmm0, xmm0
	vmovd	r10d, xmm0
	not	r10b
	cmp	rax, rsi
	jne	.LBB1_10
# %bb.9:
	mov	r9d, r10d
	jmp	.LBB1_15
.LBB1_10:
	test	sil, -32
	je	.LBB1_14
.LBB1_11:
	mov	r11, rax
	add	r9, 224
	mov	rax, r9
	and	rax, rsi
	vpbroadcastb	ymm1, r8d
	vpbroadcastb	ymm0, r10d
	.p2align	4, 0x90
.LBB1_12:                               # =>This Inner Loop Header: Depth=1
	vmovdqu	ymm2, ymmword ptr [rdi + r11]
	vpminub	ymm1, ymm1, ymm2
	vpmaxub	ymm0, ymm0, ymm2
	add	r11, 32
	cmp	rax, r11
	jne	.LBB1_12
# %bb.13:
	vextracti128	xmm2, ymm1, 1
	vpminub	xmm1, xmm1, xmm2
	vpsrlw	xmm2, xmm1, 8
	vpminub	xmm1, xmm1, xmm2
	vphminposuw	xmm1, xmm1
	vmovd	r8d, xmm1
	vextracti128	xmm1, ymm0, 1
	vpmaxub	xmm0, xmm0, xmm1
	vpternlogq	xmm0, xmm0, xmm0, 15
	vpsrlw	xmm1, xmm0, 8
	vpminub	xmm0, xmm0, xmm1
	vphminposuw	xmm0, xmm0
	vmovd	r10d, xmm0
	not	r10b
	mov	r9d, r10d
	cmp	rax, rsi
	je	.LBB1_15
	.p2align	4, 0x90
.LBB1_14:                               # =>This Inner Loop Header: Depth=1
	movzx	r9d, byte ptr [rdi + rax]
	movzx	r8d, r8b
	cmp	r8b, r9b
	cmovae	r8d, r9d
	movzx	r10d, r10b
	cmp	r10b, r9b
	cmova	r9d, r10d
	inc	rax
	mov	r10d, r9d
	cmp	rsi, rax
	jne	.LBB1_14
.LBB1_15:
	mov	byte ptr [rcx], r9b
	mov	byte ptr [rdx], r8b
	mov	rsp, rbp
	pop	rbp
	vzeroupper
	ret
.Lfunc_end1:
	.size	uint8_max_min_avx512, .Lfunc_end1-uint8_max_min_avx512
                                        # -- End function
	.section	.rodata,"a",@progbits
	.p2align	6, 0x0                          # -- Begin function int16_max_min_avx512
.LCPI2_0:
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
.LCPI2_1:
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
.LCPI2_4:
	.short	32768                           # 0x8000
.LCPI2_5:
	.short	32767                           # 0x7fff
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4, 0x0
.LCPI2_2:
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
.LCPI2_3:
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.section	.rodata.cst4,"aM",@progbits,4
	.p2align	2, 0x0
.LCPI2_6:
	.short	32768                           # 0x8000
	.short	32768                           # 0x8000
.LCPI2_7:
	.short	32767                           # 0x7fff
	.short	32767                           # 0x7fff
	.text
	.globl	int16_max_min_avx512
	.p2align	4, 0x90
	.type	int16_max_min_avx512,@function
int16_max_min_avx512:                   # @int16_max_min_avx512
# %bb.0:
	test	rsi, rsi
	jle	.LBB2_1
# %bb.3:
	push	rbp
	mov	rbp, rsp
	and	rsp, -8
	cmp	rsi, 16
	jae	.LBB2_5
# %bb.4:
	mov	r10w, -32768
	mov	r8w, 32767
	xor	eax, eax
	jmp	.LBB2_14
.LBB2_1:
	mov	r8w, 32767
	mov	r10w, -32768
	mov	word ptr [rcx], r10w
	mov	word ptr [rdx], r8w
	ret
.LBB2_5:
	movabs	r9, 9223372036854775680
	cmp	rsi, 128
	jae	.LBB2_7
# %bb.6:
	mov	r10w, -32768
	mov	r8w, 32767
	xor	eax, eax
	jmp	.LBB2_11
.LBB2_7:
	mov	rax, rsi
	and	rax, r9
	vpbroadcastw	zmm0, word ptr [rip + .LCPI2_4] # zmm0 = [32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768,32768]
	vpbroadcastw	zmm4, word ptr [rip + .LCPI2_5] # zmm4 = [32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767]
	xor	r8d, r8d
	vmovdqa64	zmm5, zmm4
	vmovdqa64	zmm6, zmm4
	vmovdqa64	zmm7, zmm4
	vmovdqa64	zmm1, zmm0
	vmovdqa64	zmm2, zmm0
	vmovdqa64	zmm3, zmm0
	.p2align	4, 0x90
.LBB2_8:                                # =>This Inner Loop Header: Depth=1
	vmovdqu64	zmm8, zmmword ptr [rdi + 2*r8]
	vmovdqu64	zmm9, zmmword ptr [rdi + 2*r8 + 64]
	vmovdqu64	zmm10, zmmword ptr [rdi + 2*r8 + 128]
	vmovdqu64	zmm11, zmmword ptr [rdi + 2*r8 + 192]
	vpminsw	zmm4, zmm4, zmm8
	vpminsw	zmm5, zmm5, zmm9
	vpminsw	zmm6, zmm6, zmm10
	vpminsw	zmm7, zmm7, zmm11
	vpmaxsw	zmm0, zmm0, zmm8
	vpmaxsw	zmm1, zmm1, zmm9
	vpmaxsw	zmm2, zmm2, zmm10
	vpmaxsw	zmm3, zmm3, zmm11
	sub	r8, -128
	cmp	rax, r8
	jne	.LBB2_8
# %bb.9:
	vpminsw	zmm4, zmm4, zmm5
	vpminsw	zmm5, zmm6, zmm7
	vpminsw	zmm4, zmm4, zmm5
	vextracti64x4	ymm5, zmm4, 1
	vpminsw	ymm4, ymm4, ymm5
	vextracti128	xmm5, ymm4, 1
	vpminsw	xmm4, xmm4, xmm5
	vpxord	xmm4, xmm4, dword ptr [rip + .LCPI2_6]{1to4}
	vphminposuw	xmm4, xmm4
	vmovd	r8d, xmm4
	xor	r8d, 32768
	vpmaxsw	zmm0, zmm0, zmm1
	vpmaxsw	zmm1, zmm2, zmm3
	vpmaxsw	zmm0, zmm0, zmm1
	vextracti64x4	ymm1, zmm0, 1
	vpmaxsw	ymm0, ymm0, ymm1
	vextracti128	xmm1, ymm0, 1
	vpmaxsw	xmm0, xmm0, xmm1
	vpxord	xmm0, xmm0, dword ptr [rip + .LCPI2_7]{1to4}
	vphminposuw	xmm0, xmm0
	vmovd	r10d, xmm0
	xor	r10d, 32767
	cmp	rax, rsi
	je	.LBB2_15
# %bb.10:
	test	sil, 112
	je	.LBB2_14
.LBB2_11:
	mov	r11, rax
	add	r9, 112
	mov	rax, r9
	and	rax, rsi
	vpbroadcastw	ymm1, r8d
	vpbroadcastw	ymm0, r10d
	.p2align	4, 0x90
.LBB2_12:                               # =>This Inner Loop Header: Depth=1
	vmovdqu	ymm2, ymmword ptr [rdi + 2*r11]
	vpminsw	ymm1, ymm1, ymm2
	vpmaxsw	ymm0, ymm0, ymm2
	add	r11, 16
	cmp	rax, r11
	jne	.LBB2_12
# %bb.13:
	vextracti128	xmm2, ymm1, 1
	vpminsw	xmm1, xmm1, xmm2
	vpxord	xmm1, xmm1, dword ptr [rip + .LCPI2_6]{1to4}
	vphminposuw	xmm1, xmm1
	vmovd	r8d, xmm1
	xor	r8d, 32768
	vextracti128	xmm1, ymm0, 1
	vpmaxsw	xmm0, xmm0, xmm1
	vpxord	xmm0, xmm0, dword ptr [rip + .LCPI2_7]{1to4}
	vphminposuw	xmm0, xmm0
	vmovd	r10d, xmm0
	xor	r10d, 32767
	cmp	rax, rsi
	je	.LBB2_15
	.p2align	4, 0x90
.LBB2_14:                               # =>This Inner Loop Header: Depth=1
	movzx	r9d, word ptr [rdi + 2*rax]
	cmp	r8w, r9w
	cmovge	r8d, r9d
	cmp	r10w, r9w
	cmovle	r10d, r9d
	inc	rax
	cmp	rsi, rax
	jne	.LBB2_14
.LBB2_15:
	mov	rsp, rbp
	pop	rbp
	mov	word ptr [rcx], r10w
	mov	word ptr [rdx], r8w
	vzeroupper
	ret
.Lfunc_end2:
	.size	int16_max_min_avx512, .Lfunc_end2-int16_max_min_avx512
                                        # -- End function
	.globl	uint16_max_min_avx512           # -- Begin function uint16_max_min_avx512
	.p2align	4, 0x90
	.type	uint16_max_min_avx512,@function
uint16_max_min_avx512:                  # @uint16_max_min_avx512
# %bb.0:
	push	rbp
	mov	rbp, rsp
	and	rsp, -8
	test	rsi, rsi
	jle	.LBB3_1
# %bb.2:
	cmp	rsi, 16
	jae	.LBB3_4
# %bb.3:
	mov	r8w, -1
	xor	eax, eax
	xor	r10d, r10d
	jmp	.LBB3_13
.LBB3_1:
	mov	r8w, -1
	xor	r10d, r10d
	jmp	.LBB3_14
.LBB3_4:
	movabs	r9, 9223372036854775680
	cmp	rsi, 128
	jae	.LBB3_6
# %bb.5:
	mov	r8w, -1
	xor	r10d, r10d
	xor	eax, eax
	jmp	.LBB3_10
.LBB3_6:
	mov	rax, rsi
	and	rax, r9
	vpxor	xmm0, xmm0, xmm0
	vpternlogd	zmm4, zmm4, zmm4, 255
	xor	r8d, r8d
	vpternlogd	zmm5, zmm5, zmm5, 255
	vpternlogd	zmm6, zmm6, zmm6, 255
	vpternlogd	zmm7, zmm7, zmm7, 255
	vpxor	xmm1, xmm1, xmm1
	vpxor	xmm2, xmm2, xmm2
	vpxor	xmm3, xmm3, xmm3
	.p2align	4, 0x90
.LBB3_7:                                # =>This Inner Loop Header: Depth=1
	vmovdqu64	zmm8, zmmword ptr [rdi + 2*r8]
	vmovdqu64	zmm9, zmmword ptr [rdi + 2*r8 + 64]
	vmovdqu64	zmm10, zmmword ptr [rdi + 2*r8 + 128]
	vmovdqu64	zmm11, zmmword ptr [rdi + 2*r8 + 192]
	vpminuw	zmm4, zmm4, zmm8
	vpminuw	zmm5, zmm5, zmm9
	vpminuw	zmm6, zmm6, zmm10
	vpminuw	zmm7, zmm7, zmm11
	vpmaxuw	zmm0, zmm0, zmm8
	vpmaxuw	zmm1, zmm1, zmm9
	vpmaxuw	zmm2, zmm2, zmm10
	vpmaxuw	zmm3, zmm3, zmm11
	sub	r8, -128
	cmp	rax, r8
	jne	.LBB3_7
# %bb.8:
	vpminuw	zmm4, zmm4, zmm5
	vpminuw	zmm5, zmm6, zmm7
	vpminuw	zmm4, zmm4, zmm5
	vextracti64x4	ymm5, zmm4, 1
	vpminuw	ymm4, ymm4, ymm5
	vextracti128	xmm5, ymm4, 1
	vpminuw	xmm4, xmm4, xmm5
	vphminposuw	xmm4, xmm4
	vmovd	r8d, xmm4
	vpmaxuw	zmm0, zmm0, zmm1
	vpmaxuw	zmm1, zmm2, zmm3
	vpmaxuw	zmm0, zmm0, zmm1
	vextracti64x4	ymm1, zmm0, 1
	vpmaxuw	ymm0, ymm0, ymm1
	vextracti128	xmm1, ymm0, 1
	vpmaxuw	xmm0, xmm0, xmm1
	vpternlogq	xmm0, xmm0, xmm0, 15
	vphminposuw	xmm0, xmm0
	vmovd	r10d, xmm0
	not	r10d
	cmp	rax, rsi
	je	.LBB3_14
# %bb.9:
	test	sil, 112
	je	.LBB3_13
.LBB3_10:
	mov	r11, rax
	add	r9, 112
	mov	rax, r9
	and	rax, rsi
	vpbroadcastw	ymm1, r8d
	vpbroadcastw	ymm0, r10d
	.p2align	4, 0x90
.LBB3_11:                               # =>This Inner Loop Header: Depth=1
	vmovdqu	ymm2, ymmword ptr [rdi + 2*r11]
	vpminuw	ymm1, ymm1, ymm2
	vpmaxuw	ymm0, ymm0, ymm2
	add	r11, 16
	cmp	rax, r11
	jne	.LBB3_11
# %bb.12:
	vextracti128	xmm2, ymm1, 1
	vpminuw	xmm1, xmm1, xmm2
	vphminposuw	xmm1, xmm1
	vmovd	r8d, xmm1
	vextracti128	xmm1, ymm0, 1
	vpmaxuw	xmm0, xmm0, xmm1
	vpternlogq	xmm0, xmm0, xmm0, 15
	vphminposuw	xmm0, xmm0
	vmovd	r10d, xmm0
	not	r10d
	cmp	rax, rsi
	je	.LBB3_14
	.p2align	4, 0x90
.LBB3_13:                               # =>This Inner Loop Header: Depth=1
	movzx	r9d, word ptr [rdi + 2*rax]
	cmp	r8w, r9w
	cmovae	r8d, r9d
	cmp	r10w, r9w
	cmovbe	r10d, r9d
	inc	rax
	cmp	rsi, rax
	jne	.LBB3_13
.LBB3_14:
	mov	word ptr [rcx], r10w
	mov	word ptr [rdx], r8w
	mov	rsp, rbp
	pop	rbp
	vzeroupper
	ret
.Lfunc_end3:
	.size	uint16_max_min_avx512, .Lfunc_end3-uint16_max_min_avx512
                                        # -- End function
	.section	.rodata.cst4,"aM",@progbits,4
	.p2align	2, 0x0                          # -- Begin function int32_max_min_avx512
.LCPI4_0:
	.long	2147483648                      # 0x80000000
.LCPI4_1:
	.long	2147483647                      # 0x7fffffff
	.text
	.globl	int32_max_min_avx512
	.p2align	4, 0x90
	.type	int32_max_min_avx512,@function
int32_max_min_avx512:                   # @int32_max_min_avx512
# %bb.0:
	test	rsi, rsi
	jle	.LBB4_1
# %bb.3:
	push	rbp
	mov	rbp, rsp
	and	rsp, -8
	cmp	rsi, 8
	jae	.LBB4_5
# %bb.4:
	mov	r10d, -2147483648
	mov	r9d, 2147483647
	xor	eax, eax
	jmp	.LBB4_14
.LBB4_1:
	mov	r9d, 2147483647
	mov	r10d, -2147483648
	mov	dword ptr [rcx], r10d
	mov	dword ptr [rdx], r9d
	ret
.LBB4_5:
	movabs	r8, 9223372036854775744
	cmp	rsi, 64
	jae	.LBB4_10
# %bb.6:
	mov	r10d, -2147483648
	mov	r9d, 2147483647
	xor	eax, eax
	jmp	.LBB4_7
.LBB4_10:
	mov	rax, rsi
	vpbroadcastd	zmm0, dword ptr [rip + .LCPI4_0] # zmm0 = [2147483648,2147483648,2147483648,2147483648,2147483648,2147483648,2147483648,2147483648,2147483648,2147483648,2147483648,2147483648,2147483648,2147483648,2147483648,2147483648]
	vpbroadcastd	zmm4, dword ptr [rip + .LCPI4_1] # zmm4 = [2147483647,2147483647,2147483647,2147483647,2147483647,2147483647,2147483647,2147483647,2147483647,2147483647,2147483647,2147483647,2147483647,2147483647,2147483647,2147483647]
	and	rax, r8
	xor	r9d, r9d
	vmovdqa64	zmm5, zmm4
	vmovdqa64	zmm6, zmm4
	vmovdqa64	zmm7, zmm4
	vmovdqa64	zmm1, zmm0
	vmovdqa64	zmm2, zmm0
	vmovdqa64	zmm3, zmm0
	.p2align	4, 0x90
.LBB4_11:                               # =>This Inner Loop Header: Depth=1
	vmovdqu64	zmm8, zmmword ptr [rdi + 4*r9]
	vmovdqu64	zmm9, zmmword ptr [rdi + 4*r9 + 64]
	vmovdqu64	zmm10, zmmword ptr [rdi + 4*r9 + 128]
	vmovdqu64	zmm11, zmmword ptr [rdi + 4*r9 + 192]
	vpminsd	zmm4, zmm4, zmm8
	vpminsd	zmm5, zmm5, zmm9
	vpminsd	zmm6, zmm6, zmm10
	vpminsd	zmm7, zmm7, zmm11
	vpmaxsd	zmm0, zmm0, zmm8
	vpmaxsd	zmm1, zmm1, zmm9
	vpmaxsd	zmm2, zmm2, zmm10
	vpmaxsd	zmm3, zmm3, zmm11
	add	r9, 64
	cmp	rax, r9
	jne	.LBB4_11
# %bb.12:
	vpminsd	zmm4, zmm4, zmm5
	vpminsd	zmm5, zmm6, zmm7
	vpminsd	zmm4, zmm4, zmm5
	vextracti64x4	ymm5, zmm4, 1
	vpminsd	zmm4, zmm4, zmm5
	vextracti128	xmm5, ymm4, 1
	vpminsd	xmm4, xmm4, xmm5
	vpshufd	xmm5, xmm4, 238                 # xmm5 = xmm4[2,3,2,3]
	vpminsd	xmm4, xmm4, xmm5
	vpshufd	xmm5, xmm4, 85                  # xmm5 = xmm4[1,1,1,1]
	vpminsd	xmm4, xmm4, xmm5
	vmovd	r9d, xmm4
	vpmaxsd	zmm0, zmm0, zmm1
	vpmaxsd	zmm1, zmm2, zmm3
	vpmaxsd	zmm0, zmm0, zmm1
	vextracti64x4	ymm1, zmm0, 1
	vpmaxsd	zmm0, zmm0, zmm1
	vextracti128	xmm1, ymm0, 1
	vpmaxsd	xmm0, xmm0, xmm1
	vpshufd	xmm1, xmm0, 238                 # xmm1 = xmm0[2,3,2,3]
	vpmaxsd	xmm0, xmm0, xmm1
	vpshufd	xmm1, xmm0, 85                  # xmm1 = xmm0[1,1,1,1]
	vpmaxsd	xmm0, xmm0, xmm1
	vmovd	r10d, xmm0
	cmp	rax, rsi
	je	.LBB4_16
# %bb.13:
	test	sil, 56
	je	.LBB4_14
.LBB4_7:
	mov	r11, rax
	add	r8, 56
	mov	rax, r8
	and	rax, rsi
	vpbroadcastd	ymm1, r9d
	vpbroadcastd	ymm0, r10d
	.p2align	4, 0x90
.LBB4_8:                                # =>This Inner Loop Header: Depth=1
	vmovdqu	ymm2, ymmword ptr [rdi + 4*r11]
	vpminsd	ymm1, ymm1, ymm2
	vpmaxsd	ymm0, ymm0, ymm2
	add	r11, 8
	cmp	rax, r11
	jne	.LBB4_8
# %bb.9:
	vextracti128	xmm2, ymm1, 1
	vpminsd	xmm1, xmm1, xmm2
	vpshufd	xmm2, xmm1, 238                 # xmm2 = xmm1[2,3,2,3]
	vpminsd	xmm1, xmm1, xmm2
	vpshufd	xmm2, xmm1, 85                  # xmm2 = xmm1[1,1,1,1]
	vpminsd	xmm1, xmm1, xmm2
	vmovd	r9d, xmm1
	vextracti128	xmm1, ymm0, 1
	vpmaxsd	xmm0, xmm0, xmm1
	vpshufd	xmm1, xmm0, 238                 # xmm1 = xmm0[2,3,2,3]
	vpmaxsd	xmm0, xmm0, xmm1
	vpshufd	xmm1, xmm0, 85                  # xmm1 = xmm0[1,1,1,1]
	vpmaxsd	xmm0, xmm0, xmm1
	vmovd	r10d, xmm0
	cmp	rax, rsi
	je	.LBB4_16
.LBB4_14:
	mov	r8d, r10d
	.p2align	4, 0x90
.LBB4_15:                               # =>This Inner Loop Header: Depth=1
	mov	r10d, dword ptr [rdi + 4*rax]
	cmp	r9d, r10d
	cmovge	r9d, r10d
	cmp	r8d, r10d
	cmovg	r10d, r8d
	inc	rax
	mov	r8d, r10d
	cmp	rsi, rax
	jne	.LBB4_15
.LBB4_16:
	mov	rsp, rbp
	pop	rbp
	mov	dword ptr [rcx], r10d
	mov	dword ptr [rdx], r9d
	vzeroupper
	ret
.Lfunc_end4:
	.size	int32_max_min_avx512, .Lfunc_end4-int32_max_min_avx512
                                        # -- End function
	.globl	uint32_max_min_avx512           # -- Begin function uint32_max_min_avx512
	.p2align	4, 0x90
	.type	uint32_max_min_avx512,@function
uint32_max_min_avx512:                  # @uint32_max_min_avx512
# %bb.0:
	push	rbp
	mov	rbp, rsp
	and	rsp, -8
	test	rsi, rsi
	jle	.LBB5_1
# %bb.2:
	cmp	rsi, 8
	jae	.LBB5_4
# %bb.3:
	xor	eax, eax
	mov	r9d, -1
	xor	r10d, r10d
	jmp	.LBB5_14
.LBB5_1:
	mov	r9d, -1
	xor	r10d, r10d
	jmp	.LBB5_9
.LBB5_4:
	movabs	r8, 9223372036854775744
	cmp	rsi, 64
	jae	.LBB5_10
# %bb.5:
	xor	r10d, r10d
	mov	r9d, -1
	xor	eax, eax
	jmp	.LBB5_6
.LBB5_10:
	mov	rax, rsi
	and	rax, r8
	vpxor	xmm0, xmm0, xmm0
	vpternlogd	zmm4, zmm4, zmm4, 255
	xor	r9d, r9d
	vpternlogd	zmm5, zmm5, zmm5, 255
	vpternlogd	zmm6, zmm6, zmm6, 255
	vpternlogd	zmm7, zmm7, zmm7, 255
	vpxor	xmm1, xmm1, xmm1
	vpxor	xmm2, xmm2, xmm2
	vpxor	xmm3, xmm3, xmm3
	.p2align	4, 0x90
.LBB5_11:                               # =>This Inner Loop Header: Depth=1
	vmovdqu64	zmm8, zmmword ptr [rdi + 4*r9]
	vmovdqu64	zmm9, zmmword ptr [rdi + 4*r9 + 64]
	vmovdqu64	zmm10, zmmword ptr [rdi + 4*r9 + 128]
	vmovdqu64	zmm11, zmmword ptr [rdi + 4*r9 + 192]
	vpminud	zmm4, zmm4, zmm8
	vpminud	zmm5, zmm5, zmm9
	vpminud	zmm6, zmm6, zmm10
	vpminud	zmm7, zmm7, zmm11
	vpmaxud	zmm0, zmm0, zmm8
	vpmaxud	zmm1, zmm1, zmm9
	vpmaxud	zmm2, zmm2, zmm10
	vpmaxud	zmm3, zmm3, zmm11
	add	r9, 64
	cmp	rax, r9
	jne	.LBB5_11
# %bb.12:
	vpminud	zmm4, zmm4, zmm5
	vpminud	zmm5, zmm6, zmm7
	vpminud	zmm4, zmm4, zmm5
	vextracti64x4	ymm5, zmm4, 1
	vpminud	zmm4, zmm4, zmm5
	vextracti128	xmm5, ymm4, 1
	vpminud	xmm4, xmm4, xmm5
	vpshufd	xmm5, xmm4, 238                 # xmm5 = xmm4[2,3,2,3]
	vpminud	xmm4, xmm4, xmm5
	vpshufd	xmm5, xmm4, 85                  # xmm5 = xmm4[1,1,1,1]
	vpminud	xmm4, xmm4, xmm5
	vmovd	r9d, xmm4
	vpmaxud	zmm0, zmm0, zmm1
	vpmaxud	zmm1, zmm2, zmm3
	vpmaxud	zmm0, zmm0, zmm1
	vextracti64x4	ymm1, zmm0, 1
	vpmaxud	zmm0, zmm0, zmm1
	vextracti128	xmm1, ymm0, 1
	vpmaxud	xmm0, xmm0, xmm1
	vpshufd	xmm1, xmm0, 238                 # xmm1 = xmm0[2,3,2,3]
	vpmaxud	xmm0, xmm0, xmm1
	vpshufd	xmm1, xmm0, 85                  # xmm1 = xmm0[1,1,1,1]
	vpmaxud	xmm0, xmm0, xmm1
	vmovd	r10d, xmm0
	cmp	rax, rsi
	je	.LBB5_9
# %bb.13:
	test	sil, 56
	je	.LBB5_14
.LBB5_6:
	mov	r11, rax
	add	r8, 56
	mov	rax, r8
	and	rax, rsi
	vpbroadcastd	ymm1, r9d
	vpbroadcastd	ymm0, r10d
	.p2align	4, 0x90
.LBB5_7:                                # =>This Inner Loop Header: Depth=1
	vmovdqu	ymm2, ymmword ptr [rdi + 4*r11]
	vpminud	ymm1, ymm1, ymm2
	vpmaxud	ymm0, ymm0, ymm2
	add	r11, 8
	cmp	rax, r11
	jne	.LBB5_7
# %bb.8:
	vextracti128	xmm2, ymm1, 1
	vpminud	xmm1, xmm1, xmm2
	vpshufd	xmm2, xmm1, 238                 # xmm2 = xmm1[2,3,2,3]
	vpminud	xmm1, xmm1, xmm2
	vpshufd	xmm2, xmm1, 85                  # xmm2 = xmm1[1,1,1,1]
	vpminud	xmm1, xmm1, xmm2
	vmovd	r9d, xmm1
	vextracti128	xmm1, ymm0, 1
	vpmaxud	xmm0, xmm0, xmm1
	vpshufd	xmm1, xmm0, 238                 # xmm1 = xmm0[2,3,2,3]
	vpmaxud	xmm0, xmm0, xmm1
	vpshufd	xmm1, xmm0, 85                  # xmm1 = xmm0[1,1,1,1]
	vpmaxud	xmm0, xmm0, xmm1
	vmovd	r10d, xmm0
	cmp	rax, rsi
	je	.LBB5_9
.LBB5_14:
	mov	r8d, r10d
	.p2align	4, 0x90
.LBB5_15:                               # =>This Inner Loop Header: Depth=1
	mov	r10d, dword ptr [rdi + 4*rax]
	cmp	r9d, r10d
	cmovae	r9d, r10d
	cmp	r8d, r10d
	cmova	r10d, r8d
	inc	rax
	mov	r8d, r10d
	cmp	rsi, rax
	jne	.LBB5_15
.LBB5_9:
	mov	dword ptr [rcx], r10d
	mov	dword ptr [rdx], r9d
	mov	rsp, rbp
	pop	rbp
	vzeroupper
	ret
.Lfunc_end5:
	.size	uint32_max_min_avx512, .Lfunc_end5-uint32_max_min_avx512
                                        # -- End function
	.section	.rodata.cst8,"aM",@progbits,8
	.p2align	3, 0x0                          # -- Begin function int64_max_min_avx512
.LCPI6_0:
	.quad	-9223372036854775808            # 0x8000000000000000
.LCPI6_1:
	.quad	9223372036854775807             # 0x7fffffffffffffff
	.text
	.globl	int64_max_min_avx512
	.p2align	4, 0x90
	.type	int64_max_min_avx512,@function
int64_max_min_avx512:                   # @int64_max_min_avx512
# %bb.0:
	movabs	r8, 9223372036854775807
	test	rsi, rsi
	jle	.LBB6_1
# %bb.3:
	push	rbp
	mov	rbp, rsp
	and	rsp, -8
	cmp	rsi, 31
	ja	.LBB6_5
# %bb.4:
	lea	r9, [r8 + 1]
	xor	eax, eax
	jmp	.LBB6_8
.LBB6_1:
	lea	r10, [r8 + 1]
	mov	qword ptr [rcx], r10
	mov	qword ptr [rdx], r8
	ret
.LBB6_5:
	add	r8, -31
	mov	rax, r8
	vpbroadcastq	zmm0, qword ptr [rip + .LCPI6_0] # zmm0 = [9223372036854775808,9223372036854775808,9223372036854775808,9223372036854775808,9223372036854775808,9223372036854775808,9223372036854775808,9223372036854775808]
	vpbroadcastq	zmm4, qword ptr [rip + .LCPI6_1] # zmm4 = [9223372036854775807,9223372036854775807,9223372036854775807,9223372036854775807,9223372036854775807,9223372036854775807,9223372036854775807,9223372036854775807]
	and	rax, rsi
	xor	r8d, r8d
	vmovdqa64	zmm5, zmm4
	vmovdqa64	zmm6, zmm4
	vmovdqa64	zmm7, zmm4
	vmovdqa64	zmm1, zmm0
	vmovdqa64	zmm2, zmm0
	vmovdqa64	zmm3, zmm0
	.p2align	4, 0x90
.LBB6_6:                                # =>This Inner Loop Header: Depth=1
	vmovdqu64	zmm8, zmmword ptr [rdi + 8*r8]
	vmovdqu64	zmm9, zmmword ptr [rdi + 8*r8 + 64]
	vmovdqu64	zmm10, zmmword ptr [rdi + 8*r8 + 128]
	vmovdqu64	zmm11, zmmword ptr [rdi + 8*r8 + 192]
	vpminsq	zmm4, zmm4, zmm8
	vpminsq	zmm5, zmm5, zmm9
	vpminsq	zmm6, zmm6, zmm10
	vpminsq	zmm7, zmm7, zmm11
	vpmaxsq	zmm0, zmm0, zmm8
	vpmaxsq	zmm1, zmm1, zmm9
	vpmaxsq	zmm2, zmm2, zmm10
	vpmaxsq	zmm3, zmm3, zmm11
	add	r8, 32
	cmp	rax, r8
	jne	.LBB6_6
# %bb.7:
	vpminsq	zmm4, zmm4, zmm5
	vpminsq	zmm5, zmm6, zmm7
	vpminsq	zmm4, zmm4, zmm5
	vextracti64x4	ymm5, zmm4, 1
	vpminsq	zmm4, zmm4, zmm5
	vextracti128	xmm5, ymm4, 1
	vpminsq	xmm4, xmm4, xmm5
	vpshufd	xmm5, xmm4, 238                 # xmm5 = xmm4[2,3,2,3]
	vpminsq	xmm4, xmm4, xmm5
	vmovq	r8, xmm4
	vpmaxsq	zmm0, zmm0, zmm1
	vpmaxsq	zmm1, zmm2, zmm3
	vpmaxsq	zmm0, zmm0, zmm1
	vextracti64x4	ymm1, zmm0, 1
	vpmaxsq	zmm0, zmm0, zmm1
	vextracti128	xmm1, ymm0, 1
	vpmaxsq	xmm0, xmm0, xmm1
	vpshufd	xmm1, xmm0, 238                 # xmm1 = xmm0[2,3,2,3]
	vpmaxsq	xmm0, xmm0, xmm1
	vmovq	r9, xmm0
	mov	r10, r9
	cmp	rax, rsi
	je	.LBB6_9
	.p2align	4, 0x90
.LBB6_8:                                # =>This Inner Loop Header: Depth=1
	mov	r10, qword ptr [rdi + 8*rax]
	cmp	r8, r10
	cmovge	r8, r10
	cmp	r9, r10
	cmovg	r10, r9
	inc	rax
	mov	r9, r10
	cmp	rsi, rax
	jne	.LBB6_8
.LBB6_9:
	mov	rsp, rbp
	pop	rbp
	mov	qword ptr [rcx], r10
	mov	qword ptr [rdx], r8
	vzeroupper
	ret
.Lfunc_end6:
	.size	int64_max_min_avx512, .Lfunc_end6-int64_max_min_avx512
                                        # -- End function
	.globl	uint64_max_min_avx512           # -- Begin function uint64_max_min_avx512
	.p2align	4, 0x90
	.type	uint64_max_min_avx512,@function
uint64_max_min_avx512:                  # @uint64_max_min_avx512
# %bb.0:
	push	rbp
	mov	rbp, rsp
	and	rsp, -8
	test	rsi, rsi
	jle	.LBB7_1
# %bb.2:
	cmp	rsi, 31
	ja	.LBB7_4
# %bb.3:
	mov	r8, -1
	xor	eax, eax
	xor	r9d, r9d
	jmp	.LBB7_7
.LBB7_1:
	mov	r8, -1
	xor	r10d, r10d
	jmp	.LBB7_8
.LBB7_4:
	movabs	rax, 9223372036854775776
	and	rax, rsi
	vpxor	xmm0, xmm0, xmm0
	vpternlogd	zmm4, zmm4, zmm4, 255
	xor	r8d, r8d
	vpternlogd	zmm5, zmm5, zmm5, 255
	vpternlogd	zmm6, zmm6, zmm6, 255
	vpternlogd	zmm7, zmm7, zmm7, 255
	vpxor	xmm1, xmm1, xmm1
	vpxor	xmm2, xmm2, xmm2
	vpxor	xmm3, xmm3, xmm3
	.p2align	4, 0x90
.LBB7_5:                                # =>This Inner Loop Header: Depth=1
	vmovdqu64	zmm8, zmmword ptr [rdi + 8*r8]
	vmovdqu64	zmm9, zmmword ptr [rdi + 8*r8 + 64]
	vmovdqu64	zmm10, zmmword ptr [rdi + 8*r8 + 128]
	vmovdqu64	zmm11, zmmword ptr [rdi + 8*r8 + 192]
	vpminuq	zmm4, zmm4, zmm8
	vpminuq	zmm5, zmm5, zmm9
	vpminuq	zmm6, zmm6, zmm10
	vpminuq	zmm7, zmm7, zmm11
	vpmaxuq	zmm0, zmm0, zmm8
	vpmaxuq	zmm1, zmm1, zmm9
	vpmaxuq	zmm2, zmm2, zmm10
	vpmaxuq	zmm3, zmm3, zmm11
	add	r8, 32
	cmp	rax, r8
	jne	.LBB7_5
# %bb.6:
	vpminuq	zmm4, zmm4, zmm5
	vpminuq	zmm5, zmm6, zmm7
	vpminuq	zmm4, zmm4, zmm5
	vextracti64x4	ymm5, zmm4, 1
	vpminuq	zmm4, zmm4, zmm5
	vextracti128	xmm5, ymm4, 1
	vpminuq	xmm4, xmm4, xmm5
	vpshufd	xmm5, xmm4, 238                 # xmm5 = xmm4[2,3,2,3]
	vpminuq	xmm4, xmm4, xmm5
	vmovq	r8, xmm4
	vpmaxuq	zmm0, zmm0, zmm1
	vpmaxuq	zmm1, zmm2, zmm3
	vpmaxuq	zmm0, zmm0, zmm1
	vextracti64x4	ymm1, zmm0, 1
	vpmaxuq	zmm0, zmm0, zmm1
	vextracti128	xmm1, ymm0, 1
	vpmaxuq	xmm0, xmm0, xmm1
	vpshufd	xmm1, xmm0, 238                 # xmm1 = xmm0[2,3,2,3]
	vpmaxuq	xmm0, xmm0, xmm1
	vmovq	r9, xmm0
	mov	r10, r9
	cmp	rax, rsi
	je	.LBB7_8
	.p2align	4, 0x90
.LBB7_7:                                # =>This Inner Loop Header: Depth=1
	mov	r10, qword ptr [rdi + 8*rax]
	cmp	r8, r10
	cmovae	r8, r10
	cmp	r9, r10
	cmova	r10, r9
	inc	rax
	mov	r9, r10
	cmp	rsi, rax
	jne	.LBB7_7
.LBB7_8:
	mov	qword ptr [rcx], r10
	mov	qword ptr [rdx], r8
	mov	rsp, rbp
	pop	rbp
	vzeroupper
	ret
.Lfunc_end7:
	.size	uint64_max_min_avx512, .Lfunc_end7-uint64_max_min_avx512
                                        # -- End function
	.ident	"Debian clang version 19.1.7 (3+b1)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
