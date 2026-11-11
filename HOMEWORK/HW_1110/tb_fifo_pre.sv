`timescale 1ns / 1ps



/////////////////////////////////////////////////////////////////////////////
interface fifo_interface(input clk);

 logic rst;
 logic [7:0] push_data;
 logic push;
 logic pop;
 logic [7:0] pop_data;
 logic full;
 logic empty;



  property p_rst_full;
			@(posedge clk) rst |-> (full === 1'b0); // full 이 x일때 일반 등가를 사용할경우, 통과 시킨다. 따라서 === 케이스 등가를 써서 4상태에 대한
													// 판별 할 수 있도록 함 
  endproperty



  property p_rst_empty;
			@(posedge clk) rst |-> (empty === 1'b1); // full 이 x일때 일반 등가를 사용할경우, 통과 시킨다. 따라서 === 케이스 등가를 써서 4상태에 대한
													// 판별 할 수 있도록 함 
  endproperty


  a_rst_full : assert property(p_rst_full)
  else $display("%t : [assert] error full = %d", $time, full);


  a_rst_empty : assert property(p_rst_empty)
  else $display("%t : [assert] error empty = %d", $time, empty);








endinterface


/////////////////////////////////////////////////////////////////////////////


class transaction;


 rand bit rst;
 rand bit [7:0] push_data;
 rand bit push;
 rand bit pop;
 logic [7:0] pop_data;
 logic  full;
 logic  empty;
  

constraint push_data_gen{push_data inside{[0:255]};}

constraint rst_gen{ rst dist{ 0:/ 9 , 1:/ 1  }; }
constraint push_gen{ push dist{ 0:/ 5 , 1:/ 5 }; }
constraint pop_gen{ pop   dist{ 0:/ 5 , 1:/ 5 }; }





	function void debug_print(string name);
		$display("%t :[%s] rst = %d, push = %d ,pop = %d, full = %d, empty = %d ,push_data = %d , pop_data= %d  ",$time,name,rst,push,pop,full,empty,push_data,pop_data);
	endfunction



endclass 


/////////////////////////////////////////////////////////////////////////////
//
//									01_GENERATOR
//
/////////////////////////////////////////////////////////////////////////////
class generator;
    
    transaction tr;
	mailbox #(transaction) gen2drv_mbox;
	event gen_next_evt;
	int       step     = 0;
	
	function new(mailbox #(transaction) gen2drv_mbox, event gen_next_evt);
		
		this.gen_next_evt =gen_next_evt;
		this.gen2drv_mbox =gen2drv_mbox;
	endfunction



	task run(int option);
		forever begin
			tr = new();
			tr.randomize();
            gen_tr(option);
			gen2drv_mbox.put(tr);
			$display("=========================================================================");
			tr.debug_print("GEN");
			@(gen_next_evt);		
		end	

	endtask

function void gen_tr(int option);
     
			case(option)
	
				0:begin
					tr.randomize();
					tr.rst  = 0;
					tr.pop  = 0;
					case(step % 6)
						0,1,2,3 : begin tr.push = 1;  end
						4       : begin tr.push = 1;             end
						5       : begin tr.push = 0; tr.rst = 1; end
					endcase
					step++;
				  end

				1:begin
					tr.randomize();
					tr.rst  = 0;
					if(step % 9 < 4) begin tr.push = 1; tr.pop = 0;  end
					else             begin tr.push = 0; tr.pop = 1;  end
					step++;
				  end

				2:begin
					tr.randomize();
					tr.rst = 0;
					tr.push = 1;
					tr.pop  = 1;
				  end
				
				3:begin
					tr.randomize();
					tr.rst = 0;
				  end

				4:begin
					tr.randomize();
				  end
			endcase	
endfunction


endclass


/////////////////////////////////////////////////////////////////////////////
//
//									02_DRIVER
//
/////////////////////////////////////////////////////////////////////////////

class driver;

    transaction tr;
	mailbox #(transaction) gen2drv_mbox;
	virtual fifo_interface fifo_vif;

	function new( mailbox #(transaction) gen2drv_mbox,virtual fifo_interface fifo_vif); 
	
		this.fifo_vif = fifo_vif;
		this.gen2drv_mbox = gen2drv_mbox;

	endfunction



	task preset();
		
	fifo_vif.rst = 1;
	@(negedge fifo_vif.clk);
	@(negedge fifo_vif.clk);
	fifo_vif.rst = 0;

	endtask


	task run();
		forever begin
			@(posedge fifo_vif.clk);
			#1;
			gen2drv_mbox.get(tr);
			tr.debug_print("DRV"); 
			fifo_vif.rst	   = tr.rst;
			fifo_vif.push_data = tr.push_data;
			fifo_vif.push = tr.push;
			fifo_vif.pop = tr.pop;

		end
	endtask

	
endclass

/////////////////////////////////////////////////////////////////////////////
//
//									03_MONITOR
//
/////////////////////////////////////////////////////////////////////////////


class monitor;

	transaction tr;
	mailbox #(transaction) mon2scb_mbox;
	virtual fifo_interface fifo_vif;


	function new( mailbox#(transaction) mon2scb_mbox ,
					virtual fifo_interface fifo_vif
					);
	
		this.mon2scb_mbox = mon2scb_mbox;  
		this.fifo_vif = fifo_vif;
	endfunction
	

	task run();

			forever begin
				@(negedge fifo_vif.clk);
				tr 				= new();
				tr.rst			= fifo_vif.rst;
				tr.pop_data 	= fifo_vif.pop_data ;
				tr.push_data	= fifo_vif.push_data ;   
				tr.push			= fifo_vif.push  ;
				tr.pop			= fifo_vif.pop ;
				tr.full			= fifo_vif.full;		
				tr.empty		= fifo_vif.empty;

				mon2scb_mbox.put(tr);
				tr.debug_print("MON");

			end

	endtask 


endclass


/////////////////////////////////////////////////////////////////////////////
//
//									04_SCOREBOARD
//
/////////////////////////////////////////////////////////////////////////////

class scoreboard;
	
	transaction tr;
	mailbox #(transaction) mon2scb_mbox;
	event gen_next_evt;
	virtual fifo_interface fifo_vif;


	localparam int DEPTH = 4;

	logic [7:0] expected_fifo[$:3];
	logic [7:0] exp_data;
	bit         exp_full, exp_empty, do_push, do_pop;

	int total_count;
	int reset_count;
	int push_count;
	int pop_count;
	int push_ignored_count;
	int pop_ignored_count;


	int pass_count;
	int fail_count;


	int full_fail_count;
	int full_pass_count;

	int empty_fail_count;
	int empty_pass_count;

	int   option;
	int   max_count;
	bit   push_seen[256];
	bit   pop_seen [256];
	int   push_cover;
	int   pop_cover;
	bit   timeout;
	event end_evt;

	function new(mailbox #(transaction) mon2scb_mbox, virtual fifo_interface fifo_vif, event gen_next_evt);
		this.fifo_vif	  =  fifo_vif;
		this.mon2scb_mbox = mon2scb_mbox;
		this.gen_next_evt = gen_next_evt;
		this.cg_fifo =		new;
	endfunction 

	covergroup cg_fifo;
			// iff(조건) -> push 일때만 집계하겠다. pop 일때도 tr.push data는 매번 posedge + 1ns 바뀌고 있기 때문 
			cp_push_data : coverpoint tr.push_data iff(tr.push){
		
				bins full[] = {[0:255]};  // 값의 범위를 지정할 수 있다
										// 퍼센트로 나온다
			}


			cp_pop_data : coverpoint tr.pop_data iff(tr.pop){
		
				bins full[] = {[0:255]};  // 값의 범위를 지정할 수 있다
										// 퍼센트로 나온다
			}

			// 동작 4가지 다 일어나는가? push + pop 

			cp_push_pop : coverpoint {tr.push,tr.pop} {
		
				bins idle = {2'b00};  
				bins push_only = {2'b10};  
				bins pop_only = {2'b01};  
				bins push_pop = {2'b11};  
										
			}

			cp_empty_full : coverpoint {tr.empty,tr.full} {
		
				bins nomal    = {2'b00};  
				bins empty    = {2'b10};  
				bins full     = {2'b01};  
				//bins error    = {2'b11};  
										
			}

			// check 안한거 -> 메모리 depth ->  depth 가 1일 때, 2일때 확인을 안해봄 
	
			cp_queue_st  : coverpoint expected_fifo.size()  {
				
				bins fifo_0 = {0};
				bins fifo_1 = {1};
				bins fifo_2 = {2};
				bins fifo_3 = {3};



			}



			// cross option -> x 조합을 만들어 내겠다. 
			cx_op_st: cross cp_push_pop,cp_empty_full;

	endgroup

	task run();

		forever begin

			mon2scb_mbox.get(tr);
			tr.debug_print("SCB");
			total_count ++;

			if(tr.rst)begin
				reset_count ++;
				expected_fifo.delete();
				check_flags(0, 1);
			end

			else begin
				exp_full  = (expected_fifo.size() == DEPTH);
				exp_empty = (expected_fifo.size() == 0);
				check_flags(exp_full, exp_empty);

				do_pop  = tr.pop  && !exp_empty;
				do_push = tr.push && !exp_full;

				if(tr.push && exp_full)  push_ignored_count ++;
				if(tr.pop  && exp_empty) pop_ignored_count ++;

				if(do_pop)begin
					pop_count ++;
					exp_data = expected_fifo.pop_front();
					if(exp_data === tr.pop_data)begin
						pass_count ++;
						if(!pop_seen[exp_data]) begin pop_seen[exp_data] = 1; pop_cover ++; end
					end
					else begin
						fail_count ++;
						$display("=========================================================================");
						$display("%t  POP FAIL : pop_data = %d / expected_pop_data = %d",$time,tr.pop_data,exp_data);
						$display("=========================================================================");
					end
				end

				if(do_push)begin
					push_count ++;
					expected_fifo.push_back(tr.push_data);
					if(!push_seen[tr.push_data]) begin push_seen[tr.push_data] = 1; push_cover ++; end
				end
				cg_fifo.sample();


			end

			if(((option == 0) ? push_cover : pop_cover) == 256) ->end_evt;
			else if(total_count == max_count) begin timeout = 1; ->end_evt; end

			->gen_next_evt;

		end
	endtask



	function void check_flags(bit expec_full, bit expec_empty);
		if(tr.full === expec_full) full_pass_count ++;
		else begin
			full_fail_count ++;
			$display("%t  FULL FAIL  : full = %b / expected_full = %b (queue size = %0d)",$time,tr.full,expec_full,expected_fifo.size());
		end

		if(tr.empty === expec_empty) empty_pass_count ++;
		else begin
			empty_fail_count ++;
			$display("%t  EMPTY FAIL : empty = %b / expected_empty = %b (queue size = %0d)",$time,tr.empty,expec_empty,expected_fifo.size());
		end
	endfunction

	task report(int option);
		string case_s; 
		
		if(option ==0) case_s = "PUSH ONLY";
		if(option ==1) case_s = "POP ONLY";
		if(option ==2) case_s = "PUSH & POP ONLY";
		if(option ==3) case_s = "RANDOM without Reset";
		if(option ==4) case_s = "RANDOM with Reset";
	



		$display("");
		$display("===================================================");
		$display("%s TEST", case_s);
		$display("===================================================");
		$display("|  total test = %5d                              |", total_count);
		$display("|  reset count= %5d                              |", reset_count);
		$display("|  pop  count = %5d                              |", pop_count);
		$display("|  push count = %5d                              |", push_count);
		$display("|  push ignored (full)  = %5d                    |", push_ignored_count);
		$display("|  pop  ignored (empty) = %5d                    |", pop_ignored_count);
		$display("+--------------------------------------------------+");
		$display("");
		$display("===================================================");
		$display("pop_data vs expect_data                    ");
		$display("===================================================");
		$display("|  pop_pass count = %5d                          |", pass_count);
		$display("|  pop_fail count = %5d                          |", fail_count);
		$display("+--------------------------------------------------+");
		$display("");
		$display("===================================================");
		$display("  full / empty pass/fail             ");
		$display("===================================================");
		$display("|  full_pass count = %5d                         |", full_pass_count);
		$display("|  full_fail count = %5d                         |", full_fail_count);
		$display("+--------------------------------------------------+");
		$display("|  empty_pass count = %5d                        |", empty_pass_count);
		$display("|  empty_fail count = %5d                        |", empty_fail_count);
		$display("+--------------------------------------------------+");
		$display("");
		$display("===================================================");
		$display("  DATA ACCEPT                     ");
		$display("===================================================");
		$display("|  end : %-8s  (%0d transactions, max %0d)", timeout ? "TIMEOUT" : "COVERED", total_count, max_count);
		$display("|  push accepted (stored)  = %3d / 256           |", push_cover);
		$display("|  pop  checked  (PASS)    = %3d / 256           |", pop_cover);
		$display("+--------------------------------------------------+");
		$display("");
		$display("===================================================");
		$display("   coverage                     ");
		$display("===================================================");
		$display("|  coverage push_data = %2.1f  %%                |", cg_fifo.cp_push_data.get_coverage());
		$display("|  coverage pop_data  = %2.1f  %%                |", cg_fifo.cp_pop_data.get_coverage());
		$display("|  coverage push /pop = %2.1f  %%                |", cg_fifo.cp_push_pop.get_coverage());
		$display("|  coverage empty / full  = %2.1f  %%            |", cg_fifo.cp_empty_full.get_coverage());
		$display("|  coverage DEPTH  = %2.1f  %%                   |", cg_fifo.cp_queue_st.get_coverage());
		$display("===================================================");
		$display("   CROSS                    ");
		$display("===================================================");
		$display("|  coverage push/pop x empty/full  = %2.1f  %%   |", cg_fifo.cx_op_st.get_coverage());
		$display("+--------------------------------------------------+");
	endtask

    endclass


/////////////////////////////////////////////////////////////////////////////
//
//									05_ENVIRONMENT
//
/////////////////////////////////////////////////////////////////////////////

class environment;

	generator gen;
	driver drv;
	monitor mon;
	scoreboard scb;
	mailbox #(transaction) mon2scb_mbox; 
	mailbox #(transaction) gen2drv_mbox; 
	event gen_next_evt;

	function new(virtual fifo_interface fifo_vif);
	
		
		gen2drv_mbox = new();
		mon2scb_mbox = new();
		gen = new(gen2drv_mbox,gen_next_evt);
		drv = new(gen2drv_mbox,fifo_vif);
		mon = new(mon2scb_mbox,fifo_vif);
		scb = new(mon2scb_mbox,fifo_vif,gen_next_evt);

	endfunction

	task run(int max_count,int option);
	
		drv.preset();
		scb.option    = option;
		scb.max_count = max_count;

		fork
			gen.run(option);
			drv.run();
			mon.run();
			scb.run();
		join_none

			@(scb.end_evt);

			#1;
			scb.report(option);

			disable fork;

	endtask

endclass



/////////////////////////////////////////////////////////////////////////////



module tb_fifo();


logic clk = 0;

fifo_interface fifo_if(clk); 
environment env;

fifo DUT(

 .clk		(clk				),
 .rst		(fifo_if.rst		),
 .push_data	(fifo_if.push_data	),
 .push		(fifo_if.push		),
 .pop		(fifo_if.pop		),	
 .pop_data	(fifo_if.pop_data	),
 .full		(fifo_if.full		),
 .empty		(fifo_if.empty		)

);

always #5 clk = ~clk;

initial begin
	
	$timeformat(-9,0,"ns",0);
	env = new(fifo_if);
	env.run(20000,4);
	$finish;

end





endmodule
