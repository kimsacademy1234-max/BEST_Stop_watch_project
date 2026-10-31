`timescale 1ns / 1ps

// FND 컨트롤러 (v2 포트 통일) — (merge) WTS · 거리 · 온습도 통합판
// 기본 흐름 (WTS, 원래 그대로):
//       i_disp_* → digit_splitter(10진 2자리) → SW2_ANODE_CHOICE(설정 점멸, 시.분 쪽만)
//       → mux_8x1(o_scan_sel 로 자리 고르기) → 2:1 MUX(i_disp_mode) → fnd_decoder → o_fnd_font
//       counter8(o_scan_sel[1:0]) → decoder_2x4 → o_fnd_com
// 스캔: i_clk_4khz 마다 o_scan_sel +1 (0~7), 한 칸 250 us, 한 바퀴 2 ms
//   scan_sel 0~3 : AN0~AN3 숫자,  4~7 : AN0~AN3 빈칸 (단 6 = AN2 가운데 점)
//
// (merge) 그림 3 (fnd_controller 부분) 대로 추가
//   ① 디코더 : i_disp_sel (= module_control_bit[6:5]) 로 i_disp_data 를 WTS / DIST / DHT 쪽으로 나눔
//        i_disp_data 배치  WTS  : {hour 6, min 6, sec 6, msec 7}
//                          DIST : {10'b0, status 2, err 1, x10 12}           (0.1cm, "352.7" / 오류 "Err1~3")
//                          DHT  : {7'b0, status 2, err 1, dashes 1, data 14} (습도 x 100 + 온도, "55.24" / 오류 "Err1~3" / 측정 전 "----")
//   ② U_FND_DIST · U_FND_DHT : 자기 데이터를 4자리 + 점으로 (스캔 카운터는 WTS 와 같이 씀)
//   ③ 3:1 MUX (i_disp_sel) : 0 WTS, 1 거리, 2 온습도 → fnd_decoder
module SW2_FND_CONTROLLER #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 6,   // (10/16) 타이머 분(0~59)이 이 자리에 와서 6
    parameter DATA_WIDTH     = MSEC_BIT_WIDTH + SEC_BIT_WIDTH + MIN_BIT_WIDTH + HOUR_BIT_WIDTH
) (
    input                   i_rst,
    input                   i_clk_4khz,
    input  [           1:0] i_disp_sel,    // (merge) 0 WTS, 1 거리, 2 온습도
    input  [DATA_WIDTH-1:0] i_disp_data,   // (merge) Top 의 FND 데이터 MUX 출력
    input                   i_disp_mode,   // 0 초.1/100초, 1 시.분
    input  [           1:0] i_wt_cursor,
    input                   i_sel_wt,      // 1 = 시계 화면
    input                   i_set_sw2,

    output [3:0] o_fnd_com,
    output [7:0] o_fnd_font
);

    // ---------------------------------------------------------------- ① 디코더 (i_disp_sel)
    wire [DATA_WIDTH-1:0] w_wts_data  = (i_disp_sel == 2'd0) ? i_disp_data       : {DATA_WIDTH{1'b0}};
    wire [          14:0] w_dist_data = (i_disp_sel == 2'd1) ? i_disp_data[14:0] : 15'd0;
    wire [          17:0] w_dht_data  = (i_disp_sel == 2'd2) ? i_disp_data[17:0] : 18'd0;

    wire [MSEC_BIT_WIDTH-1:0] w_disp_msec = w_wts_data[MSEC_BIT_WIDTH-1:0];
    wire [ SEC_BIT_WIDTH-1:0] w_disp_sec  = w_wts_data[MSEC_BIT_WIDTH +: SEC_BIT_WIDTH];
    wire [ MIN_BIT_WIDTH-1:0] w_disp_min  = w_wts_data[MSEC_BIT_WIDTH+SEC_BIT_WIDTH +: MIN_BIT_WIDTH];
    wire [HOUR_BIT_WIDTH-1:0] w_disp_hour = w_wts_data[MSEC_BIT_WIDTH+SEC_BIT_WIDTH+MIN_BIT_WIDTH +: HOUR_BIT_WIDTH];

    // ---------------------------------------------------------------- WTS (원래 SW2_FND_CONTROLLER)
    // 10진 2자리 분리
    wire [3:0] w_msec_digit1, w_msec_digit10;
    wire [3:0] w_sec_digit1,  w_sec_digit10;
    wire [3:0] w_min_digit1,  w_min_digit10;
    wire [3:0] w_hour_digit1, w_hour_digit10;

    digit_splitter #(
        .WIDTH(MSEC_BIT_WIDTH)
    ) U_MSEC (
        .i_value  (w_disp_msec),
        .o_digit1 (w_msec_digit1),
        .o_digit10(w_msec_digit10)
    );

    digit_splitter #(
        .WIDTH(SEC_BIT_WIDTH)
    ) U_SEC (
        .i_value  (w_disp_sec),
        .o_digit1 (w_sec_digit1),
        .o_digit10(w_sec_digit10)
    );

    digit_splitter #(
        .WIDTH(MIN_BIT_WIDTH)
    ) U_MIN (
        .i_value  (w_disp_min),
        .o_digit1 (w_min_digit1),
        .o_digit10(w_min_digit10)
    );

    digit_splitter #(
        .WIDTH(HOUR_BIT_WIDTH)
    ) U_HOUR (
        .i_value  (w_disp_hour),
        .o_digit1 (w_hour_digit1),
        .o_digit10(w_hour_digit10)
    );

    // 스캔 카운터 (WTS · 거리 · 온습도 같이 씀)
    wire [2:0] w_scan_sel;

    counter8 U_COUNTER8 (
        .i_clk_4khz(i_clk_4khz),
        .i_rst     (i_rst),
        .o_scan_sel(w_scan_sel)
    );

    // 0.5 초 점멸 박자
    wire w_blink_off;

    dot U_DOT (
        .i_disp_msec(w_disp_msec),
        .o_blink_off(w_blink_off)
    );

    // 설정 점멸 (시.분 쪽만)
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
    wire [3:0] w_wts_bcd;
    assign w_wts_bcd = (i_disp_mode == 0) ? w_sec_mux_bcd : w_min_mux_bcd;

    // ---------------------------------------------------------------- ② 거리 · 온습도
    wire [3:0] w_dist_bcd;
    wire [3:0] w_dht_bcd;

    fnd_dist U_FND_DIST (
        .i_scan_sel(w_scan_sel),
        .i_value   (w_dist_data[11:0]),
        .i_err     (w_dist_data[12]),
        .i_status  (w_dist_data[14:13]),
        .o_bcd     (w_dist_bcd)
    );

    fnd_dht U_FND_DHT (
        .i_scan_sel(w_scan_sel),
        .i_value   (w_dht_data[13:0]),
        .i_dashes  (w_dht_data[14]),
        .i_err     (w_dht_data[15]),
        .i_status  (w_dht_data[17:16]),
        .o_bcd     (w_dht_bcd)
    );

    // ---------------------------------------------------------------- ③ 3:1 MUX (i_disp_sel)
    wire [3:0] w_bcd;
    assign w_bcd = (i_disp_sel == 2'd1) ? w_dist_bcd :
                   (i_disp_sel == 2'd2) ? w_dht_bcd  : w_wts_bcd;

    decoder_2x4 U_DECODER (
        .i_sel    (w_scan_sel[1:0]),
        .o_fnd_com(o_fnd_com)
    );

    fnd_decoder U_FND_DEC (
        .i_bcd     (w_bcd),
        .o_fnd_font(o_fnd_font)
    );

endmodule
