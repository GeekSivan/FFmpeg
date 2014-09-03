; /*
; * Provide SSE SAO functions for HEVC decoding
; * Copyright (c) 2013 Pierre-Edouard LEPERE
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

SECTION_RODATA 32


SECTION_TEXT 32

%macro LOOP_END 4
    add              %1q, %2q                    ; dst += dststride
    add              %3q, %4q                    ; src += srcstride
    dec          heightd                         ; cmp height
    jnz               .loop                      ; height loop
%endmacro

%macro SAO_BAND_INIT_SSE 0
    and            leftq, 31
    movd              m0, leftq
    inc            leftq
    and            leftq, 31
    movd              m1, leftq
    inc            leftq
    and            leftq, 31
    movd              m2, leftq
    inc            leftq
    and            leftq, 31
    movd              m3, leftq

    movd              m4, [offsetq + 2]
    movd              m5, [offsetq + 4]
    movd              m6, [offsetq + 6]
    movd              m7, [offsetq + 8]

    SPLATW            m0, m0
    SPLATW            m1, m1
    SPLATW            m2, m2
    SPLATW            m3, m3
    SPLATW            m4, m4
    SPLATW            m5, m5
    SPLATW            m6, m6
    SPLATW            m7, m7

    pxor             m14, m14
%endmacro

%macro SAO_BAND_INIT_AVX 0
    and            leftq, 31
    movd             xm0, leftd
    inc            leftq
    and            leftq, 31
    movd             xm1, leftd
    inc            leftq
    and            leftq, 31
    movd             xm2, leftd
    inc            leftq
    and            leftq, 31
    movd             xm3, leftd

    movd              xm4, [offsetq + 2]
    movd              xm5, [offsetq + 4]
    movd              xm6, [offsetq + 6]
    movd              xm7, [offsetq + 8]

    SPLATW            m0, xm0, 0
    SPLATW            m1, xm1, 0
    SPLATW            m2, xm2, 0
    SPLATW            m3, xm3, 0
    SPLATW            m4, xm4, 0
    SPLATW            m5, xm5, 0
    SPLATW            m6, xm6, 0
    SPLATW            m7, xm7, 0

    pxor             m14, m14
%endmacro

INIT_XMM sse2

cglobal hevc_sao_band_filter_0_8_8, 7, 7, 6, dst, src, dststride, srcstride, offset, left, height

    SAO_BAND_INIT_SSE

.loop

    movh              m15, [srcq]
    punpcklbw         m8, m15, m14
    psraw             m9, m8, 3
    pcmpeqw          m10, m9, m0
    pcmpeqw          m11, m9, m1
    pcmpeqw          m12, m9, m2
    pcmpeqw          m13, m9, m3

    pand             m10, m4
    pand             m11, m5
    pand             m12, m6
    pand             m13, m7

    por              m10, m11
    por              m12, m13
    por              m10, m12

    paddw             m8, m10
    packuswb          m8, m14

    movh          [dstq], m8

    LOOP_END        dst, dststride, src, srcstride
    RET



cglobal hevc_sao_band_filter_0_16_8, 7, 7, 6, dst, src, dststride, srcstride, offset, left, height

    SAO_BAND_INIT_SSE

.loop

    movu              m15, [srcq]
    punpcklbw         m8, m15, m14
    psraw             m9, m8, 3
    pcmpeqw          m10, m9, m0
    pcmpeqw          m11, m9, m1
    pcmpeqw          m12, m9, m2
    pcmpeqw          m13, m9, m3

    pand             m10, m4
    pand             m11, m5
    pand             m12, m6
    pand             m13, m7

    por              m10, m11
    por              m12, m13
    por              m10, m12

    paddw             m8, m10

    punpckhbw         m15, m14
    psraw             m9, m15, 3
    pcmpeqw          m10, m9, m0
    pcmpeqw          m11, m9, m1
    pcmpeqw          m12, m9, m2
    pcmpeqw          m13, m9, m3

    pand             m10, m4
    pand             m11, m5
    pand             m12, m6
    pand             m13, m7

    por              m10, m11
    por              m12, m13
    por              m10, m12

    paddw            m15, m10
    packuswb          m8, m15

    movu          [dstq], m8

    LOOP_END        dst, dststride, src, srcstride
    RET






cglobal hevc_sao_band_filter_0_32_8, 7, 7, 6, dst, src, dststride, srcstride, offset, left, height

    SAO_BAND_INIT_SSE

.loop
%assign i 0
%rep    2
    movu              m15, [srcq + i]
    punpcklbw         m8, m15, m14
    psraw             m9, m8, 3
    pcmpeqw          m10, m9, m0
    pcmpeqw          m11, m9, m1
    pcmpeqw          m12, m9, m2
    pcmpeqw          m13, m9, m3

    pand             m10, m4
    pand             m11, m5
    pand             m12, m6
    pand             m13, m7

    por              m10, m11
    por              m12, m13
    por              m10, m12

    paddw             m8, m10

    punpckhbw         m15, m14
    psraw             m9, m15, 3
    pcmpeqw          m10, m9, m0
    pcmpeqw          m11, m9, m1
    pcmpeqw          m12, m9, m2
    pcmpeqw          m13, m9, m3

    pand             m10, m4
    pand             m11, m5
    pand             m12, m6
    pand             m13, m7

    por              m10, m11
    por              m12, m13
    por              m10, m12

    paddw            m15, m10
    packuswb          m8, m15

    movu      [dstq + i], m8
%assign i i+16
%endrep

    LOOP_END        dst, dststride, src, srcstride
    RET



cglobal hevc_sao_band_filter_0_56_8, 7, 7, 6, dst, src, dststride, srcstride, offset, left, height

    SAO_BAND_INIT_SSE

.loop
%assign i 0
%rep    3
    movu              m15, [srcq + i]
    punpcklbw         m8, m15, m14
    psraw             m9, m8, 3
    pcmpeqw          m10, m9, m0
    pcmpeqw          m11, m9, m1
    pcmpeqw          m12, m9, m2
    pcmpeqw          m13, m9, m3

    pand             m10, m4
    pand             m11, m5
    pand             m12, m6
    pand             m13, m7

    por              m10, m11
    por              m12, m13
    por              m10, m12

    paddw             m8, m10

    punpckhbw         m15, m14
    psraw             m9, m15, 3
    pcmpeqw          m10, m9, m0
    pcmpeqw          m11, m9, m1
    pcmpeqw          m12, m9, m2
    pcmpeqw          m13, m9, m3

    pand             m10, m4
    pand             m11, m5
    pand             m12, m6
    pand             m13, m7

    por              m10, m11
    por              m12, m13
    por              m10, m12

    paddw            m15, m10
    packuswb          m8, m15

    movu      [dstq + i], m8
%assign i i+16

    movu              m15, [srcq + i]
    punpcklbw         m8, m15, m14
    psraw             m9, m8, 3
    pcmpeqw          m10, m9, m0
    pcmpeqw          m11, m9, m1
    pcmpeqw          m12, m9, m2
    pcmpeqw          m13, m9, m3

    pand             m10, m4
    pand             m11, m5
    pand             m12, m6
    pand             m13, m7

    por              m10, m11
    por              m12, m13
    por              m10, m12

    paddw             m8, m10
    packuswb          m8, m15

    movu      [dstq + i], m8
%endrep

    LOOP_END        dst, dststride, src, srcstride
    RET


cglobal hevc_sao_band_filter_0_64_8, 7, 7, 6, dst, src, dststride, srcstride, offset, left, height

    SAO_BAND_INIT_SSE

.loop
%assign i 0
%rep    4
    movu              m15, [srcq + i]
    punpcklbw         m8, m15, m14
    psraw             m9, m8, 3
    pcmpeqw          m10, m9, m0
    pcmpeqw          m11, m9, m1
    pcmpeqw          m12, m9, m2
    pcmpeqw          m13, m9, m3

    pand             m10, m4
    pand             m11, m5
    pand             m12, m6
    pand             m13, m7

    por              m10, m11
    por              m12, m13
    por              m10, m12

    paddw             m8, m10

    punpckhbw         m15, m14
    psraw             m9, m15, 3
    pcmpeqw          m10, m9, m0
    pcmpeqw          m11, m9, m1
    pcmpeqw          m12, m9, m2
    pcmpeqw          m13, m9, m3

    pand             m10, m4
    pand             m11, m5
    pand             m12, m6
    pand             m13, m7

    por              m10, m11
    por              m12, m13
    por              m10, m12

    paddw            m15, m10
    packuswb          m8, m15

    movu      [dstq + i], m8
%assign i i+16
%endrep

    LOOP_END        dst, dststride, src, srcstride
    RET

INIT_YMM avx2

cglobal hevc_sao_band_filter_0_32_8, 7, 7, 6, dst, src, dststride, srcstride, offset, left, height

    SAO_BAND_INIT_AVX

.loop

    movu             m15, [srcq]
    punpcklbw         m8, m15, m14
    psraw             m9, m8, 3
    pcmpeqw          m10, m9, m0
    pcmpeqw          m11, m9, m1
    pcmpeqw          m12, m9, m2
    pcmpeqw          m13, m9, m3

    pand             m10, m4
    pand             m11, m5
    pand             m12, m6
    pand             m13, m7

    por              m10, m11
    por              m12, m13
    por              m10, m12

    paddw             m8, m10

    punpckhbw        m15, m14
    psraw             m9, m15, 3
    pcmpeqw          m10, m9, m0
    pcmpeqw          m11, m9, m1
    pcmpeqw          m12, m9, m2
    pcmpeqw          m13, m9, m3

    pand             m10, m4
    pand             m11, m5
    pand             m12, m6
    pand             m13, m7

    por              m10, m11
    por              m12, m13
    por              m10, m12

    paddw            m15, m10
    packuswb          m8, m15

    movu          [dstq], m8

    LOOP_END        dst, dststride, src, srcstride
    RET


cglobal hevc_sao_band_filter_0_56_8, 7, 7, 6, dst, src, dststride, srcstride, offset, left, height

    SAO_BAND_INIT_AVX

.loop

    movu             m15, [srcq]
    punpcklbw         m8, m15, m14
    psraw             m9, m8, 3
    pcmpeqw          m10, m9, m0
    pcmpeqw          m11, m9, m1
    pcmpeqw          m12, m9, m2
    pcmpeqw          m13, m9, m3

    pand             m10, m4
    pand             m11, m5
    pand             m12, m6
    pand             m13, m7

    por              m10, m11
    por              m12, m13
    por              m10, m12

    paddw             m8, m10

    punpckhbw        m15, m14
    psraw             m9, m15, 3
    pcmpeqw          m10, m9, m0
    pcmpeqw          m11, m9, m1
    pcmpeqw          m12, m9, m2
    pcmpeqw          m13, m9, m3

    pand             m10, m4
    pand             m11, m5
    pand             m12, m6
    pand             m13, m7

    por              m10, m11
    por              m12, m13
    por              m10, m12

    paddw            m15, m10
    packuswb          m8, m15

    movu          [dstq], m8

    movu            xm15, [srcq + 32]
    punpcklbw        xm8, xm15, xm14
    psraw            xm9, xm8, 3
    pcmpeqw         xm10, xm9, xm0
    pcmpeqw         xm11, xm9, xm1
    pcmpeqw         xm12, xm9, xm2
    pcmpeqw         xm13, xm9, xm3

    pand            xm10, xm4
    pand            xm11, xm5
    pand            xm12, xm6
    pand            xm13, xm7

    por             xm10, xm11
    por             xm12, xm13
    por             xm10, xm12

    paddw            xm8, xm10

    punpckhbw       xm15, xm14
    psraw            xm9, xm15, 3
    pcmpeqw         xm10, xm9, xm0
    pcmpeqw         xm11, xm9, xm1
    pcmpeqw         xm12, xm9, xm2
    pcmpeqw         xm13, xm9, xm3

    pand            xm10, xm4
    pand            xm11, xm5
    pand            xm12, xm6
    pand            xm13, xm7

    por             xm10, xm11
    por             xm12, xm13
    por             xm10, xm12

    paddw           xm15, xm10
    packuswb         xm8, xm15

    movu     [dstq + 32], m8

    movq            xm15, [srcq + 48]
    punpcklbw        xm8, xm15, xm14
    psraw            xm9, xm8, 3
    pcmpeqw         xm10, xm9, xm0
    pcmpeqw         xm11, xm9, xm1
    pcmpeqw         xm12, xm9, xm2
    pcmpeqw         xm13, xm9, xm3

    pand            xm10, xm4
    pand            xm11, xm5
    pand            xm12, xm6
    pand            xm13, xm7

    por             xm10, xm11
    por             xm12, xm13
    por             xm10, xm12

    paddw            xm8, xm10
    packuswb         xm8, xm14

    movq     [dstq + 48], xm8

    LOOP_END        dst, dststride, src, srcstride
    RET

cglobal hevc_sao_band_filter_0_64_8, 7, 7, 6, dst, src, dststride, srcstride, offset, left, height

    SAO_BAND_INIT_AVX

.loop
%assign i 0
%rep    2
    movu             m15, [srcq + i]
    punpcklbw         m8, m15, m14
    psraw             m9, m8, 3
    pcmpeqw          m10, m9, m0
    pcmpeqw          m11, m9, m1
    pcmpeqw          m12, m9, m2
    pcmpeqw          m13, m9, m3

    pand             m10, m4
    pand             m11, m5
    pand             m12, m6
    pand             m13, m7

    por              m10, m11
    por              m12, m13
    por              m10, m12

    paddw             m8, m10

    punpckhbw        m15, m14
    psraw             m9, m15, 3
    pcmpeqw          m10, m9, m0
    pcmpeqw          m11, m9, m1
    pcmpeqw          m12, m9, m2
    pcmpeqw          m13, m9, m3

    pand             m10, m4
    pand             m11, m5
    pand             m12, m6
    pand             m13, m7

    por              m10, m11
    por              m12, m13
    por              m10, m12

    paddw            m15, m10
    packuswb          m8, m15

    movu      [dstq + i], m8
%assign i i+32
%endrep

    LOOP_END        dst, dststride, src, srcstride
    RET
