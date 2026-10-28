`timescale 1ns / 1ps


module 01_UART_CONTROLLER(
    
    input i_clk, i_reset,
    input [7:0] i_ascii,
    
    input [23:0] i_get, 
    input 

    output [1:0] o_get_sel, // sender select
    output [3:0] o_fnd_sel, //FND 출력
       // o_fnd_sel[2:0] - 화면 결정 
       // o_fnd_sel[3] - dsp mode(FND_CON 입력)
    
   
   

);

typedef enum{

    space = 0,
    bacS = 1,

    under = 13,

    g =2,
    e = 3,
    t =4,
    
   
    m = 5,
    o = 6,
    d = 7,

    b = 8,
    n = 9,

    get = 10,
    mode = 11,
    btn = 12,
    
    get_hm   =14,
    get_ms   =15,
    get_temp =16,
    get_dist =17,

     
    get_hm   =14,
    get_ms   =15,
    get_temp =16,
    get_dist =17,



    
    


    



} state_t;



state_t c_state,n_state; 















endmodule
