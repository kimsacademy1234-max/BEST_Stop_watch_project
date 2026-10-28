`timescale 1ns / 1ps


module fifo#(

	parameter DEPTH = 4,
	parameter BIT_WIDTH = 8, 
	parameter ADDR_BIT_WIDTH = $clog2(DEPTH)
)(

input i_clk, 
input i_reset,
input push,pop,
input [BIT_WIDTH-1:0] push_data,

output [BIT_WIDTH-1:0] pop_data,
output full,
output empty


);



wire [ADDR_BIT_WIDTH-1:0] w_wptr,w_rptr;


control_unit#(

	.ADDR_BIT_WIDTH(ADDR_BIT_WIDTH)
)U_UART_CONTROL(


.i_clk(i_clk), 
.i_reset(i_reset), 
.push(push),
.pop(pop),
.wptr(w_wptr),
.rptr(w_rptr),
.full(full),
.empty(empty)


);



register_file#(
	.DEPTH(DEPTH),
	.BIT_WIDTH(BIT_WIDTH)
)U_REG_FILE(


.i_clk(i_clk),
.we(~full&push),
.wdata(push_data),
.waddr(w_wptr),
.raddr(w_rptr),
.rdata(pop_data)


);


endmodule



////////////////////////////////////////////////////////////////////////////////////////////////////
module control_unit #(

parameter ADDR_BIT_WIDTH = 2)(

input i_clk, 
input i_reset, 
input push,
input pop,
output [ADDR_BIT_WIDTH-1 :0 ]wptr,
output [ADDR_BIT_WIDTH-1 :0 ]rptr,
output full,
output empty


);


reg [ADDR_BIT_WIDTH-1:0] rptr_reg,rptr_next;
reg [ADDR_BIT_WIDTH-1:0] wptr_reg,wptr_next;

reg full_reg,full_next;
reg empty_reg,empty_next;

assign wptr = wptr_reg; 
assign rptr = rptr_reg;
assign full = full_reg;
assign empty = empty_reg;

always@(posedge i_clk or posedge i_reset)begin

	if(i_reset)begin
		full_reg <=1'b0;
		empty_reg <= 1'b1;
		wptr_reg <= 2'b0;
		rptr_reg <= 2'b0;

	end

	else begin
		wptr_reg <= wptr_next;
		rptr_reg <= rptr_next;
		full_reg <= full_next;
		empty_reg <= empty_next;
	
	end
end


always@(*)begin

	wptr_next =wptr_reg;
	rptr_next =rptr_reg;
	full_next =full_reg;
	empty_next = empty_reg;

	case({push,pop})

	2'b10 : begin 
			//full 아닐 때
			if(!full_reg)begin
				empty_next = 1'b0;
				wptr_next = wptr_reg + 1;
				if(wptr_next == rptr_reg)begin
					full_next = 1'b1;
				end
			end
			end

		
	2'b01: begin 
			//pop_only
			if(!empty_reg)begin
				full_next = 1'b0;
				rptr_next = rptr_reg + 1;
				if(rptr_next == wptr_reg)begin
					empty_next = 1'b1;
				end
			end
			end


	2'b11 : begin
			//push_pop
				if(full_reg)begin
					rptr_next = rptr_reg +1;
					full_next = 1'b0;
					
				end
				else if(empty_reg)begin
					wptr_next =wptr_reg + 1;
					empty_next = 1'b0;

				end
				else begin
					wptr_next = wptr_reg + 1;
					rptr_next = rptr_reg + 1;

				end
				
			end


	endcase
		

end






endmodule 









///////////////////////////////////////////////////////////////////////////////////////////////////////





module register_file#(

	parameter DEPTH = 4,
	parameter ADDR_BIT_WIDTH =$clog2(DEPTH),
	parameter BIT_WIDTH =8
)(

input i_clk,
input we,
input [BIT_WIDTH-1:0]wdata,
input [ADDR_BIT_WIDTH-1:0]waddr,
input [ADDR_BIT_WIDTH-1:0]raddr,
output [BIT_WIDTH-1:0] rdata

);


reg[7:0]register_file[0:DEPTH-1];


always@(posedge i_clk)begin

		if(we)begin

			register_file[waddr] <= wdata;

		end


end


assign rdata = register_file[raddr]; 



endmodule
