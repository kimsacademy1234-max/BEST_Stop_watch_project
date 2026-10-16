`timescale 1ns / 1ps
// =============================================================================
// tb_wt_2_rollover — WATCH (ahnsung): 1 s 정확도 + carry 경계 (verification.md §2.4)
//   P1 1 s 정확도 (프리로드 없음) WB7 · P2 00:00:59.95→00:01:00.00 · P3 00:59:59.95→01:00:00.00 (WB2)
//   P4 23:59:59.95→00:00:00.00 전 자리 + carry 리플 기록 (WB1) · P5 설정 모드 중 흐름 carry (WB5, INFO)
// =============================================================================
module tb_wt_2_rollover;
`define TB_ID "WT2"
`define TB_TIMEOUT_MS 6000
`include "tb_common.svh"

    // 프리로드 → 4 tick 뒤 xx.99 확인 → 1 tick 뒤 기대값 확인
    task automatic carry_case(input string cid, input integer h, input integer m, input integer s,
                              input string exp_99, input string exp_next, input string what);
        preload_watch(h, m, s, 95);
        wait_ticks(4);
        check(cid, wt_now() == exp_99, {what, " : 4 ticks after preload"}, exp_99, wt_now());
        wait_ticks(1);
        check(cid, wt_now() == exp_next, {what, " : carry on 5th tick"}, exp_next, wt_now());
    endtask

    initial begin
        realtime t1, t2, t_rel;
        integer i;
        string trace;
        #1;
        // ------------------------------------------------------------------ P1
        if (phase_begin(1, "1 s accuracy: interval between two sec increments == 1,000,000,000 ns (no preload)")) begin
            do_reset();
            t_rel = $realtime - US;  // 리셋 해제 시각
            set_sw(0, 0, 0, 0, 0);
            @(dut.w_wt_sec);
            t1 = $realtime;
            @(dut.w_wt_sec);
            t2 = $realtime;
            info("WB7", $sformatf("first sec increment %0.6f ms after reset release, second at +%0.6f ms",
                                  (t1 - t_rel) / 1.0e6, (t2 - t1) / 1.0e6));
            check("WB7", (t2 - t1) > 999999999.999 && (t2 - t1) < 1000000000.001, "1 s = 100,000,000 clk",
                  "1000000000.000 ns", $sformatf("%0.3f ns", t2 - t1));
            check("WB7", wt_now() == "12:00:02.00", "watch value after 2 s", "12:00:02.00", wt_now());
            phase_end();
        end
        // ------------------------------------------------------------------ P2
        if (phase_begin(2, "sec 59 -> 00, min +1 : 00:00:59.95 -> 00:01:00.00")) begin
            do_reset();
            carry_case("WB2.SEC", 0, 0, 59, "00:00:59.99", "00:01:00.00", "sec carry");
            phase_end();
        end
        // ------------------------------------------------------------------ P3
        if (phase_begin(3, "min 59 -> 00, hour +1 : 00:59:59.95 -> 01:00:00.00")) begin
            do_reset();
            carry_case("WB2.MIN", 0, 59, 59, "00:59:59.99", "01:00:00.00", "min carry");
            phase_end();
        end
        // ------------------------------------------------------------------ P4
        if (phase_begin(4, "midnight 23:59:59.95 -> 00:00:00.00 (4-stage carry in one tick)")) begin
            do_reset();
            set_sw(0, 0, 0, 1, 0);  // 시.분 화면, 12시간
            preload_watch(23, 59, 59, 95);
            check("WB4", led[15] == 1'b1, "23:59 is PM (led15)", "1", $sformatf("%b", led[15]));
            wait_ticks(4);
            check("WB1", wt_now() == "23:59:59.99", "4 ticks after preload", "23:59:59.99", wt_now());
            // 5 번째 tick: 클럭마다 값을 기록해서 carry 리플을 남김
            @(posedge dut.w_tick_10ms);
            trace = "";
            for (i = 1; i <= 5; i = i + 1) begin
                @(negedge clk);
                trace = $sformatf("%s clk+%0d=%s", trace, i, wt_now());
            end
            info("WB1", {"carry ripple after tick:", trace});
            check("WB1", wt_now() == "00:00:00.00", "all 4 digits wrap to 0 within the tick (+5 clk)", "00:00:00.00", wt_now());
            check("WB4", led[15] == 1'b0, "00:00 is AM (led15 off)", "0", $sformatf("%b", led[15]));
            check_disp("WB4", "12.00", "midnight shown as 12.00 in 12h mode");
            phase_end();
        end
        // ------------------------------------------------------------------ P5
        if (phase_begin(5, "set mode: clock keeps running, 23:59:59.95 -> 00:00 while sw2=1 (INFO)")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 0);
            preload_watch(23, 59, 59, 95);
            wait_ticks(5);
            check("WB5", wt_now() == "00:00:00.00", "carry continues in set mode", "00:00:00.00", wt_now());
            check("WB5", dut.w_set_mode == 1'b1, "still in set mode", "1", $sformatf("%b", dut.w_set_mode));
            info("WB5", "current behaviour: time set to 23:59 becomes 00:00 while user is still in set mode (clock never pauses)");
            phase_end();
        end
        tb_finish();
    end
endmodule
