`timescale 1ns / 1ps

// 4 kHz 펄스 생성기 (v2 포트 통일)
// o_clk_4khz : 100 MHz 클럭 25,000 개마다 1 클럭(10 ns) 펄스 → 주기 250 us
//              디바운서 샘플 클럭, FND 스캔 카운터 클럭으로 쓰임
module clock_tick_generator #(
    parameter CLK_FRQ = 1000
) (
    input      i_clk,
    input      i_rst,
    output reg o_clk_4khz
);

    parameter FCOUNT = (100_000_000 / CLK_FRQ);
    reg [$clog2(FCOUNT)-1:0] r_counter;

    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            r_counter  <= 0;
            o_clk_4khz <= 0;
        end else begin
            r_counter <= r_counter + 1;
            if (r_counter == FCOUNT - 1) begin
                r_counter  <= 0;
                o_clk_4khz <= 1;
            end else begin
                o_clk_4khz <= 0;
            end
        end
    end

endmodule
