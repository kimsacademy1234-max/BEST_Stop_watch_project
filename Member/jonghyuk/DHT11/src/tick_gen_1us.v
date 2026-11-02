`timescale 1ns / 1ps

module tick_gen_1us #(
    parameter F_COUNT = 100
) (
    input  clk,
    input  rst,
    input  i_enable,
    input  i_clear,
    output o_tick
);

    reg [$clog2(F_COUNT)-1:0] r_cnt;
    reg r_tick;

    assign o_tick = r_tick;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            r_cnt  <= 0;
            r_tick <= 0;
        end else if (i_clear) begin
            r_cnt  <= 0;
            r_tick <= 0;
        end else begin
            if (i_enable) begin
                if (r_cnt == F_COUNT - 1) begin
                    r_cnt  <= 0;
                    r_tick <= 1;
                end else begin
                    r_cnt  <= r_cnt + 1;
                    r_tick <= 0;
                end
            end else begin
                r_tick<=1'b0;
            end

        end
    end


endmodule
