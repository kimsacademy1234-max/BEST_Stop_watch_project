`timescale 1ns / 1ps

module tb_uart ();

    parameter BAUD_BIT_PERIOD = 100_000_000 / 9600 * 10;

    reg clk, rst, rx;
    reg [7:0] result_data, expected_data;
    wire tx;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;
    integer i;
    integer pass_count, fail_count;

    uart_fifo_ascii dut (
        .clk     (clk),
        .rst     (rst),
        .rx      (rx),       // from PC
        .tx      (tx),       // to PC
        .fnd_com (fnd_com),
        .fnd_font(fnd_font)
    );

    always #5 clk = ~clk;

    task sender_uart(input [7:0] send_data);
        integer i;
        begin
            rx = 0;  // start bit
            #(BAUD_BIT_PERIOD);
            for (i = 0; i < 8; i = i + 1) begin
                rx = send_data[i];
                #(BAUD_BIT_PERIOD);
            end
            rx = 1;  // stop bit
            #(BAUD_BIT_PERIOD);
        end
    endtask

    task receive_uart(output [7:0] rx_data);
        integer i;
        begin
            wait (~tx);
            #(BAUD_BIT_PERIOD / 2);
            if (tx != 0) begin
                $display("error start bit error");
            end
            for (i = 0; i < 8; i = i + 1) begin
                #(BAUD_BIT_PERIOD);
                rx_data[i] = tx;
            end
            #(BAUD_BIT_PERIOD);
            if (!tx) $display("error stop bit");
        end
    endtask

    task score_board(input [7:0] result, input [7:0] expected);
        begin
            if (result == expected) begin
                pass_count = pass_count + 1;
                $display("%t : pass!!!", $time);
            end
            else begin
                fail_count = fail_count + 1;
                $display("%t : fail!!!", $time);
            end
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        rx  = 1;
        i = 0;
        pass_count = 0;
        fail_count = 0;

        #10 rst = 0;

        sender_uart("1");   // '1' = 8'h31
                sender_uart("2");   // '2' = 8'h32
        sender_uart("3");   // '3' = 8'h33
        sender_uart("4");   // '4' = 8'h34
        sender_uart("5");   // '5' = 8'h35

        #1000;

        $stop;
    end

endmodule