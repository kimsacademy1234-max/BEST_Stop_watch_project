`timescale 1ns / 1ps
// DHT11 컨트롤러 (sr04_controller 와 같은 c_ = 현재 · n_ = 다음 구조)
//
// IDLE → START (FPGA 가 LOW, 18 ms 이상) → WAIT (선 놓음, 30 us)
//      → SYNC_L (센서 LOW 80 us) → SYNC_H (센서 HIGH 80 us)
//      → { DATA_SYNC (LOW 50 us) → DATA_BIT (HIGH 26~28 us = 0, 70 us = 1)
//          → BIT_DEC (1 클럭) } x 40 → STOP (센서 LOW 50 us) → IDLE
//
// 엣지를 TIMEOUT_US 넘게 못 받으면 바로 IDLE (o_valid = 0, o_done = 1).
// 습도 · 온도 출력은 마지막 정상값 유지.
module dht11_controller #(
    parameter START_US   = 18_000,   // 시작 LOW (이 값 이상)
    parameter WAIT_US    = 30,       // 선 놓고 기다리는 시간
    parameter TIMEOUT_US = 200,      // 센서 엣지 최대 대기
    parameter BIT1_US    = 40,       // HIGH 가 이보다 길면 1
    parameter USE_ILA    = 1         // 1 : ILA 연결 (단위 TB 에서는 0)
) (
    input        clk,
    input        rst,
    input        i_start,
    input        i_us_tick,
    input        i_dht11,         // 데이터선 입력 (top 의 3상태 버퍼 출력)
    output       o_dht_oe,        // 1 : 데이터선을 LOW 로 구동 (top 에서 3상태 버퍼 제어)
    output [7:0] o_humidity,      // %RH 정수부
    output [7:0] o_temperature,   // ℃ 정수부
    output       o_valid,         // 1 : 체크섬 일치, 0 : 오류 (timeout · 체크섬)
    output [1:0] o_status,        // 00 OK · 01 NO_RESPONSE · 10 TIMEOUT · 11 CHECKSUM
    output       o_done,          // 읽기 끝날 때 1 클럭
    output       o_busy,
    output [3:0] o_state,         // 디버그용 FSM 상태 (0 IDLE ~ 8 STOP)
    output       o_tick_en,
    output       o_tick_clr
);
    localparam [3:0] IDLE      = 4'd0,
                     START     = 4'd1,
                     WAIT      = 4'd2,
                     SYNC_L    = 4'd3,
                     SYNC_H    = 4'd4,
                     DATA_SYNC = 4'd5,
                     DATA_BIT  = 4'd6,
                     BIT_DEC   = 4'd7,
                     STOP      = 4'd8;

    localparam [1:0] ST_OK          = 2'b00,   // 정상
                     ST_NO_RESPONSE = 2'b01,   // 센서 응답 없음 (SYNC_L timeout)
                     ST_TIMEOUT     = 2'b10,   // 응답 뒤 데이터 중간에 끊김
                     ST_CHECKSUM    = 2'b11;   // 40 비트는 받았지만 체크섬 틀림

    (* fsm_encoding = "none" *) reg [3:0] c_state, n_state;
    reg [14:0] c_cnt_us, n_cnt_us;       // 최대 32767 us
    reg [5:0]  c_bit_cnt, n_bit_cnt;     // 0 ~ 39
    reg [39:0] c_data, n_data;           // MSB 먼저
    reg [7:0]  c_hum, n_hum;
    reg [7:0]  c_temp, n_temp;
    reg        c_valid, n_valid;
    reg [1:0]  c_status, n_status;
    reg        c_done, n_done;
    reg        c_oe;                     // 1 : FPGA 가 선을 LOW 로 구동

    // 싱크로나이저 (idle 레벨 1 로 리셋 → 리셋 풀릴 때 가짜 엣지 없음)
    (* ASYNC_REG = "TRUE" *) reg c_io_sync1, c_io_sync2;
    reg c_io_prev;
    wire w_rise = c_io_sync2 & ~c_io_prev;
    wire w_fall = ~c_io_sync2 & c_io_prev;

    // 체크섬 · timeout
    wire [7:0] w_chk_sum = c_data[39:32] + c_data[31:24] + c_data[23:16] + c_data[15:8];
    wire       w_chk_ok  = (w_chk_sum == c_data[7:0]);
    wire       w_timeout = (c_cnt_us >= TIMEOUT_US);

    // 3상태 버퍼는 top 에 둠 : LOW 만 구동하고 나머지는 high-Z (풀업이 HIGH 를 만듦)
    assign o_dht_oe      = c_oe;
    assign o_humidity    = c_hum;
    assign o_temperature = c_temp;
    assign o_valid       = c_valid;
    assign o_status      = c_status;
    assign o_state       = c_state;
    assign o_done        = c_done;
    assign o_busy        = (c_state != IDLE);
    assign o_tick_en     = (c_state != IDLE);
    assign o_tick_clr    = (c_state == IDLE);

    // Integrated Logic Analyzer : 구동 enable · 데이터선 · 동기화된 데이터선 · 상태
    generate
        if (USE_ILA) begin : g_ila
            ila_0 U_ILA (
                .clk   (clk),
                .probe0(c_oe),
                .probe1(i_dht11),
                .probe2(c_io_sync2),
                .probe3(c_state)
            );
        end
    endgenerate

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state    <= IDLE;
            c_cnt_us   <= 0;
            c_bit_cnt  <= 0;
            c_data     <= 0;
            c_hum      <= 0;
            c_temp     <= 0;
            c_valid    <= 0;
            c_status   <= ST_OK;
            c_done     <= 0;
            c_oe       <= 0;
            c_io_sync1 <= 1'b1;
            c_io_sync2 <= 1'b1;
            c_io_prev  <= 1'b1;
        end else begin
            c_state    <= n_state;
            c_cnt_us   <= n_cnt_us;
            c_bit_cnt  <= n_bit_cnt;
            c_data     <= n_data;
            c_hum      <= n_hum;
            c_temp     <= n_temp;
            c_valid    <= n_valid;
            c_status   <= n_status;
            c_done     <= n_done;
            c_oe       <= (n_state == START);   // 상태와 같은 클럭에 바뀜, FF 출력
            c_io_sync1 <= i_dht11;
            c_io_sync2 <= c_io_sync1;
            c_io_prev  <= c_io_sync2;
        end
    end

    // c_cnt_us : 상태가 바뀌면 0. 단 DATA_BIT → BIT_DEC 는 유지 (BIT_DEC 에서 HIGH 길이를 읽음)
    always @(*) begin
        n_state   = c_state;
        n_cnt_us  = c_cnt_us;
        n_bit_cnt = c_bit_cnt;
        n_data    = c_data;
        n_hum     = c_hum;
        n_temp    = c_temp;
        n_valid   = c_valid;
        n_status  = c_status;
        n_done    = 1'b0;                       // 펄스는 기본 0

        if (i_us_tick && c_state != IDLE) n_cnt_us = c_cnt_us + 1;

        case (c_state)
            IDLE: begin
                n_cnt_us = 0;
                if (i_start) begin
                    n_bit_cnt = 0;
                    n_state   = START;
                end
            end
            START: begin                        // tick 은 IDLE 에서 clear → START 진입부터 정확히 1 us 마다
                if (c_cnt_us >= START_US) begin
                    n_cnt_us = 0;
                    n_state  = WAIT;
                end
            end
            WAIT: begin
                if (c_cnt_us >= WAIT_US) begin
                    n_cnt_us = 0;
                    n_state  = SYNC_L;
                end
            end
            SYNC_L: begin                       // 선이 이미 LOW 이든 곧 LOW 가 되든 다음 상승 = 80 us LOW 끝
                if (w_rise) begin
                    n_cnt_us = 0;
                    n_state  = SYNC_H;
                end else if (w_timeout) begin
                    n_cnt_us = 0; n_valid = 1'b0; n_status = ST_NO_RESPONSE; n_done = 1'b1; n_state = IDLE;
                end
            end
            SYNC_H: begin
                if (w_fall) begin
                    n_cnt_us = 0;
                    n_state  = DATA_SYNC;
                end else if (w_timeout) begin
                    n_cnt_us = 0; n_valid = 1'b0; n_status = ST_TIMEOUT; n_done = 1'b1; n_state = IDLE;
                end
            end
            DATA_SYNC: begin
                if (w_rise) begin
                    n_cnt_us = 0;
                    n_state  = DATA_BIT;
                end else if (w_timeout) begin
                    n_cnt_us = 0; n_valid = 1'b0; n_status = ST_TIMEOUT; n_done = 1'b1; n_state = IDLE;
                end
            end
            DATA_BIT: begin
                if (w_fall) begin
                    n_state = BIT_DEC;          // c_cnt_us 유지 = HIGH 길이
                end else if (w_timeout) begin
                    n_cnt_us = 0; n_valid = 1'b0; n_status = ST_TIMEOUT; n_done = 1'b1; n_state = IDLE;
                end
            end
            BIT_DEC: begin                      // 1 클럭
                n_data    = {c_data[38:0], (c_cnt_us > BIT1_US)};
                n_bit_cnt = c_bit_cnt + 1;
                n_cnt_us  = 0;
                n_state   = (c_bit_cnt == 6'd39) ? STOP : DATA_SYNC;
            end
            STOP: begin                         // 센서 LOW 50 us 뒤 선을 놓음
                if (w_rise || w_timeout) begin
                    n_cnt_us = 0;
                    n_valid  = w_chk_ok;
                    n_status = w_chk_ok ? ST_OK : ST_CHECKSUM;
                    n_done   = 1'b1;
                    if (w_chk_ok) begin
                        n_hum  = c_data[39:32];
                        n_temp = c_data[23:16];
                    end
                    n_state = IDLE;
                end
            end
            default: n_state = IDLE;
        endcase
    end
endmodule
