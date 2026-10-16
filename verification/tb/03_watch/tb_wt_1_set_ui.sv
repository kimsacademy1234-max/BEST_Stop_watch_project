`timescale 1ns / 1ps
// =============================================================================
// tb_wt_1_set_ui — WATCH (ahnsung): 설정 UI (verification.md §2.4)
//   P1 리셋 · P2 NORMAL 무시 · P3 커서 이동/wrap · P4 분 일 ±1 wrap · P5 분 십 ±10 wrap
//   P6 시 ±1 wrap · P7 U+D 동시 · P8 sw2 재진입 · P9 다른 화면에서 버튼 무시
//   WC6 : 초 · 1/100 초 카운터의 i_up/i_down 은 시뮬 내내 0 (상시 감시)
// =============================================================================
module tb_wt_1_set_ui;
`define TB_ID "WT1"
`define TB_TIMEOUT_MS 3000
`include "tb_common.svh"

    // WC6 상시 감시
    wire w_sec_set = dut.U_WATCH_DATAPATH.U_SEC_COUNTER.i_up | dut.U_WATCH_DATAPATH.U_SEC_COUNTER.i_down |
                     dut.U_WATCH_DATAPATH.U_MSEC_COUNTER.i_up | dut.U_WATCH_DATAPATH.U_MSEC_COUNTER.i_down;
    always @(posedge w_sec_set) if (started) check("WC6", 0, "sec/msec counter got a set pulse", "never", "pulse");

    function automatic string hm();
        hm = $sformatf("%02d:%02d", dut.w_wt_hour, dut.w_wt_min);
    endfunction

    task automatic expect_hm(input string cid, input string exp_s, input string what);
        check(cid, hm() == exp_s, what, exp_s, hm());
    endtask

    task automatic expect_cur(input string cid, input integer c, input string what);
        check(cid, dut.w_cursor == c, what, $sformatf("cursor=%0d", c), $sformatf("cursor=%0d", dut.w_cursor));
    endtask

    initial begin
        #1;
        // ------------------------------------------------------------------ P1
        if (phase_begin(1, "reset: 12:00:00.00, cursor=3, set_mode=0, LED 8009 (WC1)")) begin
            do_reset();
            check("WC1", wt_now() == "12:00:00.00", "reset time", "12:00:00.00", wt_now());
            expect_cur("WC1", 3, "cursor none after reset");
            check("WC1", dut.w_set_mode == 0, "set_mode 0", "0", $sformatf("%b", dut.w_set_mode));
            check("WC1", led == 16'h8009, "LED", "8009", $sformatf("%h", led));
            phase_end();
        end
        // ------------------------------------------------------------------ P2
        if (phase_begin(2, "NORMAL (sw2=0): U/D/L/R ignored (WC2)")) begin
            do_reset();
            set_sw(0, 0, 0, 1, 0);
            press(BU); press(BD); press(BL); press(BR);
            expect_hm("WC2", "12:00", "time unchanged after U/D/L/R in NORMAL");
            expect_cur("WC2", 3, "cursor stays none");
            phase_end();
        end
        // ------------------------------------------------------------------ P3
        if (phase_begin(3, "cursor: enter -> 0, L 0->1->2->0, R 0->2->1->0 (WC3, WC4)")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 0);
            expect_cur("WC3", 0, "sw2 on -> cursor 0 (min ones)");
            check("WC3", dut.w_set_mode == 1, "set_mode 1", "1", $sformatf("%b", dut.w_set_mode));
            press(BL); expect_cur("WC4", 1, "L 0->1");
            press(BL); expect_cur("WC4", 2, "L 1->2");
            press(BL); expect_cur("WC4", 0, "L 2->0 (wrap)");
            press(BR); expect_cur("WC4", 2, "R 0->2 (wrap)");
            press(BR); expect_cur("WC4", 1, "R 2->1");
            press(BR); expect_cur("WC4", 0, "R 1->0");
            phase_end();
        end
        // ------------------------------------------------------------------ P4
        if (phase_begin(4, "min ones +-1 wrap, hour unchanged (WB3)")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 0);
            preload_watch(12, 59, 0, 0);
            press(BU); expect_hm("WB3", "12:00", "59 +1 -> 00, hour NOT +1");
            press(BD); expect_hm("WB3", "12:59", "00 -1 -> 59, hour NOT -1");
            press(BD); expect_hm("WB3", "12:58", "59 -1 -> 58");
            phase_end();
        end
        // ------------------------------------------------------------------ P5
        if (phase_begin(5, "min tens +-10 wrap: 55+10->05, 05-10->55 (WB3)")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 0);
            press(BL);
            expect_cur("WB3", 1, "cursor min tens");
            preload_watch(12, 55, 0, 0);
            press(BU); expect_hm("WB3", "12:05", "55 +10 -> 05, hour unchanged");
            press(BD); expect_hm("WB3", "12:55", "05 -10 -> 55");
            press(BD); expect_hm("WB3", "12:45", "55 -10 -> 45");
            phase_end();
        end
        // ------------------------------------------------------------------ P6
        if (phase_begin(6, "hour +-1 wrap: 12->13, 23->0, 0->23, min unchanged (WB3)")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 0);
            press(BL); press(BL);
            expect_cur("WB3", 2, "cursor hour");
            press(BU); expect_hm("WB3", "13:00", "12 +1 -> 13");
            preload_watch(23, 30, 0, 0);
            press(BU); expect_hm("WB3", "00:30", "23 +1 -> 0, min unchanged");
            press(BD); expect_hm("WB3", "23:30", "0 -1 -> 23");
            phase_end();
        end
        // ------------------------------------------------------------------ P7
        if (phase_begin(7, "U+D same instant -> U wins (WC5)")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 0);
            press2(BU, BD);
            check("WC5", last_pv == 4'b1100, "U and D pulses in the same clock", "{D,U,L,R}=1100", $sformatf("%b", last_pv));
            expect_hm("WC5", "12:01", "U+D -> +1 (U priority)");
            phase_end();
        end
        // ------------------------------------------------------------------ P8
        if (phase_begin(8, "sw2 re-entry always starts at cursor 0 (WC3)")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 0);
            press(BL); press(BL);
            expect_cur("WC3", 2, "cursor moved to hour");
            set_sw(0, 0, 0, 1, 0);
            expect_cur("WC3", 3, "sw2 off -> cursor none");
            set_sw(0, 0, 1, 1, 0);
            expect_cur("WC3", 0, "sw2 on again -> cursor 0");
            phase_end();
        end
        // ------------------------------------------------------------------ P9
        if (phase_begin(9, "other screen (sw0=1 / sw4=1): watch buttons ignored, watch keeps running (WC7)")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 1);  // 스톱워치 화면 + sw2
            press(BU); press(BD); press(BL);
            expect_hm("WC7", "12:00", "stopwatch screen: watch time unchanged");
            expect_cur("WC7", 0, "stopwatch screen: cursor unchanged");
            set_sw(1, 0, 1, 1, 0);  // 타이머 화면 + sw2
            press(BU); press(BL); press(BR);
            expect_hm("WC7", "12:00", "timer screen: watch time unchanged");
            expect_cur("WC7", 0, "timer screen: cursor unchanged");
            check("WC7", dut.w_wt_sec > 0 || dut.w_wt_msec > 0, "watch kept running", ">00:00", wt_now());
            check("WC6", w_sec_set == 0, "sec/msec set inputs tied 0", "0", $sformatf("%b", w_sec_set));
            phase_end();
        end
        tb_finish();
    end
endmodule
