`timescale 1ns / 1ps
// =============================================================================
// tb_tm_1_add_cap — TIMER (boyun): 더하기 · 상한 59:59 (verification.md §4.4)
//   P1 화면/LED · P2 0 에서 L 무시 (TB3) · P3 U×6 → 01:00 (TB2) · P4 R, D
//   P5 상한 D×5 R×9 U×5 → 59:50, U → 59:59 (TB1) · P6 59:59 에서 U/R/D · P7 52:10 + D → 59:59
// =============================================================================
module tb_tm_1_add_cap;
`define TB_ID "TM1"
`define TB_TIMEOUT_MS 3000
`include "tb_common.svh"

    task automatic tm_expect(input string cid, input string exp_s, input string what);
        check(cid, tm_now() == exp_s, what, exp_s, tm_now());
    endtask

    initial begin
        integer i;
        #1;
        // ------------------------------------------------------------------ P1
        if (phase_begin(1, "timer screen: disp_mode=1, LED led5 only, FND 00.00 (TC1)")) begin
            do_reset();
            set_sw(1, 0, 0, 0, 0);
            check("TC1", dut.w_disp_mode == 1, "timer forces MM.SS screen (sw1=0)", "1", $sformatf("%b", dut.w_disp_mode));
            check("TC6", led == 16'h0020, "LED timer screen (led5)", "0020", $sformatf("%h", led));
            check_disp("TC1", "00.00", "FND timer 00.00");
            phase_end();
        end
        // ------------------------------------------------------------------ P2
        if (phase_begin(2, "L at 00:00 does not start (TB3)")) begin
            do_reset();
            set_sw(1, 0, 0, 0, 0);
            press(BL);
            check("TB3", dut.w_tm_run == 0 && dut.w_tm_alarm == 0, "L at zero -> stays SET (no run, no alarm)", "run=0 alarm=0",
                  $sformatf("run=%b alarm=%b", dut.w_tm_run, dut.w_tm_alarm));
            phase_end();
        end
        // ------------------------------------------------------------------ P3
        if (phase_begin(3, "U x6 -> 01:00 (sec carry into min) (TB2)")) begin
            do_reset();
            set_sw(1, 0, 0, 0, 0);
            press_n(BU, 5);
            tm_expect("TB2", "00:50.00", "U x5 = +50 s");
            press(BU);
            tm_expect("TB2", "01:00.00", "00:50 + U -> 01:00 (carry)");
            check_disp("TB2", "01.00", "FND 01.00");
            phase_end();
        end
        // ------------------------------------------------------------------ P4
        if (phase_begin(4, "R +1 min, D +10 min")) begin
            do_reset();
            set_sw(1, 0, 0, 0, 0);
            press(BR);
            tm_expect("TB2", "01:00.00", "R = +1 min");
            press(BD);
            tm_expect("TB2", "11:00.00", "D = +10 min");
            press(BU);
            tm_expect("TB2", "11:10.00", "U = +10 s");
            phase_end();
        end
        // ------------------------------------------------------------------ P5
        if (phase_begin(5, "cap: D x5 -> 50:00, R x9 -> 59:00, U x5 -> 59:50, U -> 59:59 (TB1)")) begin
            do_reset();
            set_sw(1, 0, 0, 0, 0);
            press_n(BD, 5);
            tm_expect("TB1", "50:00.00", "D x5");
            press_n(BR, 9);
            tm_expect("TB1", "59:00.00", "R x9");
            press_n(BU, 5);
            tm_expect("TB1", "59:50.00", "U x5");
            press(BU);
            tm_expect("TB1", "59:59.00", "59:50 + U -> sec carry makes 60:00 -> capped 59:59");
            check_disp("TB1", "59.59", "FND never shows 60.00");
            phase_end();
        end
        // ------------------------------------------------------------------ P6
        if (phase_begin(6, "at 59:59: U / R / D each -> 59:59 (TB1)")) begin
            do_reset();
            set_sw(1, 0, 0, 0, 0);
            preload_tm(59, 59, 0);
            press(BU);
            tm_expect("TB1", "59:59.00", "59:59 + U");
            press(BR);
            tm_expect("TB1", "59:59.00", "59:59 + R");
            press(BD);
            tm_expect("TB1", "59:59.00", "59:59 + D");
            phase_end();
        end
        // ------------------------------------------------------------------ P7
        if (phase_begin(7, "52:10 + D (+10 min = 62:10) -> 59:59 (TB1)")) begin
            do_reset();
            set_sw(1, 0, 0, 0, 0);
            press_n(BD, 5);
            press_n(BR, 2);
            press(BU);
            tm_expect("TB1", "52:10.00", "built 52:10 with buttons");
            press(BD);
            tm_expect("TB1", "59:59.00", "52:10 + D -> capped 59:59");
            press(BR);
            tm_expect("TB1", "59:59.00", "59:59 + R stays");
            phase_end();
        end
        tb_finish();
    end
endmodule
