`timescale 1ns / 1ps

module btn_debounce (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);
    reg [7:0] q_reg;
    wire debounce;  //debounced
    reg edge_reg;

    // clk div : 100mhz -> 1mhz
    parameter F_COUNT = 50_000; // 100_000_000(100MHz) / 2_000(2kHz) = 50_000 (10/15 bounce test, 8 samples = 4 ms)
    reg [$clog2(F_COUNT)-1:0] counter_reg;
    reg clk_1mhz;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            clk_1mhz <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (F_COUNT - 1)) begin
                counter_reg <= 0;
                clk_1mhz <= 1'b1;
            end else begin
                clk_1mhz <= 1'b0;   // 이전에 실습했던 거는 1:1 high, low였는데, 이건 1 tick만 1
            end
        end
    end

    // 8bit shift register: SIPO
    always @(posedge clk_1mhz, posedge reset) begin
        if (reset) begin
            q_reg <= 8'h0;
        end else begin
            q_reg <= {
                i_btn, q_reg[7:1]
            };  // right shift. (쉬프트 연산자 써도 됨.), msb : in, 7:1 -> 6:0
        end
    end

    // 8-input AND gate
    assign debounce = &q_reg;


    // edge detection
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            edge_reg <= 1'b0;
        end else begin
            edge_reg <= debounce;
        end
    end

    //rising edge, tick gen
    assign o_btn = ~edge_reg & debounce;


endmodule
