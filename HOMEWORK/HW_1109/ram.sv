`timescale 1ns / 1ps


module ram(
input logic [5:0] addr,
input logic clk, 
input logic we,
input logic [7:0] wdata,
output logic [7:0] rdata
);


logic [7:0] ram [0:63];

//조합 출력 

always_ff@(posedge clk) begin


	if(we) ram[addr] <= wdata; // active high 에서 ram addr에 값을 넣는다.


	// 순차 출력

	//else rdata <= ram[addr];


end


// 조합 출력 

assign rdata = ram[addr] ; // 포트가 다르기 때문에 굳이 조합 연산을 안서도 된다.





endmodule


