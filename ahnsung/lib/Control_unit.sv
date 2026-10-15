`timescale 1ns / 1ps




module Control_unit(

    input i_clk,
    input i_reset,
    input i_btn_L, // clear 
	input i_btn_R, // run_stop
	input i_btn_U,  //mode 


	output  o_run_stop, //run-stop	
	output  o_clear, //clear
	output  o_mode //up_down
    
);

typedef enum logic [2:0]{clear = 3'd0, stop =3'd1 , run = 3'd2, mode = 3'd3} state_t;

state_t  state, n_state;








assign  o_run_stop = o_sw[0];	
assign  o_clear    = o_sw[1];
assign  o_mode     = mode_reg;



reg mode_reg, mode_next;

reg [1:0] o_sw;



always@(posedge i_clk or posedge i_reset)begin

    if(i_reset)begin 
        state <= stop;
		mode_reg <=0;
    end

    else begin
	
        state <= n_state;
		mode_reg <= mode_next;
    end

end 

////////////////////////////////////////////////////////////////
// next state logic 
////////////////////////////////////////////////////////////////
always@(*)begin

		mode_next = mode_reg;
		n_state = state;
		o_sw	= 2'b00;
        case(state)

		stop : begin if(i_btn_R) n_state = run;
					 else if(i_btn_L) n_state = clear ;
					 else if(i_btn_U) n_state = mode;
					 else n_state = stop;
					 o_sw = 2'b00;                  //  00 -> stop
			   end 


		clear: begin n_state = stop;  
			    	 o_sw = 2'b10; // 중간 run_stop bit  끝 -> clear  // 01 clear

				end

		run: begin if(i_btn_R) n_state = stop;  
				   else  n_state = run;  
				   o_sw = 2'b01;              // 10 run 

			 end


		mode : begin
					mode_next = ~mode_reg;
					o_sw = 2'b00;
					n_state = stop;
             	end 

		default : begin

					mode_next = mode_reg;
					o_sw = 2'b00;
					n_state = state;

				  end

        endcase 

end
    

endmodule





