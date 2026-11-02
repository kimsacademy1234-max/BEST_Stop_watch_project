`timescale 1ns / 1ps

module uart_fifo_ascii (
    input clk,
    input rst,
    input rx,
    output tx,
    //fnd
    output [3:0] fnd_com,
    output [7:0] fnd_font
);

    wire [7:0] w_rx_pop_data;  // PC 에서 받은 1 바이트
    wire       w_rx_empty;      // 이름은 empty 지만 값은 ~empty (그 바이트가 유효한 순간)
    wire [3:0] w_bin;  // ascii_decoder → fnd_controller (0 ~ f)
    wire w_rx_pop;

    uart_fifo_loopback U_UART_FIFO_LOOPBACK (
        .clk        (clk),
        .rst        (rst),
        .rx         (rx),             // from PC
        .tx         (tx),
        .fifo_rx_pop     (w_rx_pop),
        .rx_pop_data(w_rx_pop_data),
        .rx_empty   (w_rx_empty)
    );

    ascii_decoder U_ASCII_DECODER (
        .clk   (clk),
        .rst   (rst),
        .enable(w_rx_empty),
        .ascii (w_rx_pop_data),
        .pop(w_rx_pop),
        .bin   (w_bin)
    );

    fnd_controller U_FND_CNTL (
        .clk     (clk),
        .reset   (rst),
        .fnd_data(w_bin),
        .fnd_com (fnd_com),
        .fnd_font(fnd_font)
    );

endmodule
