
module baud_tick_gen#(
         
        parameter SAMPLING_RATE = 16,
        parameter BAUD_RATE = 9600
        )(
    input      clk,
    input      rst,
    output reg b_tick
);
    // 100Mhz -> 153,600 Hz (9600hz * 16)
    parameter F_COUNT = 100_000_000 / (BAUD_RATE* SAMPLING_RATE);
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick      <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                b_tick      <= 1'b1;
            end else begin
                b_tick <= 1'b0;
            end
        end
    end

endmodule



