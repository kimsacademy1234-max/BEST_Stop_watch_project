`timescale 1ns / 1ps



// 객체지향 하는 이유 - 재사용성, 동적 할당 ( 리소스 관리가 된다) , 동시 처리 연산이 가능하다 ( 에러 처리,드라이브)
// 한번 셋업해놓으면 다양한 패턴으로 입력을 넣을 수 있다. 


interface adder_interface();

	logic [7:0] a;
	logic [7:0] b;
	logic       mode;
	logic [7:0] s;
	logic       c;

endinterface


class transaction; // -> 벡터, 스티뮬러스를 생성하기위한 사용자 객체  //동적할당이 가능하다 

	//drive 
	// rand : randomize() 기능 - 'rand' KeyWord 있는 변수만 random값을 생성한다. 

	rand bit [7:0] a;
	rand bit [7:0] b;
	rand bit       mode;


	//monitor - 출력 값은 4상태가 나올 수 있으므로, logic 선언
	logic [7:0]  s;
	logic 		c;
	


	function debug_print(string name);

	$display("%t :[%s] a =%d, b = %d, mode = %d, s = %d, c = %d",$time,name,a,b,mode,s,c);


	endfunction





endclass 



//generator
// 객체 선언 - 26bit 짜리 자료형이 선언이 되나? PC메모리엔 어떤 일이 일어나냐
// 답 : 바로 메모리에 할당이 안된다(아직 실체가 없다) - tr은 'handle 변수' -> 동적 할당할 때 비로소 메모리에 생긴다 ( 'new')
// 정적할당 -> 프로그램 실행시, 이미 위치가 지정되고, 바뀌지 않는다.(리소스를 계속 잡고 있다)
// 동적할당 -> 객체 할당시 메모리를 잡았다가 생겼다가 한다
// 생성하기 전에 handle을 선언해야한다. -> ex) transaction tr
// function new -> 


class generator;
	
	transaction tr;
	mailbox #(transaction) gen2drv_mbox;




	function new(mailbox #(transaction) gen2drv_mbox_a);// argument 
		gen2drv_mbox = gen2drv_mbox_a; 
	endfunction 



	task run();
		// tr의 랜덤 스티뮬러스 - class 기본제공 function 
		//dr -> a,b를 어떻게 드라이브 할 것인가. -> 가상 인터페이스로 연결해야한다. 이건 SW 따라서 Virtual 키워드를 써야한다. 

		repeat(100) begin		
		tr = new; 
		tr.randomize();
		tr.debug_print("GEN");
		gen2drv_mbox.put(tr);
		end

	endtask


endclass	



class driver;
	
	transaction tr;   // generator가 저장한 메모리 주소를 가져와야 하기 때문에 핸들러가 있어야 한다 
	mailbox #(transaction) gen2drv_mbox; 


	virtual adder_interface adder_if_v; // interface는 하드웨어이기 때문에 virtual 핸들링 
	function new(mailbox #(transaction) gen2drv_mbox_a,  virtual adder_interface adder_if_v_a);// () 안에는 실제 인터페이스가 들어와야함 

		adder_if_v = adder_if_v_a; // 실제 하드웨어로 연결 ( connection)
		gen2drv_mbox = gen2drv_mbox_a;

	endfunction 



	task run();
		// tr의 랜덤 스티뮬러스 - class 기본제공 function 
		//dr -> a,b를 어떻게 드라이브 할 것인가. -> 가상 인터페이스로 연결해야한다. 이건 SW 따라서 Virtual 키워드를 써야한다. 

		forever begin
			gen2drv_mbox.get(tr);
			tr.debug_print("DRV");
	
			adder_if_v.a = tr.a;
			adder_if_v.b = tr.b;
			adder_if_v.mode = tr.mode;
		

			#10;

		end

	endtask



endclass 



class environment;


	generator gen;
	driver drv;
	mailbox #(transaction) gen2drv_mbox; 
	
	
	function new(virtual adder_interface adder_if_v);

		gen2drv_mbox = new; 
		gen = new(gen2drv_mbox);
		drv = new(gen2drv_mbox, adder_if_v); 

	endfunction 


	task run();

		forever begin

			gen.run();
			drv.run();
	

		end


	endtask 




endclass 





module tb_adder();

// interface 인스턴스 (모듈처럼 생성, 뒤에 () 필수)
adder_interface adder_if();
environment env;




adder dut(

.a(adder_if.a),     //  . -> 접근 연산자. adder_if 안에 있는 a로
.b(adder_if.b),
.s(adder_if.s),
.c(adder_if.c),
.mode(adder_if.mode)


);


initial begin


	$timeformat(-9,0,"ns",0);
	env = new(adder_if);
	env.run();

	



// 변수 선언을 for 문 안에서 선언 할 수 있음 ++ 도 지원이 가능하다

/*	for(int i =0 ; i <256; i++)begin
		adder_if.a = i;
		adder_if.b=  256-i;
		adder_if.mode = 0;
		#10;
	end*/

	$finish;

end


endmodule
