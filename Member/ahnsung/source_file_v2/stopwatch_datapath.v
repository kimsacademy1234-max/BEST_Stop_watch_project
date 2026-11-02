`timescale 1ns / 1ps

module stopwatch_datapath #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input                       clk,
    input                       rst,
    input                       i_tick_10ms,  // top 의 100hz tick
    input                       run_stop,
    input                       clear,
    input                       mode,
    input                       btn_lap,
    output [MSEC_BIT_WIDTH-1:0] msec,
    output [ SEC_BIT_WIDTH-1:0] sec,
    output [ MIN_BIT_WIDTH-1:0] min,
    output [HOUR_BIT_WIDTH-1:0] hour,
    output                      lap_active
);
    wire w_tick_10ms, w_tick_sec, w_tick_min, w_tick_hour;
    // 카운터 실제 값 (랩 컨트롤러를 거쳐 msec/sec/min/hour 로 나감)
    wire [MSEC_BIT_WIDTH-1:0] w_msec;
    wire [ SEC_BIT_WIDTH-1:0] w_sec;
    wire [ MIN_BIT_WIDTH-1:0] w_min;
    wire [HOUR_BIT_WIDTH-1:0] w_hour;

    // HOUR Counter
    stopwatch_tick_counter #(
        .TIMES(24),
        .BIT_WIDTH(HOUR_BIT_WIDTH)
    ) U_HOUR_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_hour),
        .clear     (clear),
        .mode      (mode),
        .time_count(w_hour),
        .o_tick    ()
    );

    // MIN Counter
    stopwatch_tick_counter #(
        .TIMES(60),
        .BIT_WIDTH(MIN_BIT_WIDTH)
    ) U_MIN_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_min),
        .clear     (clear),
        .mode      (mode),
        .time_count(w_min),
        .o_tick    (w_tick_hour)
    );

    // SEC Counter
    stopwatch_tick_counter #(
        .TIMES(60),
        .BIT_WIDTH(SEC_BIT_WIDTH)
    ) U_SEC_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_sec),
        .clear     (clear),
        .mode      (mode),
        .time_count(w_sec),
        .o_tick    (w_tick_min)
    );

    // MSEC COUNTER
    stopwatch_tick_counter #(
        .TIMES(100),
        .BIT_WIDTH(MSEC_BIT_WIDTH)
    ) U_MSEC_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_10ms),
        .clear     (clear),
        .mode      (mode),
        .time_count(w_msec),
        .o_tick    (w_tick_sec)
    );


    // 스톱워치는 run_stop 일 때만 tick 통과
    assign w_tick_10ms = i_tick_10ms & run_stop;

    // 랩타임: 랩 활성화 시 저장된 시간, 아니면 현재 시간 출력
    lap_controller U_LAP_CONTROLLER (
        .clk       (clk),
        .rst       (rst),
        .clear     (clear),
        .btn_lap   (btn_lap),
        .msec      (w_msec),
        .sec       (w_sec),
        .min       (w_min),
        .hour      (w_hour),
        .disp_msec (msec),
        .disp_sec  (sec),
        .disp_min  (min),
        .disp_hour (hour),
        .lap_active(lap_active)
    );



endmodule


module stopwatch_tick_counter #(
    parameter TIMES = 100,
    BIT_WIDTH = 7
) (
    input clk,
    input rst,
    input i_tick,
    input clear,
    input mode,
    output [BIT_WIDTH-1:0] time_count,
    output reg o_tick
);

    reg [$clog2(TIMES)-1:0] counter_reg;

    assign time_count = counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst | clear) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
        end else begin
            if (mode) begin
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
