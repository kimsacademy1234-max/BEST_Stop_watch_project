`timescale 1ns / 1ps


module dot(

	input [6:0] i_msec,
	output o_dot_onoff


);
// true : 1-off ,  False : 0 - on
assign o_dot_onoff = (i_msec >=50) ? 1:0; 






endmodule
