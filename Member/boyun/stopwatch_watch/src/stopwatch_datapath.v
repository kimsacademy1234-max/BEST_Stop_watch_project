`timescale 1ns / 1ps

// 사용자 stopwatch.v 에서 top(stopwatch) 만 빼고 그대로 복사 (stopwatch_datapath · tick_gen_100hz · tick_counter)
module stopwatch_datapath #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input clk,
    input rst,
    input run_stop,
    input clear,
    input mode,
    output [MSEC_BIT_WIDTH-1:0] msec,
    output [SEC_BIT_WIDTH-1:0] sec,
    output [MIN_BIT_WIDTH-1:0] min,
    output [HOUR_BIT_WIDTH-1:0] hour
);

    wire w_tick_10ms, w_tick_sec, w_tick_min, w_tick_hour;

    tick_gen_100hz U_TICK_GEN_100HZ (
        .clk(clk),
        .rst(rst),
        .run_stop(run_stop),
        .clear(clear),
        .o_tick(w_tick_10ms)     // 100hz tick
    );

    tick_counter #(
        .TIMES(100),
        .BIT_WIDTH(MSEC_BIT_WIDTH)
    ) U_MSEC_COUNTER (
        .clk(clk),
        .rst(rst),
        .i_tick(w_tick_10ms),
        .clear(clear),
        .mode(mode),
        .time_count(msec),
        .o_tick(w_tick_sec)
    );


    tick_counter #(
        .TIMES(60),
        .BIT_WIDTH(SEC_BIT_WIDTH)
    ) U_SEC_COUNTER (
        .clk(clk),
        .rst(rst),
        .i_tick(w_tick_sec),
        .clear(clear),
        .mode(mode),
        .time_count(sec),
        .o_tick(w_tick_min)
    );

    tick_counter #(
        .TIMES(60),
        .BIT_WIDTH(MIN_BIT_WIDTH)
    ) U_MIN_COUNTER (
        .clk(clk),
        .rst(rst),
        .i_tick(w_tick_min),
        .clear(clear),
        .mode(mode),
        .time_count(min),
        .o_tick(w_tick_hour)
    );

    tick_counter #(
        .TIMES(24),
        .BIT_WIDTH(HOUR_BIT_WIDTH)
    ) U_HOUR_COUNTER (
        .clk(clk),
        .rst(rst),
        .i_tick(w_tick_hour),
        .clear(clear),
        .mode(mode),
        .time_count(hour),
        .o_tick()
    );

endmodule


module tick_gen_100hz (
    input  clk,
    input  rst,
    input  run_stop,
    input  clear,
    output reg o_tick     // 100hz tick
);

    // 100Mhz -> 100Hz
    parameter F_COUNT = 100_000_000 / 100;
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst | clear) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
        end else begin
            if (run_stop) begin
                counter_reg <= counter_reg + 1;
                if (counter_reg == F_COUNT - 1) begin
                    counter_reg <= 0;
                    o_tick <= 1'b1;
                end else begin
                    o_tick <= 1'b0;
                end
            end else begin
                // run_stop이 1이고, o_tick이 1일때 run_stop이 0으로 바뀌면,
                // 계속 o_tick이 1로 남는 경우를 해결하기 위함.
                o_tick <= 1'b0;
            end
        end
    end


endmodule


module tick_counter #(
    parameter TIMES = 100,
    BIT_WIDTH = 7
) (
    input                      clk,
    input                      rst,
    input                      i_tick,
    input                      clear,
    input                      mode,
    output     [BIT_WIDTH-1:0] time_count,
    output reg                 o_tick
);

    reg [$clog2(TIMES)-1:0] counter_reg;

    assign time_count = counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst | clear) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
        end else begin
            if (mode) begin
                // down count
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
                // up count
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
