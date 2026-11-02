`timescale 1ns / 1ps

module tb_uart ();

    parameter BAUD_BIT_PERIOD = 100_000_000 / 9600 * 10;

    reg clk, rst, rx;
    reg [7:0] result_data, expected_data;
    wire tx;

    uart_loopback dut (
        .clk(clk),
        .rst(rst),
        .rx (rx),
        .tx (tx)
    );

    always #5 clk = ~clk;

    task sender_uart(input [7:0] send_data);
        integer i;
        begin
            rx = 0;  // start bit
            #(BAUD_BIT_PERIOD);
            // check start bit 0
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
            // check start bit 0. 중간 지점에서 start bit가 아직 0인지 확인.
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


    initial begin
        clk  = 0;
        rst  = 1;
        rx = 1;
        expected_data = 8'h30;

        #10 rst = 0;

        sender_uart(expected_data);
        receive_uart(result_data);

        #100;
        // to compare result data with expected data 
        if (result_data == expected_data) $display("pass!!!");
        else $display("fail!!!");
        $stop;
    end
endmodule
