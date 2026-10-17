`timescale 1ns / 1ps
// =============================================================================
// tb_sw_stop_edge — 스톱워치 STOP 이 tick 이 나오는 바로 그 클럭에 들어와도 1/100초를 안 잃는지 (클로드코드, 10/17)
//   모듈 단위: tick_gen_100hz_run (F_COUNT = 10 으로 줄임) + stopwatch_datapath
//   ① 보통 STOP (tick 사이)          → 센 수 그대로
//   ② tick 이 나오는 클럭에 STOP     → 그 마지막 칸도 세야 함
//   ③ STOP 동안 안 셈, 다시 RUN 하면 남은 칸부터 이어서 셈
//   (10/17 고치기 전 데이터패스는 tick & run_stop 으로 한 번 더 막아서 ② 에서 하나 덜 셌음)
// =============================================================================
module tb_sw_stop_edge ();
    parameter F = 10;                       // tick 간격 (클럭 수). 실제는 1,000,000

    reg clk = 0, rst = 1;
    reg run = 0, clr = 0;
    reg stop_on_tick = 0;                   // 1 이면 tick 이 나오는 클럭에 run 을 내림
    wire tick;
    wire [6:0] msec;
    wire [5:0] sec, min;
    wire [4:0] hour;
    wire lap;

    tick_gen_100hz_run #(.F_COUNT(F)) U_TG (
        .i_clk(clk), .i_rst(rst), .i_run_stop(run), .i_clear(clr), .o_tick_10ms(tick)
    );

    stopwatch_datapath U_DP (
        .i_clk(clk), .i_rst(rst), .i_tick_10ms(tick),
        .i_sw_clear(clr), .i_sw_down(1'b0), .i_sw_btn_D(1'b0),
        .o_sw_msec(msec), .o_sw_sec(sec), .o_sw_min(min), .o_sw_hour(hour), .o_sw_lap(lap)
    );

    always #5 clk = ~clk;

    // tick 생성기 카운터가 F-1 인 클럭 = 이 엣지에서 tick 이 나옴 → 같은 엣지에 run 을 0 으로 (FSM 이 STOP 으로 가는 것과 같은 타이밍)
    always @(posedge clk) begin
        if (stop_on_tick && run && U_TG.counter_reg == F - 1) begin
            run <= 1'b0;
            stop_on_tick <= 1'b0;
        end
    end

    integer err, total;

    initial begin
        err = 0;
        total = 0;
        #12 rst = 0;

        // ① 3칸 + 반 칸 세고 보통 STOP → 3
        @(negedge clk); run = 1;
        repeat (3 * F + F / 2) @(posedge clk);
        @(negedge clk); run = 0;
        repeat (5) @(posedge clk);
        total = total + 1;
        if (msec !== 7'd3) begin
            err = err + 1; $display("FAIL: normal stop -> %0d (expect 3)", msec);
        end

        // ② 다시 RUN, 남은 반 칸 + 1칸 뒤 tick 이 나오는 클럭에 STOP → 그 칸까지 5
        @(negedge clk); run = 1;
        repeat (F / 2 + 2) @(posedge clk);          // 남은 반 칸이 끝나 4 가 됨
        stop_on_tick = 1;                            // 다음 tick 이 나오는 클럭에 STOP
        wait (run == 1'b0);
        repeat (5) @(posedge clk);
        total = total + 1;
        if (msec !== 7'd5) begin
            err = err + 1; $display("FAIL: stop on the tick clock -> %0d (expect 5, the last 10 ms was lost)", msec);
        end

        // ③ STOP 동안 안 셈
        repeat (3 * F) @(posedge clk);
        total = total + 1;
        if (msec !== 7'd5) begin
            err = err + 1; $display("FAIL: counted while stopped -> %0d (expect 5)", msec);
        end

        $display("[sw edge] msec = %0d", msec);
        $display("TOTAL %0d, MISMATCH = %0d", total, err);
        $finish;
    end

endmodule
