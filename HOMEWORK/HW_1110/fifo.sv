`timescale 1ns / 1ps


module fifo(


input logic clk,
input logic rst,
input logic [7:0] push_data,
input logic push,
input logic pop,
output logic [7:0] pop_data,
output logic  full,
output logic  empty



);



logic [1:0] w_wptr,w_rptr;

register_file U_REG(

 .*,
 .waddr		(w_wptr),
 .raddr		(w_rptr),
 .we		(!full&push)
 //.clk		(clk),
// .push_data	(push_data),
// .pop_data	(pop_data)

);



control_unit U_CON(

.*,
.wptr	(w_wptr),
.rptr	(w_rptr)
//.clk	(clk ),
//.rst	(rst ),
//.push	(push),
//.pop	(pop ),
//.full	(full),
//.empty	(empty)
);



endmodule





module register_file(

input logic clk,
input [1:0] waddr,
input [1:0] raddr,
input logic [7:0] push_data,
input logic we,
output logic [7:0] pop_data

);



logic [7:0] ram [0:3];


always_ff@(posedge clk)begin


		if(we)begin
			ram[waddr] <= push_data;
		end

end

assign pop_data = ram[raddr];


endmodule 



module control_unit(

input logic clk,
input logic rst,
input logic push,
input logic pop,
output logic [1:0] wptr,
output logic [1:0] rptr,
output logic full,
output logic empty


);


logic [1:0] n_wptr, n_rptr;
logic n_full,n_empty; 


always_ff@(posedge clk, posedge rst)begin

if(rst)begin
	wptr <=  2'b00;
	rptr <=  2'b00;
	full <=  0;
	empty <= 1;
end


else begin

	wptr  <= n_wptr;  
	rptr  <= n_rptr;  
	full  <= n_full; 
	empty <= n_empty;

end


end

always_comb begin
	n_wptr  = wptr ;   
	n_rptr  = rptr ;  
	n_full  = full ;  
	n_empty = empty; 

	case({push,pop})

	2'b10 : begin
			
				if(!full)begin
					n_wptr = wptr + 1;
					n_empty = 0;
					if(n_wptr == rptr) begin
						n_full = 1;
					end
				end
			end
	
	2'b01 : begin
				if(!empty)begin
					n_rptr = rptr + 1;
					n_full = 0;	
					if(n_rptr == wptr) begin
						n_empty = 1;
					end
				end
			end
	
	2'b11 : begin
				if(full)begin
					n_rptr = rptr +1;
					n_full = 0; 
				end

				else if(empty)begin
					n_wptr = wptr +1;
					n_empty = 0; 
				end
				
				else begin	
					n_wptr = wptr +1;
					n_rptr = rptr +1;

				end
		

			end

	endcase 

end


endmodule


