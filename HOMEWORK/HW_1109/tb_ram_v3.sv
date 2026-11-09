`timescale 1ns / 1ps



/////////////////////////////////////////////////////////////////////////////
interface ram_interface(input clk);


 logic [5:0] addr;
 bit we;
 logic [7:0] wdata;
 logic [7:0] rdata;



endinterface


/////////////////////////////////////////////////////////////////////////////


class transaction;




rand  bit [5:0] addr;
randc bit we;
rand  bit [7:0] wdata;
logic [7:0] rdata;


constraint addr_dist{		 
		addr inside{[0:63]};
}

constraint wdata_dist{		 
		wdata inside{[0:255]};
}






	function void debug_print(string name);
		$display("%t :[%s] addr = %d ,we = %d, wdata = %d , rdata= %d ",$time,name,addr,we,wdata,rdata);
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
	mailbox #(transaction) gen2scb_mbox;
	event gen_next_evt;



	function new(mailbox #(transaction) gen2scb_mbox,mailbox #(transaction) gen2drv_mbox, event gen_next_evt);
		
		this.gen2scb_mbox =gen2scb_mbox;
		this.gen_next_evt =gen_next_evt;
		this.gen2drv_mbox =gen2drv_mbox;
	endfunction

	bit enable;


	task run(int run_count);
		repeat(run_count)begin
			tr = new();
			tr.randomize();
			gen2drv_mbox.put(tr);
			gen2scb_mbox.put(tr);
			$display("=========================================================================");
			tr.debug_print("  GEN  ");
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

	event mon_next_evt;	
	virtual ram_interface ram_vif;


	function new( mailbox #(transaction) gen2drv_mbox,virtual ram_interface ram_vif,
								event mon_next_evt); 
		

		this.ram_vif = ram_vif;
		this.mon_next_evt =mon_next_evt;
		this.gen2drv_mbox = gen2drv_mbox;

	endfunction


	task run();
		forever begin
			@(negedge ram_vif.clk);
			gen2drv_mbox.get(tr);
			tr.debug_print("  DRV  "); 
			ram_vif.we = tr.we;
			ram_vif.addr = tr.addr;
			ram_vif.wdata = tr.wdata;
			->mon_next_evt; // nba tiggered  혼합해서 못사용함

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
	event mon_next_evt;
	virtual ram_interface ram_vif;


	function new( mailbox#(transaction) mon2scb_mbox ,
					virtual ram_interface ram_vif, event mon_next_evt
					);
	
		this.mon2scb_mbox = mon2scb_mbox;  
		this.ram_vif = ram_vif;
		this.mon_next_evt = mon_next_evt;
	endfunction
	

	task run();

			forever begin
				@(mon_next_evt);    // blockng assignment 
				@(posedge ram_vif.clk);
				#1;
				tr = new();
				tr.rdata = ram_vif.rdata ;
				tr.we	=   ram_vif.we ;   
				tr.addr	= ram_vif.addr  ;
				tr.wdata=	ram_vif.wdata ;
				mon2scb_mbox.put(tr);
				tr.debug_print("  MON  ");

			end

	endtask 


endclass


/////////////////////////////////////////////////////////////////////////////
//
//									04_SCOREBOARD
//
/////////////////////////////////////////////////////////////////////////////

class scoreboard;
	
	transaction tr_mon,tr_gen;
	mailbox #(transaction) mon2scb_mbox;
	mailbox #(transaction) gen2scb_mbox;
	event gen_next_evt;
	virtual ram_interface ram_vif;

	function new(mailbox #(transaction) gen2scb_mbox,mailbox #(transaction) mon2scb_mbox, virtual ram_interface ram_vif, event gen_next_evt);
		this.ram_vif	  =  ram_vif;
		this.mon2scb_mbox = mon2scb_mbox;
		this.gen2scb_mbox = gen2scb_mbox;
		this.gen_next_evt = gen_next_evt;
	endfunction 
	
	logic [7:0] expected_rdata [0:63];
		
	int total_count; 
	int write_count;
	int read_count;


	int t_pass_count;
	int t_fail_count;

	int r_pass_count;
	int r_fail_count;

	int w_pass_count;
	int w_fail_count;


	task run();

		forever begin
		

			gen2scb_mbox.get(tr_gen);
			tr_gen.debug_print("SCB-GEN");
			
			mon2scb_mbox.get(tr_mon);
			tr_mon.debug_print("SCB-MON");
			total_count ++;

		if(tr_gen.we)begin
			
			if(tr_gen.wdata == tr_mon.rdata)begin
					w_pass_count ++;
					t_pass_count ++;
			end
			
			else begin
					w_fail_count ++;
					t_fail_count ++;

			end	
			expected_rdata[tr_gen.addr] = tr_gen.wdata;
			write_count ++;
		end
		
		else begin

			read_count ++; 

			if(expected_rdata[tr_gen.addr] === tr_mon.rdata)begin
						r_pass_count ++;
						t_pass_count ++;

						//$display("=========================================================================");
						//$display("%t  PASS : count  = %d  / expected_rdata = %d",$time,tr.count,expected_count);
						//$display("=========================================================================");

			end

			else begin
						r_fail_count ++;
						t_fail_count ++;
						$display("=========================================================================");
						$display("%t  FAIL : tr.rdata  = %d  / expected_rdata = %d",$time,tr_mon.rdata,expected_rdata[tr_gen.addr]);
						$display("=========================================================================");
			end

	
		end

		->gen_next_evt;

	end
	endtask

	task report();


		$display("");
		$display("+--------------------------------------------------+");
		$display("|                   TEST  REPORT                   |");
		$display("+--------------------------------------------------+");
		$display("|  total test = %5d                              |", total_count);
		$display("|  pass count = %5d                              |", t_pass_count);
		$display("|  fail count = %5d                              |", t_fail_count);
		$display("+--------------------------------------------------+");
		$display("| read  count = %5d                              |", read_count);
		$display("| read  pass  = %5d                              |", r_pass_count);
		$display("| read  fail  = %5d                              |", r_fail_count);
		$display("+--------------------------------------------------+");
		$display("| write  count = %5d                             |", write_count);
		$display("| write  pass  = %5d                             |", w_pass_count);
		$display("| write  fail  = %5d                             |", w_fail_count);
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
	mailbox #(transaction) gen2scb_mbox; 
	event gen_next_evt;
	event mon_next_evt;
	event scb_next_evt;

	function new(virtual ram_interface ram_vif);
	
		
		gen2drv_mbox = new();
		mon2scb_mbox = new();
		gen2scb_mbox = new();

		gen = new(gen2scb_mbox,gen2drv_mbox,gen_next_evt);
		drv = new(gen2drv_mbox,ram_vif,mon_next_evt);
		mon = new(mon2scb_mbox,ram_vif,mon_next_evt);
		scb = new(gen2scb_mbox,mon2scb_mbox,ram_vif,gen_next_evt);

	endfunction

	task run(int run_count);  // argument 선언
		
		fork
			gen.run(run_count);
			drv.run();
			mon.run();
			scb.run();
		join_any

			scb.report();

			disable fork;

	endtask

endclass



/////////////////////////////////////////////////////////////////////////////



module tb_ram();


logic clk = 0 ;

ram_interface ram_if(clk); 
environment env;

ram DUT(
 .addr    (ram_if.addr),		
 .clk	  (ram_if.clk), 
 .we	  (ram_if.we),
 .wdata   (ram_if.wdata),
 .rdata   (ram_if.rdata)
);


always #5 clk = ~clk;

initial begin
	
	$timeformat(-9,0,"ns",0);
	env = new(ram_if);
	env.run(300);
	$finish;

end





endmodule
