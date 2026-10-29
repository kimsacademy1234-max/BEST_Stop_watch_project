`timescale 1ns / 1ps

module top_sr04 (
    input        clk,
    input        rst,
    input        btnR,
    input        echo,
    output       trig,
    output [3:0] fnd_com,
    output [7:0] fnd_font
);
    wire w_us_tick, w_tick_en, w_tick_clr;
    wire w_sr04_start;
    wire [8:0] w_distance;

    btn_debounce U_BTN_DB (
        .clk  (clk),
        .reset(rst),
        .i_btn(btnR),
        .o_btn(w_sr04_start)
    );

    tick_gen_1us U_TICK_1US (
        .clk     (clk),
        .rst     (rst),
        .i_enable(w_tick_en),
        .i_clear (w_tick_clr),
        .o_tick  (w_us_tick)
    );

    sr04_controller U_SR04_CTRL (
        .clk       (clk),
        .rst       (rst),
        .i_start   (w_sr04_start),
        .i_us_tick (w_us_tick),
        .i_echo    (echo),
        .o_trig    (trig),
        .o_distance(w_distance),
        .o_done    (),
        .o_busy    (),
        .o_tick_en (w_tick_en),
        .o_tick_clr(w_tick_clr)
    );

    fnd_controller U_FND_CONTROLLER (
        .clk     (clk),
        .reset   (rst),
        .fnd_data({5'b00000, w_distance}),
        .fnd_com (fnd_com),
        .fnd_font(fnd_font)
    );
endmodule