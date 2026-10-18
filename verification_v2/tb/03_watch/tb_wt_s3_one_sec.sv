`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// [Vivado 에서 실행]  (요구사항 · 슬라이드 양식은 같은 폴더 PPT_SCENARIO.md)
//   1) Design Sources     : verification_v2/source_file/*.v, *.sv
//   2) Simulation Sources : 이 파일 하나 → Set as Top
//   3) Run Simulation → 같은 폴더 tb_wt_s3_one_sec_behav.wcfg 열기 → Run All (2.05 s 에서 끝, 수 분 걸림)
//   콘솔 : [STEP n] = 아래 표의 순서 n,  [SEC] = o_wt_sec 이 바뀐 순간 + 앞 변화와의 간격,  [OK]/[FAIL] = 검사
//   파형 : wcfg 마커 1~4 = 표의 순서 1~4 (마커 3 · 4 = o_wt_sec 이 바뀌는 정확한 시각)
//          마커 3 → 4 간격이 정확히 1.000000000 s.  clk 는 wcfg 에서 뺐다 (2 초 × 100 MHz 는 파형이 너무 큼)
// -----------------------------------------------------------------------------
// =============================================================================
// 3. Watch 시뮬레이션 · 시나리오 3 : 리셋 뒤 시계는 계속 흐른다 — 1 초 = 실제 1 초
//   프리로드 없음 · 버튼 없음 — 리셋만 하고 기다린다. 화면은 초.1/100초 (display_mode_sw1 = 0)
//
//   타이밍 (rst 해제 = 1 us, 그 뒤 첫 posedge = 1.005 us)
//     U_TICK_GEN_100HZ.o_tick_10ms : 클럭 1,000,000 개마다 10 ns 펄스 → 첫 tick 10.000995 ms, 간격 10 ms
//     o_wt_msec 99 → 0 (tick 100 개) → U_MSEC_COUNTER.o_tick → 다음 클럭 o_wt_sec +1
//     o_wt_sec 0 → 1 : 1,000,001,015 ns,  1 → 2 : 2,000,001,015 ns  (간격 1,000,000,000 ns)
//
//   순서 | 시각          | 입력/동작 | 확인 내용                 | 예상 결과
//   -----+---------------+-----------+---------------------------+--------------------------------
//    1   | 0.001 ms      | rst 해제  | 시계 시작                 | 12:00:00.00
//    2   | 10.000995 ms  | 대기      | o_tick_10ms 간격          | 10 ms (클럭 1,000,000 개)
//    3   | 1.000001015 s | 대기      | 1/100 초 99 → 00, 초 +1   | 12:00:01.00 (리셋 해제 + 1 s)
//    4   | 2.000001015 s | 대기      | 초 1 → 2 간격             | 정확히 1,000,000,000 ns (tick 100 개)
// =============================================================================
module tb_wt_s3_one_sec;
    localparam longint MS = 64'd1_000_000;  // 1 ms in ns

    // =========================================================================
    // DUT : Top (stopwatch_watch) — 보드 핀 이름 그대로
    // =========================================================================
    reg clk = 1'b0;
    reg rst = 1'b0;
    reg btn_R = 1'b0, btn_L = 1'b0, btn_U = 1'b0, btn_D = 1'b0;
    reg mode_sw0 = 1'b0;           // 0 시계 화면
    reg display_mode_sw1 = 1'b0;   // 0 초.1/100초
    reg set_sw2 = 1'b0;
    reg hour24_sw3 = 1'b0;
    reg timer_sw4 = 1'b0;
    wire [3:0]  fnd_com;
    wire [7:0]  fnd_font;
    wire [15:0] led;

    always #5 clk = ~clk;   // 100 MHz

    stopwatch_watch dut (
        .clk             (clk),
        .rst             (rst),
        .btn_R           (btn_R),
        .btn_L           (btn_L),
        .btn_U           (btn_U),
        .btn_D           (btn_D),
        .mode_sw0        (mode_sw0),
        .display_mode_sw1(display_mode_sw1),
        .set_sw2         (set_sw2),
        .hour24_sw3      (hour24_sw3),
        .timer_sw4       (timer_sw4),
        .fnd_com         (fnd_com),
        .fnd_font        (fnd_font),
        .led             (led)
    );

    // =========================================================================
    // 관찰 (읽기만)
    // =========================================================================
    integer  n_chk = 0, n_fail = 0;
    bit      started = 0;

    // 10 ms tick : 개수 · 첫 시각 · 간격
    integer  n_tick = 0, n_tick_bad = 0;
    realtime t_tick_first = -1, t_tick_last = -1;
    always @(posedge dut.w_tick_10ms) begin   // U_TICK_GEN_100HZ.o_tick_10ms
        if (started) begin
            if (t_tick_last >= 0 && ($realtime - t_tick_last) != 10.0e6) begin
                n_tick_bad = n_tick_bad + 1;
                $display("[%t] [WARN   ] o_tick_10ms interval %0.3f ns (exp 10,000,000 ns)", $realtime, $realtime - t_tick_last);
            end
            if (t_tick_first < 0) t_tick_first = $realtime;
            t_tick_last = $realtime;
            n_tick = n_tick + 1;
        end
    end

    // 초가 바뀐 순간 : 시각 · 앞 변화와의 간격 · 그 사이 tick 개수
    integer  n_sec_chg = 0;
    integer  tick_at_sec[0:7];
    realtime t_sec[0:7];
    always @(dut.w_wt_sec) begin   // U_WATCH_DATAPATH.o_wt_sec
        if (started && n_sec_chg < 8) begin
            t_sec[n_sec_chg]       = $realtime;
            tick_at_sec[n_sec_chg] = n_tick;
            if (n_sec_chg == 0)
                $display("[%t] [SEC    ] o_wt_sec -> %0d   (%0.0f ns after rst release)   time %02d:%02d:%02d.%02d",
                         $realtime, dut.w_wt_sec, $realtime - 1000.0,
                         dut.w_wt_hour, dut.w_wt_min, dut.w_wt_sec, dut.w_wt_msec);
            else
                $display("[%t] [SEC    ] o_wt_sec -> %0d   interval %0.0f ns, %0d ticks   time %02d:%02d:%02d.%02d",
                         $realtime, dut.w_wt_sec, $realtime - t_sec[n_sec_chg-1],
                         tick_at_sec[n_sec_chg] - tick_at_sec[n_sec_chg-1],
                         dut.w_wt_hour, dut.w_wt_min, dut.w_wt_sec, dut.w_wt_msec);
            n_sec_chg = n_sec_chg + 1;
        end
    end

    function automatic string hmsc_now();
        hmsc_now = $sformatf("%02d:%02d:%02d.%02d", dut.w_wt_hour, dut.w_wt_min, dut.w_wt_sec, dut.w_wt_msec);
    endfunction

    // =========================================================================
    // 검사
    // =========================================================================
    function automatic void check(input bit ok, input string what, input string exp_s, input string got_s);
        n_chk = n_chk + 1;
        if (ok) $display("[%t] [OK     ] %-34s | exp=%s got=%s", $realtime, what, exp_s, got_s);
        else begin
            n_fail = n_fail + 1;
            $display("[%t] [FAIL   ] %-34s | exp=%s got=%s", $realtime, what, exp_s, got_s);
        end
    endfunction

    function automatic void step(input integer n, input string what);
        $display("");
        $display("[%t] [STEP %0d ] %s", $realtime, n, what);
    endfunction

    task automatic at_ms(input real t);
        realtime target;
        target = t * 1.0e6;
        if (target > $realtime) #(target - $realtime);
    endtask

    // =========================================================================
    // 시나리오
    // =========================================================================
    initial begin
        $timeformat(-9, 0, " ns", 15);   // ns 정수로 찍어 1 s 간격을 그대로 읽기
        $display("==========================================================================================");
        $display(" 3. Watch simulation - Scenario 3 : watch keeps running after reset, 1 s = real 1 s");
        $display("  # | time               | check                     | expected");
        $display("  1 | 1,000 ns           | rst released              | 12:00:00.00");
        $display("  2 | 10,000,995 ns      | o_tick_10ms interval      | 10,000,000 ns");
        $display("  3 | 1,000,001,015 ns   | msec 99 -> 00, sec 0 -> 1 | 12:00:01.00");
        $display("  4 | 2,000,001,015 ns   | sec 1 -> 2 interval       | 1,000,000,000 ns (100 ticks)");
        $display("==========================================================================================");

        // ---------------------------------------------------------------- 1
        #10 rst = 1'b1;
        #990 rst = 1'b0;     // 1 us 에 해제
        started = 1;
        step(1, "rst 1 us pulse released (no button, no preload)");
        #10;
        check(dut.w_wt_hour == 12 && dut.w_wt_min == 0 && dut.w_wt_sec == 0 && dut.w_wt_msec == 0,
              "time after reset", "12:00:00.00", hmsc_now());

        // ---------------------------------------------------------------- 2
        at_ms(30.5);   // tick 3 개 지난 뒤
        step(2, "o_tick_10ms (U_TICK_GEN_100HZ) first tick / interval");
        check(t_tick_first == 10_000_995.0, "first o_tick_10ms time", "10000995 ns",
              $sformatf("%0.0f ns", t_tick_first));
        check(n_tick == 3 && n_tick_bad == 0, "ticks in 30.5 ms, all 10 ms apart", "3, bad 0",
              $sformatf("%0d, bad %0d", n_tick, n_tick_bad));
        check(dut.w_wt_msec == 3, "o_wt_msec after 3 ticks", "3", $sformatf("%0d", dut.w_wt_msec));

        // ---------------------------------------------------------------- 3
        at_ms(1000.5);
        step(3, "1 s after reset : msec 99 -> 00, sec 0 -> 1");
        check(n_sec_chg >= 1 && t_sec[0] == 1_000_001_015.0, "o_wt_sec 0 -> 1 time", "1000001015 ns",
              (n_sec_chg >= 1) ? $sformatf("%0.0f ns", t_sec[0]) : "no change");
        check(dut.w_wt_hour == 12 && dut.w_wt_min == 0 && dut.w_wt_sec == 1 && dut.w_wt_msec == 0,
              "time at 1000.5 ms", "12:00:01.00", hmsc_now());

        // ---------------------------------------------------------------- 4
        at_ms(2000.5);
        step(4, "sec 1 -> 2 : interval must be exactly 1 s");
        check(n_sec_chg >= 2 && (t_sec[1] - t_sec[0]) == 1.0e9, "o_wt_sec 1 -> 2 interval", "1000000000 ns",
              (n_sec_chg >= 2) ? $sformatf("%0.0f ns", t_sec[1] - t_sec[0]) : "no change");
        check(n_sec_chg >= 2 && (tick_at_sec[1] - tick_at_sec[0]) == 100, "o_tick_10ms count in 1 s", "100",
              (n_sec_chg >= 2) ? $sformatf("%0d", tick_at_sec[1] - tick_at_sec[0]) : "-");
        check(n_tick_bad == 0, "all o_tick_10ms intervals = 10 ms", "0 bad", $sformatf("%0d bad (of %0d)", n_tick_bad, n_tick));
        check(dut.w_wt_hour == 12 && dut.w_wt_min == 0 && dut.w_wt_sec == 2 && dut.w_wt_msec == 0,
              "time at 2000.5 ms", "12:00:02.00", hmsc_now());

        at_ms(2050);
        $display("");
        $display("[%t] [SUMMARY] WT-S3 checks=%0d fail=%0d => %s", $realtime, n_chk, n_fail,
                 (n_fail == 0) ? "PASS" : "FAIL");
        $finish;
    end
endmodule
