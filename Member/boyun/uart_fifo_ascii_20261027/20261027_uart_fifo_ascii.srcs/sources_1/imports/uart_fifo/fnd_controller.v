`timescale 1ns / 1ps

module fnd_controller (
    input clk,
    input reset,
    input [3:0] fnd_data, 
    output [3:0] fnd_com,
    output [7:0] fnd_font
);

    assign fnd_com = 4'b1101;

    bcd U_BCD (
        .bin(fnd_data),
        .fnd_font       (fnd_font)   // 값을 유지해서 내보내야 하므로 reg로 선언. 
    );
endmodule


module bcd (
    input [3:0] bin,
    output reg [7:0] fnd_font   // 값을 유지해서 내보내야 하므로 reg로 선언. 
);

    always @(bin) begin
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

