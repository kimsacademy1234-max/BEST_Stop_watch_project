`timescale 1ns / 1ps
//==============================================================================
// Module      : digit_splitter (v2 포트 통일)
// Description : 2자리 10진 분리. o_digit1 = 1의 자리, o_digit10 = 10의 자리
// Type        : Combinational
// Parameter   : WIDTH - 입력 비트 폭
//==============================================================================

module digit_splitter #(
    parameter WIDTH = 7
) (
    input  [WIDTH-1:0] i_value,
    output [3:0]       o_digit1,
    output [3:0]       o_digit10
);

    assign o_digit1  = (i_value) % 10;
    assign o_digit10 = (i_value / 10) % 10;

endmodule
