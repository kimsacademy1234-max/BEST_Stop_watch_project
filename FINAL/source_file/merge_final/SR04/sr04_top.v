`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
//  SR04 하위 Top (merge)
//   원래 top_sr04 에서 버튼 디바운서 · FND 컨트롤러를 뺀 것
//   - 버튼은 Top 의 공용 디바운서 (물리 | UART /btn) 를 거쳐 1클록 tick 으로 들어옴 (거리 모드일 때만)
//   - FND 는 Top 의 통합 FND_CONTROLLER 로 (o_distance_x10 · o_err)
//   - LED 는 Top 의 통합 LED 출력으로 (o_led)
//   버튼 R : 1회 측정 / 버튼 U : 자동 측정 켜기/끄기
// -----------------------------------------------------------------------------
module sr04_top (
    input         i_clk,
    input         i_rst,
    input         i_btn_R,          // 1회 측정 tick
    input         i_btn_U,          // 자동 측정 켜기/끄기 tick
    input         i_led_sw,         // 거리 막대 LED (LD0~7) ON/OFF
    input         i_echo,           // Pmod JA2
    output        o_trig,           // Pmod JA1
    output [ 8:0] o_distance,       // cm (UART 전송용)
    output [11:0] o_distance_x10,   // 0.1cm (FND "352.7")
    output        o_err,            // 마지막 측정 실패 → FND "----" / LD9
    output        o_auto_en,        // 자동 측정 중
    output        o_done,
    output [ 9:0] o_led             // LD0~7 거리 막대 / LD8 측정 중 / LD9 측정 오류
);

    wire        w_start;
    wire [ 1:0] w_status;
    wire        w_measuring;
    wire        w_busy;
    wire [ 2:0] w_state;

    sr04_mode_ctrl U_MODE (
        .i_clk    (i_clk),
        .i_rst    (i_rst),
        .i_btn_R  (i_btn_R),
        .i_btn_U  (i_btn_U),
        .o_auto_en(o_auto_en),
        .o_start  (w_start)
    );

    sr04_core U_SR04 (
        .i_clk         (i_clk),
        .i_rst         (i_rst),
        .i_start       (w_start),
        .i_auto_en     (o_auto_en),
        .i_echo        (i_echo),
        .o_trig        (o_trig),
        .o_distance    (o_distance),
        .o_distance_x10(o_distance_x10),
        .o_status      (w_status),
        .o_measuring   (w_measuring),
        .o_busy        (w_busy),
        .o_done        (o_done),
        .o_state       (w_state)
    );

    // 스위치는 거리 막대(LD0~7)만 제어, LD8 / LD9 는 항상 동작
    sr04_led_bar U_LED (
        .i_clk      (i_clk),
        .i_rst      (i_rst),
        .i_en       (i_led_sw),
        .i_done     (o_done),
        .i_status   (w_status),
        .i_dist_x10 (o_distance_x10),
        .i_measuring(w_measuring),
        .o_bar      (o_led[7:0]),
        .o_meas     (o_led[8]),
        .o_err      (o_err)
    );
    assign o_led[9] = o_err;

endmodule
