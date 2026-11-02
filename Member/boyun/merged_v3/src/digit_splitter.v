`timescale 1ns / 1ps
//==============================================================================
// Module      : digit_splitter
// Description : Binary -> 4 decimal digits (BCD). o_digit_1 = 1의 자리,
//               o_digit_10 = 10의 자리, i_ds1, i_ds10.
// Type        : Combinational
// Parameter   : WIDTH - 입력 비트 폭 (기본 9 -> 0~511)
//==============================================================================

module digit_splitter #(
    parameter WIDTH = 7
) (
    input [WIDTH-1:0] i_din,
	output [3:0] o_ds1,
	output [3:0] o_ds10

);

assign o_ds1  = (i_din)  % 10;
assign o_ds10 = (i_din / 10) % 10;

endmodule
