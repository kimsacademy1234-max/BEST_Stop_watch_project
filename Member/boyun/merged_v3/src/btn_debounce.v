`timescale 1ns / 1ps


module btn_debounce(


input clk_remake,
input clk,
input reset,
input i_btn,
output o_btn


);



reg [7:0] q_reg;

reg debounce_reg;

wire debounce;





// 8bit shift register SIPO

always@(posedge clk_remake,posedge reset)begin

	if(reset) q_reg <= 8'h00;

	else begin

		// msb : in  lsb : 7:1 -> q_reg[6:0]
		q_reg <= {i_btn,q_reg[7:1]};  // Right shift >>  


	end

	//8- input AndGATE 

end

assign debounce = &q_reg; 



//edge detect 

always@(posedge clk,posedge reset)begin

	if(reset) debounce_reg <= 0;
	
	else begin

		debounce_reg <= debounce;

	end 

end



// rising edge 에서 tick gen 
assign o_btn = ~debounce_reg&debounce;




endmodule


























