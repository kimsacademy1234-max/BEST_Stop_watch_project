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
    input  i_set_watch,
	input  i_set_timer, //시간 세팅 assert 


	output o_error,


	output [2:0] o_send_sel,
    output [2:0] o_fnd_sel, //FND 출력 
    output [23:0] o_fnd_data,
	output o_sender_go, 

	output o_uart_R,
	output o_uart_L,
	output o_uart_U,
	output o_uart_D

);










endmodule
