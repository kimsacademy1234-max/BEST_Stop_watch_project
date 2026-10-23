`timescale 1ns / 1ps

module uart_fifo_loopback (
    input clk,
    input rst,
    input rx, // from PC
    output tx
	// 아스키


);

    wire w_b_tick, w_rx_done;
    wire [7:0] w_rx_data;
	wire [7:0] w_tx_data;


	wire w_rx_empty;

	wire w_tx_full;
	wire [7:0] w_tx_push_data;	

	wire w_tx_start;

	wire w_tx_busy;

    uart_rx U_UART_RX (
        .clk    (clk),
        .rst    (rst),
        .b_tick (w_b_tick),
        .rx     (rx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

fifo DUT_FIFO_RX(

.i_clk(clk), 
.i_reset(rst),
.push(w_rx_done),
.pop(~w_tx_full),
.push_data(w_rx_data),
.pop_data(w_tx_push_data),
.full(),
.empty(w_rx_empty)
);

    uart_tx U_UART_TX (
        .clk     (clk),
        .rst     (rst),
        .tx_start(~w_tx_start),
        .tx_data (w_tx_data),
        .b_tick  (w_b_tick),
        .tx      (tx),
        .tx_busy (w_tx_busy)
    );


fifo DUT_FIFO_TX(

.i_clk(clk), 
.i_reset(rst),
.push(~w_rx_empty),
.pop(~w_tx_busy),
.push_data(w_tx_push_data),
.pop_data(w_tx_data),
.full(w_tx_full),
.empty(w_tx_start)
);






    baud_tick_gen U_BAUD_TICK_GEN (
        .clk   (clk),
        .rst   (rst),
        .b_tick(w_b_tick)
    );






endmodule


module baud_tick_gen (
    input      clk,
    input      rst,
    output reg b_tick
);
    // 100Mhz -> 153,600 Hz (9600hz * 16)
    parameter F_COUNT = 100_000_000 / (9600 * 16);
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick      <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                b_tick      <= 1'b1;
            end else begin
                b_tick <= 1'b0;
            end
        end
    end
endmodule










