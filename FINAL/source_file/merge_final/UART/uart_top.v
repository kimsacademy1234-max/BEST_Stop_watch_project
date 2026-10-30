`timescale 1ns / 1ps
// UART 하위 Top (merge) — 그림의 U_UART_FIFO_LOOPBACK + U_ASCII_DECODER + U_CONTROL + U_ASCII_SENDER
//
//  RX : rx → uart_rx → FIFO_RX → UART_ASCII_DECODER → UART_CONTROLLER
//  TX : UART_CONTROLLER (go · sel · data) → uart_sender → FIFO_TX → uart_tx → tx
//  baud tick 은 RX · TX 가 같은 주기라 하나만 두고 같이 씀
//
//  - o_module_control_bit / o_uart_mode : Top 에서 스위치 대신 쓸 모드 값 (첫 /mod 받은 뒤부터)
//  - o_send_sel → Top 의 전송 데이터 MUX 선택, 고른 값이 i_send_data 로 돌아옴
//  - i_btn_* (물리 버튼) 이 먼저, /btn 으로 들어온 버튼은 o_uart_btn_* 로 물리 버튼이 끝난 뒤 나감
module uart_top #(
    parameter AUTO_FRQ   = 5,     // /auto 전송 주기 (Hz)
    parameter RX_DEPTH   = 8,
    parameter TX_DEPTH   = 64,
    parameter DATA_WIDTH = 40     // 디코더 → 컨트롤러 명령 문자열 폭 (5 글자)
) (
    input         i_clk,
    input         i_rst,
    input         i_rx,
    input         i_btn_R,        // 물리 버튼 (디바운서 출력 tick)
    input         i_btn_L,
    input         i_btn_U,
    input         i_btn_D,
    input  [23:0] i_send_data,    // o_send_sel 로 고른 전송 데이터
    output        o_tx,
    output [ 6:0] o_module_control_bit,
    output        o_uart_mode,
    output [ 2:0] o_send_sel,
    output        o_uart_btn_R,
    output        o_uart_btn_L,
    output        o_uart_btn_U,
    output        o_uart_btn_D
);

    // baud
    wire w_b_tick;
    // RX
    wire       w_rx_done;
    wire [7:0] w_rx_data;
    wire       w_rx_full, w_rx_empty;
    wire [7:0] w_rx_pop_data;
    wire       w_rx_pop;
    // decoder → controller
    wire                  w_error, w_handshake;
    wire                  w_get, w_btn, w_set, w_off_set, w_mode, w_auto;
    wire [DATA_WIDTH-1:0] w_ascii;
    // controller → sender
    wire        w_send_go;
    wire [23:0] w_send_data;
    wire        w_send_busy;
    // TX
    wire       w_tx_push, w_tx_full, w_tx_empty, w_tx_busy;
    wire [7:0] w_tx_push_data, w_tx_pop_data;


    baud_tick_gen #(
        .BAUD_RATE    (9600),
        .SAMPLING_RATE(16)
    ) U_BAUD_TICK_GEN (
        .i_clk   (i_clk),
        .i_rst   (i_rst),
        .o_b_tick(w_b_tick)
    );

    // ---------------------------------------------------------------- RX
    uart_rx U_UART_RX (
        .i_clk    (i_clk),
        .i_rst    (i_rst),
        .i_b_tick (w_b_tick),
        .i_rx     (i_rx),
        .o_rx_data(w_rx_data),
        .o_rx_done(w_rx_done)
    );

    fifo #(
        .DEPTH    (RX_DEPTH),
        .BIT_WIDTH(8)
    ) U_FIFO_RX (
        .i_clk      (i_clk),
        .i_rst      (i_rst),
        .i_push     (w_rx_done),
        .i_pop      (w_rx_pop),
        .i_push_data(w_rx_data),
        .o_pop_data (w_rx_pop_data),
        .o_full     (w_rx_full),
        .o_empty    (w_rx_empty)
    );

    UART_ASCII_DECODER #(
        .BIT_WIDTH (8),
        .DATA_WIDTH(DATA_WIDTH)
    ) U_ASCII_DECODER (
        .i_clk      (i_clk),
        .i_rst      (i_rst),
        .i_ascii    (w_rx_pop_data),
        .i_enable   (~w_rx_empty),
        .o_error    (w_error),
        .o_pop      (w_rx_pop),
        .o_handshake(w_handshake),
        .o_get      (w_get),
        .o_btn      (w_btn),
        .o_set      (w_set),
        .o_off_set  (w_off_set),
        .o_mode     (w_mode),
        .o_auto     (w_auto),
        .o_ascii    (w_ascii)
    );

    // ---------------------------------------------------------------- CONTROL
    UART_CONTROLLER #(
        .BIT_WIDTH (8),
        .DATA_WIDTH(DATA_WIDTH),
        .AUTO_FRQ  (AUTO_FRQ)
    ) U_CONTROL (
        .i_error             (w_error),
        .i_for_sender_data   (i_send_data),
        .i_handshake         (w_handshake),
        .i_sender_busy       (w_send_busy),
        .i_clk               (i_clk),
        .i_rst               (i_rst),
        .i_con_ascii         (w_ascii),
        .i_get               (w_get),
        .i_btn               (w_btn),
        .i_mode              (w_mode),
        .i_auto              (w_auto),
        .i_btn_R             (i_btn_R),
        .i_btn_L             (i_btn_L),
        .i_btn_U             (i_btn_U),
        .i_btn_D             (i_btn_D),
        .i_off_set           (w_off_set),
        .i_set               (w_set),
        .o_module_control_bit(o_module_control_bit),
        .o_uart_mode         (o_uart_mode),
        .o_send_sel          (o_send_sel),
        .o_sender_data       (w_send_data),
        .o_sender_go         (w_send_go),
        .o_uart_R            (o_uart_btn_R),
        .o_uart_L            (o_uart_btn_L),
        .o_uart_U            (o_uart_btn_U),
        .o_uart_D            (o_uart_btn_D)
    );

    // ---------------------------------------------------------------- TX
    uart_sender U_ASCII_SENDER (
        .i_clk         (i_clk),
        .i_rst         (i_rst),
        .i_send_go     (w_send_go),
        .i_send_sel    (o_send_sel),
        .i_send_data   (w_send_data),
        .i_tx_full     (w_tx_full),
        .o_send_busy   (w_send_busy),
        .o_tx_push     (w_tx_push),
        .o_tx_push_data(w_tx_push_data)
    );

    fifo #(
        .DEPTH    (TX_DEPTH),
        .BIT_WIDTH(8)
    ) U_FIFO_TX (
        .i_clk      (i_clk),
        .i_rst      (i_rst),
        .i_push     (w_tx_push),
        .i_pop      (~w_tx_busy),       // uart_tx 가 안 바쁘면 꺼냄
        .i_push_data(w_tx_push_data),
        .o_pop_data (w_tx_pop_data),
        .o_full     (w_tx_full),
        .o_empty    (w_tx_empty)
    );

    uart_tx U_UART_TX (
        .i_clk     (i_clk),
        .i_rst     (i_rst),
        .i_tx_start(~w_tx_empty),
        .i_tx_data (w_tx_pop_data),
        .i_b_tick  (w_b_tick),
        .o_tx      (o_tx),
        .o_tx_busy (w_tx_busy)
    );

endmodule
