`timescale 1ns / 1ps


module Stop_Watch_DataPath#(

parameter MSEC_BIT_WIDTH = 7,
parameter SEC_BIT_WIDTH = 6,
parameter MIN_BIT_WIDTH = 6,
parameter HOUR_BIT_WIDTH =5

)(

input i_clk,
input i_reset,
input i_run_stop,
input i_clear,
input i_mode,
output reg [MSEC_BIT_WIDTH-1:0] msec, 
output reg [SEC_BIT_WIDTH -1:0] sec,
output reg [MIN_BIT_WIDTH -1:0] min,
output reg [HOUR_BIT_WIDTH -1:0] hour

);


wire w_msec;
wire w_sec;
wire w_min;
wire w_hour;



tick_gen_100Hz STOP_WATCH_TICK(

	.i_clk(i_clk),
	.i_reset(i_reset),
	.i_run_stop(i_run_stop),
	.i_clear(i_clear),
	.o_tic(w_msec)

);



tick_counter#(
	.COUNT(100),
	.DATA_WIDTH(MSEC_BIT_WIDTH)
) U_MSEC_TICK_COUNTER(
.i_tick		(w_msec),
.i_reset	(i_reset),
.i_clk		(i_clk),
.i_clear	(i_clear),
.i_mode		(i_mode),
.o_time_tic	(w_sec),
.o_time(msec)

);


tick_counter#(
	.COUNT(60),
	.DATA_WIDTH(SEC_BIT_WIDTH)
) U_SEC_TICK_COUNTER(
.i_tick		(w_sec),
.i_reset	(i_reset),
.i_clk		(i_clk),
.i_clear	(i_clear),
.i_mode		(i_mode),
.o_time_tic	(w_min),
.o_time(sec)

);


tick_counter#(
	.COUNT(60),
	.DATA_WIDTH(MIN_BIT_WIDTH)
) U_MIN_TICK_COUNTER(
.i_tick		(w_min),
.i_reset	(i_reset),
.i_clk		(i_clk),
.i_clear	(i_clear),
.i_mode		(i_mode),
.o_time_tic	(w_hour),
.o_time(min)

);


tick_counter#(
	.COUNT(60),
	.DATA_WIDTH(HOUR_BIT_WIDTH)
) U_HOUR_TICK_COUNTER(
.i_tick		(w_hour),
.i_reset	(i_reset),
.i_clk		(i_clk),
.i_clear	(i_clear),
.i_mode		(i_mode),
.o_time_tic	(),
.o_time(hour)

);


endmodule 












