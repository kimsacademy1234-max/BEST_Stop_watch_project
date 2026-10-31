`timescale 1ns / 1ps
// =============================================================================
// tb_D_stopwatch — D. 스톱워치 (tb_scenario.md D1 ~ D7)
//   D1 시작 정확도  D2 짧은 run 누적  D3 최대값 wrap  D4 다운 wrap  D5 RUN 중 U · L
//   D6 랩  D7 랩 + 지우기 / UART (⚠)
//   버튼 = 디바운서 출력에 1 clk (h.pulse_phy) → 시작 · 정지 엣지를 클럭 단위로 맞춤
//   시간 = T_CS (1/100 초) 배수로 판정. FAST 면 T_CS = 10 us
// =============================================================================
module tb_D_stopwatch;
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
        .TB_ID     ("D_stopwatch"),
        .ONLY      (ONLY),
        .TIMEOUT_MS(FAST ? 300 : 20_000)
    ) h ();

    localparam integer BR = 0, BL = 1, BU = 2, BD = 3;
    localparam [6:0]   SCR_SW = 7'b000_0001;
    localparam integer CS_PER_DAY = 24 * 360000;
    real TCS;   // = h.T_CS
    real CLKN;  // 클럭 1 개 (ns)

    initial begin
        string   s;
        realtime t0, t1, tr;
        integer  v0, v1, vlap, nclk;
        bit      d0;

        TCS  = h.T_CS;
        CLKN = h.CLK;

        // ---------------------------------------------------------------- D1
        if (h.run("D1")) begin
            h.begin_sc("D1", "start accuracy", "R (t0) -> R at t0 + 100.5 x T_CS",
                       "first 1/100 change exactly T_CS after R (+-5 clk), stop value 00:00:01.00");
            h.set_sw(SCR_SW);
            h.do_reset();
            h.pulse_phy(BR);
            t0 = h.t_last_pulse;
            h.wait_until(t0 + 1.5 * TCS);
            h.check("D1-1", (h.t_sw_ms_chg - t0 >= TCS - 5 * CLKN) && (h.t_sw_ms_chg - t0 <= TCS + 5 * CLKN),
                    "first 1/100 tick after R", $sformatf("%0.0f ns", TCS), $sformatf("%0.0f ns", h.t_sw_ms_chg - t0));
            h.pulse_phy_at(BR, t0 + 10 * $rtoi((100.5 * TCS) / 10));
            h.wait_until(h.t_last_pulse + 2 * TCS);
            h.check("D1-2", (h.sw_cnt_cs() == 100) && (h.dut.U_WTS.w_sw_run_stop == 0), "value after stop at 1.005 s",
                    "00:00:01.00 STOP", $sformatf("%s run %b", h.cs2str(h.sw_cnt_cs()), h.dut.U_WTS.w_sw_run_stop));
        end

        // ---------------------------------------------------------------- D2
        if (h.run("D2")) begin
            h.begin_sc("D2", "short runs accumulate", "10 x (run 0.37 T_CS, stop) -> run again",
                       "0.03 after 3.7 T_CS, 0.04 exactly at 4.00 T_CS of total run");
            h.set_sw(SCR_SW);
            h.do_reset();
            nclk = $rtoi(0.37 * TCS / CLKN);
            @(posedge h.clk);
            tr = $realtime + 10 * CLKN;
            for (int i = 0; i < 10; i++) begin
                h.pulse_phy_at(BR, tr);                      // 시작
                h.pulse_phy_at(BR, tr + nclk * CLKN);        // nclk 클럭 뒤 정지
                tr = tr + nclk * CLKN + 500 * CLKN;
            end
            h.wait_clk(5);
            h.check("D2-1", h.sw_cnt_cs() == 3, "after 10 short runs", "00:00:00.03", h.cs2str(h.sw_cnt_cs()));
            nclk = $rtoi(TCS / CLKN) * 4 - 10 * nclk;       // 4.00 T_CS 까지 남은 클럭
            h.pulse_phy_at(BR, tr);
            t0 = h.t_last_pulse;
            h.wait_until(t0 + nclk * CLKN + 2 * TCS / 10);
            h.check("D2-2", (h.sw_cnt_cs() == 4) && (h.t_sw_ms_chg - t0 >= (nclk - 5) * CLKN) && (h.t_sw_ms_chg - t0 <= (nclk + 5) * CLKN),
                    "0.03 -> 0.04 moment", $sformatf("%0d clk after restart", nclk),
                    $sformatf("%s at %0.0f clk", h.cs2str(h.sw_cnt_cs()), (h.t_sw_ms_chg - t0) / CLKN));
        end

        // ---------------------------------------------------------------- D3
        if (h.run("D3")) begin
            h.begin_sc("D3", "max value wrap (up)", "preload 23:59:59.98 -> RUN -> 2 ticks",
                       "00:00:00.00, all digits settle <= 3 clk after the tick");
            h.set_sw(SCR_SW);
            h.do_reset();
            h.preload_sw(23, 59, 59, 98);
            h.pulse_phy(BR);
            t0 = h.t_last_pulse;
            h.wait_until(t0 + 2 * TCS + 4 * CLKN + 1);    // 둘째 tick (2 T_CS + 1 clk) + 3 clk
            v0 = h.sw_cnt_cs();
            h.check("D3-1", v0 == 0, "2 ticks after 23:59:59.98", "00:00:00.00", h.cs2str(v0));
        end

        // ---------------------------------------------------------------- D4
        if (h.run("D4")) begin
            h.begin_sc("D4", "down count wrap", "STOP: U (down) -> R",
                       "00:00:00.00 -> 23:59:59.99 -> 23:59:59.98");
            h.set_sw(SCR_SW);
            h.do_reset();
            h.pulse_phy(BU);
            h.pulse_phy(BR);
            t0 = h.t_last_pulse;
            h.wait_until(t0 + TCS + 6 * CLKN);
            v0 = h.sw_cnt_cs();
            h.check("D4-1", v0 == CS_PER_DAY - 1, "first tick (down)", "23:59:59.99", h.cs2str(v0));
            h.wait_until(t0 + 2 * TCS + 6 * CLKN);
            v0 = h.sw_cnt_cs();
            h.check("D4-2", v0 == CS_PER_DAY - 2, "second tick (down)", "23:59:59.98", h.cs2str(v0));
        end

        // ---------------------------------------------------------------- D5
        if (h.run("D5")) begin
            h.begin_sc("D5", "U / L ignored while running", "RUN 50 T_CS -> U -> L -> R (stop) -> L",
                       "direction kept, not cleared; L in STOP clears");
            h.set_sw(SCR_SW);
            h.do_reset();
            h.pulse_phy(BR);
            h.wait_until(h.t_last_pulse + 50 * TCS);
            d0 = h.dut.U_WTS.w_sw_down;
            h.pulse_phy(BU);
            h.check("D5-1", h.dut.U_WTS.w_sw_down == d0, "U during RUN", $sformatf("down %b", d0),
                    $sformatf("down %b", h.dut.U_WTS.w_sw_down));
            v0 = h.sw_cnt_cs();
            h.pulse_phy(BL);
            h.wait_until($realtime + 2 * TCS);
            v1 = h.sw_cnt_cs();
            h.check("D5-2", (v1 > v0) && (h.dut.U_WTS.w_sw_run_stop == 1), "L during RUN", "not cleared, still counting",
                    $sformatf("%s -> %s run %b", h.cs2str(v0), h.cs2str(v1), h.dut.U_WTS.w_sw_run_stop));
            h.pulse_phy(BR);
            h.pulse_phy(BL);
            h.check("D5-3", h.sw_cnt_cs() == 0, "L in STOP", "00:00:00.00", h.cs2str(h.sw_cnt_cs()));
        end

        // ---------------------------------------------------------------- D6
        if (h.run("D6")) begin
            h.begin_sc("D6", "lap", "RUN -> 30 T_CS: D -> 100 T_CS -> D",
                       "display frozen + LED7, counter keeps going, second D shows current");
            h.set_sw(SCR_SW);
            h.do_reset();
            h.pulse_phy(BR);
            h.wait_until(h.t_last_pulse + 30 * TCS);
            h.pulse_phy(BD);
            vlap = h.sw_disp_cs();
            h.wait_until($realtime + 100 * TCS);
            h.check("D6-1", (h.sw_disp_cs() == vlap) && (h.led[7] == 1), "display during lap", {h.cs2str(vlap), ", LED7 1"},
                    $sformatf("%s, LED7 %b", h.cs2str(h.sw_disp_cs()), h.led[7]));
            h.check("D6-2", h.sw_cnt_cs() >= vlap + 100, "counter during lap", $sformatf(">= %s", h.cs2str(vlap + 100)),
                    h.cs2str(h.sw_cnt_cs()));
            h.pulse_phy(BD);
            h.check("D6-3", (h.sw_disp_cs() == h.sw_cnt_cs()) && (h.led[7] == 0), "second D", "display = counter, LED7 0",
                    $sformatf("%s / %s, LED7 %b", h.cs2str(h.sw_disp_cs()), h.cs2str(h.sw_cnt_cs()), h.led[7]));
        end

        // ---------------------------------------------------------------- D7
        if (h.run("D7")) begin
            h.begin_sc("D7", "lap + clear / lap + UART", "lap -> stop -> L ; /mod s_ms -> lap -> /get",
                       "lap off and 0 ; /get sends running value (spec) - code sends lap value (issue 6)");
            h.set_sw(SCR_SW);
            h.do_reset();
            h.pulse_phy(BR);
            h.wait_until(h.t_last_pulse + 30 * TCS);
            h.pulse_phy(BD);
            h.pulse_phy(BR);
            h.pulse_phy(BL);
            h.check("D7-1", (h.dut.w_sw_lap == 0) && (h.sw_disp_cs() == 0) && (h.led[7] == 0), "lap -> STOP -> L",
                    "lap 0, 00:00:00.00", $sformatf("lap %b, %s", h.dut.w_sw_lap, h.cs2str(h.sw_disp_cs())));
            h.set_sw(7'b000_0000);
            h.do_reset();
            h.mod("s_ms");
            h.pulse_phy(BR);
            h.wait_until(h.t_last_pulse + 10 * TCS);
            h.pulse_phy(BD);
            vlap = h.sw_disp_cs();
            h.flush_lines();
            h.uget();
            h.next_line(s, t0, 20 * h.MS);
            h.spec("D7-2", s != h.cs2str(vlap), "/get while lap is shown", "running value (not lap)",
                   $sformatf("\"%s\" (lap %s, counter %s)", s, h.cs2str(vlap), h.cs2str(h.sw_cnt_cs())));
        end

        h.finish_tb();
    end
endmodule
