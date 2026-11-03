`timescale 1ns / 1ps
// =============================================================================
// tb_F_timer — F. 타이머 (tb_scenario.md F1 ~ F6)
//   F1 10 초 타이머  F2 0 에서 시작  F3 포화 · 올림  F4 RUN 중 더하기 · 취소  F5 알람 끄기  F6 다른 화면에서 알람
//   타이머 버튼 : U +10 초, R +1 분, D +10 분, L 시작 / 취소
// =============================================================================
module tb_F_timer;
    localparam string ONLY = "";
    localparam bit    FAST = 1;    // 1 = 시간 줄임 (tb_scenario.md 3-3), 0 = 실제 시간

    tb_merge_harness #(
        .TICK_F    (FAST ? 1_000 : 1_000_000),
        .AUTO_FRQ  (FAST ? 200 : 1),
        .DHT_BOOT  (FAST ? 300_000 : 100_000_000),
        .DHT_INTV  (FAST ? 500_000 : 200_000_000),
        .BLINK_HALF(FAST ? 25_000 : 25_000_000),
        .BAUD      (FAST ? 115_200 : 9_600),
        .SR_TICK   (FAST ? 10 : 100),
        .DHT_TICK  (FAST ? 10 : 100),
        .TB_ID     ("F_timer"),
        .ONLY      (ONLY),
        .TIMEOUT_MS(FAST ? 300 : 120_000)
    ) h ();

    localparam integer BR = 0, BL = 1, BU = 2, BD = 3;
    localparam [6:0]   SCR_TM = 7'b001_0000, SCR_DIST = 7'b010_0000;
    real TCS, CLKN;

    function automatic string tm();
        return $sformatf("%02d:%02d.%02d run %b alarm %b", h.dut.U_WTS.w_tm_min, h.dut.U_WTS.w_tm_sec, h.dut.U_WTS.w_tm_msec,
                         h.dut.w_tm_run, h.dut.w_tm_alarm);
    endfunction

    // 알람 LED : 16 개 전부 = 시계 1/100 ≥ 50. n 번 샘플 (간격 TCS)
    task automatic alarm_led(input integer n, output bit ok, output bit seen_on, output bit seen_off);
        ok = 1; seen_on = 0; seen_off = 0;
        for (int i = 0; i < n; i++) begin
            #(TCS * 1.013);
            if (h.led !== {16{h.dut.w_wt_msec >= 50}}) ok = 0;
            if (h.led == 16'hFFFF) seen_on = 1;
            if (h.led == 16'h0000) seen_off = 1;
        end
    endtask

    task automatic wait_alarm(input real tmo_ns);
        realtime tend;
        tend = $realtime + tmo_ns;
        while ((h.dut.w_tm_alarm !== 1'b1) && ($realtime < tend)) #(TCS / 10);
    endtask

    task automatic presses(input integer b, input integer n);
        for (int i = 0; i < n; i++) h.pulse_phy(b);
    endtask

    initial begin
        realtime t0;
        integer  v0;
        bit      led_run, ok, on, off;

        TCS  = h.T_CS;
        CLKN = h.CLK;

        // ---------------------------------------------------------------- F1
        if (h.run("F1")) begin
            h.begin_sc("F1", "10 second timer", "U (+10 s) -> L (t0) -> wait alarm",
                       "00.10 ; alarm exactly 1000 T_CS after L (+-5 clk), LED6 while running ; all 16 LED blink 0.5 s");
            h.set_sw(SCR_TM);
            h.do_reset();
            h.pulse_phy(BU);
            h.check("F1-1", (h.tm_cs() == 1000) && (h.dut.w_disp_hour == 0) && (h.dut.w_disp_min == 10), "after U",
                    "00:10.00, FND MM.SS = 00.10", {tm(), $sformatf(", disp %02d.%02d", h.dut.w_disp_hour, h.dut.w_disp_min)});
            h.pulse_phy(BL);
            t0 = h.t_last_pulse;
            h.wait_until(t0 + 500 * TCS);
            led_run = h.led[6];
            wait_alarm(600 * TCS);
            h.check("F1-2", (h.t_alarm - t0 >= 1000 * TCS - 5 * CLKN) && (h.t_alarm - t0 <= 1000 * TCS + 5 * CLKN)
                            && (led_run == 1) && (h.dut.w_tm_run == 0),
                    "alarm time after L", $sformatf("%0.0f ns, LED6 1 while running", 1000 * TCS),
                    $sformatf("%0.0f ns, LED6 %b, %s", h.t_alarm - t0, led_run, tm()));
            alarm_led(150, ok, on, off);
            h.check("F1-3", ok && on && off, "alarm LED = {16{watch msec >= 50}}", "match, both FFFF and 0000 seen",
                    $sformatf("match %b, on %b, off %b", ok, on, off));
            h.pulse_phy(BU);
        end

        // ---------------------------------------------------------------- F2
        if (h.run("F2")) begin
            h.begin_sc("F2", "start from 00:00", "L at 00:00", "does not start (LED6 0)");
            h.set_sw(SCR_TM);
            h.do_reset();
            h.pulse_phy(BL);
            h.wait_clk(5);
            h.check("F2-1", (h.dut.w_tm_run == 0) && (h.led[6] == 0), "L at 00:00", "not running", tm());
        end

        // ---------------------------------------------------------------- F3
        if (h.run("F3")) begin
            h.begin_sc("F3", "saturation and carry", "D x6 ; 59:50 + U ; 00:50 + U", "59:59 ; 59:59 ; 01:00");
            h.set_sw(SCR_TM);
            h.do_reset();
            presses(BD, 6);
            h.check("F3-1", h.tm_cs() == h.hms2cs(0, 59, 59, 0), "D x6 (60 min)", "59:59.00", tm());
            h.do_reset();
            presses(BD, 5);
            presses(BR, 9);
            presses(BU, 5);
            h.note({"before U : ", tm()});
            h.pulse_phy(BU);
            h.check("F3-2", h.tm_cs() == h.hms2cs(0, 59, 59, 0), "59:50 + U", "59:59.00", tm());
            h.do_reset();
            presses(BU, 5);
            h.pulse_phy(BU);
            h.check("F3-3", h.tm_cs() == h.hms2cs(0, 1, 0, 0), "00:50 + U", "01:00.00", tm());
        end

        // ---------------------------------------------------------------- F4
        if (h.run("F4")) begin
            h.begin_sc("F4", "add ignored while running, L cancels", "00:30 run -> U R D -> L",
                       "value keeps going down ; 00:00 SET");
            h.set_sw(SCR_TM);
            h.do_reset();
            presses(BU, 3);
            h.pulse_phy(BL);
            h.wait_until($realtime + 50 * TCS);
            v0 = h.tm_cs();
            h.pulse_phy(BU);
            h.pulse_phy(BR);
            h.pulse_phy(BD);
            h.check("F4-1", (h.tm_cs() <= v0) && (h.dut.w_tm_run == 1), "U R D during RUN", $sformatf("<= %s, running", h.cs2str(v0)),
                    tm());
            h.pulse_phy(BL);
            h.check("F4-2", (h.tm_cs() == 0) && (h.dut.w_tm_run == 0) && (h.led[6] == 0), "L during RUN", "00:00.00 SET", tm());
        end

        // ---------------------------------------------------------------- F5
        if (h.run("F5")) begin
            h.begin_sc("F5", "any button clears alarm", "alarm -> R / L / U / D (each)",
                       "SET, 00:00, the press is not added");
            for (int b = 0; b < 4; b++) begin
                h.set_sw(SCR_TM);
                h.do_reset();
                h.pulse_phy(BU);
                h.pulse_phy(BL);
                wait_alarm(1100 * TCS);
                h.pulse_phy(b);
                h.wait_clk(10);
                h.check($sformatf("F5-%0d", b + 1), (h.dut.w_tm_alarm == 0) && (h.dut.w_tm_run == 0) && (h.tm_cs() == 0),
                        {"alarm + btn ", h.pick(b == 0, "R", h.pick(b == 1, "L", h.pick(b == 2, "U", "D")))}, "alarm 0, 00:00.00", tm());
            end
        end

        // ---------------------------------------------------------------- F6
        if (h.run("F6")) begin
            h.begin_sc("F6", "alarm while another screen is shown", "timer 10 s -> distance screen -> alarm -> R -> timer screen -> U",
                       "16 LED blink on distance screen ; R there does not clear ; U on timer screen clears");
            h.set_sw(SCR_TM);
            h.do_reset();
            h.pulse_phy(BU);
            h.pulse_phy(BL);
            h.set_sw(SCR_DIST);
            wait_alarm(1100 * TCS);
            alarm_led(150, ok, on, off);
            h.check("F6-1", ok && on && off && (h.dut.w_disp_sel == 1), "LED on distance screen during alarm",
                    "16 LED blink", $sformatf("match %b, on %b, off %b", ok, on, off));
            v0 = h.trig_cnt;
            h.pulse_phy(BR);
            h.wait_us(100);
            h.check("F6-2", (h.dut.w_tm_alarm == 1) && (h.trig_cnt == v0 + 1), "R on distance screen", "alarm stays, 1 trig",
                    $sformatf("alarm %b, %0d trig", h.dut.w_tm_alarm, h.trig_cnt - v0));
            h.set_sw(SCR_TM);
            h.pulse_phy(BU);
            h.check("F6-3", h.dut.w_tm_alarm == 0, "U on timer screen", "alarm 0", tm());
        end

        h.finish_tb();
    end
endmodule
