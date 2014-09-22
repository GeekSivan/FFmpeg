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

edge_shuffle:          db   1, 2, 0, 3, 4
              times 11 db  -1

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

cglobal hevc_sao_edge_filter_border_8_8, 3, 3, 2, value, src, dst
    movh              m0, valueq
    SPLATW            m0, m0, 0
    movh              m1, [srcq]
    paddb             m0, m1
    movh          [dstq], m0
    RET


cglobal hevc_sao_edge_filter_border_16_8, 3, 3, 2, value, src, dst
    movd              m0, valued
    SPLATW            m0, m0, 0
    movu              m1, [srcq]
    paddb             m0, m1
    movu          [dstq], m0
    RET

INIT_XMM avx

cglobal hevc_sao_edge_filter_main_8_8, 8, 13, 8, src0, src1, src2, dst, srcstride, dststride, sao_offset_val, height, rtmp0, rtmp1, rtmp2, rtmp3, rtmp4

    movu              m0, [sao_offset_valq]
    packsswb          m0, m0
    movu              m1, [edge_shuffle]
    pshufb            m0, m1
    xor            rtmp0q, rtmp0q
    mov            rtmp0q, 2
.loop
    movq               m1, [src0q]
    movq               m2, [src1q]
    movq               m3, [src2q]

    pminub             m4, m1, m2
    pcmpeqb            m5, m2, m4
    pcmpeqb            m6, m1, m4
    psubb              m5, m6, m5
    pminub             m4, m1, m3
    pcmpeqb            m7, m3, m4
    pcmpeqb            m6, m1, m4
    psubb              m7, m6, m7
;                    movq           [dstq], m7

    paddb              m5, m7
    movq               m6, rtmp0q
    punpcklbw          m6, m6
    SPLATW             m6, m6
    paddb              m5, m6

    pshufb             m2, m0, m5                   ;SSSE3 instruction
    pmovsxbw           m2, m2
;    pxor               m3, m3
;    pcmpgtb            m3, m2                        ;do not mix instruction with 256b registers
;    punpcklbw          m2, m3
    pxor               m3, m3
    punpcklbw          m1, m3
    paddw              m2, m1
    packuswb           m2, m2
    movq           [dstq], m2

    add             src0q, srcstrideq
    add             src1q, srcstrideq
    add             src2q, srcstrideq
    add              dstq, dststrideq
    dec          heightd
    jnz               .loop
    RET


;#if HAVE_SSE42
;#define _MM_CVTEPI8_EPI16 _mm_cvtepi8_epi16
;
;#else
;static inline __m128i _MM_CVTEPI8_EPI16(__m128i m0) {
;    return _mm_unpacklo_epi8(m0, _mm_cmplt_epi8(m0, _mm_setzero_si128()));
;}
;#endif

;         ff_hevc_sao_edge_filter_main_8_8_sse2(src + y_stride_src, src + y_stride_0_1, src + y_stride_1_1, dst + y_stride_dst, sao_offset_val[edge_idx[4]],
;                 sao_offset_val[edge_idx[3]], sao_offset_val[edge_idx[2]], sao_offset_val[edge_idx[1]], sao_offset_val[edge_idx[0]], height);
;         offset0 = _mm_set_epi8(0, 0, 0, 0,
;                               0, 0, 0, 0,
;                               0, 0, 0, sao_offset_val[edge_idx[4]],
;                               sao_offset_val[edge_idx[3]], sao_offset_val[edge_idx[2]], sao_offset_val[edge_idx[1]], sao_offset_val[edge_idx[0]]);
;        for (y = init_y; y < height; y++) {
;            for (x = 0; x < width; x += 8) {
;                x0   = _mm_loadl_epi64((__m128i *) (src + x + y_stride_src));
;                cmp0 = _mm_loadl_epi64((__m128i *) (src + x + y_stride_0_1));
;                cmp1 = _mm_loadl_epi64((__m128i *) (src + x + y_stride_1_1));
;                r2 = _mm_min_epu8(x0, cmp0);
;                x1 = _mm_cmpeq_epi8(cmp0, r2);
;                x2 = _mm_cmpeq_epi8(x0, r2);
;                x1 = _mm_sub_epi8(x2, x1);
;                r2 = _mm_min_epu8(x0, cmp1);
;                x3 = _mm_cmpeq_epi8(cmp1, r2);
;                x2 = _mm_cmpeq_epi8(x0, r2);
;                x3 = _mm_sub_epi8(x2, x3);
;                x1 = _mm_add_epi8(x1, x3);
;                x1 = _mm_add_epi8(x1, _mm_set1_epi8(2));
;                r0 = _mm_shuffle_epi8(offset0, x1);
;                r0 = _MM_CVTEPI8_EPI16(r0);
;                x0 = _mm_unpacklo_epi8(x0, _mm_setzero_si128());
;                r0 = _mm_add_epi16(r0, x0);
;                r0 = _mm_packus_epi16(r0, r0);
;                _mm_storel_epi64((__m128i *) (dst + x + y_stride_dst), r0);
;            }
;            y_stride_dst += stride_dst;
;            y_stride_src += stride_src;
;            y_stride_0_1 += stride_src;
;            y_stride_1_1 += stride_src;
;        }



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
