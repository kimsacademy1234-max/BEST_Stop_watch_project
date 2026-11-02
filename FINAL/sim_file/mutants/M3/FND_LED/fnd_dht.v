`timescale 1ns / 1ps

// 온습도 FND 자리 고르기 (merge) — DHT11 표시 (dht11_manager 의 o_fnd_data / o_dashes)
//   i_value  : 습도 x 100 + 온도 (예 : 55 %, 24 ℃ → 5524) → "55.24" (AN2 에 점)
//   i_err    : 1 이면 "ErrN" (AN3 E, AN2 r, AN1 r, AN0 = 오류 번호 i_status) — 마지막 측정 실패
//              Err1 응답 없음 (NO_RESPONSE) · Err2 중간 끊김 (TIMEOUT) · Err3 체크섬 (CHECKSUM)
//   i_dashes : 1 이고 오류가 아니면 4자리 모두 "-" (4'hc) — 아직 정상값이 없음 (첫 측정 전)
//   스캔 (WTS 와 같음) : scan_sel 0~3 = AN0~AN3 숫자, 6 = AN2 점 (4'he), 나머지 빈칸
module fnd_dht (
    input  [ 2:0] i_scan_sel,
    input  [13:0] i_value,
    input         i_dashes,
    input         i_err,
    input  [ 1:0] i_status,       // dht11_controller status (01 / 10 / 11)
    output [ 3:0] o_bcd
);

    wire [6:0] w_temp = i_value % 100;   // 온도 (0~99)
    wire [6:0] w_hum  = i_value / 100;   // 습도 (0~99)

    wire [3:0] w_temp_digit1, w_temp_digit10;
    wire [3:0] w_hum_digit1,  w_hum_digit10;

    digit_splitter #(
        .WIDTH(7)
    ) U_TEMP (
        .i_value  (w_temp),
        .o_digit1 (w_temp_digit1),
        .o_digit10(w_temp_digit10)
    );

    digit_splitter #(
        .WIDTH(7)
    ) U_HUM (
        .i_value  (w_hum),
        .o_digit1 (w_hum_digit1),
        .o_digit10(w_hum_digit10)
    );

    mux_8x1 U_DHT_MUXER (
        .i_sel (i_scan_sel),
        .i_d0  ((i_err) ? {2'b00, i_status} : (i_dashes) ? 4'hc : w_temp_digit1),
        .i_d1  ((i_err) ? 4'hb : (i_dashes) ? 4'hc : w_temp_digit10),
        .i_d2  ((i_err) ? 4'hb : (i_dashes) ? 4'hc : w_hum_digit1),
        .i_d3  ((i_err) ? 4'ha : (i_dashes) ? 4'hc : w_hum_digit10),
        .i_d4  (4'hf),
        .i_d5  (4'hf),
        .i_d6  ((i_err | i_dashes) ? 4'hf : 4'he),   // AN2 점 → "55.24"
        .i_d7  (4'hf),
        .o_data(o_bcd)
    );

endmodule
