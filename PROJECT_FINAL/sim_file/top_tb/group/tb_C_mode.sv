`timescale 1ns / 1ps
// =============================================================================
// tb_C_mode — C. 모드 선택 (스위치 ↔ UART) (tb_scenario.md C1 ~ C8)
//   C1 스위치 우선순위  C2 첫 /mod 뒤 스위치 무시  C3 틀린 /mod  C4 /mod 8 종
//   C5 12/24 유지  C6 /set w_hm 조건  C7 /mod 전 /set 24h  C8 설정 중 /mod
// =============================================================================
module tb_C_mode;
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
        .TB_ID     ("C_mode"),
        .ONLY      (ONLY),
        .TIMEOUT_MS(FAST ? 500 : 5_000)
    ) h ();

    localparam integer BR = 0, BL = 1, BU = 2, BD = 3;

    // 지금 화면 (Top 의 w_mode_* · WTS 의 sel_*)
    function automatic string scr();
        if (h.dut.w_mode_dht)  return "DHT";
        if (h.dut.w_mode_dist) return "DIST";
        if (h.dut.w_sel_tm)    return "TM";
        if (h.dut.w_sel_sw)    return "SW";
        return "WT";
    endfunction

    function automatic string b7(input [6:0] v);
        return $sformatf("%b_%b", v[6:4], v[3:0]);
    endfunction

    initial begin
        string   s, exp_scr;
        integer  e0, n0, m0, bad;
        reg [6:0] c0, v;
        bit      viol;
        string   cmds[8];
        reg [6:0] bits[8];

        // ---------------------------------------------------------------- C1
        if (h.run("C1")) begin
            h.begin_sc("C1", "switch priority", "8 combinations of sw6 sw5 sw4 sw0",
                       "sw6 > sw5 > WTS, inside WTS sw4 > sw0");
            h.do_reset();
            for (int i = 0; i < 8; i++) begin
                case (i)
                    0: begin v = 7'b000_0000; exp_scr = "WT";   end
                    1: begin v = 7'b000_0001; exp_scr = "SW";   end
                    2: begin v = 7'b001_0000; exp_scr = "TM";   end
                    3: begin v = 7'b001_0001; exp_scr = "TM";   end
                    4: begin v = 7'b010_0000; exp_scr = "DIST"; end
                    5: begin v = 7'b011_0001; exp_scr = "DIST"; end
                    6: begin v = 7'b100_0000; exp_scr = "DHT";  end
                    default: begin v = 7'b110_0000; exp_scr = "DHT"; end
                endcase
                h.set_sw(v);
                h.check($sformatf("C1-%0d", i + 1), (scr() == exp_scr)
                        && (h.dut.w_disp_sel == ((exp_scr == "DHT") ? 2 : (exp_scr == "DIST") ? 1 : 0)),
                        {"sw[6:0] = ", b7(v)}, exp_scr, $sformatf("%s (disp_sel %0d)", scr(), h.dut.w_disp_sel));
            end
        end

        // ---------------------------------------------------------------- C2
        if (h.run("C2")) begin
            h.begin_sc("C2", "after first valid /mod, switches are ignored", "/mod dist -> toggle sw0..sw6 one by one",
                       "screen / LED / button path stay distance");
            h.set_sw(7'b000_0000);
            h.do_reset();
            h.mod("dist");
            viol = 0;
            for (int i = 0; i < 7; i++) begin
                h.set_sw(7'b1 << i);
                h.wait_us(200);
                if ((h.dut.w_disp_sel != 1) || (h.led[15:10] != 0) || (h.led[9:0] != h.dut.w_sr04_led)) viol = 1;
                h.set_sw(7'b000_0000);
            end
            h.check("C2-1", (viol == 0) && (h.dut.w_disp_sel == 1), "FND source while toggling switches", "distance (disp_sel 1)",
                    $sformatf("disp_sel %0d, violation %b", h.dut.w_disp_sel, viol));
            h.check("C2-2", (viol == 0), "LED while toggling switches", "{6'b0, sr04_led}", $sformatf("%h", h.led));
            n0 = h.trig_cnt;
            h.set_sw(7'b000_0001);   // 스위치로는 스톱워치지만 무시돼야 함
            h.pulse_phy(BR);
            h.wait_us(100);
            h.check("C2-3", (h.trig_cnt == n0 + 1) && (h.dut.U_WTS.w_sw_run_stop == 0), "R goes to SR04 only",
                    "1 trig, SW still STOP", $sformatf("%0d trig, sw_run %b", h.trig_cnt - n0, h.dut.U_WTS.w_sw_run_stop));
            h.set_sw(7'b000_0000);
        end

        // ---------------------------------------------------------------- C3
        if (h.run("C3")) begin
            h.begin_sc("C3", "unknown /mod option does not take control", "/mod abcd -> sw0 1",
                       "no ERROR, uart_mode 0, switches still work");
            h.set_sw(7'b000_0000);
            h.do_reset();
            e0 = h.n_err;
            h.flush_lines();
            h.mod("abcd");
            h.wait_ms(2);
            h.check("C3-1", (h.n_err == e0) && (h.lines_pending() == 0), "/mod abcd", "no ERROR line",
                    $sformatf("%0d error, %0d line", h.n_err - e0, h.lines_pending()));
            h.set_sw(7'b000_0001);
            h.check("C3-2", (h.dut.w_uart_mode == 0) && (scr() == "SW"), "switch control kept", "uart_mode 0, sw0 -> SW",
                    $sformatf("uart_mode %b, screen %s", h.dut.w_uart_mode, scr()));
            h.set_sw(7'b000_0000);
        end

        // ---------------------------------------------------------------- C4
        if (h.run("C4")) begin
            h.begin_sc("C4", "/mod 8 commands -> module_control_bit", "w_hm w_ms s_hm s_ms t_hm t_ms dist temp",
                       "ctrl bits as README table, changed <= 1 us after last byte rx_done");
            h.set_sw(7'b000_0000);
            h.do_reset();
            cmds = '{"w_hm", "w_ms", "s_hm", "s_ms", "t_hm", "t_ms", "dist", "temp"};
            bits = '{7'b000_0010, 7'b000_0000, 7'b000_0011, 7'b000_0001, 7'b001_0010, 7'b001_0000, 7'b010_0000, 7'b100_0000};
            for (int i = 0; i < 8; i++) begin
                h.mod(cmds[i]);
                h.check($sformatf("C4-%0d", i + 1), (h.dut.w_ctrl_bit == bits[i]) && (h.t_ctrl_chg - h.t_rx_done <= 1.0 * h.US),
                        {"/mod ", cmds[i]}, $sformatf("%s, <= 1 us", b7(bits[i])),
                        $sformatf("%s, %0.0f ns after rx_done", b7(h.dut.w_ctrl_bit), h.t_ctrl_chg - h.t_rx_done));
            end
        end

        // ---------------------------------------------------------------- C5
        if (h.run("C5")) begin
            h.begin_sc("C5", "12/24 h setting survives /mod", "/mod w_hm, watch 13:00 -> /set 24h -> /mod s_ms -> /mod w_hm",
                       "bit3 stays 1, FND hour 13");
            h.do_reset();
            h.mod("w_hm");
            h.preload_wt(13, 0, 0, 0);
            h.uart_line("/set 24h");
            h.check("C5-1", (h.dut.w_ctrl_bit[3] == 1) && (h.dut.w_disp_hour == 13) && (h.led[15] == 0),
                    "/set 24h", "bit3 1, hour 13, LD15 0",
                    $sformatf("bit3 %b, hour %0d, LD15 %b", h.dut.w_ctrl_bit[3], h.dut.w_disp_hour, h.led[15]));
            h.mod("s_ms");
            h.mod("w_hm");
            h.check("C5-2", (h.dut.w_ctrl_bit[3] == 1) && (h.dut.w_disp_hour == 13), "after /mod s_ms -> /mod w_hm",
                    "bit3 1, hour 13", $sformatf("bit3 %b, hour %0d", h.dut.w_ctrl_bit[3], h.dut.w_disp_hour));
        end

        // ---------------------------------------------------------------- C6
        if (h.run("C6")) begin
            h.begin_sc("C6", "/set w_hm only on watch HH.MM screen", "/set w_hm on w_ms, s_hm, t_hm; /off w_h when not set",
                       "no change, no ERROR");
            h.do_reset();
            cmds[0] = "w_ms"; cmds[1] = "s_hm"; cmds[2] = "t_hm";
            for (int i = 0; i < 3; i++) begin
                h.mod(cmds[i]);
                c0 = h.dut.w_ctrl_bit;
                e0 = h.n_err;
                h.uart_send("/set w_hm");
                h.check($sformatf("C6-%0d", i + 1), (h.dut.w_ctrl_bit == c0) && (h.n_err == e0),
                        {"/set w_hm on ", cmds[i]}, {"bit2 0, ", b7(c0)},
                        $sformatf("%s, %0d error", b7(h.dut.w_ctrl_bit), h.n_err - e0));
            end
            h.mod("w_hm");
            c0 = h.dut.w_ctrl_bit;
            e0 = h.n_err;
            h.uart_send("/off w_h");
            h.check("C6-4", (h.dut.w_ctrl_bit == c0) && (h.n_err == e0), "/off w_h when not in set", b7(c0),
                    $sformatf("%s, %0d error", b7(h.dut.w_ctrl_bit), h.n_err - e0));
        end

        // ---------------------------------------------------------------- C7
        if (h.run("C7")) begin
            h.begin_sc("C7", "/set 24h before any /mod is ignored", "reset -> /set 24h CR -> /mod w_hm -> watch 13:00",
                       "12 h display (01)");
            h.do_reset();
            h.uart_line("/set 24h");
            h.mod("w_hm");
            h.preload_wt(13, 0, 0, 0);
            h.wait_us(10);
            h.check("C7-1", (h.dut.w_ctrl_bit[3] == 0) && (h.dut.w_disp_hour == 1), "hour display", "bit3 0, 01",
                    $sformatf("bit3 %b, %02d", h.dut.w_ctrl_bit[3], h.dut.w_disp_hour));
        end

        // ---------------------------------------------------------------- C8
        if (h.run("C8")) begin
            h.begin_sc("C8", "/mod during watch set leaves set mode", "/mod w_hm -> /set w_hm -> /mod s_ms -> /mod w_hm -> /btn U",
                       "bit2 0, cursor 3 (NORMAL), U does not change minute");
            h.do_reset();
            h.mod("w_hm");
            h.uart_send("/set w_hm");
            h.note($sformatf("after /set w_hm : bit2 %b, cursor %0d", h.dut.w_ctrl_bit[2], h.dut.w_wt_cursor));
            h.mod("s_ms");
            h.check("C8-1", (h.dut.w_ctrl_bit[2] == 0) && (h.dut.w_wt_cursor == 3), "/mod s_ms", "bit2 0, cursor 3",
                    $sformatf("bit2 %b, cursor %0d", h.dut.w_ctrl_bit[2], h.dut.w_wt_cursor));
            h.mod("w_hm");
            h.preload_wt(13, 10, 0, 0);
            m0 = h.dut.U_WTS.w_wt_min;
            h.ubtn("U");
            h.check("C8-2", (h.dut.U_WTS.w_wt_min == m0) && (h.dut.w_wt_cursor == 3), "/mod w_hm + /btn U",
                    $sformatf("min %0d, cursor 3", m0), $sformatf("min %0d, cursor %0d", h.dut.U_WTS.w_wt_min, h.dut.w_wt_cursor));
        end

        h.finish_tb();
    end
endmodule
