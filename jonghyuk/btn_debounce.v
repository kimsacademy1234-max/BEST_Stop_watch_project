`timescale 1ns / 1ps

module btn_debounce (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);

    parameter F_COUNT = 100_000;

    reg [$clog2(F_COUNT)-1:0] counter_reg;
    reg [7:0] q_reg;
    reg debounce_reg;
    reg edge_reg;

    reg btn_meta;
    reg btn_sync;

    // 버튼 입력 동기화
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            btn_meta <= 0;
            btn_sync <= 0;
        end else begin
            btn_meta <= i_btn;
            btn_sync <= btn_meta;
        end
    end

    // 1ms 간격 샘플링
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            q_reg <= 0;
            debounce_reg <= 0;
        end else begin
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                q_reg <= {btn_sync, q_reg[7:1]};

                if (&{btn_sync, q_reg[7:1]})
                    debounce_reg <= 1'b1;
                else if (~|{btn_sync, q_reg[7:1]})
                    debounce_reg <= 1'b0;

            end else begin
                counter_reg <= counter_reg + 1;
            end
        end
    end

    // 상승 에지 검출
    always @(posedge clk or posedge reset) begin
        if (reset)
            edge_reg <= 0;
        else
            edge_reg <= debounce_reg;
    end

    assign o_btn = debounce_reg & ~edge_reg;

endmodule