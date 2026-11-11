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
	fifo_vif.push = 0;
	fifo_vif.pop  = 0;
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
			option.per_instance = 1;
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
				bins fifo_4 = {4};
			}



			// cross option -> x 조합을 만들어 내겠다. 
			cx_op_st: cross cp_push_pop,cp_empty_full;

			cx_op_st_fifo_depth : cross cp_push_pop ,cp_queue_st;
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
				cg_fifo.sample();
			end

			else begin
				exp_full  = (expected_fifo.size() == DEPTH);
				exp_empty = (expected_fifo.size() == 0);
				check_flags(exp_full, exp_empty);
				cg_fifo.sample();

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

	function string pad(string s, int w);
		pad = s;
		while(pad.len() < w) pad = {pad, " "};
	endfunction

	function void print_title(string s);
		$display("|  %s|", pad(s, 56));
	endfunction

	function void print_row(string label, string value);
		$display("|    %s : %s|", pad(label, 28), pad(value, 23));
	endfunction

	function string pf(int pass, int fail);
		return $sformatf("PASS %5d   FAIL %3d", pass, fail);
	endfunction

	function string pct(real cov);
		return $sformatf("%5.1f %%", cov);
	endfunction

	task report(int option);
		string case_s, result;

		case(option)
			0 : case_s = "PUSH ONLY";
			1 : case_s = "POP ONLY";
			2 : case_s = "PUSH & POP";
			3 : case_s = "RANDOM without Reset";
			4 : case_s = "RANDOM with Reset";
		endcase

		result = (timeout) ? "TIMEOUT" : (fail_count + full_fail_count + empty_fail_count == 0) ? "PASS" : "FAIL";

		$display("");
		$display("+==========================================================+");
		$display("|  %s%s|", pad($sformatf("[Option-%0d] %s TEST", option, case_s), 46), pad(result, 10));
		$display("+==========================================================+");
		print_title("TRANSACTION");
		$display("+----------------------------------------------------------+");
		print_row("total",                $sformatf("%5d", total_count));
		print_row("reset",                $sformatf("%5d", reset_count));
		print_row("push (accepted)",      $sformatf("%5d", push_count));
		print_row("pop  (accepted)",      $sformatf("%5d", pop_count));
		print_row("push ignored (full)",  $sformatf("%5d", push_ignored_count));
		print_row("pop  ignored (empty)", $sformatf("%5d", pop_ignored_count));
		$display("+----------------------------------------------------------+");
		print_title("CHECK");
		$display("+----------------------------------------------------------+");
		print_row("pop_data vs expected", pf(pass_count, fail_count));
		print_row("full",                 pf(full_pass_count, full_fail_count));
		print_row("empty",                pf(empty_pass_count, empty_fail_count));
		$display("+----------------------------------------------------------+");
		print_title("DATA ACCEPT (0~255)");
		$display("+----------------------------------------------------------+");
		print_row("end condition",        timeout ? "TIMEOUT" : "COVERED");
		print_row("transactions",         $sformatf("%5d / max %0d", total_count, max_count));
		print_row("push accepted (stored)", $sformatf("%3d / 256", push_cover));
		print_row("pop  checked  (PASS)",   $sformatf("%3d / 256", pop_cover));
		$display("+----------------------------------------------------------+");
		print_title("COVERAGE");
		$display("+----------------------------------------------------------+");
		print_row("push_data",             pct(cg_fifo.cp_push_data.get_inst_coverage()));
		print_row("pop_data",              pct(cg_fifo.cp_pop_data.get_inst_coverage()));
		print_row("push / pop",            pct(cg_fifo.cp_push_pop.get_inst_coverage()));
		print_row("empty / full",          pct(cg_fifo.cp_empty_full.get_inst_coverage()));
		print_row("fifo count (0~3)",      pct(cg_fifo.cp_queue_st.get_inst_coverage()));
		print_row("push/pop x empty/full", pct(cg_fifo.cx_op_st.get_inst_coverage()));
		print_row("Depth x Push / Pop", pct(cg_fifo.cx_op_st_fifo_depth.get_inst_coverage()));
		$display("+==========================================================+");
		$display("");
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
	for(int opt = 0; opt < 5; opt ++) begin
		env = new(fifo_if);
		env.run(20000, opt);
	end
	$finish;

end





endmodule
