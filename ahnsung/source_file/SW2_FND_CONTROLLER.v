`timescale 1ns / 1ps



module SW2_FND_CONTROLLER#(

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
	input  i_btn_R,
	input  i_btn_L,
	input  i_sw_0,
	input  i_sw_2,

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

wire w_clk_2kHz;
wire [2:0] w_sel;
wire [3:0] w_msec_sec;
wire [3:0] w_min_hour;

//////////////////////////////////////////////////////////////////
clock_tick_generator#(

.CLK_FRQ(2000)  // 2KHz
) U_CLK_GEN (

.i_clk(i_clk),
.i_reset(i_reset),
.o_clk(w_clk_2kHz)

);

counter8 U_COUNTER8(

.i_clk(w_clk_2kHz),
.i_reset(i_reset),
.o_sel(w_sel)

);










wire w_dot_onoff;





dot U_DOT(

.i_msec(i_msec),
.o_dot_onoff(w_dot_onoff)

);




///////////////////////////////////////////////////////////////////////

wire [1:0] w_state_sel;



SW2_FSM_Change U_FSM(

.i_clk(w_clk_2kHz),
.i_reset(i_reset),
.i_btnR(i_btn_R),
.i_btnL(i_btn_L),
.o_sel(w_state_sel)


);





///////////////////////////////////////////////////////////////////////

wire [3:0] w_decode_ds1_msec;
wire [3:0] w_decode_ds10_msec;
wire [3:0] w_decode_ds1_sec;
wire [3:0] w_decode_ds10_sec;

wire [3:0] w_decode_ds1_min;
wire [3:0] w_decode_ds10_min;
wire [3:0] w_decode_ds1_hour;
wire [3:0] w_decode_ds10_hour;




///////////////////////////////////////////////////////////////////////




SW2_ANODE_CHOICE U_ANODE_CHOICE_TO_MUX1(


	.i_sw_0(i_sw_0),
	.i_sw_2(i_sw_2),
	.i_sel(w_state_sel),
	.i_dot(w_dot_onoff), 
	.i_ds1(w_ds1_msec),
	.i_ds2(w_ds10_msec),
	.i_ds3(w_ds1_sec),
	.i_ds4(w_ds10_sec),

	.o_ds1(w_decode_ds1_msec),
	.o_ds2(w_decode_ds10_msec),
	.o_ds3(w_decode_ds1_sec),
	.o_ds4(w_decode_ds10_sec)


);



SW2_ANODE_CHOICE U_ANODE_CHOICE_TO_MUX2(


	.i_sw_0(i_sw_0),
	.i_sw_2(i_sw_2),
	.i_sel(w_state_sel),
	.i_dot(w_dot_onoff), 
	.i_ds1(w_ds1_min),
	.i_ds2(w_ds10_min),
	.i_ds3(w_ds1_hour),
	.i_ds4(w_ds10_hour),
	.o_ds1(w_decode_ds1_min),
	.o_ds2(w_decode_ds10_min),
	.o_ds3(w_decode_ds1_hour),
	.o_ds4(w_decode_ds10_hour)


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


