`timescale 1ns / 1ps

// 버튼 디바운서 (v2 포트 통일)
// i_clk_4khz 상승 엣지마다 i_btn 을 8 번 샘플 → 8 개 모두 1 이면 눌림 (약 2 ms)
// o_btn : 눌림이 확정된 순간 i_clk 1 클럭 펄스
module btn_debounce (
    input  i_clk,
    input  i_rst,
    input  i_clk_4khz,
    input  i_btn,
    output o_btn
);

    reg [7:0] q_reg;
    reg       debounce_reg;
    wire      debounce;

    // 8bit shift register SIPO
    always @(posedge i_clk_4khz, posedge i_rst) begin
        if (i_rst) q_reg <= 8'h00;
        else begin
            // msb : in  lsb : 7:1 -> q_reg[6:0]
            q_reg <= {i_btn, q_reg[7:1]};  // Right shift >>
        end
    end

    // 8-input AND GATE
    assign debounce = &q_reg;

    // edge detect
    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) debounce_reg <= 0;
        else       debounce_reg <= debounce;
    end

    // rising edge 에서 tick gen
    assign o_btn = ~debounce_reg & debounce;

endmodule
