
`timescale 1ns / 1ps

module tb_lap_controller ();

    reg clk, rst, clear, btn_lap;
    reg [6:0] msec;
    reg [5:0] sec, min;
    reg  [4:0] hour;

    wire [6:0] disp_msec;
    wire [5:0] disp_sec, disp_min;
    wire [4:0] disp_hour;
    wire lap_active;

    lap_controller dut (
        .clk(clk),
        .rst(rst),
        .clear(clear),
        .btn_lap(btn_lap),
        .msec(msec),
        .sec(sec),
        .min(min),
        .hour(hour),
        .disp_msec(disp_msec),
        .disp_sec(disp_sec),
        .disp_min(disp_min),
        .disp_hour(disp_hour),
        .lap_active(lap_active)
    );

    always #5 clk = ~clk;


    initial begin
        clk = 0;
        rst = 1;
        clear = 0;
        btn_lap = 0;
        msec = 0;
        sec = 0;
        min = 0;
        hour = 0;

        #20 rst = 0;

        // Normal Count
        repeat (5) begin
            #10 sec = sec + 1;
        end

        // LAP ON
        #10 btn_lap = 1;
        #10 btn_lap = 0;

        // Time Count
        repeat (2) begin
            #10 sec = sec + 1;
        end

        // LAP OFF
        #10 btn_lap = 1;
        #10 btn_lap = 0;

        // CLEAR
        #10 clear = 1;
        #10 clear = 0;

        #100 $finish;
    end

endmodule
