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
			tr = new;
			tr.randomize();
			tr.debug_print("GEN");
			gen2drv_mbox.put(tr);
	endtask

endclass


/////////////////////////////////////////////////////////////////////////////
class driver;

	transaction tr;
	mailbox #(transaction) gen2drv_mbox;
	event drv2mon_evt;



	virtual adder_interface adder_if_v;

	function new(mailbox #(transaction) gen2drv_mbox,  virtual adder_interface adder_if_v, event drv2mon_evt);
		this.adder_if_v = adder_if_v;
		this.gen2drv_mbox = gen2drv_mbox;
		this.drv2mon_evt = drv2mon_evt;
	
	endfunction

	task run();
		begin
			gen2drv_mbox.get(tr);
			tr.debug_print("DRV");

			adder_if_v.a = tr.a;
			adder_if_v.b = tr.b;
			adder_if_v.mode = tr.mode;
			#10;
			->drv2mon_evt; // 이벤트를 발생 시켜라 
		end
	
	endtask

endclass



class monitor;

	transaction tr;
	virtual adder_interface adder_if_v;
	
	mailbox #(transaction) mon2scb_mbox;
	event drv2mon_evt; // 
	


	function new( mailbox#(transaction) mon2scb_mbox ,virtual adder_interface adder_if_v,event drv2mon_evt);

	
		this.mon2scb_mbox = mon2scb_mbox; // argument 선언 x this로 할 수 있다. 현재 객체 내부의 핸들 - this -> 변수 이름을 같게 할 수 있어서 편하다 
		this.adder_if_v = adder_if_v;// this + . -> '.' 연결자 
		this.drv2mon_evt = drv2mon_evt;




	endfunction
	

	task run();

			begin
			//event 
			@(drv2mon_evt);  // -> 'wait(drv2mon_evt)' 이렇게 쓸 수도 있다 

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
class environment;

	generator gen;
	driver drv;
	monitor mon;

	event drv2mon_evt;
	mailbox #(transaction) gen2drv_mbox;
	mailbox #(transaction) mon2scb_mbox; 


	function new(virtual adder_interface adder_if_v);
		gen2drv_mbox = new;
		gen = new(gen2drv_mbox);
		drv = new(gen2drv_mbox, adder_if_v,drv2mon_evt);
		mon = new(mon2scb_mbox,adder_if_v,drv2mon_evt);
	endfunction

	task run();
		repeat(10)begin
			gen.run();
			drv.run();
			mon.run();
		end

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
	env.run();

	$finish;
end

endmodule
