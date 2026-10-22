`timescale 1ns / 1ps


module tb_fifo();

reg i_clk,i_reset,push,pop;
reg [7:0]push_data;
wire[7:0] pop_data;
wire full,empty;





fifo DUT_FIFO(

.i_clk(i_clk), 
.i_reset(i_reset),
.push(push),
.pop(pop),
.push_data(push_data),
.pop_data(pop_data),
.full(full),
.empty(empty)

);


always #5 i_clk = ~i_clk; 

integer i;
initial begin

i_clk =0 ; i_reset =1; push =0; pop =0; push_data =0;
@(negedge i_clk);
@(negedge i_clk);

	i_reset =0;
	@(negedge i_clk);
	if(full == 0)begin
		$display("%t :pass full signal", $stime);
	end else begin
		
		$display("%t :fail full signal", $stime);
	end

	if(empty == 1)begin
		$display("%t :pass empty signal", $stime);
	end else begin
		
		$display("%t :fail empty signal", $stime);
	end

	#10;


	//push - 4번 뒤에 full == 1이 되어야한다

	for(i=0; i<5;i=i+1)begin

		@(negedge i_clk);

			push_data =8'h0a + i;
			push = 1'b1;
	end

	@(negedge i_clk);
			push = 1'b0;
	
	#100;

	$finish;




end








endmodule
