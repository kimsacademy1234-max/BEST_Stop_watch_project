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
  

constraint push_data_gen{push_data inside{[0:256]};}
constraint rst_gen{ rst dist{ 0:/ 9 , 1:/ 1  }; }





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
	
	function new(mailbox #(transaction) gen2drv_mbox, event gen_next_evt);
		
		this.gen_next_evt =gen_next_evt;
		this.gen2drv_mbox =gen2drv_mbox;
	endfunction



	task run(int run_count,int option);
		repeat(run_count)begin
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
					tr.rst = 0;
					tr.push = 1;
					tr.pop  = 0;
				  end

				1:begin
					tr.randomize();
					tr.rst = 0;
					tr.push = 0;
					tr.pop  = 1;
				  end

				2:begin
					tr.randomize();
					tr.rst = 0;
					tr.push = 1;
					tr.pop  = 1;
				  end
				
				3:begin
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
				tr.rst			= fifo_vif.rst;			// scoreboard 가 reset 을 알아야 큐를 비울 수 있음
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

	function new(mailbox #(transaction) mon2scb_mbox, virtual fifo_interface fifo_vif, event gen_next_evt);
		this.fifo_vif	  =  fifo_vif;
		this.mon2scb_mbox = mon2scb_mbox;
		this.gen_next_evt = gen_next_evt;
	endfunction 


	localparam int DEPTH = 4;

	// 기대 FIFO: 크기 제한 없는 큐 + DEPTH 비교 (DUT 버그로 더 들어와도 큐가 조용히 버리지 않도록)
	logic [7:0] expected_fifo[$];
	logic [7:0] exp_data;
	bit         exp_full, exp_empty, do_push, do_pop;

	int total_count;
	int reset_count;
	int push_count;
	int pop_count;
	int push_ignored_count;		// full 일 때 들어온 push (DUT 가 무시해야 함)
	int pop_ignored_count;		// empty 일 때 들어온 pop  (DUT 가 무시해야 함)


	int pass_count;
	int fail_count;


	int full_fail_count;
	int full_pass_count;

	int empty_fail_count;
	int empty_pass_count;


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
					exp_data = expected_fifo.pop_front();		// 한 번만 꺼내서 변수에 저장
					if(exp_data === tr.pop_data)begin
						pass_count ++;
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
				end
			end

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

	task report();


		$display("");
		$display("+--------------------------------------------------+");
		$display("|                V2 TEST  REPORT                   |");
		$display("+--------------------------------------------------+");
		$display("|  total test = %5d                              |", total_count);
		$display("|  reset count= %5d                              |", reset_count);
		$display("|  pop  count = %5d                              |", pop_count);
		$display("|  push count = %5d                              |", push_count);
		$display("|  push ignored (full)  = %5d                    |", push_ignored_count);
		$display("|  pop  ignored (empty) = %5d                    |", pop_ignored_count);
		$display("+--------------------------------------------------+");
		$display("  pop vs expect                      ");
		$display("+--------------------------------------------------+");
		$display("|  pop_pass count = %5d                          |", pass_count);
		$display("|  pop_fail count = %5d                          |", fail_count);
		$display("+--------------------------------------------------+");
		$display("  full / empty pass/fail             ");
		$display("+--------------------------------------------------+");
		$display("|  full_pass count = %5d                         |", full_pass_count);
		$display("|  full_fail count = %5d                         |", full_fail_count);
		$display("+--------------------------------------------------+");
		$display("|  empty_pass count = %5d                        |", empty_pass_count);
		$display("|  empty_fail count = %5d                        |", empty_fail_count);
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

	task run(int run_count,int option);  // argument 선언
	
		drv.preset();

		fork
			gen.run(run_count,option);
			drv.run();
			mon.run();
			scb.run();
		join_any

			#1;
			scb.report();

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
	env.run(5000,0);
	$finish;

end





endmodule
