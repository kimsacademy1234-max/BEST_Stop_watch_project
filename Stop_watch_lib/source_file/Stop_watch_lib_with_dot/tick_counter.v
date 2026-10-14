
module tick_counter#(
	parameter COUNT = 60,
	parameter DATA_WIDTH = 6
)(
	input i_tick,
	input i_reset,
	input i_clk,
	input i_clear,
	input i_mode,
	output reg o_time_tic, 	
	output [DATA_WIDTH-1:0] o_time
);

reg[$clog2(COUNT)-1:0] r_counter_reg;

always@(posedge i_clk or posedge i_reset)begin
	if(i_reset|i_clear)begin
		r_counter_reg <= 0;
		o_time_tic <=0;
	end
	else begin

		if(i_mode)begin

			 if(i_tick)begin
				r_counter_reg <= r_counter_reg -1;
				
				if(r_counter_reg == 0)begin
					r_counter_reg <= COUNT -1;
					o_time_tic <= 1;
				end

			end
			else begin 
					o_time_tic <=0;
			end


		end

		else begin

			 if(i_tick)begin
				r_counter_reg <= r_counter_reg +1;
				
				if(r_counter_reg == COUNT -1)begin
					r_counter_reg <= 0;
					o_time_tic <= 1;
				end
			 end

			 else begin
					o_time_tic <= 0;
			
		      end
		end		

			
	end
end



assign o_time = r_counter_reg; 


endmodule




