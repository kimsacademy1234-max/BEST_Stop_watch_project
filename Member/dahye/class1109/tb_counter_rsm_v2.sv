
`timescale 1ns / 1ps



/////////////////////////////////////////////////////////////////////////////
interface cnt_interface(input clk);


logic reset;
logic run_stop;
logic mode;
logic clear;
logic [7:0]  count;

	property rst_zero;
	
		@(posedge clk) reset |=>(count == 8'd0); //reset 이 1일때, 카운트는 0이어야 한다

	endproperty


		a_rst_zero : assert property(rst_zero)
		else begin
			$display("[INTERFACE] reset = %d  counter value error !! %d ",reset,count);
		end




endinterface


/////////////////////////////////////////////////////////////////////////////


class transaction;

rand bit reset;
randc bit run_stop;   // randc 쓰면 5:5, 쓰면 dist 조작이 안된다.
rand bit mode;
rand bit clear;
logic [7:0] count;
// run_stop_hold 

rand int unsigned run_stop_hold;   // 음수가 나오면 안되므로, unsigned 선언 



constraint reset_dist{		 
		reset dist{
			0:/ 9,
			1:/ 1
		};

}

constraint mode_dist{		 
		mode dist{
			0:/ 9,
			1:/ 1
		};
}


constraint clear_dist{		
		clear dist{
			0:/ 9,
			1:/ 1
		};
}


constraint run_stop_hold_range{
		run_stop_hold inside {[3:16]};
}




	function void debug_print(string name);
		$display("%t :[%s] reset = %d , run_stop = %d ,mode = %d, clear = %d , count= %d, run_stop_hold = %d ",$time,name,reset,run_stop,mode,clear,count,run_stop_hold);
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

	bit enable ;
	bit prv_reset;
	bit prv_clear;
	bit prv_mode;
	bit prv_run_stop;




	task run();
		
			while(enable)begin
			
				tr = new();
				tr.randomize(); 
				gen2drv_mbox.put(tr);
				tr.debug_print("GEN");
				@(gen_next_evt);
			end
		
	endtask

endclass


/////////////////////////////////////////////////////////////////////////////
//
//									02_DRIVER
//
/////////////////////////////////////////////////////////////////////////////

class driver;

    transaction tr;
	mailbox #(transaction) gen2drv_mbox;

	event gen_next_evt;	
	virtual cnt_interface cnt_vif;


	function new( virtual cnt_interface cnt_vif,
								event gen_next_evt, mailbox #(transaction) gen2drv_mbox);
		

		this.cnt_vif = cnt_vif;
		this.gen_next_evt =gen_next_evt;
		this.gen2drv_mbox = gen2drv_mbox;

	endfunction

	task preset();
			cnt_vif.reset = 1;
			cnt_vif.mode = 0;
			cnt_vif.clear = 0;
			cnt_vif.run_stop = 0;
			
			@(negedge cnt_vif.clk);
            $display("%t",$time);
		@(negedge cnt_vif.clk);
			
            $display("%t",$time);
			cnt_vif.reset = 0;
	endtask


	task run();
		forever begin
			gen2drv_mbox.get(tr);
			tr.debug_print("DRV");
			
			cnt_vif.mode = tr.mode;
			cnt_vif.reset = tr.reset;
			cnt_vif.clear = tr.clear;
			cnt_vif.run_stop = tr.run_stop;


			repeat(tr.run_stop_hold-1)begin

			@(negedge cnt_vif.clk);

			cnt_vif.mode = tr.mode;
			cnt_vif.reset = tr.reset;
			cnt_vif.clear = tr.clear;
			cnt_vif.run_stop = tr.run_stop;
			end
			->gen_next_evt;



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
	virtual cnt_interface cnt_vif;


	function new( mailbox#(transaction) mon2scb_mbox ,
					virtual cnt_interface cnt_vif	
					);
	
		this.mon2scb_mbox = mon2scb_mbox;  
		this.cnt_vif = cnt_vif;

	endfunction
	

	task run();

			forever begin
				@(posedge cnt_vif.clk);
                #1;
				tr = new();
				tr.mode = cnt_vif.mode ;
				tr.reset = cnt_vif.reset ;
				tr.clear = cnt_vif.clear ;
				tr.run_stop = cnt_vif.run_stop;
				tr.count = cnt_vif.count;
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
	virtual cnt_interface cnt_vif;


	function new(mailbox #(transaction) mon2scb_mbox);
		this.mon2scb_mbox = mon2scb_mbox;
	endfunction 
	
	logic [7:0] expected_count=0;
	int pass_cnt=0;
	int fail_cnt=0;
	int total_cnt =0;

	int pass_cnt_f [0:7];		
	int fail_cnt_f [0:7];
	int reset_cnt ;

	task run();

		forever begin
		
			mon2scb_mbox.get(tr);
			tr.debug_print("SCB");
		
			total_cnt ++;
			

			if(tr.reset|tr.clear) begin expected_count = 0;
										reset_cnt ++;	
			end


			else begin

				if(tr.run_stop)begin
					if(tr.mode) expected_count --;
					else		expected_count ++;
				end

			end



			if(expected_count == tr.count)begin
						pass_cnt ++;
						pass_cnt_f[{tr.run_stop,tr.mode,tr.clear}] ++;

						//$display("=========================================================================");
						//$display("%t  PASS : count  = %d  / expected_count = %d",$time,tr.count,expected_count);
						//$display("=========================================================================");

			end

			else begin
						fail_cnt ++;
						fail_cnt_f[{tr.run_stop,tr.mode,tr.clear}] ++;
						$display("=========================================================================");
						$display("%t  FAIL : count  = %d  / expected_count = %d",$time,tr.count,expected_count);
						$display("=========================================================================");
			end

		end
	

	endtask

	task report();

		string action;

		$display("");
		$display("+--------------------------------------------------+");
		$display("|                   TEST  REPORT                   |");
		$display("+--------------------------------------------------+");
		$display("|  total test = %5d                              |", total_cnt);
		$display("|  pass count = %5d                              |", pass_cnt);
		$display("|  fail count = %5d                              |", fail_cnt);
		$display("+--------------------------------------------------+");
		$display("| reset count = %5d                              |", reset_cnt);
		$display("+--------------------------------------------------+");
		$display("|               CASE  PASS / FAIL                  |");
		$display("+----------+------+-------+--------+-------+-------+");
		$display("| run_stop | mode | clear | action |  pass |  fail |");
		$display("+----------+------+-------+--------+-------+-------+");

		for(int i = 0; i < 8; i++)begin

			// 조합별 동작 이름 (모두 5글자로 맞춤)
			if(i[0])        action = "CLEAR";	// clear = 1
			else if(!i[2])  action = "STOP ";	// run_stop = 0
			else if(i[1])   action = "DOWN ";	// mode = 1
			else            action = "UP   ";	// mode = 0

			$display("|    %b     |  %b   |   %b   | %s  | %5d | %5d |",
					 i[2], i[1], i[0], action, pass_cnt_f[i], fail_cnt_f[i]);

		end

		$display("+----------+------+-------+--------+-------+-------+");
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

	function new(virtual cnt_interface cnt_vif);
	
		
		gen2drv_mbox = new();
		mon2scb_mbox = new();
		gen = new(gen2drv_mbox,gen_next_evt);
		drv = new(cnt_vif,gen_next_evt,gen2drv_mbox);
		mon = new(mon2scb_mbox,cnt_vif);
		scb = new(mon2scb_mbox);

	endfunction

	task run();  // argument 선언
		
			drv.preset();
			gen.enable = 1; 
		fork
			gen.run();
			drv.run();
			mon.run();
			scb.run();
		join_none

			#3000;
			gen.enable = 0 ;
			#1;
			scb.report();

			disable fork;

	endtask

endclass



/////////////////////////////////////////////////////////////////////////////



module tb_counter_rsm();


logic clk = 0 ;

cnt_interface cnt_if(clk); 
environment env;


counter_rsm DUT(


.i_clk			(cnt_if.clk), 
.i_reset		(cnt_if.reset),
.i_run_stop		(cnt_if.run_stop),
.i_mode 		(cnt_if.mode),
.i_clear 		(cnt_if.clear),
.o_count		(cnt_if.count)


);

always #5 clk = ~clk;

initial begin
	
	$timeformat(-9,0,"ns",0);
	env = new(cnt_if);
	env.run();
	$finish;

end





endmodule
