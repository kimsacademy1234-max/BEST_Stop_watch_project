

`timescale 1ns / 1ps


module tb_fifo();


parameter DEPTH =4;

reg i_clk,i_reset,push,pop;
reg [7:0]push_data;
wire[7:0] pop_data;
wire full,empty;




//simulater


reg [7:0] compare_buffer[0:DEPTH-1]; // 베릴로그는 큐가 없으므로, 이렇게 선언함

reg[1:0] push_cnt, pop_cnt; // interger 선언 안한 이유 : 따로 조건이 더 필요함


fifo#(
.DEPTH(DEPTH)
)
DUT_FIFO(

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
integer pass_cnt;
integer fail_cnt;
integer i;
initial begin

i_clk =0 ; i_reset =1; push =0; pop =0; push_data =0;
push_cnt = 0; pop_cnt = 0;

pass_cnt = 0;
fail_cnt = 0;


@(negedge i_clk);
@(negedge i_clk);

	i_reset =0;
	@(negedge i_clk);
	if(full == 0)begin
		$display("%t :ass full signal", $stime);
	end else begin
		
		$display("%t :ail full signal", $stime);
	end

	if(empty == 1)begin
		$display("%t :ass empty signal", $stime);
	end else begin
		
		$display("%t :ail empty signal", $stime);
	end

	#10;
///////////////////////////////////////////////////////////////////
//push - 4번 뒤에 full == 1이 되어야한다//

	for(i=0; i<5;i=i+1)begin

		@(negedge i_clk);

			push_data =8'h0a + i;
			push = 1'b1;
			if(!full)begin
			compare_buffer[push_cnt] =push_data;
			push_cnt = push_cnt + 1 ; 
			end

	end

	@(negedge i_clk);
			push = 1'b0;


///////////////////////////////////////////////////////////////////
	//pop only pop 5times

// pop해서 모니터링 할때, 스코어보드 판별 시점을 정해야 한다. 
// negedge에서 판별을 시킨다
// addr 바뀐상태에서 rdata는 조합회로이므로 바로 출력이 됨

	for(i=0; i<5;i=i+1)begin

		@(negedge i_clk);

			pop = 1'b1;
			if(!empty)begin
				if(pop_data == compare_buffer[pop_cnt])begin
					$display("%t : pass pop data",$stime);
				end
				
				else begin
					$display("%t : fail pop data",$stime);
				end
				pop_cnt = pop_cnt + 1;
			end

	end
	// empty state is '1' - pop을 4번 했으므로 
	if(empty)begin
		
		$display("%t : pass empty signal",$stime);

	end
	else begin

		$display("%t : fail empty signal",$stime);

	end


	@(negedge i_clk);
			pop = 1'b0;

/////////////////////////////////////////////////////////////////////////////////
// 마지막 시나리오 : 4 push_pop 5time
/////////////////////////////////////////////////////////////////////////////////



	for(i=0; i<5;i=i+1)begin

		@(negedge i_clk);
			push = 1'b1;
			push_data = 8'h0f - i;

			if(!full)begin
				compare_buffer[push_cnt] = push_data;
				push_cnt = push_cnt +1;
			end
			
			pop = 1'b1;

			if(!empty) begin

				if(pop_data == compare_buffer[pop_cnt])begin
					$display("%t : pass pop data",$stime);
				end
				
				else begin
					$display("%t : fail pop data",$stime);
				end
				pop_cnt = pop_cnt + 1;

			end

	end

//////////////////////////////////////////////////////////////////////////////
// randome test 
///////////////////////////////////////////////////////////////////////////



	
		@(negedge i_clk);
			push = 1'b0;
			pop  = 1'b1;
			pop_cnt = pop_cnt +1 ;
			
		@(negedge i_clk);
			pop =1'b0;
		@(negedge i_clk);

	for(i=0; i<256; i= i+1)begin	
		@(negedge i_clk);

		push  =$random()%2;
		pop   =$random()%2;
		push_data = $random()%256;

		if(push&(!full))begin
			compare_buffer[push_cnt] =push_data;
			push_cnt = push_cnt + 1 ; 
		end
		
		
		if(pop&(!empty))begin

			if(pop_data == compare_buffer[pop_cnt])begin
				$display("%t :Random test pass pop data",$stime);
				pass_cnt = pass_cnt +1;
			end
				
			else begin
					$display("%t : Random test fail pop data",$stime);
					fail_cnt =fail_cnt +1;
			end

			pop_cnt = pop_cnt + 1 ; 
		end


	end
		
		#10;
		
		
	$display("*** random result ***");	
	$display("total random test  =%d", i);	
	$display("pass count =%d", pass_cnt);
	$display("fail count =%d", fail_cnt);
			


		#10;
		$finish;

		

end


endmodule
