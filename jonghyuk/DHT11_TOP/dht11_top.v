`timescale 1ns / 1ps
// 팀 통합용 DHT11 top (fnd_controller 없음)
//  top_dht11 에서 fnd_controller 만 뺀 것. FND 는 팀 쪽 fnd_controller 에 연결
//  - o_fnd_data : 습도 x 100 + 온도 (예 : 5524 → "55.24"), o_dashes = 1 이면 "----" 표시
//  - o_humidity · o_temperature · o_valid · o_status · o_done : 원래 값 (다른 용도로 쓸 때)
//  - 데이터선 3상태 버퍼는 이 모듈 안에 있음 → 팀 top 에서는 dht11_io 를 inout 포트로 그대로 연결
module dht11_top #(
    parameter BTN_F_COUNT     = 100_000,       // 디바운스 샘플 1 ms
    parameter BOOT_CYCLES     = 100_000_000,   // 1 s
    parameter INTERVAL_CYCLES = 200_000_000,   // 2 s
    parameter TICK_F_COUNT    = 100,           // 1 us tick (시뮬레이션에서만 줄임)
    parameter START_US        = 18_000,        // 시작 LOW (시뮬레이션에서만 줄임)
    parameter USE_ILA         = 0
) (
    input         clk,
    input         rst,            // 버튼 그대로 (안에서 reset_sync)
    input         btnR,           // 측정 버튼 (안에서 디바운스)
    inout         dht11_io,       // DHT11 DATA (JA1, PULLUP)
    output [13:0] o_fnd_data,     // → 팀 fnd_controller 의 fnd_data
    output        o_dashes,       // 1 : 첫 측정 전 · 오류 → "----"
    output [2:0]  led,            // [0] 측정 중, [1] 오류, [2] 정상값
    output [7:0]  o_humidity,
    output [7:0]  o_temperature,
    output        o_valid,
    output [1:0]  o_status,       // 00 OK · 01 응답 없음 · 10 중간 끊김 · 11 체크섬
    output        o_done
);
    wire        w_rst, w_btn;
    wire        w_measuring, w_busy;
    wire [3:0]  w_state;
    wire        w_dht_oe, w_dht_in;

    // 데이터선 3상태 버퍼 : LOW 만 구동, 나머지는 high-Z (풀업이 HIGH)
    assign dht11_io = w_dht_oe ? 1'b0 : 1'bz;
    assign w_dht_in = dht11_io;

    reset_sync U_RESET_SYNC (
        .clk         (clk),
        .reset_button(rst),
        .rst         (w_rst)
    );

    btn_debounce #(.F_COUNT(BTN_F_COUNT)) U_BTN_DB (
        .clk  (clk),
        .reset(w_rst),
        .i_btn(btnR),
        .o_btn(w_btn)
    );

    dht11_core #(
        .BOOT_CYCLES    (BOOT_CYCLES),
        .INTERVAL_CYCLES(INTERVAL_CYCLES),
        .TICK_F_COUNT   (TICK_F_COUNT),
        .START_US       (START_US),
        .USE_ILA        (USE_ILA)
    ) U_DHT11_CORE (
        .clk          (clk),
        .rst          (w_rst),
        .i_start      (w_btn),
        .i_auto_en    (1'b0),
        .i_dht11      (w_dht_in),
        .o_dht_oe     (w_dht_oe),
        .o_humidity   (o_humidity),
        .o_temperature(o_temperature),
        .o_valid      (o_valid),
        .o_status     (o_status),
        .o_measuring  (w_measuring),
        .o_busy       (w_busy),
        .o_done       (o_done),
        .o_state      (w_state)
    );

    dht11_manager U_DHT11_MGR (
        .clk          (clk),
        .rst          (w_rst),
        .i_measuring  (w_measuring),
        .i_done       (o_done),
        .i_valid      (o_valid),
        .i_humidity   (o_humidity),
        .i_temperature(o_temperature),
        .o_fnd_data   (o_fnd_data),
        .o_dashes     (o_dashes),
        .o_led        (led)
    );
endmodule
