`timescale 1ns / 1ps


module BRAM_IP(

input [7:0] addr,
input i_clk, 
input we,
input [7:0] wdata,
output reg [7:0] rdata

);


reg [7:0] ram [0:255];

//조합 출력 

always@(posedge i_clk) begin


	if(we) ram[addr] <= wdata; // active high 에서 ram addr에 값을 넣는다.
	
	else rdata <= ram[addr];



end


// CL- OUTPUT
//assign rdata = ram[addr]; // 포트가 다르기 때문에 굳이 조합 연산을 안서도 된다.





endmodule
