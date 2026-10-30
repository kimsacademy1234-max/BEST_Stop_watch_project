`timescale 1ns / 1ps
// sender_tx_top : 내 sender 를 숙제의 FIFO · uart_tx · baud_tick_gen 에 이어 붙인 시험용 Top.
//                 새로 짜는 로직은 없다 — 위 연결도의 선 (w_…) 을 선언하고 모듈 4 개를 끼우기만.
module sender_tx_top #(
    parameter TX_DEPTH = 64          // parameter = 밖에서 바꿀 수 있는 상수. TX FIFO 칸 수 (숙제 fifo 기본 4 → 64)
) (
    input         clk,
    input         rst,
    input         i_send_go,
    input  [2:0]  i_send_sel,
    input  [23:0] i_send_data,
    output        o_send_busy,
    output        tx                 // PC 로 가는 선 (9600 bps)
);
    // ① 모듈 사이 선 선언 — 모듈과 모듈 사이에만 있는 선 = wire.
    //    1 비트 5 개 : w_tx_push · w_tx_full · w_tx_empty · w_tx_busy · w_b_tick
    //    8 비트 2 개 : w_tx_push_data · w_tx_pop_data         모양 : wire [7:0] w_이름;
    wire w_tx_push, w_tx_full, w_tx_empty, w_tx_busy, w_b_tick;
    wire [7:0] w_tx_push_data, w_tx_pop_data;


    // ② U_SENDER (uart_sender) — 바깥 포트 i_send_* · o_send_busy 는 그대로, TX 쪽은 ① 의 선으로.
    uart_sender U_UART_SENDER (
        .clk           (clk),
        .rst           (rst),
        .i_send_go     (i_send_go),       // U_CONTROL : "보내 줘" 1 클럭 펄스
        .i_send_sel    (i_send_sel),      // 형식 번호
        .i_send_data   (i_send_data),     // 숫자 24 비트
        .i_tx_full     (w_tx_full),       // TX FIFO : 꽉 참 (1 이면 넣지 말 것)
        .o_send_busy   (o_send_busy),     // → U_CONTROL : 보내는 중
        .o_tx_push     (w_tx_push),       // → TX FIFO : 이 클럭에 글자 하나 넣음
        .o_tx_push_data(w_tx_push_data)   // → TX FIFO : 넣는 글자
    );


    // ③ U_FIFO_TX — #(.DEPTH(TX_DEPTH)) 로 숙제 fifo 의 칸 수 (기본 4) 를 64 로 바꿔 끼움.
    //    pop 은 uart_tx 가 안 바쁠 때 (~w_tx_busy) — 숙제 uart.v U_FIFO_TX 와 같은 연결.
    fifo #(
        .DEPTH(TX_DEPTH)
    ) U_FIFO_TX (
        .clk      (clk),
        .rst      (rst),
        .push     (w_tx_push),        // ← sender
        .pop      (~w_tx_busy),       // ← uart_tx 가 안 바쁘면 꺼냄
        .push_data(w_tx_push_data),   // ← sender 글자
        .pop_data (w_tx_pop_data),    // → uart_tx 로 보낼 글자
        .full     (w_tx_full),        // → sender (꽉 차면 기다림)
        .empty    (w_tx_empty)        // → uart_tx (비어 있으면 시작 안 함)
    );


    // ④ U_UART_TX (uart_tx, TS-44 고친 판) — FIFO 에 글자가 있으면 (~empty) 시작
    uart_tx U_UART_TX (
        .clk     (clk),
        .rst     (rst),
        .tx_start(~w_tx_empty),
        .tx_data (w_tx_pop_data),
        .b_tick  (w_b_tick),
        .tx      (tx),                // → PC
        .tx_busy (w_tx_busy)
    );


    // ⑤ U_BAUD_TICK_GEN (baud_tick_gen, 숙제 uart.v 안) — 9600 × 16 tick
    baud_tick_gen U_BAUD_TICK_GEN (
        .clk   (clk),
        .rst   (rst),
        .b_tick(w_b_tick)
    );

endmodule
