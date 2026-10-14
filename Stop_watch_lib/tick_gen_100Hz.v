`timescale 1ns / 1ps


module tick_gen_100Hz(
input i_clk,
input i_reset,
input i_run_stop,
input i_clear,
output reg o_tic
);

parameter FCOUNT = 100_000_0; // 100MHz -> 10Hz tick
reg [$clog2(FCOUNT)-1 :0] r_counter;

always@(posedge i_clk or posedge i_reset)begin
	if(i_reset|i_clear)begin
		r_counter <= 0;
		o_tic <= 0;
	end
	else begin

		if(i_run_stop)begin
			r_counter <= r_counter + 1;

			if(r_counter == FCOUNT -1)begin
				r_counter <= 0;
				o_tic <= 1;
			end
			else begin
				o_tic <= 0;
			end
		end
		
		else begin
				o_tic <= 0;
				 
		end


	end
end



endmodule
