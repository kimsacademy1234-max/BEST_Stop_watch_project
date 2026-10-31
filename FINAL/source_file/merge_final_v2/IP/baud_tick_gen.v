`timescale 1ns / 1ps

// UART baud tick (9600 x 16 = 153,600 Hz)
// (merge) RX 와 TX 가 같은 주기라 Top 에서 하나만 두고 같이 씀. 포트 이름만 v2 규칙 (i_ / o_)
module baud_tick_gen #(
    parameter SAMPLING_RATE = 16,
    parameter BAUD_RATE     = 9600
) (
    input      i_clk,
    input      i_rst,
    output reg o_b_tick
);
    // 100Mhz -> 153,600 Hz (9600hz * 16)
    parameter F_COUNT = 100_000_000 / (BAUD_RATE * SAMPLING_RATE);
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
            counter_reg <= 0;
            o_b_tick    <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                o_b_tick    <= 1'b1;
            end else begin
                o_b_tick <= 1'b0;
            end
        end
    end

endmodule
