`timescale 1ns / 1ps


module UART_CONTROLLER#(
     
        parameter BIT_WIDTH = 8,
        parameter DATA_WIDTH = 32


        )(
    


	input i_error, // 디코더에서 보내는 에러 시호 
	input [23:0] i_for_sender_data,
	input i_handshake,
	input i_sender_busy,
    input i_clk, i_reset,
    input [DATA_WIDTH-1 :0] i_con_ascii,


    input  i_get, // get mode 
    input  i_btn, //btn 
    input  i_mode, // stopwatch / watch / timer / 거리/ 온습도 
    input  i_auto, // 1-> 유지 다음 1 -> 0


	input  i_off_set, // set 기능 끄기 switch 역할 
	input  i_set,

	output [6:0] o_module_control_bit, // switch 기능 


	output [2:0] o_send_sel, // sender로 데이터가 무슨 데이터인지
							// auto mode 시 0.25s 간격으로 업데이트 
    

	output [23:0] o_sender_data,
	output o_sender_go, // 


	output o_uart_R,
	output o_uart_L,
	output o_uart_U,
	output o_uart_D

);






reg [DATA_WIDTH -1 :0] c_con_ascii,n_con_ascii;
reg [6:0] c_module_control_bit, n_module_control_bit;


reg [2:0] c_sender_sel,n_sender_sel;
reg c_sender_go, n_sender_go; 
reg c_auto_enable, n_auto_enable;



reg c_btn_R,n_btn_R;
reg c_btn_L,n_btn_L;
reg c_btn_U,n_btn_U;
reg c_btn_D,n_btn_D;


wire w_clk_5hz;
wire w_auto_enable;


assign o_send_sel = c_sender_sel;
assign w_auto_enable = c_auto_enable;





typedef enum{

	IDLE = 0,
	GET  = 1,
	AUTO_ALL = 2,
	AUTO_OFF = 3,
	AUTO_SW  = 4,
	AUTO_TM  = 5,
	AUTO_WH  = 6

}state_auto;

state_auto c_auto_state,n_auto_state;





typedef enum{

MODE_IDLE = 0,
MODE = 1

}state_m;

state_m c_mode_state,n_mode_state;



sender_tick_generator #(
        .CLK_FRQ(5)
    ) U_CLK_GEN_5HZ (
        .i_clk     (i_clk),
        .i_rst     (i_reset),
		.i_enable  (w_auto_enable),
        .o_clk(w_clk_5hz)
    );



// Mode state //
always@(posedge i_clk, posedge i_reset)begin


	if(i_reset)begin
		
		c_mode_state <= MODE_IDLE;
		c_con_ascii <= 0; 
		c_module_control_bit <= 7'b000_0000;
//auto 
		c_auto_state <= AUTO_IDLE;
		c_sender_go <= 0;		
		c_sender_sel <= 0;	
	end

	else begin

		c_mode_state <=  n_mode_state;
		c_con_ascii  <=  n_con_ascii;
		c_module_control_bit <= n_module_control_bit;
//auto


		c_auto_state <= n_auto_state;
		c_sender_go <= n_sender_go;		
		c_sender_sel <= n_sender_sel;


	end

end

/////////////////////////////////////////////////////// mode //////////////////////////////////////////
always@(*)begin

		
		n_mode_state  =  c_mode_state;
		n_con_ascii   =  c_con_ascii;
		n_module_control_bit  = c_module_control_bit;

		case(c_mode_state)

		MODE_IDLE : begin

			if(i_mode)begin 
				n_mode_state = MODE;
			end
	
		end
	
		MODE : begin

				if(i_handshake)begin
					
					if(i_mode)begin					
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
							n_module_control_bit = 7'b0100_000;
							end

					"temp"  :  begin
							n_module_control_bit = 7'b1000_000;
							end


					endcase

					end

					else if(i_set&&(c_module_control_bit == 7'b0000_010)) n_module_control_bit = 7'b0000_110;
					else if(i_off_set&& c_module_control_bit == 7'b0000_110) n_module_control_bit = 7'b0000_010;

				end

			end

		endcase

end


////////////////////////////////  auto /////////////////////////////////////////////



























endmodule 





module sender_tick_generator #(
    parameter CLK_FRQ = 1000
) (
    input      i_clk,
    input      i_rst,
	input 	   i_enable,
    output reg o_clk
);

    parameter FCOUNT = (100_000_000 / CLK_FRQ);
    reg [$clog2(FCOUNT)-1:0] r_counter;

    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            r_counter  <= 0;
            o_clk <= 0;
        end else begin

			if(i_enable)begin 
				r_counter <= r_counter + 1;
				if (r_counter == FCOUNT - 1) begin
					r_counter  <= 0;
					o_clk <= 1;
            	end 

				else begin
                	o_clk <= 0;
            	end
			end
		
			else begin 
				o_clk <= 0;
			end



        end
    end

endmodule







