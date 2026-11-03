`timescale 1ns / 1ps
// =============================================================================
// tb_K_display — K. FND · LED 표시 (tb_scenario.md K1 ~ K6)
//   K1 WTS FND  K2 설정 점멸  K3 거리 FND  K4 온습도 FND  K5 LED 화면별  K6 스캔
//   FND 는 fnd_com / fnd_font 핀만 보고 읽음 (h.fnd_read : 8 칸 = 2 ms)
//   WTS tick : FAST 여도 1/100 초 = 1 ms (TICK_F 100,000) — 2 ms 동안 읽는 동안 숫자가 덜 바뀌게
// =============================================================================
module tb_K_display;
    localparam string ONLY = "";
    localparam bit    FAST = 1;    // 1 = 시간 줄임 (tb_scenario.md 3-3), 0 = 실제 시간

    tb_merge_harness #(
        .TICK_F    (FAST ? 100_000 : 1_000_000),
        .AUTO_FRQ  (FAST ? 200 : 1),
        .DHT_BOOT  (FAST ? 300_000 : 100_000_000),
        .DHT_INTV  (FAST ? 500_000 : 200_000_000),
        .BLINK_HALF(FAST ? 25_000 : 25_000_000),
        .BAUD      (FAST ? 115_200 : 9_600),
        .SR_TICK   (FAST ? 10 : 100),
        .DHT_TICK  (FAST ? 10 : 100),
        .TB_ID     ("K_display"),
        .ONLY      (ONLY),
        .TIMEOUT_MS(FAST ? 1_000 : 20_000)
    ) h ();

    localparam integer BR = 0, BL = 1, BU = 2, BD = 3;
    real U, TI;

    task automatic sr_measure(input real w_us, output bit ok);
        h.wait_sr_idle(200 * U / 1000.0);
        h.sr_mode = h.SR_NORMAL;
        h.sr_w_us = w_us;
        h.pulse_phy(BR);
        h.wait_dist_done(100 * U / 1000.0, ok);
    endtask

    task automatic dh_measure(output bit ok);
        h.pulse_phy(BR);
        h.wait_dht_done(3.0 * TI / 1.0e6, ok);
    endtask

    // 다음 스캔 칸 (4 kHz) 이 안정된 뒤
    task automatic next_slot(output reg [2:0] sel, output integer an);
        @(posedge h.dut.w_clk_4khz);
        repeat (3) @(posedge h.clk);
        #1;
        sel = h.dut.U_FND_CONTROLLER.w_scan_sel;
        an  = h.com2an(h.fnd_com);
    endtask

    // 설정 점멸 검사 : ms 동안 숫자 칸마다 (커서 자리 빈칸 == blink_off), 다른 자리 빈칸 없음
    task automatic blink_check(input integer cur, input real ms, output integer bad, output integer n_blank, output integer n_digit);
        reg [2:0] sel;
        integer   an;
        realtime  tend;
        bit       blank;
        bad = 0; n_blank = 0; n_digit = 0;
        tend = $realtime + ms * h.MS;
        while ($realtime < tend) begin
            next_slot(sel, an);
            if (sel < 4) begin
                blank = (h.fnd_font == 8'hFF);
                if (an == cur) begin
                    if (blank != h.dut.U_FND_CONTROLLER.w_blink_off) bad++;
                    if (blank) n_blank++; else n_digit++;
                end else if (blank) bad++;
            end
        end
    endtask

    initial begin
        string   s;
        bit      ok, on_seen, off_seen;
        integer  bad, nb, nd, an, prev_an, nslot;
        reg [2:0] sel;
        reg [15:0] lv;
        realtime tc[$];
        bit      seq_ok, hot_ok;

        U  = h.SR_US;
        TI = h.T_INTV;

        // ---------------------------------------------------------------- K1
        if (h.run("K1")) begin
            h.begin_sc("K1", "WTS FND", "stopwatch 12.34 stopped ; watch HH.MM 12:05 ; AN2 dot over 1.2 s",
                       "\"12.34\" ; \"12.05\" ; dot on while watch 1/100 < 50");
            h.set_sw(7'b000_0001);
            h.do_reset();
            h.preload_sw(0, 0, 12, 34);
            h.fnd_read(s);
            h.check("K1-1", s == "12.34", "stopwatch SS.CC", "\"12.34\"", {"\"", s, "\""});
            h.set_sw(7'b000_0010);
            h.preload_wt(12, 5, 0, 0);
            h.fnd_read_stable(s);
            h.check("K1-2", h.strip_dot(s) == "1205", "watch HH.MM", "\"12.05\" (dot blinks)", {"\"", s, "\""});
            bad = 0; on_seen = 0; off_seen = 0;
            for (int i = 0; i < 480; i++) begin
                next_slot(sel, an);
                if (sel == 6) begin
                    if ((h.fnd_font[7] == 1'b0) != (h.dut.w_disp_msec < 50)) bad++;
                    if (h.fnd_font[7] == 1'b0) on_seen = 1; else off_seen = 1;
                end
            end
            h.check("K1-3", (bad == 0) && on_seen && off_seen, "AN2 dot vs 1/100 < 50", "always match, on and off seen",
                    $sformatf("%0d mismatch, on %b, off %b", bad, on_seen, off_seen));
        end

        // ---------------------------------------------------------------- K2
        if (h.run("K2")) begin
            h.begin_sc("K2", "set blink", "watch set 12:34, cursor AN0 -> (R) AN2 -> (R) AN1, each ~1.1 s",
                       "only the cursor digit blank while 1/100 >= 50");
            h.set_sw(7'b000_0000);
            h.do_reset();
            h.set_sw(7'b000_0110);
            h.preload_wt(12, 34, 0, 0);
            for (int k = 0; k < 3; k++) begin
                if (k > 0) h.pulse_phy(BR);
                blink_check(h.dut.w_wt_cursor, 110.0 * h.T_CS / 1.0e6, bad, nb, nd);
                h.check($sformatf("K2-%0d", k + 1), (bad == 0) && (nb > 0) && (nd > 0), $sformatf("cursor %0d (AN%0d)",
                        h.dut.w_wt_cursor, h.dut.w_wt_cursor), "only that digit blinks",
                        $sformatf("%0d mismatch, blank %0d, digit %0d", bad, nb, nd));
            end
        end

        // ---------------------------------------------------------------- K3
        if (h.run("K3")) begin
            h.begin_sc("K3", "distance FND", "reset, 5.8, 352.7, 399.1 cm, no echo, out of range, stuck",
                       "000.0 005.8 352.7 399.1 Err1 Err2 Err3");
            h.set_sw(7'b010_0000);
            h.do_reset();
            h.fnd_read(s);
            h.check("K3-1", s == "000.0", "after reset", "\"000.0\"", {"\"", s, "\""});
            sr_measure(339, ok);
            h.fnd_read(s);
            h.check("K3-2", s == "005.8", "5.8 cm", "\"005.8\"", {"\"", s, "\""});
            sr_measure(20460, ok);
            h.fnd_read(s);
            h.check("K3-3", s == "352.7", "352.7 cm", "\"352.7\"", {"\"", s, "\""});
            sr_measure(23150, ok);
            h.fnd_read(s);
            h.check("K3-4", s == "399.1", "399.1 cm", "\"399.1\"", {"\"", s, "\""});
            h.wait_sr_idle(200 * U / 1000.0);
            h.sr_mode = h.SR_NONE;
            h.pulse_phy(BR);
            h.wait_dist_done(100 * U / 1000.0, ok);
            h.fnd_read(s);
            h.check("K3-5", s == "Err1", "no echo", "\"Err1\"", {"\"", s, "\""});
            sr_measure(23250, ok);
            h.fnd_read(s);
            h.check("K3-6", s == "Err2", "out of range", "\"Err2\"", {"\"", s, "\""});
            h.wait_sr_idle(200 * U / 1000.0);
            h.sr_mode = h.SR_MANUAL;
            h.echo = 1'b1;
            h.pulse_phy(BR);
            h.wait_dist_done(100 * U / 1000.0, ok);
            h.wait_dist_done(100 * U / 1000.0, ok);
            h.fnd_read(s);
            h.check("K3-7", s == "Err3", "echo stuck", "\"Err3\"", {"\"", s, "\""});
            h.echo = 1'b0;
            h.sr_mode = h.SR_NORMAL;
        end

        // ---------------------------------------------------------------- K4
        if (h.run("K4")) begin
            h.begin_sc("K4", "temp / humidity FND", "before first, 5/3, 55/24, no response, cut, checksum",
                       "---- 05.03 55.24 Err1 Err2 Err3");
            h.dh_default();
            h.set_sw(7'b100_0000);
            h.do_reset();
            h.fnd_read(s);
            h.check("K4-1", s == "----", "before first measurement", "\"----\"", {"\"", s, "\""});
            h.wait_until(h.t_rel + 1.1 * h.T_BOOT);
            h.dh_data = '{8'd5, 8'd0, 8'd3, 8'd0};
            dh_measure(ok);
            h.fnd_read(s);
            h.check("K4-2", s == "05.03", "5 % 3 C", "\"05.03\"", {"\"", s, "\""});
            h.dh_data = '{8'd55, 8'd0, 8'd24, 8'd0};
            dh_measure(ok);
            h.fnd_read(s);
            h.check("K4-3", s == "55.24", "55 % 24 C", "\"55.24\"", {"\"", s, "\""});
            h.dh_mode = h.DH_NONE;
            dh_measure(ok);
            h.fnd_read(s);
            h.check("K4-4", s == "Err1", "no response", "\"Err1\"", {"\"", s, "\""});
            h.dh_mode = h.DH_NORMAL;
            h.dh_nbits = 20;
            dh_measure(ok);
            h.fnd_read(s);
            h.check("K4-5", s == "Err2", "cut after 20 bits", "\"Err2\"", {"\"", s, "\""});
            h.dh_nbits = 40;
            h.dh_chk_off = 1;
            dh_measure(ok);
            h.fnd_read(s);
            h.check("K4-6", s == "Err3", "checksum", "\"Err3\"", {"\"", s, "\""});
            h.dh_default();
        end

        // ---------------------------------------------------------------- K5
        if (h.run("K5")) begin
            h.begin_sc("K5", "LED per screen", "7 screens", "README 10 jang table");
            h.dh_default();
            h.set_sw(7'b000_0000);
            h.do_reset();
            h.check("K5-1", h.led == 16'h8009, "watch SS.CC, 12 h PM", "8009", $sformatf("%h", h.led));
            h.set_sw(7'b000_0010);
            h.check("K5-2", h.led == 16'h8005, "watch HH.MM, 12 h PM", "8005", $sformatf("%h", h.led));
            h.set_sw(7'b000_0001);
            h.check("K5-3", h.led == 16'h000A, "stopwatch SS.CC", "000a", $sformatf("%h", h.led));
            h.set_sw(7'b000_0011);
            h.pulse_phy(BD);
            h.check("K5-4", h.led == 16'h0086, "stopwatch HH.MM + lap", "0086", $sformatf("%h", h.led));
            h.pulse_phy(BD);
            h.set_sw(7'b001_0010);
            h.pulse_phy(BU);
            h.pulse_phy(BL);
            h.check("K5-5", h.led == 16'h0060, "timer running", "0060", $sformatf("%h", h.led));
            h.pulse_phy(BL);
            h.set_sw(7'b010_0000);
            h.sr_mode = h.SR_NONE;
            h.pulse_phy(BR);
            h.wait_us(1000 * U / 1000.0);
            lv = h.led;
            h.wait_dist_done(100 * U / 1000.0, ok);
            h.check("K5-6", (lv[8] == 1) && (lv[15:10] == 0) && (h.led[9] == 1) && (h.led[8] == 0) && (h.led[15:10] == 0),
                    "distance : measuring then error", "LD8 1 -> LD9 1, LD15~10 0",
                    $sformatf("during %h, after %h", lv, h.led));
            h.sr_mode = h.SR_NORMAL;
            h.set_sw(7'b100_0000);
            h.wait_until(h.t_rel + 1.1 * h.T_BOOT);
            h.pulse_phy(BU);
            h.wait_dht_done(3.0 * TI / 1.0e6, ok);
            h.check("K5-7", (h.led[3] == 1) && (h.led[2] == 1) && (h.led[1] == 0) && (h.led[15:4] == 0),
                    "temp/humi : auto + valid", "LD3 1, LD2 1, LD15~4 0", $sformatf("%h", h.led));
            h.pulse_phy(BU);
        end

        // ---------------------------------------------------------------- K6
        if (h.run("K6")) begin
            h.begin_sc("K6", "FND scan", "watch 16 slots and com changes", "one-hot active-low, AN0 -> AN3 order, 250 us per slot");
            h.set_sw(7'b000_0000);
            h.do_reset();
            next_slot(sel, prev_an);
            seq_ok = 1;
            hot_ok = 1;
            for (int i = 0; i < 16; i++) begin
                next_slot(sel, an);
                if (an < 0) hot_ok = 0;
                if (an != (prev_an + 1) % 4) seq_ok = 0;
                prev_an = an;
            end
            for (int i = 0; i < 200; i++) begin
                #(10 * h.US);
                if (h.com2an(h.fnd_com) < 0) hot_ok = 0;
            end
            h.check("K6-1", hot_ok && seq_ok, "fnd_com", "one-hot active-low, AN0 1 2 3 0 ...",
                    $sformatf("one-hot %b, order %b", hot_ok, seq_ok));
            tc.delete();
            for (int i = 0; i < 9; i++) begin
                @(h.fnd_com);
                tc.push_back($realtime);
            end
            ok = 1;
            for (int i = 1; i < tc.size(); i++) if (tc[i] - tc[i - 1] != 250.0 * h.US) ok = 0;
            h.check("K6-2", ok, "slot length", "250.000 us", $sformatf("%0.3f us (first)", (tc[1] - tc[0]) / 1000.0));
        end

        h.finish_tb();
    end
endmodule
