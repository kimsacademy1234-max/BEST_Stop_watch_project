`timescale 1ns / 1ps

// 거리 FND 자리 고르기 (merge) — SR04 의 fnd_controller_dist 를 SW2_FND_CONTROLLER 스캔 방식에 맞춘 것
//   i_value : 0 ~ 4000 (0.1cm 단위) → "352.7" (AN1 에 점)
//   i_err   : 1 이면 "ErrN" (AN3 E, AN2 r, AN1 r, AN0 = 오류 번호 i_status), 점 없음
//             Err1 echo 없음 (NO_ECHO) · Err2 범위 초과 (OUT_RANGE) · Err3 echo 고착 (ECHO_STUCK)
//   스캔 (WTS 와 같음) : scan_sel 0~3 = AN0~AN3 숫자, 5 = AN1 점 (4'he), 나머지 빈칸
module fnd_dist (
    input  [ 2:0] i_scan_sel,
    input  [11:0] i_value,
    input         i_err,
    input  [ 1:0] i_status,      // sr04_controller status (01 / 10 / 11)
    output [ 3:0] o_bcd
);

    wire [6:0] w_low  = i_value % 100;   // 하위 두 자리 (0~99)
    wire [5:0] w_high = i_value / 100;   // 상위 두 자리 (0~40)

    wire [3:0] w_low_digit1,  w_low_digit10;
    wire [3:0] w_high_digit1, w_high_digit10;

    digit_splitter #(
        .WIDTH(7)
    ) U_LOW (
        .i_value  (w_low),
        .o_digit1 (w_low_digit1),
        .o_digit10(w_low_digit10)
    );

    digit_splitter #(
        .WIDTH(6)
    ) U_HIGH (
        .i_value  (w_high),
        .o_digit1 (w_high_digit1),
        .o_digit10(w_high_digit10)
    );

    mux_8x1 U_DIST_MUXER (
        .i_sel (i_scan_sel),
        .i_d0  ((i_err) ? {2'b00, i_status} : w_low_digit1),   // 오류 : 번호 1~3
        .i_d1  ((i_err) ? 4'hb : w_low_digit10),    //        r
        .i_d2  ((i_err) ? 4'hb : w_high_digit1),    //        r
        .i_d3  ((i_err) ? 4'ha : w_high_digit10),   //        E
        .i_d4  (4'hf),
        .i_d5  ((i_err) ? 4'hf : 4'he),   // AN1 점 → "352.7"
        .i_d6  (4'hf),
        .i_d7  (4'hf),
        .o_data(o_bcd)
    );

endmodule
