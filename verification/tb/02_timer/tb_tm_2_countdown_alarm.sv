`timescale 1ns / 1ps
// =============================================================================
// tb_tm_2_countdown_alarm — TIMER (boyun): 실제 카운트다운 · 알람 (verification.md §4.4)
//   P1 U 1 회(00:10) → L → ALARM 까지 실측 (프리로드 없음) ∈ (9.99 s, 10.00 s + 1 clk] (TB5)
//   P2 알람 LED 패턴 1.5 s (§1.5) · P3 D 로 끄기 → SET, 0 유지 (TB6) · P4 borrow 01:00.00→00:59.99, 10:00.00→09:59.99 (TB4)
// =============================================================================
module tb_tm_2_countdown_alarm;
`define TB_ID "TM2"
`define TB_TIMEOUT_MS 25000
`include "tb_common.svh"

    realtime t_run = 0, t_alarm = 0;
    always @(posedge dut.w_tm_run)   t_run   = $realtime;
    always @(posedge dut.w_tm_alarm) t_alarm = $realtime;

    initial begin
        realtime dt;
        integer i, nbad;
        reg [15:0] exp_led;
        #1;
        // ------------------------------------------------------------------ P1~P3 (연속: P2/P3 는 P1 의 알람을 씀)
        if (phase_begin(1, "00:10 real countdown, run->alarm interval (TB5), no preload")) begin
            do_reset();
            set_sw(1, 0, 0, 0, 0);
            press(BU);
            check("TB5", tm_now() == "00:10.00", "U -> 00:10", "00:10.00", tm_now());
            press(BL);
            check("TC6", dut.w_tm_run == 1 && led[6] == 1, "running, led6", "1 1", $sformatf("%b %b", dut.w_tm_run, led[6]));
            @(posedge dut.w_tm_alarm);
            dt = t_alarm - t_run;
            info("TB5", $sformatf("run->alarm = %0.6f ms (set 10.000 s)", dt / 1.0e6));
            check("TB5", dt > 9.99e9 && dt <= 10.0e9 + 10.001, "10 s timer duration", "(9990 ms, 10000 ms + 1 clk]",
                  $sformatf("%0.6f ms", dt / 1.0e6));
            check("TB5", tm_now() == "00:00.00" && dut.w_tm_run == 0, "at alarm: 00:00, not running", "00:00.00",
                  $sformatf("%s run=%b", tm_now(), dut.w_tm_run));
            phase_end();

            void'(phase_begin(2, "alarm LED pattern 1.5 s: all 16 = w_blink (FFFF while watch msec>=50, else 0000)"));
            nbad = 0;
            for (i = 0; i < 30; i = i + 1) begin
                #(50 * MS);
                exp_led = (dut.w_wt_msec >= 50) ? 16'hFFFF : 16'h0000;
                if (led != exp_led) nbad = nbad + 1;
                check("TC6", led == exp_led, $sformatf("alarm LED sample %0d (watch msec=%0d)", i, dut.w_wt_msec),
                      $sformatf("%h", exp_led), $sformatf("%h", led));
            end
            info("TC6", $sformatf("30 samples over 1.5 s, %0d mismatches", nbad));
            check("TC6", dut.w_tm_alarm == 1, "still alarming after 1.5 s (no auto-off)", "1", $sformatf("%b", dut.w_tm_alarm));
            phase_end();

            void'(phase_begin(3, "D turns alarm off -> SET, value stays 0 (D not used as +10 min) (TB6)"));
            press(BD);
            check("TB6", dut.w_tm_alarm == 0 && dut.w_tm_run == 0, "alarm off, SET", "alarm=0 run=0",
                  $sformatf("alarm=%b run=%b", dut.w_tm_alarm, dut.w_tm_run));
            check("TB6", tm_now() == "00:00.00", "D only turned alarm off, did not add 10 min", "00:00.00", tm_now());
            check("TC6", led == 16'h0020, "LED back to timer screen", "0020", $sformatf("%h", led));
            phase_end();
        end
        // ------------------------------------------------------------------ P4
        if (phase_begin(4, "borrow: 01:00.00 -> 00:59.99, 10:00.00 -> 09:59.99 (TB4)")) begin
            do_reset();
            set_sw(1, 0, 0, 0, 0);
            press(BU);
            press(BL);       // RUN (00:10 에서)
            preload_tm(1, 0, 0);
            wait_ticks(1);
            check("TB4", tm_now() == "00:59.99", "01:00.00 - 1 tick", "00:59.99", tm_now());
            preload_tm(10, 0, 0);
            wait_ticks(1);
            check("TB4", tm_now() == "09:59.99", "10:00.00 - 1 tick", "09:59.99", tm_now());
            check_disp("TB4", "09.59", "FND MM.SS");
            press(BL);       // 취소
            phase_end();
        end
        tb_finish();
    end
endmodule
