`timescale 1ns / 1ps

// FND 스캔 카운터 (v2 포트 통일)
// i_clk_4khz 상승 엣지마다 +1 → o_scan_sel 0~7 반복 (한 칸 250 us, 한 바퀴 2 ms)
//   o_scan_sel[1:0] → 자리(AN0~AN3) 선택, o_scan_sel[2] = 0 숫자 칸 / 1 빈칸 · 점 칸
module counter8 (
    input            i_clk_4khz,
    input            i_rst,
    output reg [2:0] o_scan_sel
);

    always @(posedge i_clk_4khz, posedge i_rst) begin
        if (i_rst) o_scan_sel <= 0;
        else       o_scan_sel <= o_scan_sel + 1;
    end

endmodule
