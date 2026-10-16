`timescale 1ns / 1ps


//////////////////////////////////////////////////////////////
module clock_tick_generator
#( parameter CLK_FRQ =1000
)(
input i_clk,
input i_reset,
output reg o_clk

);

parameter FCOUNT = (100_000_000/CLK_FRQ); // 1khz
reg [$clog2(FCOUNT)-1 :0] r_counter;

always@(posedge i_clk or posedge i_reset)begin
	if(i_reset)begin
		r_counter <= 0;
		o_clk <= 0;
	end
	else begin
			r_counter <= r_counter + 1;
			if(r_counter == FCOUNT -1)begin
				r_counter <= 0;
				o_clk <= 1;
			end
			else begin
				o_clk <= 0;
			end
	end
				 

end


endmodule
