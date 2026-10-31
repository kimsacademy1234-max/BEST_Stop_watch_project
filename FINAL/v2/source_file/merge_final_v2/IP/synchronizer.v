`timescale 1ns / 1ps

// 2-FF synchronizer (외부 비동기 입력용)
// (merge) SR04 의 synchronizer 를 IP 로 옮기고 포트 이름만 v2 규칙 (i_ / o_)
//         SR04 echo, 버튼 레벨 등 외부 입력은 이 모듈 하나로 동기화
module synchronizer (
    input  i_clk,
    input  i_rst,
    input  i_d,
    output o_q
);

    (* ASYNC_REG = "TRUE" *) reg ff1, ff2;

    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
            ff1 <= 1'b0;
            ff2 <= 1'b0;
        end else begin
            ff1 <= i_d;
            ff2 <= ff1;
        end
    end

    assign o_q = ff2;

endmodule
