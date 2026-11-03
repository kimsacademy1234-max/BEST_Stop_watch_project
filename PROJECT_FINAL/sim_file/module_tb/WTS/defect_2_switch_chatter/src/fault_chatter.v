`timescale 1ns / 1ps
// [FAULT-INJ F2] 스위치 채터링 / 노이즈 주입기 (버튼 4 개 앞) — 현업 상황: EMI 스파이크 · 낡은 스위치 접촉 불량
//   i_fault_sw15 = 1 일 때
//     안 누름 : 7 ms 마다 1 개씩 결정적 스파이크 (폭 1 us · 50 us · 500 us · 1.5 ms 순환) 를 OR
//     누르는 중: 20 ms 마다 300 us 동안 0 으로 끊음 (AND)
//   i_fault_sw15 = 0 이면 i_btn 그대로 (원본과 비트 단위로 같음)
//   i_btn / o_btn 비트 순서 = {D, U, L, R}
module fault_chatter (
    input        i_clk,
    input        i_rst,
    input        i_fault_sw15,
    input  [3:0] i_btn,
    output [3:0] o_btn
);
    localparam integer SPIKE_PERIOD = 700_000;    // 7 ms
    localparam integer DROP_PERIOD  = 2_000_000;  // 20 ms
    localparam integer DROP_WIDTH   = 30_000;     // 300 us

    reg [19:0] cnt_spike;
    reg [1:0]  spike_idx;
    reg [20:0] cnt_drop;
    reg [17:0] spike_w;

    always @(*) begin
        case (spike_idx)
            2'd0: spike_w = 18'd100;        // 1 us
            2'd1: spike_w = 18'd5_000;      // 50 us
            2'd2: spike_w = 18'd50_000;     // 500 us
            default: spike_w = 18'd150_000; // 1.5 ms (< 1.75 ms → 디바운서가 걸러야 함)
        endcase
    end

    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
            cnt_spike <= 0;
            spike_idx <= 0;
            cnt_drop  <= 0;
        end else begin
            if (cnt_spike == SPIKE_PERIOD - 1) begin
                cnt_spike <= 0;
                spike_idx <= spike_idx + 2'd1;
            end else begin
                cnt_spike <= cnt_spike + 1;
            end
            if (cnt_drop == DROP_PERIOD - 1) cnt_drop <= 0;
            else cnt_drop <= cnt_drop + 1;
        end
    end

    wire spike = (cnt_spike < spike_w);
    wire drop  = (cnt_drop < DROP_WIDTH);

    assign o_btn = i_fault_sw15 ? ((i_btn & {4{~drop}}) | (~i_btn & {4{spike}})) : i_btn;
endmodule
