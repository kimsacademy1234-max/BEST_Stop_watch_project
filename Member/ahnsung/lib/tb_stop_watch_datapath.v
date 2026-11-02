`timescale 1ns / 1ps


module tb_stop_watch_datapath();

reg i_clk;
reg i_reset;
reg i_run_stop;
reg i_clear;
reg i_mode;
wire  [6:0] msec; 
wire  [5:0] sec;
wire  [5:0] min;
wire  [4:0] hour;


Stop_Watch_DataPath DUT(

 .i_clk         ( i_clk),
 .i_reset       ( i_reset),
 .i_run_stop    ( i_run_stop), 
 .i_clear       ( i_clear),
 .i_mode        ( i_mode),
 .msec          ( msec),
 .sec           ( sec),
 .min           ( min),
 .hour          ( hour)

 );


parameter MSEC_10 = 100_000*10;


initial begin

	i_clk = 0;
	i_reset =1;
	i_run_stop=0;
	i_clear = 0;
	i_mode = 0;
	#10 i_reset =0;
	i_run_stop = 1;

	repeat(50) #(MSEC_10);


	
end


endmodule



