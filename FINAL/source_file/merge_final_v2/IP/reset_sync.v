`timescale 1ns / 1ps

// 리셋 동기화 : 누르면 바로 리셋 (비동기), 뗄 때는 클럭에 맞춰 풀림 (동기). INIT 으로 전원 켤 때도 리셋.
// (merge) DHT11 의 reset_sync 를 IP 로 옮겨 Top 에서 한 번만 사용 (모든 모듈이 같은 o_rst 를 씀)
//         포트 이름만 v2 규칙 : clk → i_clk, reset_button → i_rst_btn, rst → o_rst
module reset_sync (
    input  wire i_clk,
    input  wire i_rst_btn,
    output wire o_rst
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] reset_pipe = 2'b11;
    always @(posedge i_clk or posedge i_rst_btn)
        if (i_rst_btn) reset_pipe <= 2'b11;
        else reset_pipe <= {reset_pipe[0], 1'b0};
    assign o_rst = reset_pipe[1];
endmodule
