`timescale 1ns / 1ps

// 스톱워치 데이터패스 (v2 포트 통일)
// i_tick_10ms 는 Top 의 스톱워치 전용 tick (U_TICK_GEN_SW) — 이미 run_stop 일 때만 나오므로 그대로 받는다
// (10/17) 전에는 여기서 i_tick_10ms & i_sw_run_stop 으로 한 번 더 막았는데, STOP 이 tick 이 나온 바로 그 클럭에
//         들어오면 RUN 동안 다 센 마지막 10 ms 가 막혀 1/100초가 하나 덜 셈 → AND 와 i_sw_run_stop 포트를 지움
// 카운터 값(w_cnt_*) → lap_controller → o_sw_* (랩 중이면 고정값)
module stopwatch_datapath #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input                       i_clk,
    input                       i_rst,
    input                       i_tick_10ms,    // top 의 100hz tick
    input                       i_sw_clear,
    input                       i_sw_down,
    input                       i_sw_btn_D,     // 랩
    output [MSEC_BIT_WIDTH-1:0] o_sw_msec,
    output [ SEC_BIT_WIDTH-1:0] o_sw_sec,
    output [ MIN_BIT_WIDTH-1:0] o_sw_min,
    output [HOUR_BIT_WIDTH-1:0] o_sw_hour,
    output                      o_sw_lap        // 1 = 랩 표시 중
);
    wire w_tick_10ms, w_tick_sec, w_tick_min, w_tick_hour;
    // 카운터 실제 값 (랩 컨트롤러를 거쳐 o_sw_* 로 나감)
    wire [MSEC_BIT_WIDTH-1:0] w_cnt_msec;
    wire [ SEC_BIT_WIDTH-1:0] w_cnt_sec;
    wire [ MIN_BIT_WIDTH-1:0] w_cnt_min;
    wire [HOUR_BIT_WIDTH-1:0] w_cnt_hour;

    // HOUR Counter
    stopwatch_tick_counter #(
        .TIMES(24),
        .BIT_WIDTH(HOUR_BIT_WIDTH)
    ) U_HOUR_COUNTER (
        .i_clk  (i_clk),
        .i_rst  (i_rst),
        .i_tick (w_tick_hour),
        .i_clear(i_sw_clear),
        .i_down (i_sw_down),
        .o_count(w_cnt_hour),
        .o_tick ()
    );

    // MIN Counter
    stopwatch_tick_counter #(
        .TIMES(60),
        .BIT_WIDTH(MIN_BIT_WIDTH)
    ) U_MIN_COUNTER (
        .i_clk  (i_clk),
        .i_rst  (i_rst),
        .i_tick (w_tick_min),
        .i_clear(i_sw_clear),
        .i_down (i_sw_down),
        .o_count(w_cnt_min),
        .o_tick (w_tick_hour)
    );

    // SEC Counter
    stopwatch_tick_counter #(
        .TIMES(60),
        .BIT_WIDTH(SEC_BIT_WIDTH)
    ) U_SEC_COUNTER (
        .i_clk  (i_clk),
        .i_rst  (i_rst),
        .i_tick (w_tick_sec),
        .i_clear(i_sw_clear),
        .i_down (i_sw_down),
        .o_count(w_cnt_sec),
        .o_tick (w_tick_min)
    );

    // MSEC COUNTER
    stopwatch_tick_counter #(
        .TIMES(100),
        .BIT_WIDTH(MSEC_BIT_WIDTH)
    ) U_MSEC_COUNTER (
        .i_clk  (i_clk),
        .i_rst  (i_rst),
        .i_tick (w_tick_10ms),
        .i_clear(i_sw_clear),
        .i_down (i_sw_down),
        .o_count(w_cnt_msec),
        .o_tick (w_tick_sec)
    );


    // tick 은 U_TICK_GEN_SW 가 RUN 동안만 만든다 (10/17: run_stop AND 삭제)
    assign w_tick_10ms = i_tick_10ms;

    // 랩타임: 랩 활성화 시 저장된 시간, 아니면 현재 시간 출력
    lap_controller U_LAP_CONTROLLER (
        .i_clk     (i_clk),
        .i_rst     (i_rst),
        .i_sw_clear(i_sw_clear),
        .i_sw_btn_D(i_sw_btn_D),
        .i_cnt_msec(w_cnt_msec),
        .i_cnt_sec (w_cnt_sec),
        .i_cnt_min (w_cnt_min),
        .i_cnt_hour(w_cnt_hour),
        .o_sw_msec (o_sw_msec),
        .o_sw_sec  (o_sw_sec),
        .o_sw_min  (o_sw_min),
        .o_sw_hour (o_sw_hour),
        .o_sw_lap  (o_sw_lap)
    );

endmodule


module stopwatch_tick_counter #(
    parameter TIMES = 100,
    BIT_WIDTH = 7
) (
    input                  i_clk,
    input                  i_rst,
    input                  i_tick,
    input                  i_clear,
    input                  i_down,
    output [BIT_WIDTH-1:0] o_count,
    output reg             o_tick
);

    reg [$clog2(TIMES)-1:0] counter_reg;

    assign o_count = counter_reg;

    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst | i_clear) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
        end else begin
            if (i_down) begin
                if (i_tick) begin
                    counter_reg <= counter_reg - 1;
                    if (counter_reg == 0) begin
                        counter_reg <= TIMES - 1;
                        o_tick <= 1'b1;
                    end
                end else begin
                    o_tick <= 1'b0;
                end
            end else begin
                if (i_tick) begin
                    counter_reg <= counter_reg + 1;
                    if (counter_reg == TIMES - 1) begin
                        counter_reg <= 0;
                        o_tick <= 1'b1;
                    end
                end else begin
                    o_tick <= 1'b0;
                end
            end
        end
    end

endmodule
