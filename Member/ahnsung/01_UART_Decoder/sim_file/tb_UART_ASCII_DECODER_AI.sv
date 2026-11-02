`timescale 1ns / 1ps


module tb_UART_ASCII_DECODER;

parameter BIT_WIDTH = 8;
parameter DATA_WIDTH = 40;

reg clk, reset;
reg sender_busy;

wire [BIT_WIDTH-1:0] i_ascii;
wire i_enable;

wire o_error, o_pop, o_handshake;
wire o_get, o_btn, o_mode, o_auto;
wire [DATA_WIDTH-1:0] o_ascii;

reg [8*16-1:0] tname;      // 파형에서 ASCII 로 보는 테스트 이름


UART_ASCII_DECODER #(
    .BIT_WIDTH (BIT_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) U_ASCII_DECODER (
    .i_clk        (clk),
    .i_reset      (reset),
    .i_ascii      (i_ascii),
    .i_enable     (i_enable),
    .i_rx_done    (1'b0),
    .i_sender_busy(sender_busy),
    .o_error      (o_error),
    .o_pop        (o_pop),
    .o_handshake  (o_handshake),
    .o_get        (o_get),
    .o_btn        (o_btn),
    .o_mode       (o_mode),
    .o_auto       (o_auto),
    .o_ascii      (o_ascii)
);


always #5 clk = ~clk;   // 100MHz


///////////////////// FIFO_RX 모델 /////////////////////
// FIFO 와 같이 rdata = mem[rptr] 조합 출력, ~empty = i_enable

reg [7:0] fifo_mem [0:255];
reg [7:0] wptr, rptr;

assign i_enable = (wptr != rptr);
assign i_ascii  = fifo_mem[rptr];

always@(posedge clk, posedge reset)begin
    if(reset) rptr <= 0;
    else if(o_pop) rptr <= rptr + 1;
end


///////////////////// 결과 캡처 /////////////////////

integer hs_cnt, err_cnt;
integer pass_cnt, fail_cnt;
reg [3:0] cap_flags;               // {get, mode, btn, auto}
reg [DATA_WIDTH-1:0] cap_data;

always@(posedge clk)begin
    if(o_handshake)begin
        hs_cnt = hs_cnt + 1;
        cap_flags = {o_get, o_mode, o_btn, o_auto};
        cap_data = o_ascii;
    end
    if(o_error) err_cnt = err_cnt + 1;
end


///////////////////// task /////////////////////

// 문자열을 FIFO 에 push, gap 클럭 간격
task send_str(input string s, input integer gap);
    integer i;
    for(i = 0; i < s.len(); i = i + 1)begin
        @(negedge clk);
        fifo_mem[wptr] = s[i];
        wptr = wptr + 1;
        repeat(gap) @(negedge clk);
    end
endtask

task wait_idle;
    wait(wptr == rptr);
    repeat(10) @(posedge clk);
endtask

task start(input [8*16-1:0] name);
    tname = name;
    hs_cnt = 0;
    err_cnt = 0;
    cap_flags = 0;
    cap_data = 0;
endtask

task check(input integer exp_hs, input integer exp_err,
           input [3:0] exp_flags, input [DATA_WIDTH-1:0] exp_data);
    if(hs_cnt == exp_hs && err_cnt == exp_err &&
       (exp_hs == 0 || (cap_flags == exp_flags && cap_data == exp_data)))begin
        pass_cnt = pass_cnt + 1;
        $display("[PASS] %0s", tname);
    end
    else begin
        fail_cnt = fail_cnt + 1;
        $display("[FAIL] %0s : hs=%0d(exp %0d) err=%0d(exp %0d) flags=%b(exp %b) data=\"%0s\"(exp \"%0s\")",
                 tname, hs_cnt, exp_hs, err_cnt, exp_err, cap_flags, exp_flags, cap_data, exp_data);
    end
endtask


///////////////////// 시나리오 /////////////////////
//                      flags = {get, mode, btn, auto}

initial begin
    clk = 0;
    reset = 1;
    sender_busy = 0;
    wptr = 0;
    hs_cnt = 0; err_cnt = 0;
    pass_cnt = 0; fail_cnt = 0;
    tname = "reset";

    repeat(5) @(posedge clk);
    reset = 0;
    repeat(5) @(posedge clk);

    // 정상 명령
    start("get sw_hm");   send_str("/get sw_hm", 20);     wait_idle; check(1, 0, 4'b1000, "sw_hm");
    start("get w_hm CR"); send_str("/get w_hm\x0d", 20);  wait_idle; check(1, 0, 4'b1000, "w_hm");
    start("mod sw_ms");   send_str("/mod sw_ms", 20);     wait_idle; check(1, 0, 4'b0100, "sw_ms");
    start("mod temp LF"); send_str("/mod temp\x0a", 20);  wait_idle; check(1, 0, 4'b0100, "temp");
    start("btn R");       send_str("/btn R", 20);         wait_idle; check(1, 0, 4'b0010, "R");
    start("btn L");       send_str("/btn L", 20);         wait_idle; check(1, 0, 4'b0010, "L");
    start("auto f");      send_str("/auto f", 20);        wait_idle; check(1, 0, 4'b0001, 0);
    start("auto ab f");   send_str("/auto abf", 20);      wait_idle; check(1, 0, 4'b0001, 0);

    // 연속 입력 (gap 0, 바이트가 FIFO 에 쌓인 상태)
    start("burst U D");   send_str("/btn U/btn D", 0);    wait_idle; check(2, 0, 4'b0010, "D");

    // 에러
    start("err gxt");     send_str("/gxt ", 20);          wait_idle; check(0, 1, 0, 0);
    start("err btn X");   send_str("/btn X", 20);         wait_idle; check(0, 1, 0, 0);
    start("err x cmd");   send_str("/x", 20);             wait_idle; check(0, 1, 0, 0);
    start("err empty");   send_str("/get \x0d", 20);      wait_idle; check(0, 1, 0, 0);
    start("err restart"); send_str("/g/btn L", 20);       wait_idle; check(1, 1, 4'b0010, "L");

    // IDLE 에서 시작 문자 아닌 바이트는 무시
    start("idle junk");   send_str("abc\x0d\x0a", 20);    wait_idle; check(0, 0, 0, 0);

    // sender busy 동안 pop 정지
    start("sender busy");
    sender_busy = 1;
    send_str("/btn D", 5);
    repeat(50) @(posedge clk);
    if(rptr != wptr - 6 || hs_cnt != 0)begin
        fail_cnt = fail_cnt + 1;
        $display("[FAIL] sender busy : busy 중 pop 발생 (rptr=%0d wptr=%0d)", rptr, wptr);
    end
    sender_busy = 0;
    wait_idle; check(1, 0, 4'b0010, "D");

    $display("==============================");
    $display(" PASS : %0d   FAIL : %0d", pass_cnt, fail_cnt);
    $display("==============================");
    $finish;
end

initial begin
    #1_000_000;
    $display("[TIMEOUT]");
    $finish;
end


endmodule
