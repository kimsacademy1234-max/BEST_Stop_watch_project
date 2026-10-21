`timescale 1ns / 1ps
// =============================================================================
// tb_tick_restart — 타이머 "시작 → 첫 1/100초" 가 언제나 정확히 10 ms 인지 (10/17)
//   ① 리셋 뒤 처음 시작   ② 알람이 울린 뒤 다시 시작   ③ L 로 취소한 뒤 다시 시작
//   잰 것: o_tm_run 이 1 이 된 순간 → 타이머 전용 tick(w_tm_tick_10ms) 첫 펄스까지
//   기대: 셋 다 10,000,000 ns (클럭 1,000,000 개)
//   (10/17 ② 를 고치기 전에는 tick 카운터가 알람 때 0 으로 안 돌아가서 9,999,980 ns 였음)
// =============================================================================
module tb_tick_restart ();
    reg clk = 0, rst = 0;
    reg btn_R = 0, btn_L = 0, btn_U = 0, btn_D = 0;
    reg mode_sw0 = 0, display_mode_sw1 = 0, set_sw2 = 0, hour24_sw3 = 0;
    reg timer_sw4 = 1;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;
    wire [15:0] led;

    stopwatch_watch DUT (
        .clk(clk), .rst(rst),
        .btn_R(btn_R), .btn_L(btn_L), .btn_U(btn_U), .btn_D(btn_D),
        .mode_sw0(mode_sw0), .display_mode_sw1(display_mode_sw1),
        .set_sw2(set_sw2), .hour24_sw3(hour24_sw3), .timer_sw4(timer_sw4),
        .fnd_com(fnd_com), .fnd_font(fnd_font), .led(led)
    );

    always #5 clk = ~clk;

    wire tm_run   = DUT.w_tm_run;
    wire tm_alarm = DUT.w_tm_alarm;
    wire tm_tick  = DUT.w_tm_tick_10ms;

    integer err, total;
    reg [63:0] t_run, t_tick;

    initial begin
        err = 0;
        total = 0;
        #1;
        rst = 1; #1000; rst = 0; #1000;

        // ------------------------------------------------ ① 리셋 뒤 처음 시작
        btn_U = 1; #5_000_000; btn_U = 0; #5_000_000;          // 00:10
        btn_L = 1;
        @(posedge tm_run);  t_run  = $time;
        @(posedge tm_tick); t_tick = $time;
        #1; btn_L = 0;
        $display("[1] first start  : run -> first tick = %0d ns", t_tick - t_run);
        total = total + 1;
        if (t_tick - t_run !== 64'd10_000_000) begin
            err = err + 1;
            $display("FAIL: first start %0d ns (expect 10000000)", t_tick - t_run);
        end

        // ------------------------------------------------ ② 알람 뒤 다시 시작
        @(posedge tm_alarm); #1;                                // 10 초 기다림
        btn_D = 1; #5_000_000; btn_D = 0; #5_000_000;          // 알람 끄기 → SET
        btn_U = 1; #5_000_000; btn_U = 0; #5_000_000;          // 00:10
        btn_L = 1;
        @(posedge tm_run);  t_run  = $time;
        @(posedge tm_tick); t_tick = $time;
        #1; btn_L = 0;
        $display("[2] after alarm  : run -> first tick = %0d ns", t_tick - t_run);
        total = total + 1;
        if (t_tick - t_run !== 64'd10_000_000) begin
            err = err + 1;
            $display("FAIL: restart after alarm %0d ns (expect 10000000)", t_tick - t_run);
        end

        // ------------------------------------------------ ③ 취소 뒤 다시 시작
        #20_000_000;
        btn_L = 1; #5_000_000; btn_L = 0; #5_000_000;          // 취소 → 00:00 SET
        btn_U = 1; #5_000_000; btn_U = 0; #5_000_000;          // 00:10
        btn_L = 1;
        @(posedge tm_run);  t_run  = $time;
        @(posedge tm_tick); t_tick = $time;
        #1; btn_L = 0;
        $display("[3] after cancel : run -> first tick = %0d ns", t_tick - t_run);
        total = total + 1;
        if (t_tick - t_run !== 64'd10_000_000) begin
            err = err + 1;
            $display("FAIL: restart after cancel %0d ns (expect 10000000)", t_tick - t_run);
        end

        $display("TOTAL %0d, MISMATCH = %0d", total, err);
        $finish;
    end

endmodule
