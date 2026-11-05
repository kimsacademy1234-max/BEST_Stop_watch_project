`timescale 1ns / 1ps


module register_8bit(


	
	
	input logic i_clk,
	input logic i_reset,
	input logic [7:0] d_in,
	output logic [7:0]  q



);



always_ff@(posedge i_clk , posedge i_reset)begin



	if(i_reset) q <= 0;
	else q  <= d_in; 

end


endmodule
