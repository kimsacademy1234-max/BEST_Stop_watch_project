`timescale 1ns / 1ps
// [FAULT-INJ F4] 리셋 라인 글리치 주입기 — 현업 상황: 모터 · 정전기 · 긴 배선의 EMI 가 비동기 리셋 핀에 수 ns 펄스
//   sw_fault 의 상승 엣지(2FF 동기화)에서 내부 리셋에 1 클럭(10 ns) 펄스를 OR 한다
//   sw_fault 를 안 올리면 o_rst = i_rst (원본과 같음). LED 는 건드리지 않음 (사람이 btnC 를 누른 것과 구분 안 되게)
module fault_rst_glitch (
    input  clk,
    input  i_rst,
    input  sw_fault,
    output o_rst
);
    reg [2:0] sync;
    reg       pulse;

    always @(posedge clk, posedge i_rst) begin
        if (i_rst) begin
            sync  <= 3'b000;
            pulse <= 1'b0;
        end else begin
            sync  <= {sync[1:0], sw_fault};
            pulse <= sync[1] & ~sync[2];   // 상승 엣지 1 클럭
        end
    end

    assign o_rst = i_rst | pulse;
endmodule
