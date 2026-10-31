`timescale 1ns / 1ps
// DHT11 통합용 IP. 이 모듈 하나와 top 의 3상태 버퍼 2 줄이면 연결 끝.
//   (merge) clk / rst → i_clk / i_rst (v2 포트 규칙), 1 us tick 은 IP 의 tick_gen_us
//   안에 들어있는 것 : tick_gen_us (1 us tick) · dht11_controller (FSM)
//                      · 요청 관리 (전원/리셋 뒤 1 s 대기, 측정 시작 간격 2 s, 자동 측정)
//
// top 에서 :
//   assign dht11_io = w_dht_oe ? 1'b0 : 1'bz;   // LOW 만 구동, 나머지 high-Z
//   assign w_dht_in = dht11_io;
//   XDC : dht11_io 핀에 PULLUP true (센서 모듈에 풀업 없으면 외부 5 kΩ)
module dht11_core #(
    parameter BOOT_CYCLES     = 100_000_000,   // 전원/리셋 뒤 대기 1 s
    parameter INTERVAL_CYCLES = 200_000_000,   // 측정 시작 간격 2 s (= auto 주기)
    parameter TICK_F_COUNT    = 100,           // 100 MHz → 1 us tick (시뮬레이션에서만 줄임)
    parameter START_US        = 18_000,        // 시작 LOW 18 ms (시뮬레이션에서만 줄임)
    parameter USE_ILA         = 0              // 1 : 컨트롤러 안 ILA 사용 (ila_0 IP 필요)
) (
    input        i_clk,
    input        i_rst,             // 비동기 리셋, active high
    input        i_start,         // 1 회 측정 요청, 1 클럭 펄스 (간격 안이면 기억했다가 시작)
    input        i_auto_en,       // 1 이면 2 s 마다 자동 측정
    input        i_dht11,         // 센서 DATA 입력 (내부 2-FF 동기화)
    output       o_dht_oe,        // 1 : DATA 선을 LOW 로 구동 (top 3상태 버퍼 제어)
    output [7:0] o_humidity,      // %RH 정수, 마지막 정상값 유지
    output [7:0] o_temperature,   // ℃ 정수, 마지막 정상값 유지
    output       o_valid,         // 마지막 측정 1 : 정상, 0 : 오류
    output [1:0] o_status,        // 00 OK · 01 NO_RESPONSE · 10 TIMEOUT · 11 CHECKSUM
    output       o_measuring,     // 실제 측정 중 (START ~ STOP)
    output       o_busy,          // 측정 + 다음 측정 대기 중 (부팅 1 s, 간격 2 s 포함)
    output       o_done,          // 측정 완료 1 클럭 펄스, 이때 값 · valid · status 확정
    output [3:0] o_state          // 디버그용 FSM 상태 (0 IDLE ~ 8 STOP)
);
    localparam CD_MAX = (BOOT_CYCLES > INTERVAL_CYCLES) ? BOOT_CYCLES : INTERVAL_CYCLES;

    wire w_us_tick, w_tick_en, w_tick_clr;
    wire w_measuring;
    reg  [$clog2(CD_MAX + 1)-1:0] c_cooldown;
    reg  c_pending, c_start;

    // (* 시뮬레이션에서 측정 시작을 세기 쉽도록 이름 유지 *)
    wire w_start = c_start;

    assign o_measuring = w_measuring;
    assign o_busy      = w_measuring || (c_cooldown != 0) || c_start;

    // 요청 관리 : 간격 안에 들어온 요청은 기억, 측정 중 요청은 무시
    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
            c_cooldown <= BOOT_CYCLES;
            c_pending  <= 1'b0;
            c_start    <= 1'b0;
        end else begin
            c_start <= 1'b0;
            if (c_cooldown != 0) c_cooldown <= c_cooldown - 1;
            if (i_start && !w_measuring && !c_start) c_pending <= 1'b1;
            if (!w_measuring && !c_start && c_cooldown == 0 && (c_pending || i_auto_en)) begin
                c_start    <= 1'b1;
                c_pending  <= 1'b0;
                c_cooldown <= INTERVAL_CYCLES;
            end
        end
    end

    // (merge) tick_gen_1us → IP 의 공용 tick_gen_us (SR04 와 같은 모듈)
    tick_gen_us #(.F_COUNT(TICK_F_COUNT)) U_TICK_1US (
        .i_clk   (i_clk),
        .i_rst   (i_rst),
        .i_enable(w_tick_en),
        .i_clear (w_tick_clr),
        .o_tick  (w_us_tick)
    );

    dht11_controller #(
        .START_US(START_US),
        .USE_ILA (USE_ILA)
    ) U_DHT11_CTRL (
        .i_clk        (i_clk),
        .i_rst        (i_rst),
        .i_start      (w_start),
        .i_us_tick    (w_us_tick),
        .i_dht11      (i_dht11),
        .o_dht_oe     (o_dht_oe),
        .o_humidity   (o_humidity),
        .o_temperature(o_temperature),
        .o_valid      (o_valid),
        .o_status     (o_status),
        .o_done       (o_done),
        .o_busy       (w_measuring),
        .o_state      (o_state),
        .o_tick_en    (w_tick_en),
        .o_tick_clr   (w_tick_clr)
    );
endmodule
