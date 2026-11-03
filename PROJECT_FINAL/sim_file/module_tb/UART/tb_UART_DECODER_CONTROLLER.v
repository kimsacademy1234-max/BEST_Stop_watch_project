`timescale 1ns / 1ps


module tb_uart_decoder();


parameter BAUD_RATE = 100_000_000/9600*10;

parameter AUTO_FRQ  = 2000;    // 실제 5hz -> sim 에서는 2khz (50_000 clk) 로 빠르게
parameter SEND_CLK  = 40_000;  // sender 가 go 받고 busy 유지하는 clk 수 (auto tick 보다 살짝 짧게)


reg clk,rst;
reg rx;
reg [7:0] DATA_8BIT;          // 지금 보내는 1byte (Radix: ASCII)
reg [8*16-1:0] TX_TEXT;       // 지금까지 보낸 명령 문자열 (Radix: ASCII)
reg sender_busy;

reg btn_R, btn_L, btn_U, btn_D;   // 물리 버튼 (debounce 후 tick 이라고 가정)

     wire w_b_tick;
     wire w_error;         
   
     wire w_handshake;
     wire w_get;
     wire w_btn;
     wire w_mode;
     wire w_auto;
     wire [39:0] w_ascii;
     wire w_rx_empty;
     wire w_rx_full;
     wire w_rx_done;
     wire w_set;
     wire [7:0] w_rx_data;
     wire [7:0] w_pop_data;
     wire w_pop; 
     wire w_off_set;

     wire [6:0]  w_module_control_bit;
     wire [2:0]  w_send_sel;
     wire [23:0] w_for_sender_data;
     wire [23:0] w_sender_data;
     wire w_sender_go;
     wire w_uart_R, w_uart_L, w_uart_U, w_uart_D;

uart_rx U_UART_RX (
        .clk    (clk),
        .rst    (rst),
        .b_tick (w_b_tick),
        .rx     (rx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );


fifo#(
    .DEPTH(8),
    .BIT_WIDTH(8)

    )DUT_FIFO_RX(
.i_clk(clk), 
.i_reset(rst),
.push(w_rx_done),
.pop(w_pop),
.push_data(w_rx_data),
.pop_data(w_pop_data),
.full(w_rx_full),
.empty(w_rx_empty)
);

UART_ASCII_DECODER#(

    .BIT_WIDTH(8),
    .DATA_WIDTH(40)

)U_UART_ASCII_DECODER(
     
     .i_clk(clk),
     .i_reset(rst),
     .i_ascii(w_pop_data),
     .i_enable(~w_rx_empty),
     .o_error(w_error),
     .o_pop(w_pop),
     .o_handshake(w_handshake),
     .o_get(w_get),
	 .o_set(w_set),
	 .o_off_set(w_off_set),
     .o_btn(w_btn),
     .o_mode(w_mode),
     .o_auto(w_auto),
     .o_ascii(w_ascii)
  );


UART_CONTROLLER#(

    .BIT_WIDTH(8),
    .DATA_WIDTH(40),
    .AUTO_FRQ(AUTO_FRQ)

)U_UART_CONTROLLER(

     .i_error(w_error),
     .i_for_sender_data(w_for_sender_data),
     .i_handshake(w_handshake),
     .i_sender_busy(sender_busy),
     .i_clk(clk),
     .i_reset(rst),
     .i_con_ascii(w_ascii),
     .i_get(w_get),
     .i_btn(w_btn),
     .i_mode(w_mode),
     .i_auto(w_auto),
     .i_btn_R(btn_R),
     .i_btn_L(btn_L),
     .i_btn_U(btn_U),
     .i_btn_D(btn_D),
     .i_off_set(w_off_set),
     .i_set(w_set),
     .o_module_control_bit(w_module_control_bit),
     .o_send_sel(w_send_sel),
     .o_sender_data(w_sender_data),
     .o_sender_go(w_sender_go),
     .o_uart_R(w_uart_R),
     .o_uart_L(w_uart_L),
     .o_uart_U(w_uart_U),
     .o_uart_D(w_uart_D)
  );


    baud_tick_gen#(
        .BAUD_RATE(9600),
        .SAMPLING_RATE(16)

            )U_BAUD_TICK_GEN (
        .clk   (clk),
        .rst   (rst),
        .b_tick(w_b_tick)
    );



////////////////////////////////////// 모듈 출력 mux 모델 //////////////////////////////////////
// sel 별로 값이 다르게 보이도록 고정 data (0:SW 1:TM 2:WH 3:DIST 4:TEMP)
assign w_for_sender_data = (w_send_sel == 3'd0) ? 24'h11_11_11 :
                           (w_send_sel == 3'd1) ? 24'h22_22_22 :
                           (w_send_sel == 3'd2) ? 24'h33_33_33 :
                           (w_send_sel == 3'd3) ? 24'h44_44_44 :
                           (w_send_sel == 3'd4) ? 24'h55_55_55 : 24'h00_00_00;


////////////////////////////////////// sender 모델 //////////////////////////////////////
// go 받으면 다음 clk 부터 SEND_CLK 동안 busy
integer busy_cnt;

always@(posedge clk, posedge rst)begin
	if(rst)begin
		sender_busy <= 0;
		busy_cnt    <= 0;
	end
	else if(w_sender_go)begin
		sender_busy <= 1;
		busy_cnt    <= SEND_CLK;
	end
	else if(busy_cnt > 1) busy_cnt <= busy_cnt - 1;
	else begin
		sender_busy <= 0;
		busy_cnt    <= 0;
	end
end


////////////////////////////////////// scoreboard //////////////////////////////////////
// decoder 출력 (handshake / ascii / error) 만 보고 기댓값 만들어서 controller 출력이랑 비교
//  - error / get / btn : controller 가 handshake 받은 clk 에 바로 pend 에 넣으니까 바로 반영
//  - mode / auto       : controller state 가 1clk 뒤에 바뀌니까 1clk 늦게 반영 (upd_*)

localparam [3:0] EXP_NONE = 4'd15;   // auto 아님
localparam [3:0] EXP_ALL  = 4'd8;    // auto all

integer pass_cnt, fail_cnt;
integer exp_err_cnt;    // 아직 안 나간 error 개수
integer exp_get_cnt;    // 아직 안 나간 get 개수
integer exp_tick_cnt;   // 아직 안 나간 auto 차례 개수
reg [2:0] exp_mode_sel; // /mod 로 정해진 sel
reg [3:0] exp_auto;     // auto 일 때 보낼 sel (EXP_ALL / EXP_NONE)
reg [2:0] exp_scan;     // auto all 다음 차례
reg [3:0] exp_btn;      // {R,L,U,D} 나와야 하는 uart btn
time      exp_btn_t [3:0];

reg        upd_valid, upd_mode, upd_auto;
reg [39:0] upd_ascii;

wire w_phy_btn  = btn_R | btn_L | btn_U | btn_D;
wire [3:0] w_uart_btn = {w_uart_R, w_uart_L, w_uart_U, w_uart_D};

function [23:0] exp_data(input [2:0] sel);
	case(sel)
		3'd0 : exp_data = 24'h11_11_11;
		3'd1 : exp_data = 24'h22_22_22;
		3'd2 : exp_data = 24'h33_33_33;
		3'd3 : exp_data = 24'h44_44_44;
		3'd4 : exp_data = 24'h55_55_55;
		default : exp_data = 24'h00_00_00;
	endcase
endfunction

function string sel_name(input [2:0] sel);
	case(sel)
		3'd0 : sel_name = "SW";
		3'd1 : sel_name = "TM";
		3'd2 : sel_name = "WH";
		3'd3 : sel_name = "DIST";
		3'd4 : sel_name = "TEMP";
		3'd7 : sel_name = "ERR";
		default : sel_name = "??";
	endcase
endfunction

function string btn_name(input integer i);
	case(i)
		3 : btn_name = "R";
		2 : btn_name = "L";
		1 : btn_name = "U";
		default : btn_name = "D";
	endcase
endfunction

task check(input bit ok, input string msg);
begin
	if(ok)begin
		pass_cnt = pass_cnt + 1;
		$display("[%0t] [PASS] %s", $time, msg);
	end
	else begin
		fail_cnt = fail_cnt + 1;
		$display("[%0t] [FAIL] %s", $time, msg);
	end
end
endtask


always@(posedge clk)begin : SCOREBOARD

	reg [2:0] exp_sel;
	reg       ok;
	string    tag, why;
	integer   i;

	if(!rst)begin

	// ---------------- 1. sender go ----------------
	if(w_sender_go)begin
		why = "";
		if(w_send_sel == 3'd7)begin
			tag = "ERROR   "; exp_sel = 3'd7;
			ok  = (exp_err_cnt > 0);
			if(ok) exp_err_cnt = exp_err_cnt - 1;
			else   why = " (error 안 들어왔는데 sel 7)";
		end
		else if(exp_auto == EXP_NONE)begin
			tag = "GET     "; exp_sel = exp_mode_sel;
			ok  = (exp_get_cnt > 0);
			if(ok) exp_get_cnt = exp_get_cnt - 1;
			else   why = " (get 안 들어왔는데 go)";
		end
		else begin
			tag = (exp_auto == EXP_ALL) ? "AUTO_ALL" : "AUTO    ";
			exp_sel = (exp_auto == EXP_ALL) ? exp_scan : exp_auto[2:0];
			ok  = (exp_tick_cnt > 0);
			if(ok) exp_tick_cnt = exp_tick_cnt - 1;
			else   why = " (auto tick 없는데 go)";
			if(exp_auto == EXP_ALL) exp_scan = (exp_scan == 3'd4) ? 3'd0 : exp_scan + 1;
		end

		if(sender_busy) why = {why, " (sender busy 중에 go)"};

		check(ok && !sender_busy && (w_send_sel == exp_sel) && (w_sender_data == exp_data(exp_sel)),
		      $sformatf("%s exp sel=%0d(%s) data=%h | out sel=%0d(%s) data=%h%s",
		                tag, exp_sel, sel_name(exp_sel), exp_data(exp_sel),
		                w_send_sel, sel_name(w_send_sel), w_sender_data, why));
	end

	// ---------------- 2. uart btn ----------------
	if(|w_uart_btn && w_phy_btn)
		check(0, $sformatf("BTN      물리 btn(R%b L%b U%b D%b) 이랑 uart btn(R%b L%b U%b D%b) 같은 clk",
		                   btn_R, btn_L, btn_U, btn_D, w_uart_R, w_uart_L, w_uart_U, w_uart_D));

	for(i = 3; i >= 0; i = i - 1)begin
		if(exp_btn[i])begin
			if(!w_phy_btn)begin   // 물리 btn 없는 clk -> 이번 clk 에 나와야 함
				check(w_uart_btn[i],
				      $sformatf("BTN      exp uart %s | out uart %s=%b (요청 후 %0d clk, 물리 btn 대기 %0d clk)",
				                btn_name(i), btn_name(i), w_uart_btn[i],
				                ($time - exp_btn_t[i]) / 10, ($time - exp_btn_t[i]) / 10 - 1));
				exp_btn[i] = 0;
			end
		end
		else if(w_uart_btn[i])
			check(0, $sformatf("BTN      exp 없음 | out uart %s=1 (요청 안 했는데 출력)", btn_name(i)));
	end

	// ---------------- 3. 1clk 늦게 반영 (mode / auto) ----------------
	if(upd_valid)begin
		if(upd_mode)begin
			case(upd_ascii[31:0])
				"w_hm", "w_ms" : exp_mode_sel = 3'd2;
				"t_hm", "t_ms" : exp_mode_sel = 3'd1;
				"s_hm", "s_ms" : exp_mode_sel = 3'd0;
				"dist"         : exp_mode_sel = 3'd3;
				"temp"         : exp_mode_sel = 3'd4;
			endcase
		end
		if(upd_auto)begin
			case(upd_ascii[23:0])
				"_sw" : exp_auto = 4'd0;
				"_tm" : exp_auto = 4'd1;
				"_wh" : exp_auto = 4'd2;
				"dis" : exp_auto = 4'd3;
				"tem" : exp_auto = 4'd4;
				"all" : exp_auto = EXP_ALL;
				"off" : begin exp_auto = EXP_NONE; exp_tick_cnt = 0; end
			endcase
		end
		upd_valid = 0;
	end

	// ---------------- 4. 이번 clk decoder / tick 입력 ----------------
	if(w_error) exp_err_cnt = exp_err_cnt + 1;

	// auto off 직후 1~2clk 동안 enable 내려가기 전에 나오는 tick 은 controller 도 버림
	if(U_UART_CONTROLLER.w_clk_5hz && exp_auto != EXP_NONE)begin
		exp_tick_cnt = exp_tick_cnt + 1;
		if(exp_tick_cnt > 1)begin   // controller 는 차례 1개만 저장 -> 2개 쌓이면 손실
			check(0, "AUTO     못 보낸 차례가 있는데 tick 또 들어옴 (데이터 손실)");
			exp_tick_cnt = 1;
		end
	end

	if(w_handshake)begin
		if(w_get && exp_auto == EXP_NONE) exp_get_cnt = exp_get_cnt + 1;

		if(w_btn)begin
			case(w_ascii[7:0])
				"R" : begin exp_btn[3] = 1; exp_btn_t[3] = $time; end
				"L" : begin exp_btn[2] = 1; exp_btn_t[2] = $time; end
				"U" : begin exp_btn[1] = 1; exp_btn_t[1] = $time; end
				"D" : begin exp_btn[0] = 1; exp_btn_t[0] = $time; end
			endcase
		end

		if(w_mode || w_auto)begin
			upd_valid = 1;
			upd_mode  = w_mode;
			upd_auto  = w_auto;
			upd_ascii = w_ascii;
		end
	end

	end
end

initial begin
	pass_cnt = 0;     fail_cnt = 0;
	exp_err_cnt = 0;  exp_get_cnt = 0;  exp_tick_cnt = 0;
	exp_mode_sel = 3'd2;              // 리셋 : module_control_bit = 0 -> WH
	exp_auto = EXP_NONE;
	exp_scan = 0;
	exp_btn  = 0;
	upd_valid = 0;
end


// 끝났을 때 못 나간 게 남아 있으면 FAIL
task report();
begin
	$display("");
	check(exp_err_cnt == 0, $sformatf("END      못 나간 error = %0d", exp_err_cnt));
	check(exp_get_cnt == 0, $sformatf("END      못 나간 get   = %0d", exp_get_cnt));
	check(exp_btn     == 0, $sformatf("END      못 나간 uart btn = %b (RLUD)", exp_btn));
	$display("");
	$display("==================================================");
	if(fail_cnt == 0) $display("  PASS : %0d / %0d", pass_cnt, pass_cnt);
	else              $display("  FAIL : %0d  (PASS %0d)", fail_cnt, pass_cnt);
	$display("==================================================");
end
endtask




////////////////////////////////////////////////////////////////////////////////////
task sender( string txt);

	integer i,j;

begin

	$display("[%0t] TX : \"%s\"", $time, txt);
	TX_TEXT = 0;

	for(j=0; j <txt.len();j=j+1)begin
		DATA_8BIT = txt[j];
		TX_TEXT = {TX_TEXT[8*15-1:0], txt[j]};
		rx = 0;
		#(BAUD_RATE);
		for(i=0; i <8; i=i+1)begin
			
			rx = txt[j][i];
			#(BAUD_RATE);
		end 

		rx = 1;
		#(BAUD_RATE);
	end
	#(BAUD_RATE*10);

end
endtask


// uart 버튼이 o_uart_* 로 나가려는 clk 에 물리 버튼을 hold_clk 동안 같이 넣음
// phy : 0=R 1=L 2=U 3=D
task btn_collide(string txt, integer phy, integer hold_clk);
begin
	fork
		sender(txt);
		begin
			@(posedge clk iff (w_handshake && w_btn));   // 이 edge 다음 clk 에 c_btn_* = 1
			#1;
			case(phy)
				0 : btn_R = 1;
				1 : btn_L = 1;
				2 : btn_U = 1;
				3 : btn_D = 1;
			endcase
			repeat(hold_clk) @(posedge clk);
			#1;
			{btn_R, btn_L, btn_U, btn_D} = 4'b0000;
		end
	join
end
endtask


always #5 clk = ~clk;


initial	begin

clk = 0;
rst = 1;
rx = 1;
{btn_R, btn_L, btn_U, btn_D} = 4'b0000;

#10 rst = 0;

// ---------------- mode + get : 현재 모드 sel / data 출력 ----------------
$display("\n==== [1] mode + get ====");
sender("/get \015");               // 리셋 직후 -> WH (sel 2)
sender("/mod s_hm");
sender("/get \015");               // SW (sel 0)
sender("/mod t_ms");
sender("/get \015");               // TM (sel 1)
sender("/mod temp");
sender("/get \015");               // TEMP (sel 4)
sender("/mod w_hm");

// ---------------- error (auto 아님) ----------------
$display("\n==== [2] error (auto 아님) ====");
sender("/gxt ");                   // error -> sel 7

// ---------------- btn ----------------
$display("\n==== [3] btn : 물리 btn 우선 ====");
sender("/btn R");                              // 물리 버튼 없음 -> 바로 o_uart_R
btn_collide("/btn R", 0, 1);                   // 같은 버튼 물리 R tick 1clk 동시 -> uart R 1clk 뒤
btn_collide("/btn U", 1, 3);                   // 물리 L 3clk 유지 중 uart U -> L 끝나고 U

// ---------------- auto ----------------
$display("\n==== [4] auto + error ====");
sender("/auto all");               // 0 -> 1 -> 2 -> 3 -> 4 순서
sender("/gxt ");                   // auto 중 error -> busy 면 저장했다가 sel 7, 그 차례 data 안 빠짐
sender("/gxt ");
sender("/auto _tm");               // TM (sel 1) 만
sender("/gxt ");
sender("/auto off");

$display("\n==== [5] auto off 후 get ====");
sender("/get \015");               // auto off 후 get -> WH (sel 2)


#(BAUD_RATE*20);

report();

$finish;

end


endmodule
