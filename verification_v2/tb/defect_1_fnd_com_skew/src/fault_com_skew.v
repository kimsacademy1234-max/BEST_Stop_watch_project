`timescale 1ns / 1ps
// [FAULT-INJ F1] FND 자리선택(com) 위상 지연 주입기 — 현업 상황: 애노드 구동 트랜지스터 turn-off 지연 / 배선 스큐
//   i_fnd_com 이 바뀌면 N 클럭 동안 이전 com 을 유지한 뒤 바꾼다 (font 는 바로 바뀜 → 이전 자리에 다음 숫자가 잠깐 켜짐 = 고스팅)
//   i_fault_sw15 = 0 이면 i_fnd_com 을 그대로 통과 (원본과 비트 단위로 같음)
module fault_com_skew #(
    parameter N = 12500           // 12,500 clk = 125 us = 슬롯(250 us)의 1/2 → 보드에서 눈에 보이게 과장
) (
    input        i_clk,
    input        i_rst,
    input        i_fault_sw15,
    input  [3:0] i_fnd_com,
    output [3:0] o_fnd_com
);
    reg [3:0]  com_d;
    reg [15:0] cnt;

    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
            com_d <= 4'b1110;
            cnt   <= 16'd0;
        end else if (i_fnd_com != com_d) begin
            if (cnt >= N - 1) begin
                com_d <= i_fnd_com;
                cnt   <= 16'd0;
            end else begin
                cnt <= cnt + 16'd1;
            end
        end else begin
            cnt <= 16'd0;
        end
    end

    assign o_fnd_com = (i_fault_sw15 && N > 0) ? com_d : i_fnd_com;
endmodule
