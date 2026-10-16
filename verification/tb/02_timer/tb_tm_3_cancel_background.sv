`timescale 1ns / 1ps
// =============================================================================
// tb_tm_3_cancel_background — TIMER (boyun): 취소 · 백그라운드 · 게이팅 (verification.md §4.4)
//   P1 RUN 중 U/R/D 무시 (TC2) · P2 RUN 중 L → 0, SET · P3 시작 → 시계 화면 → 프리로드 00:00.30 → 시계 화면에서 ALARM LED (TC3)
//   P4 시계 화면 버튼으로 안 꺼짐 (TC4) · P5 sw4+sw0 → 타이머 우선, 버튼으로 끄기 (TC5)
// =============================================================================
module tb_tm_3_cancel_background;
`define TB_ID "TM3"
`define TB_TIMEOUT_MS 3000
`include "tb_common.svh"

    function automatic integer tm_cs();  // 남은 시간 (1/100 초)
        tm_cs = (dut.w_tm_min * 60 + dut.w_tm_sec) * 100 + dut.w_tm_msec;
    endfunction

    initial begin
        integer c1;
        reg [15:0] exp_led;
        #1;
        // ------------------------------------------------------------------ P1
        if (phase_begin(1, "RUN: U/R/D ignored (TC2)")) begin
            do_reset();
            set_sw(1, 0, 0, 0, 0);
            press(BR);   // 01:00
            press(BL);   // RUN
            c1 = tm_cs();
            press(BU); press(BR); press(BD);
            check("TC2", tm_cs() < c1 && tm_cs() > c1 - 10, "U/R/D during RUN add nothing (only ~30 ms elapsed)",
                  $sformatf("(%0d,%0d)", c1 - 10, c1), $sformatf("%0d (%s)", tm_cs(), tm_now()));
            check("TC2", dut.w_tm_run == 1, "still running", "1", $sformatf("%b", dut.w_tm_run));
            phase_end();
        end
        // ------------------------------------------------------------------ P2
        if (phase_begin(2, "RUN: L -> cancel to 00:00, SET")) begin
            do_reset();
            set_sw(1, 0, 0, 0, 0);
            press(BR);
            press(BL);
            #(50 * MS);
            press(BL);
            check("TC2", tm_now() == "00:00.00" && dut.w_tm_run == 0 && dut.w_tm_alarm == 0, "L during RUN cancels (0, SET, no alarm)",
                  "00:00.00 SET", $sformatf("%s run=%b alarm=%b", tm_now(), dut.w_tm_run, dut.w_tm_alarm));
            phase_end();
        end
        // ------------------------------------------------------------------ P3~P4 (연속)
        if (phase_begin(3, "background: start, go to watch screen, preload 00:00.30 -> ALARM LED on watch screen (TC3)")) begin
            do_reset();
            set_sw(1, 0, 0, 0, 0);
            press(BR);
            press(BL);
            set_sw(0, 0, 0, 1, 0);  // 시계 화면
            check("TC3", dut.w_tm_run == 1, "timer runs in background", "1", $sformatf("%b", dut.w_tm_run));
            preload_tm(0, 0, 30);
            @(posedge dut.w_tm_alarm);
            info("TC3", "ALARM reached while watch screen is shown");
            #(20 * MS);
            exp_led = (dut.w_wt_msec >= 50) ? 16'hFFFF : 16'h0000;
            check("TC3", led == exp_led, "alarm LED pattern on watch screen", $sformatf("%h", exp_led), $sformatf("%h", led));
            check_disp("TC3", "12.00", "FND still shows the watch (12.00)");
            phase_end();

            void'(phase_begin(4, "watch-screen buttons do not stop the alarm (TC4)"));
            press(BU); press(BD); press(BL); press(BR);
            check("TC4", dut.w_tm_alarm == 1, "alarm still on after watch-screen U/D/L/R", "1", $sformatf("%b", dut.w_tm_alarm));
            set_sw(0, 0, 0, 0, 1);  // 스톱워치 화면
            press(BD);
            check("TC4", dut.w_tm_alarm == 1, "alarm still on after stopwatch-screen D", "1", $sformatf("%b", dut.w_tm_alarm));
            press(BD);  // 랩 원복
            phase_end();
        end
        // ------------------------------------------------------------------ P5
        if (phase_begin(5, "sw4=1 & sw0=1 -> timer has priority; timer-screen button turns alarm off (TC5)")) begin
            if (dut.w_tm_alarm == 0) begin  // +phase=5 단독 실행 대비
                do_reset();
                set_sw(1, 0, 0, 0, 0);
                press(BU);
                press(BL);
                preload_tm(0, 0, 30);
                @(posedge dut.w_tm_alarm);
            end
            set_sw(1, 0, 0, 0, 1);
            check("TC5", dut.w_sel_tm == 1 && dut.w_sel_sw == 0, "timer selected over stopwatch", "sel_tm=1 sel_sw=0",
                  $sformatf("sel_tm=%b sel_sw=%b", dut.w_sel_tm, dut.w_sel_sw));
            press(BR);
            check("TC5", dut.w_tm_alarm == 0 && tm_now() == "00:00.00", "R on timer screen turns alarm off, no +1 min",
                  "alarm=0 00:00.00", $sformatf("alarm=%b %s", dut.w_tm_alarm, tm_now()));
            check("TC6", led == 16'h0020, "LED timer screen with sw0=1: led5 only (led1 off, timer has priority)", "0020", $sformatf("%h", led));
            phase_end();
        end
        tb_finish();
    end
endmodule
