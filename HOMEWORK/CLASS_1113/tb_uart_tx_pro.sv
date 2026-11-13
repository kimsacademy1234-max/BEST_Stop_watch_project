`timescale 1ns / 1ps



/////////////////////////////////////////////////////////////////////////////
interface uart_interface(input clk);

logic       rst;
logic       tx_start;
logic [7:0] tx_data;
logic       tx;
logic       tx_busy;







endinterface


/////////////////////////////////////////////////////////////////////////////


class transaction;

 rand logic [7:0] tx_data;
 logic tx;
 logic rst;
 logic tx_busy;
 logic tx_start;

 rand int unsigned  interval; // 구간은 양수이므로 unsigned로 선언해야함.  
 bit frame_error;
 bit stop_error;
 longint all_frame;


constraint tx_data_gen{tx_data inside{[0:255]};}
constraint interval_range{interval < 1042;}

function void debug_print(string name);
	$display("%t :[%s] reset =  %d , start = %d , tx_data = %d , interval = %d , tx_busy =  %d"
				,$time,name,rst,tx_start,tx_data,interval,tx_busy);

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



	task run(int run_count);
		repeat(run_count) begin
			tr = new();
			tr.randomize();
			tr.rst = 0; 
			tr.tx_start = 0; 
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
	virtual uart_interface uart_vif;

	covergroup cp_gen;

		cp_interval : coverpoint tr.interval iff(!uart_vif.tx_busy) {

			bins zero = {0};
			bins interval = {[1:1041]};
		}



	endgroup 


	task drv_report();


		$display(" inteval coverage for 0 " );		
		$display("+----------------------------------------------------------+");
		$display(" interval 0  = %2.1f %% " , cp_gen.cp_interval.get_coverage());
		$display("+----------------------------------------------------------+");


	endtask





	function new( mailbox #(transaction) gen2drv_mbox,virtual uart_interface uart_vif); 
	
		this.uart_vif = uart_vif;
		this.gen2drv_mbox = gen2drv_mbox;
		this.cp_gen =new; 
	endfunction



	task preset();
		
	uart_vif.rst = 1;
	uart_vif.tx_data = 0;
	uart_vif.tx_start = 0;
	repeat(2) @(negedge uart_vif.clk);
	uart_vif.rst = 0;

	endtask

	int  busy_check; 

	task run();
		forever begin
			@(negedge uart_vif.clk);
			busy_check = 0;
			gen2drv_mbox.get(tr);
			cp_gen.sample();
			tr.debug_print("DRV");
			//check tx_busy
			
			while(uart_vif.tx_busy)begin
				@(negedge uart_vif.clk);
				busy_check ++;
				if(busy_check > 10416*10)begin

					$display("tx_busy hige was too long");
					break;
				end

			end

			//tx_busy
			if(!uart_vif.tx_busy) begin
				repeat(tr.interval+1) @(negedge uart_vif.clk);
				uart_vif.rst = 0; 
				uart_vif.tx_start = 1;
				uart_vif.tx_data = tr.tx_data; 
				@(negedge uart_vif.clk);
				uart_vif.tx_start = 0;
				uart_vif.tx_data = 8'hxx; 
			end

		end
	endtask















	
endclass

/////////////////////////////////////////////////////////////////////////////
//
//									03_MONITOR
//
/////////////////////////////////////////////////////////////////////////////


class monitor;

	transaction tr_in , tr_out;
	mailbox #(transaction) mon2scb_in;
	mailbox #(transaction) mon2scb_out;
	virtual uart_interface uart_vif;
	parameter BAUD_TIME = 10416*10; // 
	parameter FRAME_TIME = BAUD_TIME * 10;
	


	function new( mailbox#(transaction) mon2scb_in,mailbox #(transaction) mon2scb_out,
					virtual uart_interface uart_vif
					);
	
		this.mon2scb_in = mon2scb_in;  
		this.mon2scb_out = mon2scb_out;  
		this.uart_vif = uart_vif;

	endfunction

	longint end_busy_time;
	longint start_time;
	longint stop_time;
 	longint stop_start;
	longint end_time; 
	longint start_frame;

	longint n_stop_time; 



	task uart_receive(output logic [7:0] receive_data);

			@(posedge uart_vif.clk);

			#(BAUD_TIME/2);
			
			for(int i=0; i< 8; i++)begin 
		
			#(BAUD_TIME);
			receive_data[i] = uart_vif.tx;

			end

			#(BAUD_TIME/2);
		
			

	endtask

	task check_start_frame(output start_frame_error);
					 start_frame_error = 0;
			@(posedge uart_vif.clk);
			start_time = $time;
		
				#1;
				while(uart_vif.tx == 0 & (end_time-start_time)<= BAUD_TIME )begin //tx 가 바뀌어도 탈출, baud_time 이상이면 탈출 
					end_time = $time; // 시간 값 계산
					@(posedge uart_vif.clk);
				end

				if( end_time - start_time <  BAUD_TIME*(15/16))begin 
					start_frame_error = 1;
					start_frame = start_time-end_time;
					
					$display(" start_frame" ,start_time);
					$display(" end_frame" ,end_time);
					$display(" start_frame_err" , start_frame);
				end

		
	endtask



	task check_end_frame(output end_frame_error);

				
				end_frame_error = 0; 
			    stop_time = $time;
				

			while((!uart_vif.tx)&((stop_start - stop_time) <= BAUD_TIME/2))begin
					@(posedge uart_vif.clk);	
					stop_start = $time;
			end


			while((uart_vif.tx) & ((stop_start-stop_time <= BAUD_TIME)) & (uart_vif.tx_busy))begin
					@(posedge uart_vif.clk);	
					stop_start  = $time; 	
		
			end


			if( (stop_start - stop_time)< BAUD_TIME *(15/16)) begin
					
					end_frame_error = 1;
					$display("==================================================");
					$display(" end_frame_err" , stop_start - stop_time);

			end


	endtask





	task run();

		forever begin

			//1.wait start check
			@(posedge uart_vif.clk);
			while(!uart_vif.tx_start)begin
					@(posedge uart_vif.clk);
			end

			tr_in = new;
			tr_in.tx_data = uart_vif.tx_data; 
			tr_in.tx_busy = uart_vif.tx_busy;
			mon2scb_in.put(tr_in);
			tr_in.debug_print("MON-IN");
			tr_out = new;

			fork 
			uart_receive(tr_out.tx_data);
			check_start_frame(tr_out.frame_error);
			join 
			
			check_end_frame(tr_out.stop_error); 
		
			tr_out.interval  = ((start_time - n_stop_time)/10)-2;
			$display("interval =  %4d ", tr_out.interval);
			tr_out.all_frame = stop_start - start_time; 
			tr_out.rst = uart_vif.rst;
			tr_out.tx_busy = uart_vif.tx_busy;
			tr_out.tx = uart_vif.tx;

			n_stop_time = stop_start; 
			mon2scb_out.put(tr_out);
			tr_out.debug_print("MON-OUT");
			
		end
			


	endtask 


endclass


/////////////////////////////////////////////////////////////////////////////
//
//									04_SCOREBOARD
//
/////////////////////////////////////////////////////////////////////////////

class scoreboard;
	
	transaction tr_in , tr_out;
	mailbox #(transaction) mon2scb_in;
	mailbox #(transaction) mon2scb_out;
	event gen_next_evt;


	parameter BAUD_FRAME = 10416*10*10; 

	covergroup cg_uart;

			option.per_instance = 1; 
			
			cp_tx_data_coner : coverpoint tr_in.tx_data {

				bins coner[] = {8'h55,8'haa};

			}

			cp_tx_data : coverpoint tr_in.tx_data {

				bins data[] = {[0:255]};
				ignore_bins skip = {8'h55,8'haa}; 
	
			}



	endgroup



	function new(mailbox #(transaction) mon2scb_in, mailbox #(transaction) mon2scb_out,event gen_next_evt);
		this.mon2scb_in = mon2scb_in;
		this.mon2scb_out = mon2scb_out;
		this.gen_next_evt = gen_next_evt;
		this.cg_uart =  new;
	endfunction 



	int tx_data_total;
	int tx_data_pass;
	int tx_data_fail;
	
	int start_frame_fail;
	int start_frame_pass; 
	
	int frame_pass;
	int frame_fail;


	int stop_pass;
	int stop_fail;


	task check_frame(longint all_frame , bit start_frame_error, bit stop_error);

		if(start_frame_error) begin
			start_frame_fail ++; 
			$display("=================================================");
			$display(" 				START FRAME ERROR				");	
			$display("=================================================");
		
		end
		
		else begin
			start_frame_pass ++;

		end

		if(stop_error) begin
			stop_fail ++; 
			$display("=================================================");
			$display(" 				STOP FRAME ERROR				");	
			$display("=================================================");
		
		end
		
		else begin
			stop_pass ++;

		end

		if((all_frame <= BAUD_FRAME) &(all_frame >= BAUD_FRAME *(15/16)))begin 
			frame_pass ++; 
		end

		else begin
			frame_fail ++; 
			
			$display("=================================================");
			$display(" 				 ALL FRAME FAIL				");	
			$display("=================================================");
			$display(" frame_ num = %d " , all_frame);
	
		end

	endtask



	task run();
		forever begin
			mon2scb_in.get(tr_in);
			cg_uart.sample();
			tr_in.debug_print("SCB_in");

			mon2scb_out.get(tr_out);
			tr_out.debug_print("SCB_out");
			
			tx_data_total++;

			if(tr_in.tx_data === tr_out.tx_data)begin
					tx_data_pass ++; 
			end

			else begin
					$display("tx_data fail");
					tx_data_fail++; 
			end

			check_frame(tr_out.all_frame,tr_out.frame_error,tr_out.stop_error);


		-> gen_next_evt;
		end



	endtask 


	task report();

			$display("+----------------------------------------------------------+");
			$display("UART TX Verification ");
			$display("+----------------------------------------------------------+");
			$display("total            num = %4d " , tx_data_total);
			$display("tx_data pass     num = %4d " , tx_data_pass);
			$display("tx_data fail     num = %4d " , tx_data_fail);
			$display("+----------------------------------------------------------+");
			$display("start_frame_pass num = %4d", start_frame_pass);
			$display("start_frame_fail num = %4d", start_frame_fail);
			$display("stop_frame_pass  num = %4d", stop_pass);
			$display("stop_frame_fail  num = %4d", stop_fail);
			$display("frame_pass	   num = %4d", frame_pass);
			$display("frame_fail	   num = %4d", frame_fail);
			$display("+----------------------------------------------------------+");
			$display("DATA Coverage  ");
			$display("+----------------------------------------------------------+");
			$display("  ALL DATA  : %2.1f %% ",cg_uart.cp_tx_data.get_coverage());
			$display("  DATA [8'h00 / 8'h55 / 8'haa / 8'hFF  : %2.1f %% ",cg_uart.cp_tx_data_coner.get_coverage());
			$display("+----------------------------------------------------------+");

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
	mailbox #(transaction) mon2scb_in; 
	mailbox #(transaction) mon2scb_out; 
	mailbox #(transaction) gen2drv_mbox; 
	event gen_next_evt;

	function new(virtual uart_interface uart_vif);
	
		
		gen2drv_mbox = new();
		mon2scb_in = new();
		mon2scb_out = new();
		gen = new(gen2drv_mbox,gen_next_evt);
		drv = new(gen2drv_mbox,uart_vif);
		mon = new(mon2scb_in,mon2scb_out,uart_vif);
		scb = new(mon2scb_in,mon2scb_out,gen_next_evt);

	endfunction

	task run(int run_count);
	
			drv.preset();
	
		fork
			gen.run(run_count);
			drv.run();
			mon.run();
			scb.run();
		join_any


			#1;
			scb.report();
			drv.drv_report();	
			disable fork;

	endtask

endclass



/////////////////////////////////////////////////////////////////////////////



module tb_uart_tx();


logic clk = 0;

uart_interface uart_if(clk); 
environment env;




uart_tx DUT(

 .clk		(clk				),
 .rst		(uart_if.rst		),
 .tx_start	(uart_if.tx_start	),
 .tx_data	(uart_if.tx_data	),
 .tx		(uart_if.tx			),	
 .tx_busy	(uart_if.tx_busy	)

);

always #5 clk = ~clk;

initial begin
	
	$timeformat(-9,0,"ns",0);
	env = new(uart_if);
	env.run(5);
	




	$finish;

end





endmodule
