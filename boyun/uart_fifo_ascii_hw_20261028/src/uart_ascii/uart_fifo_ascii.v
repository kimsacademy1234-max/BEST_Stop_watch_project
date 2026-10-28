`timescale 1ns / 1ps

module uart_fifo_ascii (
    input clk,
    input rst,
    input rx,
    output tx,
    //fnd
    output [3:0] fnd_com,
    output [7:0] fnd_font,

    input         btn_R,
    input         btn_L,
    input         btn_U,
    input         btn_D,
    input         mode_sw0,
    input         display_mode_sw1,
    input         set_sw2,
    input         hour24_sw3,
    input         timer_sw4,

    output [15:0] led

);

    wire [7:0] w_rx_pop_data;  // PC 에서 받은 1 바이트
    wire       w_rx_empty;      // 이름은 empty 지만 값은 ~empty (그 바이트가 유효한 순간)
    wire w_rx_pop;
    
    wire w_key_run_stop, w_key_clear, w_key_mode, w_key_status;
    
    // fifo_tx - ascii sender
    wire [7:0] w_tx_push_data;
    wire w_tx_push;
    wire w_tx_full;

    uart_fifo_loopback U_UART_FIFO_LOOPBACK (
        .clk           (clk),
        .rst           (rst),
        .i_rx          (rx),             // from PC
        .o_tx          (tx),
        .i_rx_pop      (w_rx_pop),
        .i_tx_push     (w_tx_push),
        .i_tx_push_data(w_tx_push_data),
        .o_tx_full     (w_tx_full),
        .o_rx_pop_data (w_rx_pop_data),
        .o_rx_empty    (w_rx_empty)
    );

    ascii_decoder U_ASCII_DECODER (
        .clk          (clk),
        .rst          (rst),
        .i_enable   (w_rx_empty),
        .i_ascii(w_rx_pop_data),
        .o_pop     (w_rx_pop),
        .o_key_run_stop(w_key_run_stop),
        .o_key_clear(w_key_clear),
        .o_key_mode(w_key_mode),
        .o_key_status(w_key_status)
    );

    ascii_sender U_ASCII_SENDER(
    .clk(clk),
    .rst(rst),
    .i_key_status(w_key_status),    // 디코더 's' 펄스
    .i_tx_full(w_tx_full),       // FIFO_TX 꽉 참
    .o_tx_push_data(w_tx_push_data),  // 보낼 바이트
    .o_tx_push(w_tx_push)        // 1 클럭 = 한 바이트 넣기
);

    stopwatch_watch U_STOPWATCH_WATCH (
    .clk(clk),
    .rst(rst),
    .btn_R(btn_R),
    .btn_L(btn_L),
    .btn_U(btn_U),
    .btn_D(btn_D),
    .mode_sw0(mode_sw0),
    .display_mode_sw1(display_mode_sw1),
    .set_sw2(set_sw2),
    .hour24_sw3(hour24_sw3),
    .timer_sw4(timer_sw4),
    .i_key_run_stop(w_key_run_stop),
    .i_key_clear(w_key_clear),
    .i_key_mode(w_key_mode),
    .fnd_com(fnd_com),
    .fnd_font(fnd_font),
    .led(led)
);

endmodule
