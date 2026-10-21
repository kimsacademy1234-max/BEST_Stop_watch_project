`timescale 1ns / 1ps


module register_8(


input i_clk,i_reset,
input [7:0] din,
output [7:0] q

);




reg [7:0] q_reg;


always@(posedge i_clk or posedge i_reset)begin


if(i_reset)begin

	q_reg <= 0;
	

end

else begin

	q_reg<= din;


end
end


assign q = q_reg;





endmodule
