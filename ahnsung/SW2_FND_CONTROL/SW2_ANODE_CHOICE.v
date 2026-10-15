`timescale 1ns / 1ps


module anode_choice(

	input i_sw_0,
	input i_sw_2,
	input [1:0]i_sel,
	input i_dot, 
	input [3:0] i_ds1,
	input [3:0] i_ds2,
	input [3:0] i_ds3,
	input [3:0] i_ds4,

	output [3:0] o_ds1,
	output [3:0] o_ds2,
	output [3:0] o_ds3,
	output [3:0] o_ds4

);





reg[15:0] r_ds;

always@(*)begin

	if((i_sw_0==1'b0)&&(i_sw_2==1'b1))begin
/*
idot ->


*/ 
		if(!i_dot)begin // 점이 켜졋을때 
			r_ds = {i_ds1,i_ds2,i_ds3,i_ds4};
		end

		else begin // 점이 꺼졌을때 
			case(i_sel)
			2'b00 : r_ds = {4'hd,i_ds2,i_ds3,i_ds4};
			2'b01 : r_ds = {i_ds1,4'hd,i_ds3,i_ds4};
			2'b10 : r_ds = {i_ds1,i_ds2,4'hd,i_ds4};
			2'b11 : r_ds = {i_ds1,i_ds2,i_ds3,4'hd};
			endcase
		end
	end

	else begin
			r_ds = {i_ds1,i_ds2,i_ds3,i_ds4};
	end


end

assign o_ds1 = r_ds[15:12];
assign o_ds2 = r_ds[11:8];
assign o_ds3 = r_ds[7:4];
assign o_ds4 = r_ds[3:0];




endmodule
