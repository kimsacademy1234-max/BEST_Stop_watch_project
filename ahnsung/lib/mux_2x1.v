`timescale 1ns / 1ps
//==============================================================================
// Module      : mux_4x1
// Description : 4-to-1 multiplexer. i_sel = 0~3 -> o_data = i_d0~i_d3
// Type        : Combinational
// Parameter   : WIDTH - 데이터 비트 폭 (기본 4)
//==============================================================================

module mux_2x1 #(
    parameter WIDTH = 4
) (
    input  wire [1:0]       i_sel,
    input  wire [WIDTH-1:0] i_d0,
    input  wire [WIDTH-1:0] i_d1,
    input  wire [WIDTH-1:0] i_d2,
    input  wire [WIDTH-1:0] i_d3,

    output reg  [WIDTH-1:0] o_data
);

always @(*) begin
    case (i_sel)
        2'b00:   o_data = i_d0;
        2'b01:   o_data = i_d1;
        2'b10:   o_data = i_d2;
        2'b11:   o_data = i_d3;
        default: o_data = {WIDTH{1'b0}};
    endcase
end

endmodule
