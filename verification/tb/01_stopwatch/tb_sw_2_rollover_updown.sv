`timescale 1ns / 1ps
// =============================================================================
// tb_sw_2_rollover_updown — STOPWATCH (jonghyuk): carry / borrow 경계 (verification.md §3.4)
//   P1 업 00:00:59.95 → 00:01:00.00 · P2 00:59:59.95 → 01:00:00.00 · P3 23:59:59.95 → 00:00:00.00 (SB1)
//   P4 STOP 에서 U(다운) → RUN, 프리로드 00:00:00.05 → 00:00:00.00 → 23:59:59.99 (SB2)
//   P5 다운 RUN 중 U → 계속 다운(무시), STOP → U → 업 복귀 (SB6)
//   프리로드는 RUN 중 tick 직후에 대입 (다음 tick 이 정확히 10 ms 뒤 → 결정적)
// =============================================================================
module tb_sw_2_rollover_updown;
`define TB_ID "SW2"
`define TB_TIMEOUT_MS 3000
`include "tb_common.svh"

    task automatic carry_case(input string cid, input integer h, input integer m, input integer s, input integer c,
                              input integer n1, input string exp_1, input string exp_2, input string what);
        preload_sw(h, m, s, c);
        wait_ticks(n1);
        check(cid, sw_raw() == exp_1, {what, " : before boundary"}, exp_1, sw_raw());
        wait_ticks(1);
        check(cid, sw_raw() == exp_2, {what, " : on boundary tick"}, exp_2, sw_raw());
    endtask

    initial begin
        longint c1;
        #1;
        // ------------------------------------------------------------------ P1~P3
        if (phase_begin(1, "up: 00:00:59.95 -> 00:01:00.00 (SB1)")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            carry_case("SB1", 0, 0, 59, 95, 4, "00:00:59.99", "00:01:00.00", "sec carry");
            phase_end();
        end
        if (phase_begin(2, "up: 00:59:59.95 -> 01:00:00.00 (SB1)")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            carry_case("SB1", 0, 59, 59, 95, 4, "00:59:59.99", "01:00:00.00", "min carry");
            phase_end();
        end
        if (phase_begin(3, "up: 23:59:59.95 -> 00:00:00.00 (hour TIMES=24 wrap) (SB1)")) begin
            do_reset();
            set_sw(0, 0, 0, 1, 1);
            press(BR);
            carry_case("SB1", 23, 59, 59, 95, 4, "23:59:59.99", "00:00:00.00", "24 h wrap");
            check_disp("SB1", "00.00", "FND HH.MM after wrap");
            phase_end();
        end
        // ------------------------------------------------------------------ P4
        if (phase_begin(4, "down: STOP U -> down, RUN, 00:00:00.05 -> 00:00:00.00 -> 23:59:59.99 (SB2)")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BU);
            check("SB6", dut.w_mode == 1, "U in STOP -> down mode", "1", $sformatf("%0d", dut.w_mode));
            press(BR);
            carry_case("SB2", 0, 0, 0, 5, 5, "00:00:00.00", "23:59:59.99", "borrow chain from 0");
            wait_ticks(1);
            check("SB2", sw_raw() == "23:59:59.98", "keeps counting down", "23:59:59.98", sw_raw());
            phase_end();
        end
        // ------------------------------------------------------------------ P5
        if (phase_begin(5, "down RUN: U ignored; STOP -> U -> up again (SB6)")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BU);   // 다운
            press(BR);   // RUN
            preload_sw(0, 0, 10, 0);
            press(BU);   // RUN 중 → 무시
            check("SB6", dut.w_mode == 1, "U during RUN ignored (still down)", "1", $sformatf("%0d", dut.w_mode));
            c1 = sw_count();
            #(50 * MS);
            check("SB6", sw_count() < c1, "still counting down", $sformatf("<%0d", c1), $sformatf("%0d", sw_count()));
            press(BR);   // STOP
            press(BU);   // STOP 에서 → 업
            check("SB6", dut.w_mode == 0, "U in STOP -> up", "0", $sformatf("%0d", dut.w_mode));
            press(BR);   // RUN
            c1 = sw_count();
            #(50 * MS);
            check("SB6", sw_count() > c1, "counting up again", $sformatf(">%0d", c1), $sformatf("%0d", sw_count()));
            phase_end();
        end
        tb_finish();
    end
endmodule
