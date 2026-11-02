`timescale 1ns / 1ps
//==============================================================================
// Module      : decoder_2x4
// Description : 2-to-4 decoder, active-low one-hot output.
//               FND common(anode) 선택용: 00 -> 1110, 11 -> 0111
// Type        : Combinational
//==============================================================================

module decoder_2x4 (
    input  wire [1:0] i_sel,

    output reg  [3:0] o_dec_n
);

always @(*) begin
    case (i_sel)
        2'b00:   o_dec_n = 4'b1110;
        2'b01:   o_dec_n = 4'b1101;
        2'b10:   o_dec_n = 4'b1011;
        2'b11:   o_dec_n = 4'b0111;
        default: o_dec_n = 4'b1111;
    endcase
end

endmodule
