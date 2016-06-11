//+build !noasm,!appengine

#include "textflag.h"

TEXT ·countNewlines(SB), NOSPLIT, $0
	MOVQ input_base+0(FP), SI
	MOVQ length+24(FP), CX
	PXOR X4, X4
	CMPQ CX, $0
	JE   cn_end
	PXOR X0, X0
	PXOR X1, X1
	PXOR X2, X2
	PXOR X3, X3
	MOVQ $0x0A0A0A0A0A0A0A0A, R8
	MOVQ R8, X0
	MOVQ $0x0101010101010101, R10
	MOVQ R10, X1
	XORQ AX, AX
	MOVQ CX, BX
	ANDQ $7, CX
	SHRQ $3, BX
	JZ   cn_tail

cn_loop:
	MOVQ    (SI)(AX*8), X2
	PCMPEQB X0, X2
	PAND    X1, X2
	PSADBW  X3, X2
	PADDD   X2, X4
	INCQ    AX
	CMPQ    AX, BX
	JL      cn_loop

cn_tail:
	IMULQ   $-8, CX
	ADDQ    $64, CX
	SHRQ    CX, R10
	MOVQ    R10, X1
	MOVQ    (SI)(AX*8), X2
	PCMPEQB X0, X2
	PAND    X1, X2
	PSADBW  X3, X2
	PADDD   X2, X4

cn_end:
	MOVQ X4, ret+32(FP)
	RET

TEXT ·bytesToLower(SB), NOSPLIT, $0
	MOVQ       input_base+0(FP), SI
	MOVQ       output_base+24(FP), DI
	MOVQ       length+48(FP), CX
	CMPQ       CX, $0
	JE         btl_end
	MOVQ       $0x4141414141414141, R8
	MOVQ       R8, X4                   // [8]byte{65,65..}
	PUNPCKLQDQ X4, X4
	MOVQ       $0x1A1A1A1A1A1A1A1A, R9
	MOVQ       R9, X5                   // [8]byte{26,26..}
	PUNPCKLQDQ X5, X5
	MOVQ       $0x2020202020202020, R10
	MOVQ       R10, X6                  // [8]byte{32,32..}
	PUNPCKLQDQ X6, X6
	XORQ       AX, AX
	MOVQ       CX, BX
	ANDQ       $0xF, BX
	SHRQ       $4, CX
	JZ         btl_tail

btl_loop:
	MOVOU   (SI)(AX*8), X0
	MOVOU   X0, X1
	PSUBB   X4, X1
	MOVOU   X5, X7
	PCMPGTB X1, X7
	PXOR    X8, X8
	PCMPGTB X1, X8
	PXOR    X8, X7
	PAND    X6, X7
	PADDB   X7, X0
	MOVOU   X0, (DI)(AX*8)
	ADDQ    $2, AX
	LOOPNE  btl_loop

btl_tail:
	MOVOU   (SI)(AX*8), X0
	MOVOU   X0, X1
	PSUBB   X4, X1
	PCMPGTB X1, X5
	PXOR    X8, X8
	PCMPGTB X1, X8
	PXOR    X8, X5
	PAND    X6, X5
	PADDB   X5, X0

	LEAQ    (DI)(AX*8), DI // Destination address
	PCMPEQB X8, X8         // All 1's for mask
	PXOR    X7, X7         // All 0's for mask shift
	SHLQ    $3, BX         // BX *= 8 (len * sizeof(BYTE))
	CMPQ    BX, $64
	JG      btl_high

	MOVQ $64, R9
	MOVQ $64, R8
	SUBQ BX, R8

btl_high:
	MOVQ $128, R9
	XORQ R8, R8
	SUBQ BX, R9

btl_tail_end:
	MOVQ       R9, X7 // High mask shift
	PUNPCKLQDQ X7, X7 // Move high shift to high quadword
	MOVQ       R8, X7 // Low mask shift
	PSRLQ      X7, X8 // Shift mask
	MASKMOVDQU X8, X0 // Only move those tail bytes

btl_end:
	RET

