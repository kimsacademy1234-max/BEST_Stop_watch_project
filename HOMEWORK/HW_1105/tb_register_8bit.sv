`timescale 1ns / 1ps



/////////////////////////////////////////////////////////////////////////////
interface reg_interface(input clk);

	logic [7:0] d;
	logic [7:0] q;
	logic       reset;

endinterface


/////////////////////////////////////////////////////////////////////////////


class transaction;



	bit reset;
	rand bit [7:0] d;
	logic [7:0] q;


	function debug_print(string name);
		$display("%t :[%s] d =%d, q = %d ",$time,name,d,q);
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

	function new(mailbox #(transaction) gen2drv_mbox_a, event gen_next_evt);
		this.gen2drv_mbox = gen2drv_mbox_a;
		this.gen_next_evt = gen_next_evt ;
	endfunction



	task run(int run_count);  
		repeat(run_count) begin
			tr = new;
			tr.randomize();
			tr.debug_print("GEN");
			gen2drv_mbox.put(tr);
			@(gen_next_evt);	
			$display("%t : come gen next evt", $time);
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
	event mon_next_evt;

	virtual reg_interface reg_if_v;


	function new(mailbox #(transaction) gen2drv_mbox,  virtual reg_interface reg_if_v,event mon_next_evt);
		this.reg_if_v = reg_if_v;
		this.gen2drv_mbox = gen2drv_mbox;
		this.mon_next_evt = mon_next_evt ;
	endfunction

	task run();
		forever begin
			@(posedge reg_if_v.clk);
			gen2drv_mbox.get(tr);
			#1;
			reg_if_v.d = tr.d;   // DRIVE - D 
			-> mon_next_evt;
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
	virtual reg_interface reg_if_v;
	event mon_next_evt;


	function new( mailbox#(transaction) mon2scb_mbox ,
					virtual reg_interface reg_if_v,	
					event mon_next_evt);
	
		this.mon2scb_mbox = mon2scb_mbox;  
		this.reg_if_v = reg_if_v;
		this.mon_next_evt = mon_next_evt;

	endfunction
	

	task run();

			forever begin
				@(mon_next_evt);
				tr = new;




				mon2scb_mbox.







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

	function new(mailbox #(transaction) mon2scb_mbox
				 	,event gen_next_evt );


		this.mon2scb_mbox = mon2scb_mbox;
		this.gen_next_evt = gen_next_evt;
	endfunction 
	
	task run();



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

	mailbox #(transaction) gen2drv_mbox;
	mailbox #(transaction) mon2scb_mbox; 
	event gen_next_evt,mon_next_evt;


	function new(virtual reg_interface reg_if_v);

		gen2drv_mbox = new;
		mon2scb_mbox = new;
		gen = new(gen2drv_mbox,gen_next_evt);
		drv = new(gen2drv_mbox, reg_if_v,gen_next_evt);
		mon = new(mon2scb_mbox,reg_if_v,mon_next_evt);
		scb = new(mon2scb_mbox,gen_next_evt);

	endfunction




	task run(int run_count);  // argument 선언
		fork
			gen.run(run_count);
			drv.run();
			mon.run();
			scb.run();
		join_any

		$display("%t : end fork join", $time);
		#100;
		$display("pass count = %d",scb.pass_cnt);
		$display("fail count = %d",scb.fail_cnt);
	endtask

endclass



/////////////////////////////////////////////////////////////////////////////



module tb_register_8bit();


logic clk;

reg_interface reg_if(clk); 
environment env;


register_8bit DUT(
	 .i_clk(clk),
	 .i_reset(reg_if.reset),
	 .d_in(reg_if.d),
	 .q(reg_if.q)
);

always #5 clk = ~clk;

initial begin
	
	clk = 0;
	env = new(reg_if);
	$finish;

end





endmodule
