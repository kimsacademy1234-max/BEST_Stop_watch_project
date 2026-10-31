`timescale 1ns / 1ps
// uart_sender : send_go 를 받으면 그 순간의 sel · data 를 잡아 두고, 한 클럭에 한 글자씩 TX FIFO 에 넣는 FSM.
//               구성 : ① 레지스터 선언 ② 글자 MUX ③ 출력 assign ④ 레지스터 갱신 (seq) ⑤ 다음 값 계산 (comb, ASM 그대로).
// (merge) clk / rst → i_clk / i_rst (v2 포트 규칙)
module uart_sender (
    input i_clk,
    input i_rst,
    input i_send_go,  // U_CONTROL : "보내 줘" 1 클럭 펄스
    input [2:0] i_send_sel,  // 형식 번호
    input [23:0] i_send_data,  // 숫자 24 비트
    input i_tx_full,  // TX FIFO : 꽉 참 (1 이면 넣지 말 것)
    output o_send_busy,  // → U_CONTROL : 보내는 중
    output o_tx_push,  // → TX FIFO : 이 클럭에 글자 하나 넣음
    output [7:0] o_tx_push_data  // → TX FIFO : 넣는 글자
);
    // 상태 이름 — localparam = 이 모듈 안에서만 쓰는 이름 붙인 상수. 상태가 2 개라 1 비트면 됨.
    localparam IDLE = 1'b0, SEND = 1'b1;

    // ① 레지스터 선언 — c_ · n_ 짝 4 쌍 (c_ = 지금 FF 값, n_ = 다음 클럭에 넣을 값).
    //    모양 : reg [폭-1:0] c_이름, n_이름;      (1 비트면 [폭-1:0] 생략)
    //    c_state / n_state  1 비트 : IDLE · SEND
    //    c_sel   / n_sel    3 비트 : send_go 때 잡아 둔 형식 번호
    //    c_data  / n_data  24 비트 : send_go 때 잡아 둔 숫자 (보내는 동안 바깥 값이 바뀌어도 이 값으로)
    //    c_idx   / n_idx    4 비트 : 몇 번째 글자 (0 ~ 12 → 4 비트면 0 ~ 15 까지)
    //    + wire w_last_idx 4 비트 : 글자 MUX 가 알려 주는 마지막 칸 번호
    reg c_state, n_state;
    reg [2:0] c_sel, n_sel;
    reg [23:0] c_data, n_data;
    reg [3:0] c_idx, n_idx;
    wire [3:0] w_last_idx;

    // ② 글자 MUX 붙이기 (sender_char_mux 인스턴스) — 입력에는 바깥 i_ 가 아니라 "잡아 둔" c_ 를 넣는다.
    //    모양 : sender_char_mux U_CHAR_MUX ( .i_sel(?), .i_data(?), .i_idx(?), .o_char(?), .o_last_idx(?) );
    //    o_char 는 모듈 출력 o_tx_push_data 에 바로, o_last_idx 는 w_last_idx 에.
    //    예 : c_sel = 0 · c_data = 12:34:56.78 · c_idx = 0 → o_tx_push_data = 8'h31 ("1")
    sender_char_mux U_SENDER_CHAR_MUX (
        .i_sel(c_sel),
        .i_data(c_data),
        .i_idx(c_idx),
        .o_char(o_tx_push_data),
        .o_last_idx(w_last_idx)
    );

    // ③ 출력 두 줄 (assign) — 조건이 맞으면 1 이 되는 식.
    //    o_send_busy : 상태가 SEND 이면 1                      (상태만 보면 정해짐 → 무어 출력)
    //    o_tx_push   : 상태가 SEND 이고 그리고 i_tx_full 이 0 이면 1  (입력 full 에 따라 바뀜 → 밀리 출력)
    //    쓰는 연산 : == (같다) · && (그리고) · ! (아니다).   예 : SEND 인데 full = 1 → push 0 (그 클럭은 기다림)
    assign o_send_busy = (c_state == SEND);
    assign o_tx_push   = (c_state == SEND) && (i_tx_full == 0);


    // ④ 레지스터 갱신 (seq always) — 클럭 올라갈 때마다 c_ 에 n_ 을 넣는다. SR04 와 같은 모양.
    //    always @(posedge clk, posedge rst) begin
    //        if (rst) → c_state 는 IDLE, 나머지 c_ 는 0           (rst 는 감지 목록에 있어 클럭 없이도 바로 = 비동기)
    //        else     → c_state <= n_state; … 4 줄               (FF 에 넣는 곳이라 <= )
    //    end
    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
            c_state <= IDLE;
            c_sel   <= 0;
            c_data  <= 0;
            c_idx   <= 0;
        end else begin
            c_state <= n_state;
            c_sel   <= n_sel;
            c_data  <= n_data;
            c_idx   <= n_idx;
        end

    end


    // ⑤ 다음 값 계산 (comb always) — ASM 을 그대로 옮기는 곳. 블록 하나 = case 항목 하나, 마름모 하나 = if 하나.
    //    always @(*) begin
    //        맨 위 기본값 4 줄 : n_state = c_state;  n_sel = c_sel;  n_data = c_data;  n_idx = c_idx;
    //          (왜 : 아래에서 아무 일도 안 하는 경로 = "그대로" 가 되고, 래치 (Synth 8-327) 도 안 생김)
    //        case (c_state)
    //          IDLE : i_send_go 가 1 이면 → n_sel · n_data 에 바깥 값 잡기, n_idx 에 0, n_state 에 SEND   (ASM 주황 상자 4 개)
    //          SEND : i_tx_full 이 0 일 때만 (1 이면 아무것도 안 함 = 기다림)
    //                   c_idx == w_last_idx 이면 → n_state 에 IDLE   (방금 넣은 게 마지막 글자)
    //                   아니면                → n_idx 에 c_idx + 1  (다음 글자)
    //        endcase
    //    end
    //    always @(*) 안은 전부 = (blocking). <= 를 쓰지 않는다.
    always @(*) begin
        n_state = c_state;
        n_sel   = c_sel;
        n_data  = c_data;
        n_idx   = c_idx;
        case (c_state)
            IDLE: begin
                if (i_send_go) begin
                    n_sel   = i_send_sel;
                    n_data  = i_send_data;
                    n_idx   = 0;
                    n_state = SEND;
                end
            end
            SEND: begin
                if (~i_tx_full) begin
                    if (c_idx == w_last_idx) begin
                        n_state = IDLE;
                    end else begin
                        n_idx = c_idx + 1;
                    end
                end
            end
        endcase
    end
endmodule
