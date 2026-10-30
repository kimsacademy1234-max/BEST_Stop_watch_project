`timescale 1ns / 1ps

// BCD → 7 세그먼트 (v2 포트 통일), active-low, o_fnd_font[7] = 점(DP)
// 0~9 숫자, 4'hc = "-" (BF, 거리/온습도 오류), 4'hd · 4'hf = 빈칸(FF), 4'he = 점만 켬(7F)
module fnd_decoder (
    input      [3:0] i_bcd,
    output reg [7:0] o_fnd_font
);

    always @(i_bcd) begin
        case (i_bcd)
            4'h0: o_fnd_font = 8'hC0;
            4'h1: o_fnd_font = 8'hF9;
            4'h2: o_fnd_font = 8'hA4;
            4'h3: o_fnd_font = 8'hB0;
            4'h4: o_fnd_font = 8'h99;
            4'h5: o_fnd_font = 8'h92;
            4'h6: o_fnd_font = 8'h82;
            4'h7: o_fnd_font = 8'hF8;
            4'h8: o_fnd_font = 8'h80;
            4'h9: o_fnd_font = 8'h90;
            4'hc: o_fnd_font = 8'hBF;           // (merge) g 세그먼트만 = "-"
            4'hd: o_fnd_font = 8'hFF;
            4'he: o_fnd_font = 8'b0111_1111;
            4'hf: o_fnd_font = 8'b1111_1111;
            default: o_fnd_font = 8'hC0;
        endcase
    end

endmodule
