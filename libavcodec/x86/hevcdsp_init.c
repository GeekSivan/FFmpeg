/*
 * Copyright (c) 2013 Seppo Tomperi
 * Copyright (c) 2013 - 2014 Pierre-Edouard Lepere
 *
 *
 * This file is part of ffmpeg.
 *
 * ffmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * ffmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with ffmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#include "config.h"
#include "libavutil/cpu.h"
#include "libavutil/x86/asm.h"
#include "libavutil/x86/cpu.h"
#include "libavcodec/get_bits.h" /* required for hevcdsp.h GetBitContext */
#include "libavcodec/hevcdsp.h"
#include "libavcodec/x86/hevcdsp.h"

/***********************************/
/* deblocking */

#define LFC_FUNC(DIR, DEPTH, OPT)                                        \
void ff_hevc_ ## DIR ## _loop_filter_chroma_ ## DEPTH ## _ ## OPT(uint8_t *_pix, ptrdiff_t _stride, int *_tc, uint8_t *_no_p, uint8_t *_no_q);

#define LFL_FUNC(DIR, DEPTH, OPT)                                        \
void ff_hevc_ ## DIR ## _loop_filter_luma_ ## DEPTH ## _ ## OPT(uint8_t *_pix, ptrdiff_t stride, int *_beta, int *_tc, \
uint8_t *_no_p, uint8_t *_no_q);

#define LFC_FUNCS(type, depth) \
LFC_FUNC(h, depth, sse2)  \
LFC_FUNC(v, depth, sse2)

#define LFL_FUNCS(type, depth) \
LFL_FUNC(h, depth, ssse3)  \
LFL_FUNC(v, depth, ssse3)

LFC_FUNCS(uint8_t,   8)
LFC_FUNCS(uint8_t,  10)
LFL_FUNCS(uint8_t,   8)
LFL_FUNCS(uint8_t,  10)

#ifdef OPTI_ASM
#if ARCH_X86_64

#define mc_rep_func(name, bitd, step, W) \
void ff_hevc_put_hevc_##name##W##_##bitd##_sse4(int16_t *_dst, ptrdiff_t dststride,                             \
                                                uint8_t *_src, ptrdiff_t _srcstride, int height,                \
                                                intptr_t mx, intptr_t my, int width)                            \
{                                                                                                               \
    int i;                                                                                                      \
    uint8_t *src;                                                                                               \
    int16_t *dst;                                                                                               \
    for (i = 0; i < W; i += step) {                                                                             \
        src  = _src + (i * ((bitd + 7) / 8));                                                                   \
        dst = _dst + i;                                                                                         \
        ff_hevc_put_hevc_##name##step##_##bitd##_sse4(dst, dststride, src, _srcstride, height, mx, my, width);  \
    }                                                                                                           \
}
#define mc_rep_uni_func(name, bitd, step, W) \
void ff_hevc_put_hevc_uni_##name##W##_##bitd##_sse4(uint8_t *_dst, ptrdiff_t dststride,                         \
                                                    uint8_t *_src, ptrdiff_t _srcstride, int height,            \
                                                    intptr_t mx, intptr_t my, int width)                        \
{                                                                                                               \
    int i;                                                                                                      \
    uint8_t *src;                                                                                               \
    uint8_t *dst;                                                                                               \
    for (i = 0; i < W; i += step) {                                                                             \
        src = _src + (i * ((bitd + 7) / 8));                                                                    \
        dst = _dst + (i * ((bitd + 7) / 8));                                                                    \
        ff_hevc_put_hevc_uni_##name##step##_##bitd##_sse4(dst, dststride, src, _srcstride,                      \
                                                          height, mx, my, width);                               \
    }                                                                                                           \
}
#define mc_rep_bi_func(name, bitd, step, W) \
void ff_hevc_put_hevc_bi_##name##W##_##bitd##_sse4(uint8_t *_dst, ptrdiff_t dststride, uint8_t *_src,           \
                                                   ptrdiff_t _srcstride, int16_t* _src2, ptrdiff_t _src2stride, \
                                                   int height, intptr_t mx, intptr_t my, int width)             \
{                                                                                                               \
    int i;                                                                                                      \
    uint8_t  *src;                                                                                              \
    uint8_t  *dst;                                                                                              \
    int16_t  *src2;                                                                                             \
    for (i = 0; i < W ; i += step) {                                                                            \
        src  = _src + (i * ((bitd + 7) / 8));                                                                   \
        dst  = _dst + (i * ((bitd + 7) / 8));                                                                   \
        src2 = _src2 + i;                                                                                       \
        ff_hevc_put_hevc_bi_##name##step##_##bitd##_sse4(dst, dststride, src, _srcstride, src2,                 \
                                                         _src2stride, height, mx, my, width);                   \
    }                                                                                                           \
}

#define mc_rep_funcs(name, bitd, step, W)        \
    mc_rep_func(name, bitd, step, W);            \
    mc_rep_uni_func(name, bitd, step, W);        \
    mc_rep_bi_func(name, bitd, step, W)


mc_rep_funcs(pel_pixels, 8, 16, 64);
mc_rep_funcs(pel_pixels, 8, 16, 48);
mc_rep_funcs(pel_pixels, 8, 16, 32);
mc_rep_funcs(pel_pixels, 8,  8, 24);

mc_rep_funcs(pel_pixels,10,  8, 64);
mc_rep_funcs(pel_pixels,10,  8, 48);
mc_rep_funcs(pel_pixels,10,  8, 32);
mc_rep_funcs(pel_pixels,10,  8, 24);
mc_rep_funcs(pel_pixels,10,  8, 16);
mc_rep_funcs(pel_pixels,10,  4, 12);

mc_rep_funcs(epel_h, 8, 16, 64);
mc_rep_funcs(epel_h, 8, 16, 48);
mc_rep_funcs(epel_h, 8, 16, 32);
mc_rep_funcs(epel_h, 8,  8, 24);
mc_rep_funcs(epel_h,10,  8, 64);
mc_rep_funcs(epel_h,10,  8, 48);
mc_rep_funcs(epel_h,10,  8, 32);
mc_rep_funcs(epel_h,10,  8, 24);
mc_rep_funcs(epel_h,10,  8, 16);
mc_rep_funcs(epel_h,10,  4, 12);
mc_rep_funcs(epel_v, 8, 16, 64);
mc_rep_funcs(epel_v, 8, 16, 48);
mc_rep_funcs(epel_v, 8, 16, 32);
mc_rep_funcs(epel_v, 8,  8, 24);
mc_rep_funcs(epel_v,10,  8, 64);
mc_rep_funcs(epel_v,10,  8, 48);
mc_rep_funcs(epel_v,10,  8, 32);
mc_rep_funcs(epel_v,10,  8, 24);
mc_rep_funcs(epel_v,10,  8, 16);
mc_rep_funcs(epel_v,10,  4, 12);
mc_rep_funcs(epel_hv, 8,  8, 64);
mc_rep_funcs(epel_hv, 8,  8, 48);
mc_rep_funcs(epel_hv, 8,  8, 32);
mc_rep_funcs(epel_hv, 8,  8, 24);
mc_rep_funcs(epel_hv, 8,  8, 16);
mc_rep_funcs(epel_hv, 8,  4, 12);
mc_rep_funcs(epel_hv,10,  8, 64);
mc_rep_funcs(epel_hv,10,  8, 48);
mc_rep_funcs(epel_hv,10,  8, 32);
mc_rep_funcs(epel_hv,10,  8, 24);
mc_rep_funcs(epel_hv,10,  8, 16);
mc_rep_funcs(epel_hv,10,  4, 12);

mc_rep_funcs(qpel_h, 8, 16, 64);
mc_rep_funcs(qpel_h, 8, 16, 48);
mc_rep_funcs(qpel_h, 8, 16, 32);
mc_rep_funcs(qpel_h, 8,  8, 24);
mc_rep_funcs(qpel_h,10,  8, 64);
mc_rep_funcs(qpel_h,10,  8, 48);
mc_rep_funcs(qpel_h,10,  8, 32);
mc_rep_funcs(qpel_h,10,  8, 24);
mc_rep_funcs(qpel_h,10,  8, 16);
mc_rep_funcs(qpel_h,10,  4, 12);
mc_rep_funcs(qpel_v, 8, 16, 64);
mc_rep_funcs(qpel_v, 8, 16, 48);
mc_rep_funcs(qpel_v, 8, 16, 32);
mc_rep_funcs(qpel_v, 8,  8, 24);
mc_rep_funcs(qpel_v,10,  8, 64);
mc_rep_funcs(qpel_v,10,  8, 48);
mc_rep_funcs(qpel_v,10,  8, 32);
mc_rep_funcs(qpel_v,10,  8, 24);
mc_rep_funcs(qpel_v,10,  8, 16);
mc_rep_funcs(qpel_v,10,  4, 12);
mc_rep_funcs(qpel_hv, 8,  8, 64);
mc_rep_funcs(qpel_hv, 8,  8, 48);
mc_rep_funcs(qpel_hv, 8,  8, 32);
mc_rep_funcs(qpel_hv, 8,  8, 24);
mc_rep_funcs(qpel_hv, 8,  8, 16);
mc_rep_funcs(qpel_hv, 8,  4, 12);
mc_rep_funcs(qpel_hv,10,  8, 64);
mc_rep_funcs(qpel_hv,10,  8, 48);
mc_rep_funcs(qpel_hv,10,  8, 32);
mc_rep_funcs(qpel_hv,10,  8, 24);
mc_rep_funcs(qpel_hv,10,  8, 16);
mc_rep_funcs(qpel_hv,10,  4, 12);

#define mc_rep_uni_w(bitd, step, W) \
void ff_hevc_put_hevc_uni_w##W##_##bitd##_sse4(uint8_t *_dst, ptrdiff_t dststride, int16_t *_src, ptrdiff_t _srcstride, \
                                               int height, int denom,  int _wx, int _ox)                                \
{                                                                                                                       \
    int i;                                                                                                              \
    int16_t *src;                                                                                                       \
    uint8_t *dst;                                                                                                       \
    for (i = 0; i < W; i += step) {                                                                                     \
        src= _src + i;                                                                                                  \
        dst= _dst + (i * ((bitd + 7) / 8));                                                                             \
        ff_hevc_put_hevc_uni_w##step##_##bitd##_sse4(dst, dststride, src, _srcstride,                                   \
                                                     height, denom, _wx, _ox);                                          \
    }                                                                                                                   \
}

mc_rep_uni_w(8, 6, 12);
mc_rep_uni_w(8, 8, 16);
mc_rep_uni_w(8, 8, 24);
mc_rep_uni_w(8, 8, 32);
mc_rep_uni_w(8, 8, 48);
mc_rep_uni_w(8, 8, 64);

mc_rep_uni_w(10, 6, 12);
mc_rep_uni_w(10, 8, 16);
mc_rep_uni_w(10, 8, 24);
mc_rep_uni_w(10, 8, 32);
mc_rep_uni_w(10, 8, 48);
mc_rep_uni_w(10, 8, 64);

#define mc_rep_bi_w(bitd, step, W) \
void ff_hevc_put_hevc_bi_w##W##_##bitd##_sse4(uint8_t *_dst, ptrdiff_t dststride, int16_t *_src, ptrdiff_t _srcstride,  \
                                              int16_t *_src2, ptrdiff_t _src2stride, int height,                        \
                                              int denom,  int _wx0,  int _wx1, int _ox0, int _ox1)                      \
{                                                                                                                       \
    int i;                                                                                                              \
    int16_t *src;                                                                                                       \
    int16_t *src2;                                                                                                      \
    uint8_t *dst;                                                                                                       \
    for (i = 0; i < W; i += step) {                                                                                     \
        src  = _src  + i;                                                                                               \
        src2 = _src2 + i;                                                                                               \
        dst  = _dst  + (i * ((bitd + 7) / 8));                                                                          \
        ff_hevc_put_hevc_bi_w##step##_##bitd##_sse4(dst, dststride, src, _srcstride, src2, _src2stride,                 \
                                                    height, denom, _wx0, _wx1, _ox0, _ox1);                             \
    }                                                                                                                   \
}

mc_rep_bi_w(8, 6, 12);
mc_rep_bi_w(8, 8, 16);
mc_rep_bi_w(8, 8, 24);
mc_rep_bi_w(8, 8, 32);
mc_rep_bi_w(8, 8, 48);
mc_rep_bi_w(8, 8, 64);

mc_rep_bi_w(10, 6, 12);
mc_rep_bi_w(10, 8, 16);
mc_rep_bi_w(10, 8, 24);
mc_rep_bi_w(10, 8, 32);
mc_rep_bi_w(10, 8, 48);
mc_rep_bi_w(10, 8, 64);

#define mc_uni_w_func(name, bitd, W) \
void ff_hevc_put_hevc_uni_w_##name##W##_##bitd##_sse4(uint8_t *_dst, ptrdiff_t _dststride,          \
                                                      uint8_t *_src, ptrdiff_t _srcstride,          \
                                                      int height, int denom,                        \
                                                      int _wx, int _ox,                             \
                                                      intptr_t mx, intptr_t my, int width)          \
{                                                                                                   \
    LOCAL_ALIGNED_16(int16_t, temp, [71 * 64]);                                                     \
    ff_hevc_put_hevc_##name##W##_##bitd##_sse4(temp, 64, _src, _srcstride, height, mx, my, width);  \
    ff_hevc_put_hevc_uni_w##W##_##bitd##_sse4(_dst, _dststride, temp, 64, height, denom, _wx, _ox); \
}

#define mc_uni_w_funcs(name, bitd)       \
        mc_uni_w_func(name, bitd, 4);    \
        mc_uni_w_func(name, bitd, 8);    \
        mc_uni_w_func(name, bitd, 12);   \
        mc_uni_w_func(name, bitd, 16);   \
        mc_uni_w_func(name, bitd, 24);   \
        mc_uni_w_func(name, bitd, 32);   \
        mc_uni_w_func(name, bitd, 48);   \
        mc_uni_w_func(name, bitd, 64)

mc_uni_w_funcs(pel_pixels, 8);
mc_uni_w_func(pel_pixels, 8, 6);
mc_uni_w_funcs(epel_h, 8);
mc_uni_w_func(epel_h, 8, 6);
mc_uni_w_funcs(epel_v, 8);
mc_uni_w_func(epel_v, 8, 6);
mc_uni_w_funcs(epel_hv, 8);
mc_uni_w_func(epel_hv, 8, 6);
mc_uni_w_funcs(qpel_h, 8);
mc_uni_w_funcs(qpel_v, 8);
mc_uni_w_funcs(qpel_hv, 8);

mc_uni_w_funcs(pel_pixels, 10);
mc_uni_w_func(pel_pixels, 10, 6);
mc_uni_w_funcs(epel_h, 10);
mc_uni_w_func(epel_h, 10, 6);
mc_uni_w_funcs(epel_v, 10);
mc_uni_w_func(epel_v, 10, 6);
mc_uni_w_funcs(epel_hv, 10);
mc_uni_w_func(epel_hv, 10, 6);
mc_uni_w_funcs(qpel_h, 10);
mc_uni_w_funcs(qpel_v, 10);
mc_uni_w_funcs(qpel_hv, 10);


#define mc_bi_w_func(name, bitd, W) \
void ff_hevc_put_hevc_bi_w_##name##W##_##bitd##_sse4(uint8_t *_dst, ptrdiff_t _dststride,            \
                                                     uint8_t *_src, ptrdiff_t _srcstride,            \
                                                     int16_t *_src2, ptrdiff_t _src2stride,          \
                                                     int height, int denom,                          \
                                                     int _wx0, int _wx1, int _ox0, int _ox1,         \
                                                     intptr_t mx, intptr_t my, int width)            \
{                                                                                                    \
    LOCAL_ALIGNED_16(int16_t, temp, [71 * 64]);                                                      \
    ff_hevc_put_hevc_##name##W##_##bitd##_sse4(temp, 64, _src, _srcstride, height, mx, my, width);   \
    ff_hevc_put_hevc_bi_w##W##_##bitd##_sse4(_dst, _dststride, temp, 64, _src2, _src2stride,         \
                                             height, denom, _wx0, _wx1, _ox0, _ox1);                 \
}

#define mc_bi_w_funcs(name, bitd)       \
        mc_bi_w_func(name, bitd, 4);    \
        mc_bi_w_func(name, bitd, 8);    \
        mc_bi_w_func(name, bitd, 12);   \
        mc_bi_w_func(name, bitd, 16);   \
        mc_bi_w_func(name, bitd, 24);   \
        mc_bi_w_func(name, bitd, 32);   \
        mc_bi_w_func(name, bitd, 48);   \
        mc_bi_w_func(name, bitd, 64)

mc_bi_w_funcs(pel_pixels, 8);
mc_bi_w_func(pel_pixels, 8, 6);
mc_bi_w_funcs(epel_h, 8);
mc_bi_w_func(epel_h, 8, 6);
mc_bi_w_funcs(epel_v, 8);
mc_bi_w_func(epel_v, 8, 6);
mc_bi_w_funcs(epel_hv, 8);
mc_bi_w_func(epel_hv, 8, 6);
mc_bi_w_funcs(qpel_h, 8);
mc_bi_w_funcs(qpel_v, 8);
mc_bi_w_funcs(qpel_hv, 8);

mc_bi_w_funcs(pel_pixels, 10);
mc_bi_w_func(pel_pixels, 10, 6);
mc_bi_w_funcs(epel_h, 10);
mc_bi_w_func(epel_h, 10, 6);
mc_bi_w_funcs(epel_v, 10);
mc_bi_w_func(epel_v, 10, 6);
mc_bi_w_funcs(epel_hv, 10);
mc_bi_w_func(epel_hv, 10, 6);
mc_bi_w_funcs(qpel_h, 10);
mc_bi_w_funcs(qpel_v, 10);
mc_bi_w_funcs(qpel_hv, 10);

#endif //ARCH_X86_64

#endif


#define EPEL_LINKS(pointer, my, mx, fname, bitd)           \
        PEL_LINK(pointer, 1, my , mx , fname##4 ,  bitd ); \
        PEL_LINK(pointer, 2, my , mx , fname##6 ,  bitd ); \
        PEL_LINK(pointer, 3, my , mx , fname##8 ,  bitd ); \
        PEL_LINK(pointer, 4, my , mx , fname##12,  bitd ); \
        PEL_LINK(pointer, 5, my , mx , fname##16,  bitd ); \
        PEL_LINK(pointer, 6, my , mx , fname##24,  bitd ); \
        PEL_LINK(pointer, 7, my , mx , fname##32,  bitd ); \
        PEL_LINK(pointer, 8, my , mx , fname##48,  bitd ); \
        PEL_LINK(pointer, 9, my , mx , fname##64,  bitd )
#define QPEL_LINKS(pointer, my, mx, fname, bitd)           \
        PEL_LINK(pointer, 1, my , mx , fname##4 ,  bitd ); \
        PEL_LINK(pointer, 3, my , mx , fname##8 ,  bitd ); \
        PEL_LINK(pointer, 4, my , mx , fname##12,  bitd ); \
        PEL_LINK(pointer, 5, my , mx , fname##16,  bitd ); \
        PEL_LINK(pointer, 6, my , mx , fname##24,  bitd ); \
        PEL_LINK(pointer, 7, my , mx , fname##32,  bitd ); \
        PEL_LINK(pointer, 8, my , mx , fname##48,  bitd ); \
        PEL_LINK(pointer, 9, my , mx , fname##64,  bitd )


void ff_hevcdsp_init_x86(HEVCDSPContext *c, const int bit_depth)
{
    int mm_flags = av_get_cpu_flags();

    if (bit_depth == 8) {
        if (EXTERNAL_MMX(mm_flags)) {
            /*if (mm_flags & AV_CPU_FLAG_CMOV)
                c->h264_luma_dc_dequant_idct = ff_h264_luma_dc_dequant_idct_mmx; */

            if (EXTERNAL_MMXEXT(mm_flags)) {
#if ARCH_X86_32 && HAVE_MMXEXT_EXTERNAL
                /* MMEXT optimizations */
#endif /* ARCH_X86_32 && HAVE_MMXEXT_EXTERNAL */

#ifdef __SSE2__
                if (EXTERNAL_SSE2(mm_flags)) {
                    c->hevc_v_loop_filter_chroma = ff_hevc_v_loop_filter_chroma_8_sse2;
                    c->hevc_h_loop_filter_chroma = ff_hevc_h_loop_filter_chroma_8_sse2;
                }
#endif //__SSE2__
#ifdef __SSSE3__
                if (EXTERNAL_SSSE3(mm_flags)) {
/*
                    c->transform_4x4_luma_add = ff_hevc_transform_4x4_luma_add_8_sse4;
                    c->transform_add[0] = ff_hevc_transform_4x4_add_8_sse4;
                    c->transform_add[1] = ff_hevc_transform_8x8_add_8_sse4;
                    c->transform_add[2] = ff_hevc_transform_16x16_add_8_sse4;
                    c->transform_add[3] = ff_hevc_transform_32x32_add_8_sse4;

                    c->transform_dc_add[0] = ff_hevc_transform_4x4_dc_add_8_sse4;
                    c->transform_dc_add[1] = ff_hevc_transform_8x8_dc_add_8_sse4;
                    c->transform_dc_add[2] = ff_hevc_transform_16x16_dc_add_8_sse4;
                    c->transform_dc_add[3] = ff_hevc_transform_32x32_dc_add_8_sse4;

*/

#if ARCH_X86_64
                    c->hevc_v_loop_filter_luma = ff_hevc_v_loop_filter_luma_8_ssse3;
                    c->hevc_h_loop_filter_luma = ff_hevc_h_loop_filter_luma_8_ssse3;
#endif
                }
#endif //__SSSE3__
#ifdef __SSE4_1__

                if (EXTERNAL_SSE4(mm_flags)) {

                    EPEL_LINKS(c->put_hevc_epel, 0, 0, pel_pixels,  8);
                    EPEL_LINKS(c->put_hevc_epel, 0, 1, epel_h,      8);
                    EPEL_LINKS(c->put_hevc_epel, 1, 0, epel_v,      8);
                    EPEL_LINKS(c->put_hevc_epel, 1, 1, epel_hv,     8);

                    QPEL_LINKS(c->put_hevc_qpel, 0, 0, pel_pixels, 8);
                    QPEL_LINKS(c->put_hevc_qpel, 0, 1, qpel_h,     8);
                    QPEL_LINKS(c->put_hevc_qpel, 1, 0, qpel_v,     8);
                    QPEL_LINKS(c->put_hevc_qpel, 1, 1, qpel_hv,    8);

               /*     c->transform_skip[0]  = ff_hevc_transform_skip_8_sse;
                    c->sao_edge_filter[0] = ff_hevc_sao_edge_filter_0_8_sse;
                    c->sao_edge_filter[1] = ff_hevc_sao_edge_filter_1_8_sse;
                    c->sao_band_filter    = ff_hevc_sao_band_filter_0_8_sse;*/

#ifdef SVC_EXTENSION
    c->upsample_filter_block_luma_h[1] = ff_upsample_filter_block_luma_h_x2_sse;
    c->upsample_filter_block_cr_h[1] = ff_upsample_filter_block_cr_h_x2_sse;
    c->upsample_filter_block_luma_v[1] = ff_upsample_filter_block_luma_v_x2_sse;
    c->upsample_filter_block_cr_v[1] = ff_upsample_filter_block_cr_v_x2_sse;

    c->upsample_filter_block_luma_h[2] = ff_upsample_filter_block_luma_h_x1_5_sse;
    c->upsample_filter_block_cr_h[2] = ff_upsample_filter_block_cr_h_x1_5_sse;
    c->upsample_filter_block_luma_v[2] = ff_upsample_filter_block_luma_v_x1_5_sse;
    c->upsample_filter_block_cr_v[2] = ff_upsample_filter_block_cr_v_x1_5_sse;

/*
c->upsample_filter_block_luma_h[0] = ff_upsample_filter_block_luma_h_all_sse;
c->upsample_filter_block_cr_h[0] = ff_upsample_filter_block_cr_h_all_sse;
c->upsample_filter_block_luma_v[0] = ff_upsample_filter_block_luma_v_all_sse;
c->upsample_filter_block_cr_v[0] = ff_upsample_filter_block_cr_v_all_sse;
*/


#endif
                }
#endif //__SSE4_1__
                if (EXTERNAL_AVX(mm_flags)) {
                }
            }
        }
    } else if (bit_depth == 10) {
        if (EXTERNAL_MMX(mm_flags)) {
            if (EXTERNAL_MMXEXT(mm_flags)) {
#if ARCH_X86_32
#endif /* ARCH_X86_32 */
#ifdef __SSE2__
                if (EXTERNAL_SSE2(mm_flags)) {
//                    c->hevc_v_loop_filter_chroma = ff_hevc_v_loop_filter_chroma_10_sse2;
//                    c->hevc_h_loop_filter_chroma = ff_hevc_h_loop_filter_chroma_10_sse2;
#if HAVE_ALIGNED_STACK
                    /*stuff that requires aligned stack */
#endif /* HAVE_ALIGNED_STACK */
                }
#endif /* __SSE2__ */
#ifdef __SSSE3__
                if (EXTERNAL_SSSE3(mm_flags)) {
#if ARCH_X86_64
//                    c->hevc_v_loop_filter_luma = ff_hevc_v_loop_filter_luma_10_ssse3;
//                    c->hevc_h_loop_filter_luma = ff_hevc_h_loop_filter_luma_10_ssse3;
#endif
                }
#endif //__SSSE3__
#ifdef __SSSE4__
                if (EXTERNAL_SSE4(mm_flags)) {
 /*                   c->transform_4x4_luma_add   = ff_hevc_transform_4x4_luma_add_10_sse4;
                    c->transform_add[0]         = ff_hevc_transform_4x4_add_10_sse4;
                    c->transform_add[1]         = ff_hevc_transform_8x8_add_10_sse4;
                    c->transform_add[2]         = ff_hevc_transform_16x16_add_10_sse4;
                    c->transform_add[3]         = ff_hevc_transform_32x32_add_10_sse4;
*/
                    EPEL_LINKS(c->put_hevc_epel, 0, 0, pel_pixels, 10);
                    EPEL_LINKS(c->put_hevc_epel, 0, 1, epel_h,     10);
                    EPEL_LINKS(c->put_hevc_epel, 1, 0, epel_v,     10);
                    EPEL_LINKS(c->put_hevc_epel, 1, 1, epel_hv,    10);

                    QPEL_LINKS(c->put_hevc_qpel, 0, 0, pel_pixels, 10);
                    QPEL_LINKS(c->put_hevc_qpel, 0, 1, qpel_h,     10);
                    QPEL_LINKS(c->put_hevc_qpel, 1, 0, qpel_v,     10);
                    QPEL_LINKS(c->put_hevc_qpel, 1, 1, qpel_hv,    10);

                    c->sao_edge_filter[0] = ff_hevc_sao_edge_filter_0_10_sse;
                    c->sao_edge_filter[1] = ff_hevc_sao_edge_filter_1_10_sse;
                    c->sao_band_filter    = ff_hevc_sao_band_filter_0_10_sse;
                }
#endif //__SSE4_1__
                if (EXTERNAL_AVX(mm_flags)) {
                }
            }
        }
    }
}

