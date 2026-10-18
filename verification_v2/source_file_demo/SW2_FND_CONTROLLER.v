`timescale 1ns / 1ps

// FND 컨트롤러 (v2 포트 통일)
// 흐름: i_disp_* → digit_splitter(10진 2자리) → SW2_ANODE_CHOICE(설정 점멸, 시.분 쪽만)
//       → mux_8x1(o_scan_sel 로 자리 고르기) → 2:1 MUX(i_disp_mode) → fnd_decoder → o_fnd_font
//       counter8(o_scan_sel[1:0]) → decoder_2x4 → o_fnd_com
// 스캔: i_clk_4khz 마다 o_scan_sel +1 (0~7), 한 칸 250 us, 한 바퀴 2 ms
//   scan_sel 0~3 : AN0~AN3 숫자,  4~7 : AN0~AN3 빈칸 (단 6 = AN2 가운데 점)
// (v2) 안 쓰던 i_clk(100 MHz), i_btn_R, i_btn_L 삭제
//      i_sw_0(= sw_mode | sw_timer) → i_sel_wt (= 그 반대, 시계 화면일 때 1)
//      초.1/100초 쪽 SW2_ANODE_CHOICE(U_ANODE_CHOICE_TO_MUX1) 삭제: 늘 그대로 통과라 동작 같음
module SW2_FND_CONTROLLER #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input                       i_rst,
    input                       i_clk_4khz,
    input  [MSEC_BIT_WIDTH-1:0] i_disp_msec,
    input  [ SEC_BIT_WIDTH-1:0] i_disp_sec,
    input  [ MIN_BIT_WIDTH-1:0] i_disp_min,
    input  [HOUR_BIT_WIDTH-1:0] i_disp_hour,
    input                       i_disp_mode,   // 0 초.1/100초, 1 시.분
    input  [               1:0] i_wt_cursor,
    input                       i_sel_wt,      // 1 = 시계 화면
    input                       i_set_sw2,

    output [3:0] o_fnd_com,
    output [7:0] o_fnd_font
);

    // 10진 2자리 분리
    wire [3:0] w_msec_digit1, w_msec_digit10;
    wire [3:0] w_sec_digit1,  w_sec_digit10;
    wire [3:0] w_min_digit1,  w_min_digit10;
    wire [3:0] w_hour_digit1, w_hour_digit10;

    digit_splitter #(
        .WIDTH(7)
    ) U_MSEC (
        .i_value  (i_disp_msec),
        .o_digit1 (w_msec_digit1),
        .o_digit10(w_msec_digit10)
    );

    digit_splitter #(
        .WIDTH(6)
    ) U_SEC (
        .i_value  (i_disp_sec),
        .o_digit1 (w_sec_digit1),
        .o_digit10(w_sec_digit10)
    );

    digit_splitter #(
        .WIDTH(6)
    ) U_MIN (
        .i_value  (i_disp_min),
        .o_digit1 (w_min_digit1),
        .o_digit10(w_min_digit10)
    );

    digit_splitter #(
        .WIDTH(HOUR_BIT_WIDTH)   // (10/16) 5 고정 → parameter: 타이머 분(0~59)이 이 자리에 옴
    ) U_HOUR (
        .i_value  (i_disp_hour),
        .o_digit1 (w_hour_digit1),
        .o_digit10(w_hour_digit10)
    );

    // 스캔 카운터
    wire [2:0] w_scan_sel;

    counter8 U_COUNTER8 (
        .i_clk_4khz(i_clk_4khz),
        .i_rst     (i_rst),
        .o_scan_sel(w_scan_sel)
    );

    // 0.5 초 점멸 박자
    wire w_blink_off;

    dot U_DOT (
        .i_disp_msec(i_disp_msec),
        .o_blink_off(w_blink_off)
    );

    // 설정 점멸 (시.분 쪽만). 점멸은 시.분 화면(i_disp_mode = 1)에서만 일어나므로
    // 초.1/100초 쪽 digit 은 SW2_ANODE_CHOICE 없이 U_SEC_MUXER 에 바로 연결
    wire [3:0] w_mux2_an0, w_mux2_an1, w_mux2_an2, w_mux2_an3;

    SW2_ANODE_CHOICE U_ANODE_CHOICE_TO_MUX2 (
        .i_set_sw2  (i_set_sw2),
        .i_disp_mode(i_disp_mode),
        .i_sel_wt   (i_sel_wt),
        .i_wt_cursor(i_wt_cursor),
        .i_blink_off(w_blink_off),
        .i_an0      (w_min_digit1),
        .i_an1      (w_min_digit10),
        .i_an2      (w_hour_digit1),
        .i_an3      (w_hour_digit10),
        .o_an0      (w_mux2_an0),
        .o_an1      (w_mux2_an1),
        .o_an2      (w_mux2_an2),
        .o_an3      (w_mux2_an3)
    );

    // 자리 고르기 (scan_sel 4~7 = 빈칸, 6 = 가운데 점: w_blink_off = 0 이면 4'he 점 켬)
    wire [3:0] w_sec_mux_bcd;
    wire [3:0] w_min_mux_bcd;

    mux_8x1 U_SEC_MUXER (
        .i_sel (w_scan_sel),
        .i_d0  (w_msec_digit1),
        .i_d1  (w_msec_digit10),
        .i_d2  (w_sec_digit1),
        .i_d3  (w_sec_digit10),
        .i_d4  (4'hf),
        .i_d5  (4'hf),
        .i_d6  ({3'b111, w_blink_off}),
        .i_d7  (4'hf),
        .o_data(w_sec_mux_bcd)
    );

    mux_8x1 U_MIN_MUXER (
        .i_sel (w_scan_sel),
        .i_d0  (w_mux2_an0),
        .i_d1  (w_mux2_an1),
        .i_d2  (w_mux2_an2),
        .i_d3  (w_mux2_an3),
        .i_d4  (4'hf),
        .i_d5  (4'hf),
        .i_d6  ({3'b111, w_blink_off}),
        .i_d7  (4'hf),
        .o_data(w_min_mux_bcd)
    );

    // 2:1 MUX (assign): 0 초.1/100초, 1 시.분
    wire [3:0] w_bcd;
    assign w_bcd = (i_disp_mode == 0) ? w_sec_mux_bcd : w_min_mux_bcd;

    decoder_2x4 U_DECODER (
        .i_sel    (w_scan_sel[1:0]),
        .o_fnd_com(o_fnd_com)
    );

    fnd_decoder U_FND_DEC (
        .i_bcd     (w_bcd),
        .o_fnd_font(o_fnd_font)
    );

endmodule
