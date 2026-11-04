`timescale 1ns / 1ps


/////////////////////////////////////////////////////////////////////////////
interface adder_interface();

	logic [7:0] a;
	logic [7:0] b;
	logic       mode;
	logic [7:0] s;
	logic       c;

endinterface


/////////////////////////////////////////////////////////////////////////////
class transaction;

	rand bit [7:0] a;
	rand bit [7:0] b;
	rand bit       mode;

	logic [7:0]  s;
	logic 		c;

// 제약 조건
	constraint adder_limit{
		a > 128;
		b < 64;
	}

	constraint adder_inside{
		a inside {128,200,212,250};  // {[128:200]} -> 이렇게 특정 범위 안의 값으로 지정 가능
	}
	
	
	constraint adder_distribute{
		mode dist{
			0:/80,
			1:/20
			};
		}


	function debug_print(string name);
		$display("%t :[%s] a =%d, b = %d, mode = %d, s = %d, c = %d",$time,name,a,b,mode,s,c);
	endfunction

endclass


/////////////////////////////////////////////////////////////////////////////
class generator;

	transaction tr;
	mailbox #(transaction) gen2drv_mbox;

	function new(mailbox #(transaction) gen2drv_mbox_a);
		gen2drv_mbox = gen2drv_mbox_a;
	endfunction

	task run();
		begin
			tr = new;
			tr.randomize();
			tr.debug_print("GEN");
			gen2drv_mbox.put(tr);
		end
	endtask

endclass


/////////////////////////////////////////////////////////////////////////////
class driver;

	transaction tr;
	mailbox #(transaction) gen2drv_mbox;



	virtual adder_interface adder_if_v;

	function new(mailbox #(transaction) gen2drv_mbox,  virtual adder_interface adder_if_v);
		this.adder_if_v = adder_if_v;
		this.gen2drv_mbox = gen2drv_mbox;
	
	endfunction

	task run();
		begin
			gen2drv_mbox.get(tr);
			tr.debug_print("DRV");

			adder_if_v.a = tr.a;
			adder_if_v.b = tr.b;
			adder_if_v.mode = tr.mode;
			#10;
		end
	
	endtask

endclass


/////////////////////////////////////////////////////////////////////////////

class monitor;

	transaction tr;
	virtual adder_interface adder_if_v;
	
	mailbox #(transaction) mon2scb_mbox;
	


	function new( mailbox#(transaction) mon2scb_mbox ,virtual adder_interface adder_if_v);

	
		this.mon2scb_mbox = mon2scb_mbox; // argument 선언 x this로 할 수 있다. 현재 객체 내부의 핸들 - this -> 변수 이름을 같게 할 수 있어서 편하다 
		this.adder_if_v = adder_if_v;// this + . -> '.' 연결자 

	endfunction
	

	task run();

			begin

			//tr 생성

			tr = new;
			tr.a = adder_if_v.a;
			tr.b = adder_if_v.b;
			tr.s = adder_if_v.s;
			tr.mode = adder_if_v.mode;
			tr.c = adder_if_v.c;
			tr.debug_print("MON"); // Transaction 객체에 현재 찍힌 값이 뭔지 알 수 있다.
			
			mon2scb_mbox.put(tr); // monitor에서 생성해서 mailbox로 넣어줌 
			
			end

	endtask 


endclass

///////////////////////////////////////////////////////////////////////////////


class scoreboard;
	
	transaction tr;
	mailbox #(transaction) mon2scb_mbox;
	
	function new(mailbox #(transaction) mon2scb_mbox);

		this.mon2scb_mbox = mon2scb_mbox;

	endfunction 
	
		bit [7:0] expected_s;
		bit expected_c;
		int pass_cnt,fail_cnt;


	task run();

		// get transaction 

		mon2scb_mbox.get(tr);

		if(tr.mode)
		{expected_c, expected_s} =  tr.a - tr.b;
		
		else 
		{expected_c, expected_s} =  tr.a + tr.b;
		//pass/ fail


		if({expected_c, expected_s} == {tr.c,tr.s})begin 
			$display("%t : pass ",$time);
			
			pass_cnt ++;
	

		end else begin

			$display("fail");
			tr.debug_print("SCB");

			fail_cnt ++;

		end
	endtask

endclass

///////////////////////////////////////////////////////////////////////////////
class environment;

	generator gen;
	driver drv;
	monitor mon;
	scoreboard scb;


	mailbox #(transaction) gen2drv_mbox;
	mailbox #(transaction) mon2scb_mbox; 


	function new(virtual adder_interface adder_if_v);
		gen2drv_mbox = new;
		mon2scb_mbox = new;
		gen = new(gen2drv_mbox);
		drv = new(gen2drv_mbox, adder_if_v);
		mon = new(mon2scb_mbox,adder_if_v);
		scb = new(mon2scb_mbox);


	endfunction

	task run(int run_count);  // argument 선언
		repeat(run_count)begin
			gen.run();
			drv.run();
			mon.run();
			scb.run(); 
		end

	
		$display("pass count = %d",scb.pass_cnt);
		$display("fail count = %d",scb.fail_cnt);

	endtask

endclass

/////////////////////////////////////////////////////////////////////////////

module tb_adder();

adder_interface adder_if();
environment env;

adder dut(
	.a(adder_if.a),
	.b(adder_if.b),
	.s(adder_if.s),
	.c(adder_if.c),
	.mode(adder_if.mode)
);

initial begin
	$timeformat(-9,0,"ns",0);
	env = new(adder_if);
	env.run(10);

	$finish;
end

endmodule
