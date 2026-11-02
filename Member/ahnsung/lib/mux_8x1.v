`timescale 1ns / 1ps
//==============================================================================
// Module      : mux_4x1
// Description : 4-to-1 multiplexer. i_sel = 0~3 -> o_data = i_d0~i_d3
// Type        : Combinational
// Parameter   : WIDTH - 데이터 비트 폭 (기본 4)
//==============================================================================

module mux_8x1 #(
    parameter WIDTH = 4
) (
    input  wire [2:0]       i_sel,
    input  wire [WIDTH-1:0] i_d0,
    input  wire [WIDTH-1:0] i_d1,
    input  wire [WIDTH-1:0] i_d2,
    input  wire [WIDTH-1:0] i_d3,
    input  wire [WIDTH-1:0] i_d4,
    input  wire [WIDTH-1:0] i_d5,
    input  wire [WIDTH-1:0] i_d6,
    input  wire [WIDTH-1:0] i_d7,

    output reg  [WIDTH-1:0] o_data
);

always @(*) begin
    case (i_sel)
        3'b000:   o_data = i_d0;
        3'b001:   o_data = i_d1;
        3'b010:   o_data = i_d2;
        3'b011:   o_data = i_d3;
        3'b100:   o_data = i_d4;
        3'b101:   o_data = i_d5;
        3'b110:   o_data = i_d6;
        3'b111:   o_data = i_d7;

        default: o_data = {WIDTH{1'b0}};
    endcase
end

endmodule
