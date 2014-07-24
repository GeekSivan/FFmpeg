; /*
; * Provide SSE & MMX idct functions for HEVC decoding
; * Copyright (c) 2014 Pierre-Edouard LEPERE
; *
; * This file is part of FFmpeg.
; *
; * FFmpeg is free software; you can redistribute it and/or
; * modify it under the terms of the GNU Lesser General Public
; * License as published by the Free Software Foundation; either
; * version 2.1 of the License, or (at your option) any later version.
; *
; * FFmpeg is distributed in the hope that it will be useful,
; * but WITHOUT ANY WARRANTY; without even the implied warranty of
; * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; * Lesser General Public License for more details.
; *
; * You should have received a copy of the GNU Lesser General Public
; * License along with FFmpeg; if not, write to the Free Software
; * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
; */
%include "libavutil/x86/x86util.asm"

SECTION_RODATA
max_pixels_10:          times 16  dw ((1 << 10)-1)
dc_add_10:              times 4 dd ((1 << 14-10) + 1)


SECTION .text

;the idct_dc_add macros and functions were largely inspired by x264 project's code in the h264_idct.asm file
%macro DC_ADD_INIT_MMX 2
    mova              m2, [r1]
    mova              m4, [r1+8]
    pxor              m3, m3
    psubw             m3, m2
    packuswb          m2, m2
    packuswb          m3, m3
    pxor              m5, m5
    psubw             m5, m4
    packuswb          m4, m4
    packuswb          m5, m5
%endmacro

%macro DC_ADD_INIT 2-3
    mova              m0, [r1]
    mova              m4, [r1+8]
    pxor              m1, m1
    psubw             m1, m0
    packuswb          m0, m0
    packuswb          m1, m1
    pxor              m5, m5
    psubw             m5, m4
    packuswb          m4, m4
    packuswb          m5, m5
%endmacro

%macro DC_ADD_INIT_AVX2 2
    add              %1w, ((1 << 14-8) + 1)
    sar              %1w, (15-8)
    movd             xm0, %1d
    vpbroadcastw      m0, xm0    ;SPLATW
    lea               %1, [%2*3]
    pxor              m1, m1
    psubw             m1, m0
    packuswb          m0, m0
    packuswb          m1, m1
%endmacro

%macro DC_ADD_OP_MMX 4
    %1                m0, [%2     ]
    %1                m1, [%2+%3  ]
    paddusb           m0, m2
    paddusb           m1, m4
    psubusb           m0, m3
    psubusb           m1, m5
    %1         [%2     ], m0
    %1         [%2+%3  ], m1
%endmacro

%macro DC_ADD_INIT_SSE_8 2
    movu              m4, [r1]
    movu              m6, [r1+16]
    movu              m8, [r1+32]
    movu             m10, [r1+48]
    lea               %1, [%2*3]
    pxor              m5, m5
    psubw             m5, m4
    packuswb          m4, m4
    packuswb          m5, m5
    pxor              m7, m7
    psubw             m7, m6
    packuswb          m6, m6
    packuswb          m7, m7
    pxor              m9, m9
    psubw             m9, m8
    packuswb          m8, m8
    packuswb          m9, m9
    pxor             m11, m11
    psubw            m11, m10
    packuswb         m10, m10
    packuswb         m11, m11
%endmacro

%macro DC_ADD_INIT_SSE_16 2
    lea               %1, [%2*3]
    movu              m4, [r1]
    movu              m6, [r1+16]
    pxor              m5, m5
    psubw             m7, m5, m6
    psubw             m5, m4
    packuswb          m4, m6
    packuswb          m5, m7

    movu              m6, [r1+32]
    movu              m8, [r1+48]
    pxor              m7, m7
    psubw             m9, m7, m8
    psubw             m7, m6
    packuswb          m6, m8
    packuswb          m7, m9

    movu              m8, [r1+64]
    movu             m10, [r1+80]
    pxor              m9, m9
    psubw            m11, m9, m10
    psubw             m9, m8
    packuswb          m8, m10
    packuswb          m9, m11

    movu             m10, [r1+96]
    movu             m12, [r1+112]
    pxor             m11, m11
    psubw            m13, m11, m12
    psubw            m11, m10
    packuswb         m10, m12
    packuswb         m11, m13
%endmacro

%macro DC_ADD_OP_SSE 4
    %1                m0, [%2     ]
    %1                m1, [%2+%3  ]
    %1                m2, [%2+%3*2]
    %1                m3, [%2+%4  ]
    paddusb           m0, m4
    paddusb           m1, m6
    paddusb           m2, m8
    paddusb           m3, m10
    psubusb           m0, m5
    psubusb           m1, m7
    psubusb           m2, m9
    psubusb           m3, m11
    %1         [%2     ], m0
    %1         [%2+%3  ], m1
    %1         [%2+2*%3], m2
    %1         [%2+%4  ], m3
%endmacro

%macro DC_ADD_OP_SSE_32 4
    %1                m0, [%2      ]
    %1                m1, [%2+16   ]
    %1                m2, [%2+%3   ]
    %1                m3, [%2+%3+16]
    paddusb           m0, m4
    paddusb           m1, m6
    paddusb           m2, m8
    paddusb           m3, m10
    psubusb           m0, m5
    psubusb           m1, m7
    psubusb           m2, m9
    psubusb           m3, m11
    %1        [%2      ], m0
    %1        [%2+16   ], m1
    %1        [%2+%3   ], m2
    %1        [%2+%3+16], m3
%endmacro


%macro DC_ADD_OP 4
    %1                m0, [%2     ]
    %1                m1, [%2+%3  ]
    %1                m2, [%2+%3*2]
    %1                m3, [%2+%4  ]
    paddusb           m0, m4
    paddusb           m1, m6
    paddusb           m2, m8
    paddusb           m3, m10
    psubusb           m0, m5
    psubusb           m1, m7
    psubusb           m2, m9
    psubusb           m3, m11
    %1         [%2     ], m0
    %1         [%2+%3  ], m1
    %1         [%2+2*%3], m2
    %1         [%2+%4  ], m3
%endmacro

%macro DC_ADD_OP_AVX2 3
    mova              m2, [%1     ]
    mova              m3, [%1+%2  ]
    mova              m4, [%1+%2*2]
    mova              m5, [%1+%3  ]
    paddusb           m2, m0
    paddusb           m3, m0
    paddusb           m4, m0
    paddusb           m5, m0
    psubusb           m2, m1
    psubusb           m3, m1
    psubusb           m4, m1
    psubusb           m5, m1
    vmovdqa    [%1     ], m2
    vmovdqa    [%1+%2  ], m3
    vmovdqa    [%1+%2*2], m4
    vmovdqa    [%1+%3  ], m5
%endmacro

%macro TRANSFORM_ADD 3
    mova              m2, [%1     ]
    mova              m3, [%1+%2  ]
    mova              m4, [%1+%2*2]
    mova              m5, [%1+%3  ]
%endmacro

INIT_MMX mmxext
; void ff_hevc_idct_dc_add_8_mmxext(uint8_t *dst, int16_t *coeffs, ptrdiff_t stride)
cglobal hevc_transform_add4_8, 3, 4, 6
    DC_ADD_INIT_MMX   r3, r2
    DC_ADD_OP_MMX   movh, r0, r2, r3
    lea               r1, [r1+16]
    lea               r0, [r0+r2*2]
    DC_ADD_INIT_MMX   r3, r2
    DC_ADD_OP_MMX   movh, r0, r2, r3
    RET


INIT_XMM sse2
; void ff_hevc_transform_add8_8_sse2(uint8_t *dst, int16_t *coeffs, ptrdiff_t stride)
cglobal hevc_transform_add8_8, 3, 4, 6
    DC_ADD_INIT_SSE_8 r3, r2
    DC_ADD_OP_SSE   movh, r0, r2, r3
    lea               r1, [r1+8*8]
    lea               r0, [r0+r2*4]
    DC_ADD_INIT_SSE_8 r3, r2
    DC_ADD_OP_SSE   movh, r0, r2, r3
    RET


; void ff_hevc_transform_add16_8_sse2(uint8_t *dst, int16_t *coeffs, ptrdiff_t stride)
cglobal hevc_transform_add16_8, 3, 4, 6
    DC_ADD_INIT_SSE_16 r3, r2
    DC_ADD_OP_SSE    movu, r0, r2, r3
%rep 3
    lea                r1, [r1+16*8]
    lea                r0, [r0+r2*4]
    DC_ADD_INIT_SSE_16 r3, r2
    DC_ADD_OP_SSE    movu, r0, r2, r3
%endrep
    RET

; void ff_hevc_transform_add16_8_sse2(uint8_t *dst, int16_t *coeffs, ptrdiff_t stride)
cglobal hevc_transform_add32_8, 3, 4, 6
    DC_ADD_INIT_SSE_16 r3, r2
    DC_ADD_OP_SSE_32 movu, r0, r2, r3
%rep 15
    lea                r1, [r1+16*8]
    lea                r0, [r0+r2*2]
    DC_ADD_INIT_SSE_16 r3, r2
    DC_ADD_OP_SSE_32 movu, r0, r2, r3
%endrep
    RET

%if HAVE_AVX2_EXTERNAL
INIT_YMM avx2
; void ff_hevc_idct32_dc_add_8_avx2(uint8_t *dst, int16_t *coeffs, ptrdiff_t stride)
cglobal hevc_idct32_dc_add_8, 3, 4, 6
    movsx             r3, word [r1]
    DC_ADD_INIT_AVX2  r3, r2
    DC_ADD_OP       mova, r0, r2, r3,
 %rep 7
    lea               r0, [r0+r2*4]
    DC_ADD_OP       mova, r0, r2, r3
%endrep
    RET
%endif ;HAVE_AVX2_EXTERNAL
;-----------------------------------------------------------------------------
; void ff_hevc_idct_dc_add_10(pixel *dst, int16_t *block, int stride)
;-----------------------------------------------------------------------------
%macro IDCT_DC_ADD_OP_10 3
    pxor              m5, m5
%if avx_enabled
    paddw             m1, m0, [%1+0   ]
    paddw             m2, m0, [%1+%2  ]
    paddw             m3, m0, [%1+%2*2]
    paddw             m4, m0, [%1+%3  ]
%else
    mova              m1, [%1+0   ]
    mova              m2, [%1+%2  ]
    mova              m3, [%1+%2*2]
    mova              m4, [%1+%3  ]
    paddw             m1, m0
    paddw             m2, m0
    paddw             m3, m0
    paddw             m4, m0
%endif
    CLIPW             m1, m5, m6
    CLIPW             m2, m5, m6
    CLIPW             m3, m5, m6
    CLIPW             m4, m5, m6
    mova       [%1+0   ], m1
    mova       [%1+%2  ], m2
    mova       [%1+%2*2], m3
    mova       [%1+%3  ], m4
%endmacro

INIT_MMX mmxext
cglobal hevc_idct4_dc_add_10,3,3, 7
    mov              r1w, [r1]
    add              r1w, ((1 << 4) + 1)
    sar              r1w, 5
    movd              m0, r1d
    lea               r1, [r2*3]
    SPLATW            m0, m0, 0
    mova              m6, [max_pixels_10]
    IDCT_DC_ADD_OP_10 r0, r2, r1
    RET

;-----------------------------------------------------------------------------
; void ff_hevc_idct8_dc_add_10(pixel *dst, int16_t *block, int stride)
;-----------------------------------------------------------------------------
%macro IDCT8_DC_ADD 0
cglobal hevc_idct8_dc_add_10,3,4,7
    mov              r1w, [r1]
    add              r1w, ((1 << 4) + 1)
    sar              r1w, 5
    movd              m0, r1d
    lea               r1, [r2*3]
    SPLATW            m0, m0, 0
    mova              m6, [max_pixels_10]
    IDCT_DC_ADD_OP_10 r0, r2, r1
    lea               r0, [r0+r2*4]
    IDCT_DC_ADD_OP_10 r0, r2, r1
    RET
%endmacro

INIT_XMM sse2
IDCT8_DC_ADD
%if HAVE_AVX_EXTERNAL
INIT_XMM avx
IDCT8_DC_ADD
%endif

%if HAVE_AVX2_EXTERNAL
INIT_YMM avx2
cglobal hevc_idct16_dc_add_10,3,4,7
    mov              r1w, [r1]
    add              r1w, ((1 << 4) + 1)
    sar              r1w, 5
    movd             xm0, r1d
    lea               r1, [r2*3]
    vpbroadcastw      m0, xm0    ;SPLATW
    mova              m6, [max_pixels_10]
    IDCT_DC_ADD_OP_10 r0, r2, r1
    lea               r0, [r0+r2*4]
    IDCT_DC_ADD_OP_10 r0, r2, r1
    lea               r0, [r0+r2*4]
    IDCT_DC_ADD_OP_10 r0, r2, r1
    lea               r0, [r0+r2*4]
    IDCT_DC_ADD_OP_10 r0, r2, r1
    RET
%endif ;HAVE_AVX_EXTERNAL
