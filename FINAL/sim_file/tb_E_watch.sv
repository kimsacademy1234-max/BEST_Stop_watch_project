`timescale 1ns / 1ps
// =============================================================================
// tb_E_watch — E. 시계 (tb_scenario.md E1 ~ E6)
//   E1 초기 · 1 초  E2 12/24 경계  E3 설정 커서 순환  E4 설정 값 wrap  E5 동시 입력  E6 초 화면에서 설정 (⚠)
//   경계값은 프리로드 (카운터 레지스터 force 1 clk) 뒤 실제 tick 으로 넘김
// =============================================================================
module tb_E_watch;
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
        .TB_ID     ("E_watch"),
        .ONLY      (ONLY),
        .TIMEOUT_MS(FAST ? 200 : 20_000)
    ) h ();

    localparam integer BR = 0, BL = 1, BU = 2, BD = 3;
    localparam [6:0]   SCR_HM = 7'b000_0010, SCR_SET = 7'b000_0110;
    real TCS, CLKN;

    function automatic string hm();
        return $sformatf("%02d:%02d (disp %02d, LD15 %b)", h.dut.U_WTS.w_wt_hour, h.dut.U_WTS.w_wt_min,
                         h.dut.w_disp_hour, h.led[15]);
    endfunction

    initial begin
        integer  hh0, dh0, idx, hh, mi, ds, exp_cur[6];
        bit      pm0;
        realtime t0;

        TCS  = h.T_CS;
        CLKN = h.CLK;

        // ---------------------------------------------------------------- E1
        if (h.run("E1")) begin
            h.begin_sc("E1", "initial value and first second", "reset -> wait 1 s",
                       "12:00:00.00, sec 0->1 exactly 100 T_CS after release (+-5 clk), LD15 1");
            h.set_sw(7'b000_0000);
            h.do_reset();
            h.check("E1-1", (h.wt_cs() == h.hms2cs(12, 0, 0, 0)) && (h.led[15] == 1), "right after reset",
                    "12:00:00.00, LD15 1", $sformatf("%s, LD15 %b", h.cs2str(h.wt_cs()), h.led[15]));
            h.wait_until(h.t_rel + 100 * TCS + 20 * CLKN);
            h.check("E1-2", (h.dut.U_WTS.w_wt_sec == 1) && (h.t_wt_sec_chg - h.t_rel >= 100 * TCS - 5 * CLKN)
                            && (h.t_wt_sec_chg - h.t_rel <= 100 * TCS + 5 * CLKN),
                    "sec 0 -> 1", $sformatf("12:00:01.00 at %0.0f ns", 100 * TCS),
                    $sformatf("%s at %0.0f ns", h.cs2str(h.wt_cs()), h.t_wt_sec_chg - h.t_rel));
        end

        // ---------------------------------------------------------------- E2
        if (h.run("E2")) begin
            h.begin_sc("E2", "12 / 24 h boundaries", "preload hour / 11:59:59.99 / 23:59:59.99, real tick crosses",
                       "00 -> 12 AM, 12 PM, 13 -> 01, 24 h mode shows 13");
            h.do_reset();
            h.set_sw(SCR_HM);
            h.preload_wt(0, 30, 0, 0);
            h.wait_clk(2);
            h.check("E2-1", (h.dut.w_disp_hour == 12) && (h.led[15] == 0), "00:30 in 12 h", "disp 12, LD15 0", hm());
            h.preload_wt(11, 59, 59, 99);
            h.wait_clk(2);
            pm0 = h.led[15];
            h.wait_until($realtime + TCS + 10 * CLKN);
            h.check("E2-2", (pm0 == 0) && (h.dut.U_WTS.w_wt_hour == 12) && (h.dut.w_disp_hour == 12) && (h.led[15] == 1),
                    "11:59:59.99 -> 12:00", "disp 12, LD15 0 -> 1", {$sformatf("LD15 before %b, ", pm0), hm()});
            h.preload_wt(12, 30, 0, 0);
            h.wait_clk(2);
            h.check("E2-3", (h.dut.w_disp_hour == 12) && (h.led[15] == 1), "12:30 in 12 h", "disp 12, LD15 1", hm());
            h.preload_wt(13, 30, 0, 0);
            h.wait_clk(2);
            h.check("E2-4", (h.dut.w_disp_hour == 1) && (h.led[15] == 1), "13:30 in 12 h", "disp 01, LD15 1", hm());
            h.preload_wt(23, 59, 59, 99);
            h.wait_clk(2);
            pm0 = h.led[15];
            h.wait_until($realtime + TCS + 10 * CLKN);
            h.check("E2-5", (pm0 == 1) && (h.dut.U_WTS.w_wt_hour == 0) && (h.dut.w_disp_hour == 12) && (h.led[15] == 0),
                    "23:59:59.99 -> 00:00", "disp 12, LD15 1 -> 0", {$sformatf("LD15 before %b, ", pm0), hm()});
            h.set_sw(SCR_HM | 7'b000_1000);
            h.preload_wt(13, 30, 0, 0);
            h.wait_clk(2);
            h.check("E2-6", (h.dut.w_disp_hour == 13) && (h.led[15] == 0), "13:30 in 24 h", "disp 13, LD15 0", hm());
        end

        // ---------------------------------------------------------------- E3
        if (h.run("E3")) begin
            h.begin_sc("E3", "set cursor rotation", "set on -> R x3 -> L x3",
                       "R: 0 -> 2 -> 1 -> 0, L: 0 -> 1 -> 2 -> 0 (0 min1, 1 min10, 2 hour)");
            h.set_sw(7'b000_0000);
            h.do_reset();
            h.set_sw(SCR_SET);
            h.wait_clk(3);
            h.note($sformatf("set entered : cursor %0d (expect 0)", h.dut.w_wt_cursor));
            exp_cur = '{2, 1, 0, 1, 2, 0};
            for (int i = 0; i < 6; i++) begin
                h.pulse_phy((i < 3) ? BR : BL);
                h.check($sformatf("E3-%0d", i + 1), h.dut.w_wt_cursor == exp_cur[i], h.pick(i < 3, "R", "L"),
                        $sformatf("cursor %0d", exp_cur[i]), $sformatf("cursor %0d", h.dut.w_wt_cursor));
            end
        end

        // ---------------------------------------------------------------- E4
        if (h.run("E4")) begin
            h.begin_sc("E4", "set value wraps per digit, no carry", "preload, U / D on each cursor",
                       "59+1=00, 00-1=59, 55+10=05, 05-10=55, 23+1=0, 0-1=23, other digits unchanged");
            h.set_sw(7'b000_0000);
            h.do_reset();
            h.set_sw(SCR_SET);
            h.wait_clk(3);
            // 분 1 (cursor 0)
            h.preload_wt(12, 59, 0, 0);
            h.pulse_phy(BU);
            h.check("E4-1", (h.dut.U_WTS.w_wt_min == 0) && (h.dut.U_WTS.w_wt_hour == 12), "min1 : 12:59 U", "12:00", hm());
            h.preload_wt(12, 0, 0, 0);
            h.pulse_phy(BD);
            h.check("E4-2", (h.dut.U_WTS.w_wt_min == 59) && (h.dut.U_WTS.w_wt_hour == 12), "min1 : 12:00 D", "12:59", hm());
            // 분 10 (cursor 1)
            h.pulse_phy(BL);
            h.preload_wt(12, 55, 0, 0);
            h.pulse_phy(BU);
            h.check("E4-3", (h.dut.U_WTS.w_wt_min == 5) && (h.dut.U_WTS.w_wt_hour == 12), "min10 : 12:55 U", "12:05", hm());
            h.preload_wt(12, 5, 0, 0);
            h.pulse_phy(BD);
            h.check("E4-4", (h.dut.U_WTS.w_wt_min == 55) && (h.dut.U_WTS.w_wt_hour == 12), "min10 : 12:05 D", "12:55", hm());
            // 시 (cursor 2)
            h.pulse_phy(BL);
            h.preload_wt(23, 10, 0, 0);
            h.pulse_phy(BU);
            h.check("E4-5", (h.dut.U_WTS.w_wt_hour == 0) && (h.dut.U_WTS.w_wt_min == 10), "hour : 23:10 U", "00:10", hm());
            h.preload_wt(0, 10, 0, 0);
            h.pulse_phy(BD);
            h.check("E4-6", (h.dut.U_WTS.w_wt_hour == 23) && (h.dut.U_WTS.w_wt_min == 10), "hour : 00:10 D", "23:10", hm());
        end

        // ---------------------------------------------------------------- E5
        if (h.run("E5")) begin
            h.begin_sc("E5", "simultaneous inputs", "U+D same clk ; minute tick and U same clk (force aligned)",
                       "no change ; tick only (U dropped)");
            h.set_sw(7'b000_0000);
            h.do_reset();
            h.set_sw(SCR_SET);
            h.wait_clk(3);
            h.preload_wt(12, 10, 0, 0);
            h.pulse_phy2(BU, BD);
            h.check("E5-1", h.dut.U_WTS.w_wt_min == 10, "U + D same clock", "min 10", hm());
            h.preload_wt(12, 10, 59, 99);
            // P1 : 1/100 의 올림이 초 카운터에 들어가는 엣지 → 다음 엣지 P2 에 분 카운터 tick
            @(posedge h.clk iff ((h.dut.U_WTS.U_WATCH_DATAPATH.w_tick_sec === 1'b1) && (h.dut.U_WTS.w_wt_sec == 59)));
            h.pulse_phy_at(BU, $realtime + 10.0);
            h.wait_clk(3);
            h.check("E5-2", (h.dut.U_WTS.w_wt_min == 11) && (h.dut.U_WTS.w_wt_sec == 0), "minute tick + U same clock",
                    "min 11 (tick only)", hm());
        end

        // ---------------------------------------------------------------- E6
        if (h.run("E6")) begin
            h.begin_sc("E6", "set switch on SS.CC screen", "switch mode : sw1 0 + sw2 1 (watch SS.CC) -> U",
                       "spec : minute not changed (not visible) - code changes it (issue 5)");
            h.set_sw(7'b000_0000);
            h.do_reset();
            h.set_sw(7'b000_0100);
            h.wait_clk(3);
            h.preload_wt(12, 10, 0, 0);
            h.pulse_phy(BU);
            h.spec("E6-1", h.dut.U_WTS.w_wt_min == 10, "U on watch SS.CC with set_sw2 1", "min 10 (unchanged)",
                   $sformatf("min %0d (cursor %0d)", h.dut.U_WTS.w_wt_min, h.dut.w_wt_cursor));
        end

        h.finish_tb();
    end
endmodule
