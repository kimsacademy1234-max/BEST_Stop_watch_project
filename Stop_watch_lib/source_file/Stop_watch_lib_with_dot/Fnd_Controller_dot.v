`timescale 1ns / 1ps


module Fnd_Controller_dot#(

parameter MSEC_BIT_WIDTH = 7,
parameter SEC_BIT_WIDTH = 6,
parameter MIN_BIT_WIDTH = 6,
parameter HOUR_BIT_WIDTH =5

)
(
    input  i_clk,
    input  i_reset,
	input  [MSEC_BIT_WIDTH-1:0]  i_msec, 
	input  [SEC_BIT_WIDTH -1:0]  i_sec,
	input  [MIN_BIT_WIDTH -1:0]  i_min,
	input  [HOUR_BIT_WIDTH -1:0] i_hour,
	input  i_sw_display_mode,



    output wire [3:0] o_fnd_com,
    output wire [7:0] o_fnd_data

);


/////////////////////////////////////////////////////////////////////////////

wire [3:0] w_ds1_msec;
wire [3:0] w_ds10_msec;


wire [3:0] w_ds1_sec;
wire [3:0] w_ds10_sec;

wire [3:0] w_ds1_min;
wire [3:0] w_ds10_min;

wire [3:0] w_ds1_hour;
wire [3:0] w_ds10_hour;
/////////////////////////////////////////////////////////////////////////////


digit_splitter #(
   	.WIDTH (7)
) U_MSEC (

	.i_din(i_msec),
	.o_ds1(w_ds1_msec),
	.o_ds10(w_ds10_msec)

);

digit_splitter #(
   	.WIDTH (6)
) U_SEC (

	.i_din(i_sec),
	.o_ds1(w_ds1_sec),
	.o_ds10(w_ds10_sec)

);


digit_splitter #(
   	.WIDTH (6)
) U_MIN (

	.i_din(i_min),
	.o_ds1(w_ds1_min),
	.o_ds10(w_ds10_min)

);


digit_splitter #(
   	.WIDTH (5)
) U_HOUR (

	.i_din(i_hour),
	.o_ds1(w_ds1_hour),
	.o_ds10(w_ds10_hour)

);


//////////////////////////////////////////////////////////////////

wire w_clk_1kHz;

//////////////////////////////////////////////////////////////////
clock_tick_generator#(

.CLK_FRQ(2000)  // 2KHz
) U_CLK_GEN_1KHZ (

.i_clk(i_clk),
.i_reset(i_reset),
.o_clk(w_clk_1kHz)

);

counter8 U_COUNTER8(

.i_clk(w_clk_1kHz),
.i_reset(i_reset),
.o_sel(w_sel)

);



//////////////////////////////////////////////////////////////////////
wire [2:0] w_sel;
wire [3:0] w_msec_sec;
wire [3:0] w_min_hour;

////////////////////////////////////////////////////////////////////







wire w_dot_onoff;





dot U_DOT(

.i_msec(i_msec),
.o_dot_onoff(w_dot_onoff)

);






mux_8x1 U_SEC_MUXER(

    .i_sel (w_sel),
    .i_d0  (w_ds1_msec),
    .i_d1  (w_ds10_msec),
    .i_d2  (w_ds1_sec),
    .i_d3  (w_ds10_sec),
    .i_d4  (4'hf),
    .i_d5  (4'hf),
    .i_d6  ({3'b111,w_dot_onoff}),
    .i_d7  (4'hf),

	.o_data (w_msec_sec)
);


mux_8x1 U_MIN_MUXER(

    .i_sel (w_sel),
    .i_d0  (w_ds1_min),
    .i_d1  (w_ds10_min),
    .i_d2  (w_ds1_hour),
    .i_d3  (w_ds10_hour),
    .i_d4  (4'hf),
    .i_d5  (4'hf),
    .i_d6  ({3'b111,w_dot_onoff}),
    .i_d7  (4'hf),
	.o_data (w_min_hour)
);






/// mux_4x1 //



wire [3:0] w_input_BCD;
assign w_input_BCD = (i_sw_display_mode == 0)? w_msec_sec : w_min_hour;

/////////////////////////////////////////////////////////////////////////
decoder_2x4 U_DECODER(

	.i_sel(w_sel[1:0]),
	.o_dec_n(o_fnd_com)

);



fnd_decoder U_FND_DEC (
    .i_hex      (w_input_BCD),
    .o_fnd_data (o_fnd_data)
);

endmodule


