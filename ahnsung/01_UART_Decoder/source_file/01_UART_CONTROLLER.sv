`timescale 1ns / 1ps


module UART_CONTROLLER#(
     
        parameter BIT_WIDTH = 8,
        parameter DATA_WIDTH = 32


        )(
    

	input i_sender_busy,
    input i_clk, i_reset,
    input [DATA_WIDTH-1 :0] i_con_ascii,
    input  i_handshake,


    input  i_get, // get mode 
    input  i_btn, //btn 
    input  i_mode, // stopwatch / watch / timer / 거리/ 온습도 
    input  i_auto, // 1-> 유지 다음 1 -> 0


	input  i_off_set, // set 기능 끄기 switch 역할 
	input  i_set,

	output o_error,
	output [6:0] o_module_control_bit, // switch 기능 


	output [2:0] o_send_sel, // sender로 데이터가 무슨 데이터인지
							// auto mode 시 0.25s 간격으로 업데이트 
    output [2:0] o_fnd_sel, //FND 출력 
    output [23:0] o_fnd_data,
	


	output o_sender_go,


	output o_uart_R,
	output o_uart_L,
	output o_uart_U,
	output o_uart_D

);



assign o_uart_R = (i_con_ascii == "000R")? 1:0;
assign o_uart_L = (i_con_ascii == "000L")? 1:0;
assign o_uart_U = (i_con_ascii == "000U")? 1:0;
assign o_uart_D = (i_con_ascii == "000D")? 1:0;




reg [DATA_WIDTH -1 :0] c_con_ascii,n_con_ascii;
reg [6:0] c_module_control_bit, n_module_control_bit;
reg [2:0] c_fnd_sel,n_fnd_sel;




typedef enum{

MODE_IDLE = 0,
MODE = 1

}state_m;



state_m mode_state,n_mode_state;




// Mode state //
always@(posedge i_clk, posedge i_reset)begin


	if(i_reset)begin
		
		c_mode_state <= MODE_IDLE;
		c_fnd_sel	<= 3'd1;
		c_con_ascii <= 0; 
		c_module_control_bit <= 7'b000_0000;

	end

	else begin

		c_mode_state <=  n_mode_state;
		c_fnd_sel <= n_fnd_sel;
		c_con_ascii  <=  n_con_ascii;
		c_module_control_bit <= n_module_control_bit;
	
	end

end


always@(*)begin

		
		n_mode_state  =  c_mode_state;
		n_fnd_sel 	  =  c_fnd_sel;
		n_con_ascii   =  c_con_ascii;
		n_module_control_bit  = c_module_control_bit;

		case(mode_state)

		MODE_IDLE : begin

			if(i_mode)begin 
				n_mode_state = MODE;
			end
	
		end
	
		MODE : begin

			if(i_hanshake)begin

				case(i_con_ascii)

				"w_hm" : begin
						n_module_control_bit = 7'b0000_010;
					   end 
				
				"w_ms" : begin
						n_module_control_bit = 7'b0000_000;
					   end
				
				
				"t_hm" : begin
						n_module_control_bit = 7'b0010_010;
					   end
				"t_ms" :  begin
					 	n_module_control_bit = 7'b0010_000;
						end
				
				"s_hm" :  begin
					 	n_module_control_bit = 7'b0000_011;
						end
				
				"s_ms"  :  begin
					 	n_module_control_bit = 7'b0000_001;
						end

				"dist"  :  begin
					 	n_module_control_bit = 7'b1000_000;
						end

				"temp"  :  begin
					 	n_module_control_bit = 7'b1100_001;
						end



				endcase




			end
				
				
			
			
		
			
			
		
		



		end






		endcase

















end










































endmodule
