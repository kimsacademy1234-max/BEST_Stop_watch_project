`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/28 03:12:42
// Design Name: 
// Module Name: ascii_sender
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ascii_sender (
    input        clk,
    input        rst,
    input        i_key_status,    // 디코더 's' 펄스
    input        i_tx_full,       // FIFO_TX 꽉 참
    output [7:0] o_tx_push_data,  // 보낼 바이트
    output       o_tx_push        // 1 클럭 = 한 바이트 넣기
);

    localparam IDLE = 1'b0, SEND = 1'b1;
    reg r_state, state_next;
    reg r_idx, idx_next;  // 2 바이트면 0 · 1 → 1 비트

    // ① 출력 (assign 2 줄)
    //    o_tx_push_data : r_idx 가 0 이면 첫 바이트, 1 이면 둘째 바이트 (조건 연산자 ? :)
    assign o_tx_push_data = (r_idx == 1'b0) ? "O" : "K";
    //    o_tx_push      : SEND 상태이고 full 이 아닐 때 1
    assign o_tx_push = (r_state == SEND) && ~i_tx_full;

    // ② 순차 always : rst 이면 IDLE · 0, 아니면 r_xxx <= xxx_next
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            r_state <= IDLE;
            r_idx   <= 1'b0;
        end else begin
            r_state <= state_next;
            r_idx   <= idx_next;
        end
    end

    // ③ 조합 always : 맨 위에서 state_next = r_state; idx_next = r_idx;  → case (r_state) 로 위 표
    always @(*) begin
        state_next = r_state;
        idx_next   = r_idx;
        case (r_state)
            IDLE: begin
                // i_key_status 가 1 이면 → idx_next = 0, state_next = SEND
                if (i_key_status) begin
                    idx_next   = 0;
                    state_next = SEND;
                end

            end
            SEND: begin
                // i_tx_full 이 0 이면 (이번 클럭에 push 됨) :
                if (!i_tx_full) begin
                    //     r_idx 가 마지막 (1) 이면 state_next = IDLE
                    if (r_idx) begin
                        state_next = IDLE;
                        //     아니면 idx_next = r_idx + 1
                    end else begin
                        idx_next = r_idx + 1;
                    end
                    // i_tx_full 이 1 이면 아무것도 안 함 (기다림)
                end
            end
            default: state_next = IDLE;
        endcase
    end

endmodule
