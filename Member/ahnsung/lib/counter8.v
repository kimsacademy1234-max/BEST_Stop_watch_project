`timescale 1ns / 1ps


module counter8(

	input i_clk,
	input i_reset,
	output reg [2:0] o_sel

);

always@(posedge i_clk,posedge i_reset)begin

	if(i_reset)begin

		o_sel <= 0;
		
	end
	
	else begin
		o_sel <= o_sel +1;

		end
end


endmodule
