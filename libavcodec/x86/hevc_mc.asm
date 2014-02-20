; /*
; * Provide SSE luma mc functions for HEVC decoding
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

SECTION_RODATA
cextern hevc_epel_filters
cextern hevc_qpel_filters

epel_extra_before   DB  1                        ;corresponds to EPEL_EXTRA_BEFORE in hevc.h
max_pb_size         DB  64                       ;corresponds to MAX_PB_SIZE in hevc.h

qpel_extra_before   DB  0,  3,  3,  2            ;corresponds to the ff_hevc_qpel_extra_before in hevc.c
qpel_extra          DB  0,  6,  7,  6            ;corresponds to the ff_hevc_qpel_extra in hevc.c
qpel_extra_after    DB  0,  3,  4,  4


single_mask_16      DW  0,  0,  0,  0,  0,  0,  0, -1
single_mask_32      DW  0,  0,  0,  0,  0,  0, -1, -1
SECTION .text

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%macro LOOP_INIT 2
    pxor             m15, m15                    ; set register at zero
    mov              r10, 0                      ; set height counter
%1:
    mov               r9, 0                      ; set width counter
%2:
%endmacro

%macro LOOP_END 7
    add               r9, %3                     ; add 4 for width loop
    cmp               r9, widthq                 ; cmp width
    jl                %2                         ; width loop
%ifidn %5, dststride
    lea              %4q, [%4q+2*%5q]           ; dst += dststride
%else
    lea              %4q, [%4q+  %5 ]           ; dst += dststride
%endif
%ifidn %7, srcstride
    lea              %6q, [%6q+  %7q]           ; src += srcstride
%else
    lea              %6q, [%6q+  %7 ]           ; src += srcstride
%endif
    add              r10, 1
    cmp              r10, heightq                ; cmp height
    jl                %1                         ; height loop
%endmacro

%macro LOOP_EPEL_HV_INIT 4
    pxor             m15, m15                    ; set register at zero
    mov               r9, 0                      ; set width counter
%1:
    mov              r10, 0                      ; set height counter
;first 3 H calculus
%if %3 == 8
    EPEL_LOAD         %3, mx, 1
%else
    EPEL_LOAD         %3, mx, 2
%endif
    EPEL_COMPUTE      %3, %4
    SWAP              m4, m0
    lea              mxq, [mxq + srcstrideq]
%if %3 == 8
    EPEL_LOAD         %3, mx, 1
%else
    EPEL_LOAD         %3, mx, 2
%endif
    EPEL_COMPUTE      %3, %4
    SWAP              m5, m0
    lea              mxq, [mxq + srcstrideq]
%if %3 == 8
    EPEL_LOAD         %3, mx, 1
%else
    EPEL_LOAD         %3, mx, 2
%endif
    EPEL_COMPUTE      %3, %4
    SWAP              m6, m0
    lea              mxq, [mxq + srcstrideq]
%2:
%endmacro

%macro LOOP_HV_END 9
    lea              %8q, [%8q+2*%5q]            ; dst += dststride
    lea              %9q, [%9q+  %7q]            ; src += srcstride
    inc              r10                         ; add 1 for height loop
    cmp              r10, heightq                ; cmp height
    jl                %2                         ; height loop
    add               r9, %3                     ; add width
    lea              %8q,[%4q]                   ; dst = dst2
    lea              %9q,[%6q]                   ; src = src2
    cmp               r9, widthq                 ; cmp width
    jl                %1                         ; weight loop
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


%macro EPEL_FILTER 2
    movsxd           %2q, %2d                    ; extend sign
    sub              %2q, 1
    shl              %2q, 2                      ; multiply by 4
    lea              r11, [hevc_epel_filters]
    movq             m13, [r11 + %2q]            ; get 4 first values of filters
%if %1 == 8
    punpcklwd        m13, m13
%else
    pmovsxbw         m13, m13
%endif
    punpckldq        m13, m13
    movdqa           m14, m13
    punpckhqdq       m14, m14                    ; contains last 2 filters
    punpcklqdq       m13, m13                    ;
%endmacro

%macro EPEL_HV_FILTER 1
    movsxd           mxq, mxd                    ; extend sign
    movsxd           myq, myd                    ; extend sign
    sub              mxq, 1
    sub              myq, 1
    shl              mxq, 2                      ; multiply by 4
    shl              myq, 2                      ; multiply by 4
    lea              r11, [hevc_epel_filters]
    movq             m13, [r11 + mxq]            ; get 4 first values of H filter
    movq             m11, [r11 + myq]
%if %1 == 8
    punpcklwd        m13, m13
    pmovsxbw         m11, m11                    ; need 16bit filters for V
%else
    pmovsxbw         m13, m13
    pmovsxbw         m11, m11
%endif
    punpckldq        m13, m13
    punpckldq        m11, m11
    movdqa           m14, m13
    movdqa           m12, m11
    punpckhqdq       m14, m14                    ;H
    punpckhqdq       m12, m12                    ;V
    punpcklqdq       m13, m13                    ;H
    punpcklqdq       m11, m11                    ;V
%endmacro


%macro QPEL_H_FILTER 2
    movsxd           %2q, %2d                    ; extend sign
    sub              %2q, 1
    shl              %2q, 4                      ; multiply by 16
    lea              r11, [hevc_qpel_filters]
    movq             m11, [r11 + %2q]            ; get 4 first values of filters
%if %1 == 8
    punpcklwd        m11, m11
%else
    pmovsxbw         m11, m11
%endif
    punpckhdq        m13, m11, m11
    punpckldq        m11, m11
    movdqa           m14, m13
    movdqa           m12, m11
    punpckhqdq       m14, m14                    ; contains last 2 filters
    punpcklqdq       m13, m13                    ;
    punpckhqdq       m12, m12                    ;
    punpcklqdq       m11, m11                    ; contains first 2 filters

%endmacro

%macro QPEL_V_FILTER 2
    movdqu            m6, [qpel_h_filter%1_10]
    psrldq            m7, m6, 2
    psrldq            m8, m6, 4
    psrldq            m9, m6, 6
    psrldq           m10, m6, 8
    psrldq           m11, m6, 10
    psrldq           m12, m6, 12
    psrldq           m13, m6, 14

    punpcklwd         m6, m6                    ; put double values to 32bit.
    punpcklwd         m7, m7
    punpcklwd         m8, m8
    punpcklwd         m9, m9
    punpcklwd        m10, m10
    punpcklwd        m11, m11
    punpcklwd        m12, m12
    punpcklwd        m13, m13

%if %2 == 10
    psrad             m6, m6, 16
    psrad             m7, m7, 16
    psrad             m8, m8, 16
    psrad             m9, m9, 16
    psrad            m10, m10, 16
    psrad            m11, m11, 16
    psrad            m12, m12, 16
    psrad            m13, m13, 16
%endif

    pshufd            m6, m6, 0
    pshufd            m7, m7, 0
    pshufd            m8, m8, 0
    pshufd            m9, m9, 0
    pshufd           m10, m10, 0
    pshufd           m11, m11, 0
    pshufd           m12, m12, 0
    pshufd           m13, m13, 0

%endmacro



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%macro MC_LOAD_PIXEL 1
%if %1 == 8
    movdqu            m0, [srcq+  r9]            ; load data from source
%else
    movdqu            m0, [srcq+2*r9]            ; load data from source
%endif
%endmacro

%macro EPEL_LOAD 3
%if %1 == 8
    lea              r11, [%2q+  r9]
%else
    lea              r11, [%2q+2*r9]
%endif
    movdqu            m0, [r11     ]            ;load 128bit of x
%ifidn %3, srcstride
    lea              r8q, [%3q*3]
    movdqu            m1, [r11+  %3q]            ;load 128bit of x+stride
    movdqu            m2, [r11+2*%3q]            ;load 128bit of x+2*stride
    movdqu            m3, [r11+r8  ]            ;load 128bit of x+2*stride
%else
    movdqu            m1, [r11+  %3]            ;load 128bit of x+stride
    movdqu            m2, [r11+2*%3]            ;load 128bit of x+2*stride
    movdqu            m3, [r11+3*%3]            ;load 128bit of x+3*stride
%endif

%if %1 == 8
    SBUTTERFLY        bw, 0, 1, 10
    SBUTTERFLY        bw, 2, 3, 10
%else
    SBUTTERFLY        wd, 0, 1, 10
    SBUTTERFLY        wd, 2, 3, 10
%endif

%endmacro

%macro QPEL_H_LOAD 1
%if %1 = 8
    movdqu            m0, [srcq+  r9-3]          ; load data from source
    movdqu            m1, [srcq+  r9-2]
    movdqu            m2, [srcq+  r9-1]
    movdqu            m3, [srcq+  r9  ]
    movdqu            m4, [srcq+  r9+1]
    movdqu            m5, [srcq+  r9+2]
    movdqu            m6, [srcq+  r9+3]
    movdqu            m7, [srcq+  r9+4]
    SBUTTERFLY        wd, 0, 1, 10
    SBUTTERFLY        wd, 2, 3, 10
    SBUTTERFLY        wd, 4, 5, 10
    SBUTTERFLY        wd, 6, 7, 10
%else
    movdqu            m0, [srcq+  2*r9-6]          ; load data from source
    movdqu            m1, [srcq+  2*r9-4]
    movdqu            m2, [srcq+  2*r9-2]
    movdqu            m3, [srcq+  2*r9  ]
    movdqu            m4, [srcq+  2*r9+2]
    movdqu            m5, [srcq+  2*r9+4]
    movdqu            m6, [srcq+  2*r9+6]
    movdqu            m7, [srcq+  2*r9+8]
    SBUTTERFLY        dq, 0, 1, 10
    SBUTTERFLY        dq, 2, 3, 10
    SBUTTERFLY        dq, 4, 5, 10
    SBUTTERFLY        dq, 6, 7, 10
%endif
%endmacro



%macro QPEL_V_LOAD 3
    xor              r11, r11
%if %1 == 8
    lea              r11, [%2q+  r9]
%else
    lea              r11, [%2q+2*r9]
%endif
    lea               r8q, [%3q*3]
    mov               r12q, r11q
    sub               r12q, r8
    movdqu            m0, [r12]                            ;load x- 3*srcstride
    movdqu            m1, [r12+%3q]                        ;load x- 2*srcstride
    movdqu            m2, [r12+2*%3q]                      ;load x-srcstride
    movdqu            m3, [r11]                            ;load x
    movdqu            m4, [r11+  %3q]                      ;load x+stride
    movdqu            m5, [r11+2*%3q]                      ;load x+2*stride
    movdqu            m6, [r11+r8]                         ;load x+3*stride
    movdqu            m7, [r11+4*%3q]                      ;load x+4*stride
%if %1 == 8
    SBUTTERFLY        bw, 0, 1, 8
    SBUTTERFLY        bw, 2, 3, 8
    SBUTTERFLY        bw, 4, 5, 8
    SBUTTERFLY        bw, 6, 7, 8
%else
    SBUTTERFLY        wd, 0, 1, 8
    SBUTTERFLY        wd, 2, 3, 8
    SBUTTERFLY        wd, 4, 5, 8
    SBUTTERFLY        wd, 6, 7, 8
%endif
%endmacro

%macro PEL_STORE2 3
    movd     [%1q+2*r9], %2
%endmacro
%macro PEL_STORE4 3
    movq      [%1q+2*r9],%2
%endmacro
%macro PEL_STORE8 3
    movdqa    [%1q+2*r9],%2
%endmacro
%macro PEL_STORE16 3
    PEL_STORE8        %1, %2, %3
    movdqa [%1q+2*r9+16], %3
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%if ARCH_X86_64
INIT_XMM sse4                                    ; adds ff_ and _sse4 to function name

; ******************************
; void put_hevc_mc_pixels(int16_t *dst, ptrdiff_t dststride,
;                         uint8_t *_src, ptrdiff_t _srcstride,
;                         int width, int height, int mx, int my,
;                         int16_t* mcbuffer)
;
;        r0 : *dst
;        r1 : dststride
;        r2 : *src
;        r3 : srcstride
;        r4 : width
;        r5 : height
;
; ******************************
%macro MC_PIXEL_COMPUTE2_8 0
    punpcklbw         m1, m0, m15
    psllw             m1, 6
%endmacro
%macro MC_PIXEL_COMPUTE4_8 0
    MC_PIXEL_COMPUTE2_8
%endmacro
%macro MC_PIXEL_COMPUTE8_8 0
    MC_PIXEL_COMPUTE2_8
%endmacro
%macro MC_PIXEL_COMPUTE16_8 0
    MC_PIXEL_COMPUTE2_8
    punpckhbw         m2, m0, m15
    psllw             m2, 6
%endmacro

%macro MC_PIXEL_COMPUTE2_10 0
    psllw             m1, m0, 4
%endmacro
%define MC_PIXEL_COMPUTE4_10 MC_PIXEL_COMPUTE2_10
%define MC_PIXEL_COMPUTE8_10 MC_PIXEL_COMPUTE2_10

%macro PUT_HEVC_MC_PIXELS 3
    LOOP_INIT %3_pixels_h_%1_%2, %3_pixels_v_%1_%2
    MC_LOAD_PIXEL     %2
    MC_PIXEL_COMPUTE%1_%2
    PEL_STORE%1      dst, m1, m2
    LOOP_END %3_pixels_h_%1_%2, %3_pixels_v_%1_%2, %1, dst, dststride, src, srcstride
    RET
%endmacro

; ******************************
; void put_hevc_epel_h(int16_t *dst, ptrdiff_t dststride,
;                     uint8_t *_src, ptrdiff_t _srcstride,
;                     int width, int height, int mx, int my,
;                     int16_t* mcbuffer)
;
;      r0 : *dst
;      r1 : dststride
;      r2 : *src
;      r3 : srcstride
;      r4 : width
;      r5 : height
;
; ******************************

%macro PUT_HEVC_EPEL_H 2
%if %2 == 8
    sub             srcq, 1
%else
    sub             srcq, 2
%endif
    EPEL_FILTER       %2, mx
    LOOP_INIT  epel_h_h_%1_%2, epel_h_w_%1_%2
%if %2 == 8
    EPEL_LOAD         %2, src, 1
%else
    EPEL_LOAD         %2, src, 2
%endif
    EPEL_COMPUTE      %2, %1
    PEL_STORE%1       dst, m0, m1
    LOOP_END   epel_h_h_%1_%2, epel_h_w_%1_%2, %1, dst, dststride, src, srcstride
%endmacro

; ******************************
; void put_hevc_epel_v(int16_t *dst, ptrdiff_t dststride,
;                      uint8_t *_src, ptrdiff_t _srcstride,
;                      int width, int height, int mx, int my,
;                      int16_t* mcbuffer)
;
;      r0 : *dst
;      r1 : dststride
;      r2 : *src
;      r3 : srcstride
;      r4 : width
;      r5 : height
;
; ******************************

%macro EPEL_COMPUTE 2
%if %1 == 8
    pmaddubsw         m0, m13
    pmaddubsw         m2, m14
    paddw             m0, m2
%if %2 == 16
    pmaddubsw         m1, m13
    pmaddubsw         m3, m14
    paddw             m1, m3
%endif
%else
    pmaddwd           m0, m13
    pmaddwd           m2, m14
    pmaddwd           m1, m13
    pmaddwd           m3, m14
    paddd             m0, m2
    paddd             m1, m3
%if %1 == 10
    psrad             m0, 2
    psrad             m1, 2
%endif
%if %1 == 14
    psrad             m0, 6
    psrad             m1, 6
%endif
    packssdw          m0, m1
%endif
%endmacro

%macro EPEL_COMPUTE_14 0
    pmaddwd           m0, m11
    pmaddwd           m1, m11
    pmaddwd           m2, m12
    pmaddwd           m3, m12
    paddd             m0, m2
    paddd             m1, m3
    psrad             m0, 6
    psrad             m1, 6
    packssdw          m0, m1
%endmacro


%macro PUT_HEVC_EPEL_V 2
    sub               srcq, srcstrideq
    EPEL_FILTER       %2, my
    LOOP_INIT epel_v_h_%1_%2, epel_v_w_%1_%2
    EPEL_LOAD         %2, src, srcstride
    EPEL_COMPUTE      %2, %1
    PEL_STORE%1      dst, m0, m1
    LOOP_END  epel_v_h_%1_%2, epel_v_w_%1_%2, %1, dst, dststride, src, srcstride
%endmacro

; ******************************
; void put_hevc_epel_hv(int16_t *dst, ptrdiff_t dststride,
;                       uint8_t *_src, ptrdiff_t _srcstride,
;                       int width, int height, int mx, int my)
;
;      r0 : *dst
;      r1 : dststride
;      r2 : *src
;      r3 : srcstride
;      r4 : width
;      r5 : height
;      r6 : mx
;      r7 : my
;
; ******************************
%macro PUT_HEVC_EPEL_HV 2
    EPEL_HV_FILTER %2          ; H on m11 and m12. V on m13, m14
%if %2 == 8
    sub             srcq, 1
%else
    sub             srcq, 2
%endif
    xor               mxq, mxq
    xor               myq, myq
    sub             srcq, srcstrideq             ; src -= srcstride
    lea              mxq, [srcq]
    lea              myq, [dstq]

    LOOP_EPEL_HV_INIT  epel_hv_w_%1_%2, epel_hv_h_%1_%2, %2, %1
%if %2 == 8
    EPEL_LOAD         %2, mx, 1
%else
    EPEL_LOAD         %2, mx, 2
%endif
    EPEL_COMPUTE      %2, %1
    SWAP              m7, m0

    punpcklwd         m0, m4, m5
    punpckhwd         m1, m4, m5
    punpcklwd         m2, m6, m7
    punpckhwd         m3, m6, m7

    EPEL_COMPUTE_14

    PEL_STORE%1       my, m0, m15

    movdqa               m4, m5
    movdqa               m5, m6
    movdqa               m6, m7

    LOOP_HV_END   epel_hv_w_%1_%2, epel_hv_h_%1_%2, %1, dst, dststride, src, srcstride, my, mx

%endmacro


; ******************************
; void put_hevc_qpel_h(int16_t *dst, ptrdiff_t dststride,
;                     uint8_t *_src, ptrdiff_t _srcstride,
;                     int width, int height, int mx, int my)
;
;      r0 : *dst
;      r1 : dststride
;      r2 : *src
;      r3 : srcstride
;      r4 : width
;      r5 : height
;
; ******************************

%macro QPEL_H_COMPUTE 2
%if %2 == 8
    pmaddubsw         m0, m11
    pmaddubsw         m2, m12
    pmaddubsw         m4, m13
    pmaddubsw         m6, m14
    paddw             m0, m2
    paddw             m4, m6
    paddw             m0, m4
%if %1 == 16
    pmaddubsw         m1, m11
    pmaddubsw         m3, m12
    pmaddubsw         m5, m13
    pmaddubsw         m7, m14
    paddw             m1, m3
    paddw             m5, m7
    paddw             m1, m5
%endif
%else
    pmaddwd           m0, m11
    pmaddwd           m2, m12
    pmaddwd           m4, m13
    pmaddwd           m6, m14
    paddd             m0, m2
    paddd             m4, m6
    paddd             m0, m4
    psrad             m0, 2

%if %1 == 8
    pmaddwd           m1, m11
    pmaddwd           m3, m12
    pmaddwd           m5, m13
    pmaddwd           m7, m14
    paddd             m1, m3
    paddd             m5, m7
    paddd             m1, m5
    psrad             m1, 2
%endif
    packssdw          m0, m1
%endif
%endmacro

%macro PUT_HEVC_QPEL_H 2
    QPEL_H_FILTER     %2, mx
    LOOP_INIT  qpel_h_h_%1_%2, qpel_h_w_%1_%2
    QPEL_H_LOAD       %2
    QPEL_H_COMPUTE    %1, %2
    PEL_STORE%1      dst, m0, m1
    LOOP_END   qpel_h_h_%1_%2, qpel_h_w_%1_%2, %1, dst, dststride, src, srcstride
%endmacro


; ******************************
; void put_hevc_qpel_v(int16_t *dst, ptrdiff_t dststride,
;                     uint8_t *_src, ptrdiff_t _srcstride,
;                     int width, int height, int16_t* mcbuffer)
;
;      r0 : *dst
;      r1 : dststride
;      r2 : *src
;      r3 : srcstride
;      r4 : width
;      r5 : height
;
; ******************************

%macro PUT_HEVC_QPEL_V 2
    QPEL_H_FILTER     %2, my
    LOOP_INIT qpel_v_h_%1_%2, qpel_v_w_%1_%2
    QPEL_V_LOAD       %2, src, srcstride
    QPEL_H_COMPUTE    %1, %2
    PEL_STORE%1      dst, m0, m1
    LOOP_END  qpel_v_h_%1_%2, qpel_v_w_%1_%2, %1, dst, dststride, src, srcstride
%endmacro


; ******************************
; void put_hevc_mc_pixels(int16_t *dst, ptrdiff_t dststride,
;                         uint8_t *_src, ptrdiff_t _srcstride,
;                         int width, int height, int mx, int my,
;                         int16_t* mcbuffer)
; ******************************
cglobal hevc_put_hevc_pel_pixels2_8, 9, 12, 0 , dst, dststride, src, srcstride,width,height
    PUT_HEVC_MC_PIXELS 2, 8, epel
cglobal hevc_put_hevc_pel_pixels4_8, 9, 12, 0 , dst, dststride, src, srcstride,width,height
    PUT_HEVC_MC_PIXELS 4, 8, epel
cglobal hevc_put_hevc_pel_pixels8_8, 9, 12, 0 , dst, dststride, src, srcstride,width,height
    PUT_HEVC_MC_PIXELS 8, 8, epel
cglobal hevc_put_hevc_pel_pixels16_8, 9, 12, 0 , dst, dststride, src, srcstride,width,height
    PUT_HEVC_MC_PIXELS 16, 8, epel

cglobal hevc_put_hevc_pel_pixels2_10, 9, 12, 0 , dst, dststride, src, srcstride,width,height
    PUT_HEVC_MC_PIXELS 2, 10, epel
cglobal hevc_put_hevc_pel_pixels4_10, 9, 12, 0 , dst, dststride, src, srcstride,width,height
    PUT_HEVC_MC_PIXELS 4, 10, epel
cglobal hevc_put_hevc_pel_pixels8_10, 9, 12, 0 , dst, dststride, src, srcstride,width,height
    PUT_HEVC_MC_PIXELS 8, 10, epel


; ******************************
; void put_hevc_epel_hX(int16_t *dst, ptrdiff_t dststride,
;                       uint8_t *_src, ptrdiff_t _srcstride,
;                       int width, int height, int mx, int my,
;                       int16_t* mcbuffer)
; ******************************
cglobal hevc_put_hevc_epel_h2_8, 9, 12, 0 , dst, dststride, src, srcstride,width,height,mx,my
    PUT_HEVC_EPEL_H    2, 8
    RET
cglobal hevc_put_hevc_epel_h4_8, 9, 12, 0 , dst, dststride, src, srcstride,width,height,mx,my
    PUT_HEVC_EPEL_H    4, 8
    RET
cglobal hevc_put_hevc_epel_h8_8, 9, 12, 0 , dst, dststride, src, srcstride,width,height,mx,my
    PUT_HEVC_EPEL_H    8, 8
    RET
    cglobal hevc_put_hevc_epel_h16_8, 9, 12, 0 , dst, dststride, src, srcstride,width,height,mx,my
    PUT_HEVC_EPEL_H    16, 8
    RET

cglobal hevc_put_hevc_epel_h2_10, 9, 12, 0 , dst, dststride, src, srcstride,width,height,mx,my
    PUT_HEVC_EPEL_H    2, 10
    RET
cglobal hevc_put_hevc_epel_h4_10, 9, 12, 0 , dst, dststride, src, srcstride,width,height,mx,my
    PUT_HEVC_EPEL_H    4, 10
    RET
cglobal hevc_put_hevc_epel_h8_10, 9, 12, 0 , dst, dststride, src, srcstride,width,height,mx,my
    PUT_HEVC_EPEL_H    8, 10
    RET

; ******************************
; void put_hevc_epel_v(int16_t *dst, ptrdiff_t dststride,
;                      uint8_t *_src, ptrdiff_t _srcstride,
;                      int width, int height, int mx, int my,
;                      int16_t* mcbuffer)
; ******************************
cglobal hevc_put_hevc_epel_v2_8, 8, 12, 0 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_EPEL_V    2, 8
    RET
cglobal hevc_put_hevc_epel_v4_8, 8, 12, 0 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_EPEL_V    4, 8
    RET
cglobal hevc_put_hevc_epel_v8_8, 8, 12, 0 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_EPEL_V    8, 8
    RET
cglobal hevc_put_hevc_epel_v16_8, 8, 12, 0 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_EPEL_V   16, 8
    RET

cglobal hevc_put_hevc_epel_v2_10, 8, 12, 0 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_EPEL_V    2, 10
    RET
cglobal hevc_put_hevc_epel_v4_10, 8, 12, 0 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_EPEL_V    4, 10
    RET
cglobal hevc_put_hevc_epel_v8_10, 8, 12, 0 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_EPEL_V    8, 10
    RET

cglobal hevc_put_hevc_epel_v2_14, 8, 12, 0 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_EPEL_V    2, 14
    RET
cglobal hevc_put_hevc_epel_v4_14, 8, 12, 0 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_EPEL_V    4, 14
    RET
cglobal hevc_put_hevc_epel_v8_14, 8, 12, 0 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_EPEL_V    8, 14
    RET

; ******************************
; void put_hevc_epel_hv(int16_t *dst, ptrdiff_t dststride,
;                       uint8_t *_src, ptrdiff_t _srcstride,
;                       int width, int height, int mx, int my,
;                       int16_t* mcbuffer)
; ******************************
cglobal hevc_put_hevc_epel_hv2_8, 8, 12, 12 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_EPEL_HV   2, 8
    RET
cglobal hevc_put_hevc_epel_hv4_8, 8, 15, 12 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_EPEL_HV   4, 8
    RET
cglobal hevc_put_hevc_epel_hv8_8, 9, 12, 0 , dst, dststride, src, srcstride, width, height, mx, my, mcbuffer
    PUT_HEVC_EPEL_HV   8, 8
    RET
cglobal hevc_put_hevc_epel_hv2_10, 9, 12, 0 , dst, dststride, src, srcstride, width, height, mx, my, mcbuffer
    PUT_HEVC_EPEL_HV   2, 10
    RET
cglobal hevc_put_hevc_epel_hv4_10, 9, 12, 0 , dst, dststride, src, srcstride, width, height, mx, my, mcbuffer
    PUT_HEVC_EPEL_HV   4, 10
    RET

cglobal hevc_put_hevc_epel_hv8_10, 9, 12, 0 , dst, dststride, src, srcstride, width, height, mx, my, mcbuffer
    PUT_HEVC_EPEL_HV   8, 10
    RET

; ******************************
; void put_hevc_qpel_hX_X_X(int16_t *dst, ptrdiff_t dststride,
;                       uint8_t *_src, ptrdiff_t _srcstride,
;                       int width, int height, int mx, int my)
; ******************************
cglobal hevc_put_hevc_qpel_h4_8, 9, 14, 15 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_QPEL_H    4, 8
    RET

cglobal hevc_put_hevc_qpel_h8_8, 9, 14, 15 , dst, dststride, src, srcstride,width,height, mx, my
    PUT_HEVC_QPEL_H    8, 8
    RET

cglobal hevc_put_hevc_qpel_h16_8, 9, 14, 15 , dst, dststride, src, srcstride,width,height, mx, my
    PUT_HEVC_QPEL_H    16, 8
    RET

cglobal hevc_put_hevc_qpel_h4_10, 9, 14, 15 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_QPEL_H    4, 10
    RET

cglobal hevc_put_hevc_qpel_h8_10, 9, 14, 15 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_QPEL_H    8, 10
    RET

    ; ******************************
; void put_hevc_qpel_vX_X_X(int16_t *dst, ptrdiff_t dststride,
;                       uint8_t *_src, ptrdiff_t _srcstride,
;                       int width, int height, int16_t* mcbuffer)
; ******************************
cglobal hevc_put_hevc_qpel_v4_8, 9, 14, 0 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_QPEL_V    4, 8
    RET

cglobal hevc_put_hevc_qpel_v8_8, 9, 14, 0 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_QPEL_V    8, 8
    RET

cglobal hevc_put_hevc_qpel_v16_8, 9, 14, 0 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_QPEL_V    16, 8
    RET

cglobal hevc_put_hevc_qpel_v4_10, 9, 14, 0 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_QPEL_V    4, 10
    RET

cglobal hevc_put_hevc_qpel_v8_10, 9, 14, 0 , dst, dststride, src, srcstride, width, height, mx, my
    PUT_HEVC_QPEL_V    8, 10
    RET


%endif ; ARCH_X86_64
