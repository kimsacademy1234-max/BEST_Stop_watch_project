`timescale 1ns / 1ps
// DHT11 하위 Top (merge)
//  원래 dht11_top 에서 reset_sync · 버튼 디바운서를 뺀 것 (둘 다 Top 에서 한 번만 → IP 공용)
//  - 버튼은 Top 의 공용 디바운서 (물리 | UART /btn) 를 거쳐 1클록 tick 으로 들어옴 (온습도 모드일 때만)
//  - o_fnd_data : 습도 x 100 + 온도 (예 : 5524 → "55.24"), o_dashes = 1 이면 "----" 표시
//  - 버튼 R : 1회 측정 / 버튼 U : 자동 측정 켜기/끄기 (켜면 2 s 마다 측정, o_led[3])
//  - 데이터선 3상태 버퍼는 이 모듈 안에 있음 → Top 에서는 dht11_io 를 inout 포트로 그대로 연결
module dht11_top #(
    parameter BOOT_CYCLES     = 100_000_000,   // 1 s
    parameter INTERVAL_CYCLES = 200_000_000,   // 2 s
    parameter TICK_F_COUNT    = 100,           // 1 us tick (시뮬레이션에서만 줄임)
    parameter START_US        = 18_000,        // 시작 LOW (시뮬레이션에서만 줄임)
    parameter USE_ILA         = 0
) (
    input         i_clk,
    input         i_rst,
    input         i_btn_R,        // 1회 측정 tick
    input         i_btn_U,        // 자동 측정 켜기/끄기 tick
    inout         io_dht11,       // DHT11 DATA (JXADC3, PULLUP)
    output [13:0] o_fnd_data,     // → FND_CONTROLLER
    output        o_dashes,       // 1 : 첫 측정 전 · 오류 → "----"
    output [ 3:0] o_led,          // [0] 측정 중 [1] 오류 [2] 정상값 [3] 자동 측정
    output [ 7:0] o_humidity,     // → UART 전송용
    output [ 7:0] o_temperature,
    output        o_valid,
    output [ 1:0] o_status,       // 00 OK · 01 응답 없음 · 10 중간 끊김 · 11 체크섬
    output        o_done
);
    wire        w_measuring, w_busy;
    wire [ 3:0] w_state;
    wire        w_dht_oe, w_dht_in;

    // 데이터선 3상태 버퍼 : LOW 만 구동, 나머지는 high-Z (풀업이 HIGH)
    assign io_dht11 = w_dht_oe ? 1'b0 : 1'bz;
    assign w_dht_in = io_dht11;

    // 버튼 U 누를 때마다 자동 측정 켜기/끄기
    reg c_auto_mode;
    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst)        c_auto_mode <= 1'b0;
        else if (i_btn_U) c_auto_mode <= ~c_auto_mode;
    end
    assign o_led[3] = c_auto_mode;

    dht11_core #(
        .BOOT_CYCLES    (BOOT_CYCLES),
        .INTERVAL_CYCLES(INTERVAL_CYCLES),
        .TICK_F_COUNT   (TICK_F_COUNT),
        .START_US       (START_US),
        .USE_ILA        (USE_ILA)
    ) U_DHT11_CORE (
        .i_clk        (i_clk),
        .i_rst        (i_rst),
        .i_start      (i_btn_R),
        .i_auto_en    (c_auto_mode),
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
        .i_clk        (i_clk),
        .i_rst        (i_rst),
        .i_measuring  (w_measuring),
        .i_done       (o_done),
        .i_valid      (o_valid),
        .i_humidity   (o_humidity),
        .i_temperature(o_temperature),
        .o_fnd_data   (o_fnd_data),
        .o_dashes     (o_dashes),
        .o_led        (o_led[2:0])
    );
endmodule
