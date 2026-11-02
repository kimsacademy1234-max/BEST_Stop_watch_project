`timescale 1ns / 1ps

module stopwatch (
    input        clk,
    input        rst,
    input        btnR,
    input        btnL,
    input        btnU,
    input        btnD,
    input        sw_display_mode,
    output [3:0] fnd_com,
    output [7:0] fnd_font,
    output       led_lap
);

    parameter MSEC_BIT_WIDTH = 7;
    parameter SEC_BIT_WIDTH = 6;
    parameter MIN_BIT_WIDTH = 6;
    parameter HOUR_BIT_WIDTH = 5;



    wire [MSEC_BIT_WIDTH-1:0] w_msec;
    wire [ SEC_BIT_WIDTH-1:0] w_sec;
    wire [ MIN_BIT_WIDTH-1:0] w_min;
    wire [HOUR_BIT_WIDTH-1:0] w_hour;
    wire w_btn_run_stop, w_run_stop, w_btn_clear, w_btn_mode;
    wire w_clear, w_mode;

    wire w_btn_lap;

    wire [6:0] w_disp_msec;
    wire [5:0] w_disp_sec;
    wire [5:0] w_disp_min;
    wire [4:0] w_disp_hour;



    btn_debounce U_BD_RUN_STOP (
        .clk  (clk),
        .reset(rst),
        .i_btn(btnR),
        .o_btn(w_btn_run_stop)
    );

    btn_debounce U_BD_CLEAR (
        .clk  (clk),
        .reset(rst),
        .i_btn(btnL),
        .o_btn(w_btn_clear)
    );

    btn_debounce U_BD_MODE (
        .clk  (clk),
        .reset(rst),
        .i_btn(btnU),
        .o_btn(w_btn_mode)
    );

    btn_debounce U_BD_LAP (
        .clk  (clk),
        .reset(rst),
        .i_btn(btnD),
        .o_btn(w_btn_lap)
    );


    control_unit U_STOPWATCH_CONTROL_UNIT (
        .clk         (clk),
        .reset       (rst),
        .btn_run_stop(w_btn_run_stop),
        .btn_clear   (w_btn_clear),
        .btn_mode    (w_btn_mode),
        .run_stop    (w_run_stop),
        .clear       (w_clear),
        .mode        (w_mode)
    );


    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .clk     (clk),
        .rst     (rst),
        .run_stop(w_run_stop),
        .clear   (w_clear),
        .mode    (w_mode),
        .msec    (w_msec),
        .sec     (w_sec),
        .min     (w_min),
        .hour    (w_hour)
    );

    lap_controller U_LAP_CONTROLLER (
        .clk    (clk),
        .rst    (rst),
        .clear  (w_clear),
        .btn_lap(w_btn_lap),

        .msec(w_msec),
        .sec (w_sec),
        .min (w_min),
        .hour(w_hour),

        .disp_msec(w_disp_msec),
        .disp_sec (w_disp_sec),
        .disp_min (w_disp_min),
        .disp_hour(w_disp_hour),

        .lap_active(led_lap)
    );


    fnd_controller U_FND_CNTL (
        .clk            (clk),
        .reset          (rst),
        .sw_display_mode(sw_display_mode),
        .msec           (w_disp_msec),
        .sec            (w_disp_sec),
        .min            (w_disp_min),
        .hour           (w_disp_hour),
        .fnd_com        (fnd_com),
        .fnd_font       (fnd_font)
    );



endmodule

module stopwatch_datapath #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input                       clk,
    input                       rst,
    input                       run_stop,
    input                       clear,
    input                       mode,
    output [MSEC_BIT_WIDTH-1:0] msec,
    output [ SEC_BIT_WIDTH-1:0] sec,
    output [ MIN_BIT_WIDTH-1:0] min,
    output [HOUR_BIT_WIDTH-1:0] hour
);
    wire w_tick_10ms, w_tick_sec, w_tick_min, w_tick_hour;

    // HOUR Counter
    tick_counter #(
        .TIMES(24),
        .BIT_WIDTH(HOUR_BIT_WIDTH)
    ) U_HOUR_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_hour),
        .clear     (clear),
        .mode      (mode),
        .time_count(hour),
        .o_tick    ()
    );

    // MIN Counter
    tick_counter #(
        .TIMES(60),
        .BIT_WIDTH(MIN_BIT_WIDTH)
    ) U_MIN_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_min),
        .clear     (clear),
        .mode      (mode),
        .time_count(min),
        .o_tick    (w_tick_hour)
    );

    // SEC Counter
    tick_counter #(
        .TIMES(60),
        .BIT_WIDTH(SEC_BIT_WIDTH)
    ) U_SEC_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_sec),
        .clear     (clear),
        .mode      (mode),
        .time_count(sec),
        .o_tick    (w_tick_min)
    );

    // MSEC COUNTER
    tick_counter #(
        .TIMES(100),
        .BIT_WIDTH(MSEC_BIT_WIDTH)
    ) U_MSEC_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_10ms),
        .clear     (clear),
        .mode      (mode),
        .time_count(msec),
        .o_tick    (w_tick_sec)
    );


    tick_gen_100hz U_TICK_GEN_100HZ (
        .clk     (clk),
        .rst     (rst),
        .run_stop(run_stop),
        .clear   (clear),
        .o_tick  (w_tick_10ms)

    );



endmodule


module tick_counter #(
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


module tick_gen_100hz (
    input clk,
    input rst,
    input run_stop,
    input clear,
    output reg o_tick
);

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
                o_tick <= 1'b0;
            end
        end
    end


endmodule
