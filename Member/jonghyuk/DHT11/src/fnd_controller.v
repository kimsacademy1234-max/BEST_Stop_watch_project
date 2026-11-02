`timescale 1ns / 1ps
// 원본(이전 실습) 구조 유지 : 스캔 → 2x4 디코더, digit_splitter → mux → bcd
// 고친 점
//  - clk_div_800hz 의 분주 출력을 클럭으로 쓰지 않고 800 Hz tick(enable) 으로 counter_4 구동
//  - i_dashes : 1 이면 네 자리 모두 "-"
//  - i_dp[3:0] : 자리별 소수점 (1 = 켬), fnd_font[7] 로 출력
module fnd_controller #(
    parameter SCAN_COUNT = 125_000      // 100 MHz / 125_000 = 800 Hz (자리 전환)
) (
    input        clk,
    input        reset,
    input  [13:0] fnd_data,             // 0 ~ 9999
    input        i_dashes,
    input  [3:0] i_dp,
    output [3:0] fnd_com,
    output [7:0] fnd_font
);
    wire [3:0] w_ds1, w_ds10, w_ds100, w_ds1000, w_mux_out;
    wire [1:0] w_ds_sel;
    wire       w_tick_800hz;
    wire [7:0] w_font;

    tick_div #(.F_COUNT(SCAN_COUNT)) U_TICK_800HZ (
        .clk   (clk),
        .reset (reset),
        .o_tick(w_tick_800hz)
    );

    counter_4 U_COUNTER_4 (
        .clk   (clk),
        .reset (reset),
        .i_en  (w_tick_800hz),
        .ds_sel(w_ds_sel)
    );

    decoder_2x4 U_DECODER_2x4 (
        .ds_sel (w_ds_sel),
        .fnd_com(fnd_com)
    );

    digit_splitter U_DIGIT_SPLITTER (
        .dsin  (fnd_data),
        .ds1   (w_ds1),
        .ds10  (w_ds10),
        .ds100 (w_ds100),
        .ds1000(w_ds1000)
    );

    mux_4x1 U_MUX_4x1 (
        .sel    (w_ds_sel),
        .in0    (w_ds1),
        .in1    (w_ds10),
        .in2    (w_ds100),
        .in3    (w_ds1000),
        .mux_out(w_mux_out)
    );

    bcd U_BCD (
        .bin     (w_mux_out),
        .fnd_font(w_font)
    );

    // "-" = g 세그먼트만 켬 (active low). 소수점은 bit7, 0 이 켜짐
    assign fnd_font[6:0] = i_dashes ? 7'b011_1111 : w_font[6:0];
    assign fnd_font[7]   = ~(i_dp[w_ds_sel] & ~i_dashes);
endmodule


// F_COUNT 클럭마다 1 클럭 tick
module tick_div #(
    parameter F_COUNT = 125_000
) (
    input      clk,
    input      reset,
    output reg o_tick
);
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            o_tick      <= 1'b0;
        end else if (counter_reg == F_COUNT - 1) begin
            counter_reg <= 0;
            o_tick      <= 1'b1;
        end else begin
            counter_reg <= counter_reg + 1;
            o_tick      <= 1'b0;
        end
    end
endmodule


module counter_4 (
    input        clk,
    input        reset,
    input        i_en,
    output [1:0] ds_sel
);
    reg [1:0] counter_reg;

    assign ds_sel = counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset)     counter_reg <= 2'b0;      // 1의 자리부터
        else if (i_en) counter_reg <= counter_reg + 1;
    end
endmodule


module decoder_2x4 (
    input      [1:0] ds_sel,
    output reg [3:0] fnd_com
);
    always @(*) begin
        case (ds_sel)
            2'b00:   fnd_com = 4'b1110;
            2'b01:   fnd_com = 4'b1101;
            2'b10:   fnd_com = 4'b1011;
            2'b11:   fnd_com = 4'b0111;
            default: fnd_com = 4'b1111;
        endcase
    end
endmodule


module mux_4x1 (
    input      [1:0] sel,
    input      [3:0] in0,
    input      [3:0] in1,
    input      [3:0] in2,
    input      [3:0] in3,
    output reg [3:0] mux_out
);
    always @(*) begin
        case (sel)
            2'b00:   mux_out = in0;
            2'b01:   mux_out = in1;
            2'b10:   mux_out = in2;
            2'b11:   mux_out = in3;
            default: mux_out = in0;
        endcase
    end
endmodule


module digit_splitter (
    input  [13:0] dsin,
    output [3:0]  ds1,
    output [3:0]  ds10,
    output [3:0]  ds100,
    output [3:0]  ds1000
);
    assign ds1    = dsin % 10;
    assign ds10   = (dsin / 10) % 10;
    assign ds100  = (dsin / 100) % 10;
    assign ds1000 = (dsin / 1000) % 10;
endmodule


module bcd (
    input      [3:0] bin,
    output reg [7:0] fnd_font
);
    always @(*) begin
        case (bin)
            4'b0000: fnd_font = 8'hc0;
            4'b0001: fnd_font = 8'hf9;
            4'b0010: fnd_font = 8'ha4;
            4'b0011: fnd_font = 8'hb0;
            4'b0100: fnd_font = 8'h99;
            4'b0101: fnd_font = 8'h92;
            4'b0110: fnd_font = 8'h82;
            4'b0111: fnd_font = 8'hf8;
            4'b1000: fnd_font = 8'h80;
            4'b1001: fnd_font = 8'h90;
            4'b1010: fnd_font = 8'h88;
            4'b1011: fnd_font = 8'h83;
            4'b1100: fnd_font = 8'hc6;
            4'b1101: fnd_font = 8'ha1;
            4'b1110: fnd_font = 8'h86;
            4'b1111: fnd_font = 8'h8e;
            default: fnd_font = 8'hff;
        endcase
    end
endmodule
