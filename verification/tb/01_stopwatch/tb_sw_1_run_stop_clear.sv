`timescale 1ns / 1ps
// =============================================================================
// tb_sw_1_run_stop_clear — STOPWATCH (jonghyuk) (verification.md §3.4)
//   P1 리셋 · P2 RUN 1 s 실측(SC3, FSM 신호 기준) · P3 STOP 유지 200 ms · P4 STOP 클리어(+랩 해제)
//   P5 RUN 중 L·U 무시 (SB5, SB6) · P6 STOP 에서 R+L 동시 → RUN + 0 (SB7, LIMIT)
//   P7 시계 화면에서 백그라운드 증가 + 시계 버튼 게이팅 (SC5)
// =============================================================================
module tb_sw_1_run_stop_clear;
`define TB_ID "SW1"
`define TB_TIMEOUT_MS 6000
`include "tb_common.svh"

    realtime t_run_rise = 0, t_run_fall = 0;
    always @(posedge dut.w_run_stop) t_run_rise = $realtime;
    always @(negedge dut.w_run_stop) t_run_fall = $realtime;

    initial begin
        realtime win, t_target;
        longint c1, c2;
        integer pv, m0;
        #1;
        // ------------------------------------------------------------------ P1
        if (phase_begin(1, "reset -> 0, STOP, LED")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);  // 스톱워치, 초.1/100
            check("SC1", sw_count() == 0 && dut.w_run_stop == 0, "reset -> 00:00:00.00 STOP", "0 STOP",
                  $sformatf("%s run=%b", sw_raw(), dut.w_run_stop));
            check("SC6", led == 16'h000A, "LED stopwatch SS.CC (led1, led3)", "000a", $sformatf("%h", led));
            check_disp("SC7", "00.00", "FND SS.CC");
            phase_end();
        end
        // ------------------------------------------------------------------ P2
        if (phase_begin(2, "RUN window exactly 1.000 s (w_run_stop) -> count 99..100 (SC3, SB3)")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            check("SC2", dut.w_run_stop == 1, "R -> RUN", "1", $sformatf("%b", dut.w_run_stop));
            // 두 번째 R: 8 번째 샘플이 (첫 RUN 상승 - 1clk) + 1 s 에 오도록 1.875 ms 앞서 누름
            t_target = t_run_rise - 10.0 + 1.0e9 - 1.875e6;
            #(t_target - $realtime);
            press(BR);
            win = t_run_fall - t_run_rise;
            info("SC3", $sformatf("RUN window (w_run_stop high) = %0.6f ms, count = %0d (%s)", win / 1.0e6, sw_count(), sw_raw()));
            check("SC3", win > 1.0e9 - 20.0e3 && win < 1.0e9 + 20.0e3, "RUN window length", "1000.000000 ms +-20us",
                  $sformatf("%0.6f ms", win / 1.0e6));
            check("SC3", sw_count() >= 99 && sw_count() <= 100, "count after 1.000 s RUN", "99..100", $sformatf("%0d", sw_count()));
            check("SC2", dut.w_run_stop == 0, "2nd R -> STOP", "0", $sformatf("%b", dut.w_run_stop));
            phase_end();
        end
        // ------------------------------------------------------------------ P3
        if (phase_begin(3, "STOP holds value for 200 ms")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            #(120 * MS);
            press(BR);
            c1 = sw_count();
            #(200 * MS);
            check("SC2", sw_count() == c1 && c1 > 0, "value held in STOP", $sformatf("%0d", c1), $sformatf("%0d", sw_count()));
            phase_end();
        end
        // ------------------------------------------------------------------ P4
        if (phase_begin(4, "STOP: L -> 0 and lap released (SC4)")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            #(150 * MS);
            press(BR);  // STOP, 값 있음
            press(BD);  // 랩 켜기
            check("SC4", dut.w_lap_active == 1, "lap on before clear", "1", $sformatf("%b", dut.w_lap_active));
            check("SC6", led[7] == 1, "led7 = lap", "1", $sformatf("%b", led[7]));
            press(BL);
            check("SC4", sw_count() == 0 && dut.w_lap_active == 0, "L in STOP -> 0, lap off", "0 lap=0",
                  $sformatf("%0d lap=%b", sw_count(), dut.w_lap_active));
            check_disp("SC4", "00.00", "FND after clear");
            phase_end();
        end
        // ------------------------------------------------------------------ P5
        if (phase_begin(5, "RUN: L ignored (value kept, keeps counting), U ignored (direction kept) (SB5, SB6)")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            #(300 * MS);
            c1 = sw_count();
            press(BL);
            c2 = sw_count();
            check("SB5", c2 > c1 && dut.w_run_stop == 1, "L during RUN ignored: not cleared, still RUN",
                  $sformatf(">%0d RUN", c1), $sformatf("%0d run=%b", c2, dut.w_run_stop));
            m0 = dut.w_mode;
            press(BU);
            check("SB6", dut.w_mode == m0, "U during RUN ignored: direction unchanged", $sformatf("%0d", m0), $sformatf("%0d", dut.w_mode));
            c1 = sw_count();
            #(50 * MS);
            check("SB6", sw_count() > c1, "still counting up after U", $sformatf(">%0d", c1), $sformatf("%0d", sw_count()));
            phase_end();
        end
        // ------------------------------------------------------------------ P6
        if (phase_begin(6, "STOP: R and L pressed at the same instant -> RUN and cleared to 0 (SB7, LIMIT)")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            #(250 * MS);
            press(BR);
            c1 = sw_count();
            check("SB7", c1 > 0 && dut.w_run_stop == 0, "STOP with a value before R+L", ">0 STOP",
                  $sformatf("%0d run=%b", c1, dut.w_run_stop));
            press2(BR, BL);
            pv = last_pv;
            check("SB7", pv == 4'b0011, "R and L debounced pulses in the same clock", "{D,U,L,R}=0011", $sformatf("%b", pv));
            check("SB7", dut.w_run_stop == 1 && sw_count() <= 1, "R+L same clock in STOP -> RUN from 0",
                  "RUN count<=1", $sformatf("run=%b count=%0d (was %0d)", dut.w_run_stop, sw_count(), c1));
            if (dut.w_run_stop == 1 && sw_count() <= 1)
                limit("SB7", $sformatf("R+L same clock in STOP: RUN starts AND measured %0d counts are cleared (board FSM spec: R wins, no clear)", c1));
            phase_end();
        end
        // ------------------------------------------------------------------ P7
        if (phase_begin(7, "background: stopwatch keeps running on watch screen, watch buttons not routed (SC5)")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            set_sw(0, 0, 0, 0, 0);  // 시계 화면
            check("SC6", led == 16'h8009, "LED on watch screen", "8009", $sformatf("%h", led));
            c1 = sw_count();
            press(BR); press(BL); press(BU); press(BD);
            c2 = sw_count();
            check("SC5", dut.w_run_stop == 1 && dut.w_lap_active == 0 && dut.w_mode == 0,
                  "watch-screen R/L/U/D do not reach stopwatch", "RUN lap=0 mode=0",
                  $sformatf("run=%b lap=%b mode=%b", dut.w_run_stop, dut.w_lap_active, dut.w_mode));
            check("SC5", c2 >= c1 + 3, "stopwatch counted in background (40 ms of presses)", $sformatf(">=%0d", c1 + 3), $sformatf("%0d", c2));
            check("SC5", dut.w_wt_hour == 12 && dut.w_wt_min == 0, "watch not changed by buttons in NORMAL", "12:00", wt_now());
            set_sw(0, 0, 0, 0, 1);
            #(30 * MS);
            check("SC5", sw_count() > c2 && dut.w_run_stop == 1, "back on stopwatch screen, still running (30 ms later)",
                  $sformatf(">%0d", c2), $sformatf("%0d", sw_count()));
            phase_end();
        end
        tb_finish();
    end
endmodule
