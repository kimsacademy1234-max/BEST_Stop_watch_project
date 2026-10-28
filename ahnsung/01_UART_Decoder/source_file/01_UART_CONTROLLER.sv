`timescale 1ns / 1ps


module 01_UART_CONTROLLER#(
     
        parameter BIT_WIDTH = 8,
        parameter DATA_WIDTH = 40


        )(
    
    input i_clk, i_reset,
    input [DATA_WIDTH-1 :0] i_con_ascii,
    
    input  i_pop,
    input  i_handshake,

    input  i_get,
    input  i_btn,

    input  i_mode, // stopwatch / watch / timer / 거리/ 온습도 
    input  i_auto,

    input  i_set


    output [3:0] o_fnd_sel, //FND 출력    
    output [23:0] o_fnd_data,
    
    
    

);










endmodule
