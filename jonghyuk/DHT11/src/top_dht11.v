`timescale 1ns / 1ps
// DHT11 온습도 : btnR 한 번 = 한 번 측정, FND = 습도.온도 (예 : 55.24)
// rst = btnC. 오류(응답 없음 · 체크섬)와 첫 측정 전은 "----"
// 센서 관련은 dht11_core 하나에 들어있음 (팀 통합 때도 이 모듈만 가져가면 됨)
module top_dht11 #(
    parameter BTN_F_COUNT     = 100_000,       // 디바운스 샘플 1 ms
    parameter BOOT_CYCLES     = 100_000_000,   // 1 s
    parameter INTERVAL_CYCLES = 200_000_000,   // 2 s
    parameter TICK_F_COUNT    = 100,           // 1 us tick (시뮬레이션에서만 줄임)
    parameter START_US        = 18_000,        // 시작 LOW (시뮬레이션에서만 줄임)
    parameter FND_SCAN        = 125_000,       // FND 자리 전환 800 Hz
    parameter USE_ILA         = 1
) (
    input        clk,
    input        rst,
    input        btnR,
    inout        dht11_io,
    output [3:0] fnd_com,
    output [7:0] fnd_font,
    output [2:0] led
);
    wire        w_rst;
    wire        w_btn, w_measuring, w_busy, w_done, w_valid;
    wire [1:0]  w_status;
    wire [3:0]  w_state;
    wire [7:0]  w_humidity, w_temperature;
    wire [13:0] w_fnd_data;
    wire        w_dashes;
    wire        w_dht_oe, w_dht_in;

    // 데이터선 3상태 버퍼 : LOW 만 구동, 나머지는 high-Z (풀업이 HIGH)
    assign dht11_io = w_dht_oe ? 1'b0 : 1'bz;
    assign w_dht_in = dht11_io;

    // btnC 를 그대로 쓰지 않고 리셋 해제를 클럭에 맞춤
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
        .i_auto_en    (1'b0),          // 자동 측정 안 씀 (스위치 연결하면 2 s 마다 측정)
        .i_dht11      (w_dht_in),
        .o_dht_oe     (w_dht_oe),
        .o_humidity   (w_humidity),
        .o_temperature(w_temperature),
        .o_valid      (w_valid),
        .o_status     (w_status),
        .o_measuring  (w_measuring),
        .o_busy       (w_busy),
        .o_done       (w_done),
        .o_state      (w_state)
    );

    dht11_manager U_DHT11_MGR (
        .clk          (clk),
        .rst          (w_rst),
        .i_measuring  (w_measuring),
        .i_done       (w_done),
        .i_valid      (w_valid),
        .i_humidity   (w_humidity),
        .i_temperature(w_temperature),
        .o_fnd_data   (w_fnd_data),
        .o_dashes     (w_dashes),
        .o_led        (led)
    );

    fnd_controller #(.SCAN_COUNT(FND_SCAN)) U_FND_CONTROLLER (
        .clk     (clk),
        .reset   (w_rst),
        .fnd_data(w_fnd_data),
        .i_dashes(w_dashes),
        .i_dp    (4'b0100),            // 습도 일의 자리 뒤 소수점 : 55.24
        .fnd_com (fnd_com),
        .fnd_font(fnd_font)
    );
endmodule
