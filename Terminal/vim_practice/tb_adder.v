module tb_adder;
    reg  [3:0] a, b;
    wire [4:0] sum;

    adder dut (.a(a), .b(b), .sum(sum));

    initial begin
        a = 4'd1; b = 4'd2; #10;
        a = 4'd3; b = 4'd4; #10;
        a = 4'd5; b = 4'd6; #10;
        a = 4'd7; b = 4'd8; #10;
        $finish;
    end
endmodule
