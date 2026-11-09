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
	event gen_next_evt;
	
	function new(mailbox #(transaction) gen2drv_mbox, event gen_next_evt);
		
		this.gen_next_evt =gen_next_evt;
		this.gen2drv_mbox =gen2drv_mbox;
	endfunction

	bit enable;


	task run(int run_count);
		repeat(run_count)begin
			tr = new();
			tr.randomize();
			gen2drv_mbox.put(tr);
			$display("=========================================================================");
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
			tr.debug_print("DRV"); 
			ram_vif.we = tr.we;
			ram_vif.addr = tr.addr;
			ram_vif.wdata = tr.wdata;
			->>mon_next_evt; // nba tiggered  혼합해서 못사용함

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
				wait(mon_next_evt.triggered);    // blockng assignment 
				@(posedge ram_vif.clk);
				tr = new();
				tr.rdata = ram_vif.rdata ;
				tr.we	=   ram_vif.we ;   
				tr.addr	= ram_vif.addr  ;
				tr.wdata=	ram_vif.wdata ;
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
	virtual ram_interface ram_vif;

	function new(mailbox #(transaction) mon2scb_mbox, virtual ram_interface ram_vif, event gen_next_evt);
		this.ram_vif	  =  ram_vif;
		this.mon2scb_mbox = mon2scb_mbox;
		this.gen_next_evt = gen_next_evt;
	endfunction 
	
	logic [7:0] expected_rdata [0:63];
		
	int total_count; 
	int write_count;
	int read_count;
	int pass_count;
	int fail_count;

	// 주소 커버리지 : 쓴 뒤에 read로 비교까지 끝난 주소 수
	bit written [0:63];
	bit checked [0:63];
	int checked_count;
	bit done;



	task run();

		forever begin
		
			mon2scb_mbox.get(tr);
			tr.debug_print("SCB");
			total_count ++;

		if(tr.we)begin
			expected_rdata[tr.addr] = tr.wdata;
			written[tr.addr] = 1;
			write_count ++;
		end
		
		else begin
			read_count ++; 

			if(written[tr.addr] && !checked[tr.addr])begin
					checked[tr.addr] = 1;
					checked_count ++;
					if(checked_count == 64) done = 1;
			end

			if(expected_rdata[tr.addr] === tr.rdata)begin
						pass_count ++;

						//$display("=========================================================================");
						//$display("%t  PASS : count  = %d  / expected_rdata = %d",$time,tr.count,expected_count);
						//$display("=========================================================================");

			end

			else begin
						fail_count ++;
						$display("=========================================================================");
						$display("%t  FAIL : tr.rdata  = %d  / expected_rdata = %d",$time,tr.rdata,expected_rdata[tr.addr]);
						$display("=========================================================================");
			end

	
		end

		->gen_next_evt;

	end
	endtask

	task report();


		$display("");
		$display("+--------------------------------------------------+");
		$display("|                V2 TEST  REPORT                   |");
		$display("+--------------------------------------------------+");
		$display("|  total test = %5d                              |", total_count);
		$display("|  pass count = %5d                              |", pass_count);
		$display("|  fail count = %5d                              |", fail_count);
		$display("+--------------------------------------------------+");
		$display("| read  count = %5d                              |", read_count);
		$display("| write count = %5d                              |", write_count);
		$display("+--------------------------------------------------+");
		$display("| addr check  = %5d / 64                         |", checked_count);
		$display("| all checked = %s                                |", done ? "YES" : "NO ");
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
	event mon_next_evt;

	function new(virtual ram_interface ram_vif);
	
		
		gen2drv_mbox = new();
		mon2scb_mbox = new();
		gen = new(gen2drv_mbox,gen_next_evt);
		drv = new(gen2drv_mbox,ram_vif,mon_next_evt);
		mon = new(mon2scb_mbox,ram_vif,mon_next_evt);
		scb = new(mon2scb_mbox,ram_vif,gen_next_evt);

	endfunction

	task run(int run_count);  // argument 선언
		
		fork
			gen.run(run_count);
			drv.run();
			mon.run();
			scb.run();
			wait(scb.done);		// 64개 주소 확인이 끝나면 join_any 통과 (run_count는 상한선)
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
	env.run(5000);
	$finish;

end





endmodule
