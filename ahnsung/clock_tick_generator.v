`timescale 1ns / 1ps

/*

모듈 명 : clock_tick_generator 
instanciation 시 사용 방법.

clock_tick_generator#(
	.CLK_FRQ(사용하고자 하는 clk frequeny 를 'Hz' 단위로 입력) 
)U_CLK_GEN_''(

.i_clk(),
.i_reset(),
.o_clk() 

);






*/
//////////////////////////////////////////////////////////////
module clock_tick_generator
#( parameter CLK_FRQ =2000 // Hz 단위로 입력하면 됨.
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
