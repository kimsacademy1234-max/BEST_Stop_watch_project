`timescale 1ns / 1ps


module SW2_FSM_Change(

	input i_clk,
	input i_reset,
    input i_sw_2,
	input i_btnR,
	input i_btnL,
	output reg[1:0] o_sel

);



typedef enum{

AN0 =0,
AN1 =1,
AN2 =2,
IDLE =3
} state_t;

state_t state,n_state;

always@(posedge i_clk or posedge i_reset)begin

	if(i_reset)begin 
		state <= IDLE;

	end 

	else begin 

		state <= n_state;
	end	
end

always@(*)begin

	case(state)

   
	IDLE : begin
		   
           end

	AN0 : begin
		   if(i_btnR)begin n_state = AN2; end
		   else if(i_btnL)begin n_state = AN1; end
		   else begin n_state = AN0;end
		   o_sel = 2'b00;
		  end

	AN1 : begin
		   if(i_btnR)begin n_state = AN0; end
		   else if(i_btnL)begin n_state = AN2; end
		   else begin n_state = AN1;end

		   o_sel = 2'b01;
		   end
	AN2 : begin
		   if(i_btnR)begin n_state = AN1; end
		   else if(i_btnL)begin n_state = AN2; end
		   else begin n_state = AN2; end
		   o_sel = 2'b10;
		   end
									
	 endcase

end



endmodule
