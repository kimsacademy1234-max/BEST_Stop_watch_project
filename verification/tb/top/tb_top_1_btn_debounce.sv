`timescale 1ns / 1ps
// =============================================================================
// tb_top_1_btn_debounce — 공통: 스위치 노이즈 · 누름 시간 (verification.md §5.1)
//   P0 리셋 직후 X 없음 · P1 누름 길이 sweep · P2 바운스 패턴 · P3 긴 누름 2 s
//   P4 누른 중 0 글리치 300 us (LIMIT) · P5 펄스 폭 = 1 clk
//   자극 대상: 시계 설정 모드(sw2=1, cursor 0) 의 U → 분 증가량으로 눌림 횟수 확인
// =============================================================================
module tb_top_1_btn_debounce;
`define TB_ID "TOP1"
`define TB_TIMEOUT_MS 6000
`include "tb_common.svh"

    // 시계 설정 모드에서 U 를 hi ns 누르고, 기대 펄스 수 / 분 증가량 확인
    task automatic try_press(input string cid, input longint hi, input integer exp_n, input string what);
        integer p0, m0, dp, dm;
        p0 = pc[BU];
        m0 = dut.w_wt_min;
        press_ns(BU, hi, 5 * MS);
        dp = pc[BU] - p0;
        dm = (dut.w_wt_min - m0 + 60) % 60;
        check(cid, dp == exp_n, $sformatf("%s : w_btnU pulses", what), $sformatf("%0d", exp_n), $sformatf("%0d", dp));
        check(cid, dm == exp_n, $sformatf("%s : watch min delta", what), $sformatf("+%0d", exp_n), $sformatf("+%0d", dm));
        info(cid, $sformatf("%s -> pulses=%0d min %0d->%0d", what, dp, m0, dut.w_wt_min));
    endtask

    initial begin
        integer p0, m0;
        #1;
        // ------------------------------------------------------------------ P0
        if (phase_begin(0, "reset: no X on outputs 1 us after reset, LED=8009")) begin
            do_reset();  // 해제 후 1 us 대기 포함
            check("X", (^{fnd_com, fnd_font, led}) !== 1'bx, "no X/Z on fnd_com/fnd_font/led", "no X",
                  $sformatf("com=%b font=%b led=%b", fnd_com, fnd_font, led));
            check("WC1", led == 16'h8009, "LED after reset (all switches 0)", "8009", $sformatf("%h", led));
            check("WC1", wt_now() == "12:00:00.00", "watch reset value", "12:00:00.00", wt_now());
            phase_end();
        end
        // ------------------------------------------------------------------ P1
        if (phase_begin(1, "press length sweep 1.0/1.5/1.7 ms (ignore) 2.0/2.5/5/100 ms (1 pulse)")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 0);  // 시계 설정, cursor 0 (분 일)
            try_press("P1.1.0ms", 1000 * US, 0, "press 1.0 ms");
            try_press("P1.1.5ms", 1500 * US, 0, "press 1.5 ms");
            try_press("P1.1.7ms", 1700 * US, 0, "press 1.7 ms");
            try_press("P1.2.0ms", 2000 * US, 1, "press 2.0 ms");
            try_press("P1.2.5ms", 2500 * US, 1, "press 2.5 ms");
            try_press("P1.5ms",   5 * MS,    1, "press 5 ms");
            try_press("P1.100ms", 100 * MS,  1, "press 100 ms");
            phase_end();
        end
        // ------------------------------------------------------------------ P2
        if (phase_begin(2, "bounce pattern -> exactly 1 pulse")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 0);
            p0 = pc[BU];
            m0 = dut.w_wt_min;
            press_bounce(BU);
            check("BOUNCE", pc[BU] - p0 == 1, "bounce pattern -> w_btnU pulses", "1", $sformatf("%0d", pc[BU] - p0));
            check("BOUNCE", dut.w_wt_min == (m0 + 1) % 60, "bounce pattern -> min +1", $sformatf("%0d", (m0 + 1) % 60),
                  $sformatf("%0d", dut.w_wt_min));
            phase_end();
        end
        // ------------------------------------------------------------------ P3
        if (phase_begin(3, "long press 2 s -> 1 pulse (no auto-repeat)")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 0);
            try_press("LONG", 2000 * MS, 1, "press 2 s");
            phase_end();
        end
        // ------------------------------------------------------------------ P4
        if (phase_begin(4, "0-glitch 300 us while held -> 2 pulses (design limit)")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 0);
            p0 = pc[BU];
            m0 = dut.w_wt_min;
            @(negedge clk);
            btnU = 1; #(10 * MS);
            btnU = 0; #(300 * US);
            btnU = 1; #(10 * MS);
            btnU = 0; #(5 * MS);
            check("GLITCH", pc[BU] - p0 == 2, "held + 300 us dropout -> w_btnU pulses", "2", $sformatf("%0d", pc[BU] - p0));
            check("GLITCH", dut.w_wt_min == (m0 + 2) % 60, "held + 300 us dropout -> min +2", $sformatf("%0d", (m0 + 2) % 60),
                  $sformatf("%0d", dut.w_wt_min));
            if (pc[BU] - p0 == 2)
                limit("GLITCH", "debouncer filters only press-start bounce: a 300 us dropout while held = 2nd press (release needs 1 sample)");
            phase_end();
        end
        // ------------------------------------------------------------------ P5
        if (phase_begin(5, "pulse width of all w_btnX = 1 clk")) begin
            check("PW", pw_bad == 0, $sformatf("all debouncer pulses 1 clk wide (R=%0d L=%0d U=%0d D=%0d pulses seen)",
                                                pc[0], pc[1], pc[2], pc[3]), "0 bad", $sformatf("%0d bad", pw_bad));
            phase_end();
        end
        tb_finish();
    end
endmodule
