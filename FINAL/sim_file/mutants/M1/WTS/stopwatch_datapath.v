`timescale 1ns / 1ps

// ?ä§?Ü±?õåÏπ? ?ç∞?ù¥?Ñ∞?å®?ä§ (v2 ?è¨?ä∏ ?Üµ?ùº)
// i_tick_10ms ?äî Top ?ùò ?ä§?Ü±?õåÏπ? ?†Ñ?ö© tick (U_TICK_GEN_SW) ?? ?ù¥ÎØ? run_stop ?ùº ?ïåÎß? ?Çò?ò§ÎØ?Î°? Í∑∏Î?Î°? Î∞õÎäî?ã§
// (10/17) ?†Ñ?óê?äî ?ó¨Í∏∞ÏÑú i_tick_10ms & i_sw_run_stop ?úºÎ°? ?ïú Î≤? ?çî ÎßâÏïò?äî?ç∞, STOP ?ù¥ tick ?ù¥ ?Çò?ò® Î∞îÎ°ú Í∑? ?Å¥?ü≠?óê
//         ?ì§?ñ¥?ò§Î©? RUN ?èô?ïà ?ã§ ?Ñº ÎßàÏ?Îß? 10 ms Í∞? ÎßâÌ? 1/100Ï¥àÍ? ?ïò?Çò ?çú ?Öà ?Üí AND ?? i_sw_run_stop ?è¨?ä∏Î•? Ïß???
// Ïπ¥Ïö¥?Ñ∞ Í∞?(w_cnt_*) ?Üí lap_controller ?Üí o_sw_* (?û© Ï§ëÏù¥Î©? Í≥†Ï†ïÍ∞?)
module stopwatch_datapath #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input                       i_clk,
    input                       i_rst,
    input                       i_tick_10ms,    // top ?ùò 100hz tick
    input                       i_sw_clear,
    input                       i_sw_down,
    input                       i_sw_btn_D,     // ?û©
    output [MSEC_BIT_WIDTH-1:0] o_sw_msec,
    output [ SEC_BIT_WIDTH-1:0] o_sw_sec,
    output [ MIN_BIT_WIDTH-1:0] o_sw_min,
    output [HOUR_BIT_WIDTH-1:0] o_sw_hour,
    output                      o_sw_lap        // 1 = ?û© ?ëú?ãú Ï§?
);
    wire w_tick_10ms, w_tick_sec, w_tick_min, w_tick_hour;
    // Ïπ¥Ïö¥?Ñ∞ ?ã§?†ú Í∞? (?û© Ïª®Ìä∏Î°§Îü¨Î•? Í±∞Ï≥ê o_sw_* Î°? ?ÇòÍ∞?)
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


    // tick ?? U_TICK_GEN_SW Í∞? RUN ?èô?ïàÎß? ÎßåÎì†?ã§ (10/17: run_stop AND ?Ç≠?†ú)
    assign w_tick_10ms = i_tick_10ms;

    // ?û©???ûÑ: ?û© ?ôú?Ñ±?ôî ?ãú ???û•?êú ?ãúÍ∞?, ?ïÑ?ãàÎ©? ?òÑ?û¨ ?ãúÍ∞? Ï∂úÎ†•
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
