`timescale 1ns / 1ps
// =============================================================================
// tb_H_uart_ctrl — H. UART 컨트롤러 · 전송 (tb_scenario.md H1 ~ H12)
//   H1 화면별 /get  H2 스위치 모드 /get (⚠)  H3 auto 중 /get  H4 /auto 주기  H5 /auto all 순서
//   H6 auto 중 전환  H7 off 뒤 재시작 (⚠)  H8 ERROR 우선 · 줄 무결성  H9 /get 연타 (⚠)
//   H10 응답 형식 경계값  H11 /btn  H12 물리 + UART 같은 clk
//   줄 종류 판별 : 스톱워치 05:xx (프리로드), 타이머 00:30 (D x3), 시계 12:xx, 거리 NNNcm, 온습도 NN%NNC
//   모든 줄은 하네스가 send_go 순간 스냅샷과 비교 (불일치 = WARN + 요약의 mismatch)
// =============================================================================
module tb_H_uart_ctrl;
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
        .TB_ID     ("H_uart_ctrl"),
        .ONLY      (ONLY),
        .TIMEOUT_MS(FAST ? 600 : 120_000)
    ) h ();

    localparam integer BR = 0, BL = 1, BU = 2, BD = 3;
    real TA, LINE13, T_RESP, TOL;

    function automatic string kind(input string s);
        if (s == "ERROR") return "ERR";
        if (h.is_dist(s)) return "DIST";
        if (h.is_temp(s) || s == "--%--C") return "TEMP";   // (v2) 첫 측정 전 온습도 = "--%--C"
        if (h.is_err(s)) return "SENSOR_ERR";                // (v2) 거리 · 온습도 오류 "Err N"
        if (h.is_time(s)) begin
            if (s.substr(0, 1) == "05") return "SW";
            if (s.substr(0, 4) == "00:30") return "TM";
            if (s.substr(0, 1) == "12") return "WH";
            return "TIME";
        end
        return "?";
    endfunction

    // 줄 종류를 구별할 수 있게 : 스톱워치 05:00:00.00 (정지), 타이머 00:30:00 (SET), 시계 12 시
    task automatic setup_kinds();
        h.set_sw(7'b000_0000);
        h.do_reset();
        h.preload_sw(5, 0, 0, 0);
        h.set_sw(7'b001_0000);
        for (int i = 0; i < 3; i++) h.pulse_phy(BD);
        h.set_sw(7'b000_0000);
    endtask

    initial begin
        string   s, k, seq, exp_seq, scr[5], mods[5], opts[5], kinds[5];
        realtime t0, t1, t2, t3, t_cr, t_a;
        integer  e0, n0, l0, nerr, b0, bl0;
        bit      ok, fmt_ok;

        TA     = h.T_AUTO;
        LINE13 = 13 * 10 * h.TX_BIT_NS;     // 13 글자 줄 길이
        T_RESP = h.BIT_NS;                  // 9600 : 0.1 ms ≈ 1 bit
        TOL    = 10 * h.US;                 // /auto 박자 허용

        // ---------------------------------------------------------------- H1
        if (h.run("H1")) begin
            h.begin_sc("H1", "/get on each screen", "/mod X -> /get <CR> (5 screens)",
                       "right format + go snapshot, first byte < 1 bit after CR, line ends <= 13 chars + 1 bit");
            setup_kinds();
            mods  = '{"s_ms", "t_hm", "w_hm", "dist", "temp"};
            kinds = '{"SW", "TM", "WH", "DIST", "TEMP"};
            for (int i = 0; i < 5; i++) begin
                h.mod(mods[i]);
                h.flush_lines();
                n0 = h.n_line_mis;
                h.uget();
                t_cr = h.t_rx_done;
                h.next_line(s, t0, 3 * LINE13);
                h.check($sformatf("H1-%0d", i + 1), (kind(s) == kinds[i]) && (h.n_line_mis == n0) && (t0 - t_cr < T_RESP)
                        && (h.last_t1 - t_cr <= LINE13 + T_RESP),
                        {"/mod ", mods[i], " + /get"}, {kinds[i], " line"},
                        $sformatf("\"%s\" (%s), start %0.1f us, end %0.3f ms", s, kind(s), (t0 - t_cr) / 1000.0,
                                  (h.last_t1 - t_cr) / 1.0e6));
            end
        end

        // ---------------------------------------------------------------- H2
        if (h.run("H2")) begin
            h.begin_sc("H2", "/get in switch mode", "no /mod, sw5 = distance screen -> /get <CR>",
                       "design intent (B-1, 10/31): terminal is used after /mod only -> watch line, no ERROR / hang");
            h.set_sw(7'b000_0000);
            h.do_reset();
            h.set_sw(7'b010_0000);
            h.flush_lines();
            h.uget();
            h.next_line(s, t0, 3 * LINE13);
            h.check("H2-1", h.is_time(s), "/get on distance screen (switch mode, before /mod)", "watch line HH:MM:SS.CC",
                    {"\"", s, "\""});
            h.set_sw(7'b000_0000);
        end

        // ---------------------------------------------------------------- H3
        if (h.run("H3")) begin
            h.begin_sc("H3", "/get during /auto is ignored", "/auto _sw -> first line -> 0.3 T_AUTO -> /get <CR>",
                       "no extra line, no ERROR, next auto line 1 T_AUTO later");
            setup_kinds();
            h.flush_lines();
            h.uart_send("/auto _sw");
            h.next_line(s, t1, 2 * TA);
            h.wait_until(t1 + 0.3 * TA);
            e0 = h.n_err;
            h.uget();
            h.next_line(s, t2, 2 * TA);
            h.check("H3-1", (kind(s) == "SW") && (t2 - t1 >= TA - TOL) && (t2 - t1 <= TA + TOL) && (h.n_err == e0),
                    "line after /get", $sformatf("SW line %0.3f ms after previous", TA / 1.0e6),
                    $sformatf("\"%s\" %0.3f ms, %0d error", s, (t2 - t1) / 1.0e6, h.n_err - e0));
            h.uart_send("/auto off");
        end

        // ---------------------------------------------------------------- H4
        if (h.run("H4")) begin
            h.begin_sc("H4", "/auto period", "/auto opt -> 3 lines (fresh reset per option)",
                       "first line T_AUTO after handshake, period T_AUTO +- 10 us, right format");
            opts  = '{"_sw", "_tm", "_wh", "dis", "tem"};
            kinds = '{"SW", "TM", "WH", "DIST", "TEMP"};
            for (int i = 0; i < 5; i++) begin
                setup_kinds();
                h.flush_lines();
                h.uart_send({"/auto ", opts[i]});
                t_a = h.t_hs;
                h.next_line(s, t1, 2 * TA);
                fmt_ok = (kind(s) == kinds[i]);
                h.next_line(s, t2, 2 * TA);
                fmt_ok = fmt_ok && (kind(s) == kinds[i]);
                h.next_line(s, t3, 2 * TA);
                fmt_ok = fmt_ok && (kind(s) == kinds[i]);
                h.check($sformatf("H4-%0d", i + 1), fmt_ok && (t1 - t_a >= TA - TOL) && (t1 - t_a <= TA + TOL)
                        && (t2 - t1 >= TA - TOL) && (t2 - t1 <= TA + TOL) && (t3 - t2 >= TA - TOL) && (t3 - t2 <= TA + TOL),
                        {"/auto ", opts[i]}, $sformatf("%s, %0.3f ms each", kinds[i], TA / 1.0e6),
                        $sformatf("%s, first %0.4f, %0.4f, %0.4f ms", kind(s), (t1 - t_a) / 1.0e6, (t2 - t1) / 1.0e6,
                                  (t3 - t2) / 1.0e6));
                h.uart_send("/auto off");
            end
        end

        // ---------------------------------------------------------------- H5
        if (h.run("H5")) begin
            h.begin_sc("H5", "/auto all order", "/auto all, 10 lines", "SW TM WH DIST TEMP SW TM WH DIST TEMP");
            setup_kinds();
            h.flush_lines();
            h.uart_send("/auto all");
            seq = "";
            for (int i = 0; i < 10; i++) begin
                h.next_line(s, t0, 2 * TA);
                seq = {seq, kind(s), " "};
            end
            exp_seq = "SW TM WH DIST TEMP SW TM WH DIST TEMP ";
            h.check("H5-1", seq == exp_seq, "order of 10 lines", exp_seq, seq);
            h.uart_send("/auto off");
        end

        // ---------------------------------------------------------------- H6
        if (h.run("H6")) begin
            h.begin_sc("H6", "switch auto target while running", "/auto _sw -> 0.4 T_AUTO -> /auto _tm",
                       "next line still 1 T_AUTO after the first command, content TM");
            setup_kinds();
            h.flush_lines();
            h.uart_send("/auto _sw");
            t_a = h.t_hs;
            h.wait_until(t_a + 0.4 * TA);
            h.uart_send("/auto _tm");
            h.next_line(s, t1, 2 * TA);
            h.check("H6-1", (kind(s) == "TM") && (t1 - t_a >= TA - TOL) && (t1 - t_a <= TA + TOL), "first line",
                    $sformatf("TM at %0.3f ms", TA / 1.0e6), $sformatf("%s at %0.4f ms", kind(s), (t1 - t_a) / 1.0e6));
            h.uart_send("/auto off");
        end

        // ---------------------------------------------------------------- H7
        if (h.run("H7")) begin
            h.begin_sc("H7", "/auto off then restart", "/auto _sw -> 0.3 T_AUTO -> off -> 1.5 T_AUTO -> /auto _sw",
                       "no line while off ; spec: first line 1 T_AUTO after restart - code: earlier (issue 3)");
            setup_kinds();
            h.flush_lines();
            h.uart_send("/auto _sw");
            t_a = h.t_hs;
            h.wait_until(t_a + 0.3 * TA);
            h.uart_send("/auto off");
            n0 = h.n_tx_bytes;
            h.wait_until($realtime + 1.5 * TA);
            h.check("H7-1", (h.n_tx_bytes == n0) && (h.lines_pending() == 0), "while off", "no byte",
                    $sformatf("%0d byte", h.n_tx_bytes - n0));
            h.uart_send("/auto _sw");
            t_a = h.t_hs;
            h.next_line(s, t1, 2 * TA);
            h.spec("H7-2", (t1 - t_a >= TA - TOL) && (t1 - t_a <= TA + TOL), "first line after restart",
                   $sformatf("%0.3f ms", TA / 1.0e6), $sformatf("%0.4f ms (%0.2f T_AUTO)", (t1 - t_a) / 1.0e6, (t1 - t_a) / TA));
            h.uart_send("/auto off");
        end

        // ---------------------------------------------------------------- H8
        if (h.run("H8")) begin
            h.begin_sc("H8", "ERROR priority and line integrity", "ERROR during a line ; ERROR on the auto beat ; 3 ERRORs in /auto all",
                       "lines never mixed, ERROR first then data, scan order kept");
            setup_kinds();
            h.mod("s_ms");
            h.flush_lines();
            n0 = h.n_line_mis;
            h.uget();
            while (h.dut.U_UART.w_tx_busy !== 1'b1) #(100);
            h.uart_send("/gx");
            h.next_line(s, t0, 3 * LINE13);
            h.next_line(k, t1, 3 * LINE13);
            h.check("H8-1", (kind(s) == "SW") && (k == "ERROR") && (h.n_line_mis == n0) && (h.n_bad_line == 0),
                    "/gx while /get line is sent", "SW line intact, then ERROR", $sformatf("\"%s\", \"%s\"", s, k));
            // 둘째 : auto 박자 (w_clk_5hz) 와 같은 클럭에 ERROR (force)
            setup_kinds();
            h.flush_lines();
            h.uart_send("/auto _sw");
            forever begin
                @(posedge h.clk);
                #1;
                if (h.dut.U_UART.U_CONTROL.w_clk_5hz === 1'b1) break;
            end
            force h.dut.U_UART.w_error = 1'b1;
            @(posedge h.clk);
            #1;
            release h.dut.U_UART.w_error;
            h.next_line(s, t0, 3 * LINE13);
            h.next_line(k, t1, 3 * LINE13);
            h.check("H8-2", (s == "ERROR") && (kind(k) == "SW"), "ERROR and auto beat in the same clock", "ERROR, then SW",
                    $sformatf("\"%s\", \"%s\"", s, k));
            h.uart_send("/auto off");
            // 셋째 : /auto all 중 ERROR 3 번
            setup_kinds();
            h.flush_lines();
            h.uart_send("/auto all");
            t_a = h.t_hs;
            for (int i = 1; i <= 3; i++) begin
                h.wait_until(t_a + (1.3 * i) * TA);
                h.uart_send("/x");
            end
            h.wait_until(t_a + 6.5 * TA);
            seq = "";
            nerr = 0;
            while (h.lines_pending() > 0) begin
                h.next_line(s, t0, 1);
                if (s == "ERROR") nerr++;
                else seq = {seq, kind(s), " "};
            end
            exp_seq = "SW TM WH DIST TEMP SW ";
            h.check("H8-3", (seq == exp_seq) && (nerr == 3), "/auto all with 3 ERRORs", {exp_seq, "+ 3 ERROR"},
                    $sformatf("%s+ %0d ERROR", seq, nerr));
            h.uart_send("/auto off");
        end

        // ---------------------------------------------------------------- H9
        if (h.run("H9")) begin
            h.begin_sc("H9", "/get burst", "/mod s_ms -> 20 x /get <CR> back to back",
                       "spec: 20 lines - code may merge requests once TX FIFO is full (issue 4)");
            setup_kinds();
            h.mod("s_ms");
            h.flush_lines();
            l0 = h.lines.size();
            n0 = h.n_bad_line;
            for (int i = 0; i < 20; i++) h.uget();
            h.wait_tx_quiet(3 * LINE13 / 1.0e6);
            fmt_ok = 1;
            for (int i = l0; i < h.lines.size(); i++) if (kind(h.lines[i]) != "SW") fmt_ok = 0;
            h.spec("H9-1", (h.lines.size() - l0 == 20) && fmt_ok && (h.n_bad_line == n0), "responses to 20 /get",
                   "20 SW lines", $sformatf("%0d lines, all SW %b", h.lines.size() - l0, fmt_ok));
        end

        // ---------------------------------------------------------------- H10
        if (h.run("H10")) begin
            h.begin_sc("H10", "reply format boundary values", "watch 13:05 on 12 h ; timer 01:30 running ; Err1 ; Err2 ; temp before first",
                       "13:05 (24 h) ; 00:01:xx ; Err 1 ; Err 2 ; --%--C (v2)");
            h.set_sw(7'b000_0000);
            h.do_reset();
            h.mod("w_hm");
            h.preload_wt(13, 5, 0, 0);
            h.flush_lines();
            h.uget();
            h.next_line(s, t0, 3 * LINE13);
            h.check("H10-1", (s.substr(0, 4) == "13:05") && (h.dut.w_disp_hour == 1), "watch 13:05, 12 h display",
                    "\"13:05:..\", FND 01", $sformatf("\"%s\", FND %02d", s, h.dut.w_disp_hour));
            h.mod("t_hm");
            h.ubtn("R");
            for (int i = 0; i < 3; i++) h.ubtn("U");
            h.ubtn("L");
            h.flush_lines();
            h.uget();
            h.next_line(s, t0, 3 * LINE13);
            h.check("H10-2", h.is_time(s) && (s.substr(0, 5) == "00:01:"), "timer 01:30 running", "\"00:01:..\"",
                    {"\"", s, "\""});
            h.ubtn("L");
            h.mod("dist");
            h.sr_mode = h.SR_NONE;
            h.pulse_phy(BR);
            h.wait_dist_done(100, ok);
            h.flush_lines();
            h.uget();
            h.next_line(s, t0, 3 * LINE13);
            h.check("H10-3", (s == "Err 1") && (h.dist_st == 1), "distance Err1 (no echo)", "Err 1",
                    $sformatf("\"%s\" status %0d", s, h.dist_st));
            h.wait_sr_idle(100);
            h.sr_mode = h.SR_NORMAL;
            h.sr_w_us = 23250;
            h.pulse_phy(BR);
            h.wait_dist_done(100, ok);
            h.flush_lines();
            h.uget();
            h.next_line(s, t0, 3 * LINE13);
            h.check("H10-4", (s == "Err 2") && (h.dist_st == 2), "distance Err2 (out of range)", "Err 2",
                    $sformatf("\"%s\" status %0d", s, h.dist_st));
            h.wait_sr_idle(100);
            h.sr_w_us = 1000;
            h.do_reset();
            h.mod("temp");
            h.flush_lines();
            h.uget();
            h.next_line(s, t0, 3 * LINE13);
            h.check("H10-5", s == "--%--C", "temp before first measurement", "--%--C", {"\"", s, "\""});
        end

        // ---------------------------------------------------------------- H11
        if (h.run("H11")) begin
            h.begin_sc("H11", "/btn R L U D", "/mod s_ms -> /btn R, D, (R) L, U",
                       "1 UART pulse each, stopwatch reacts");
            h.set_sw(7'b000_0000);
            h.do_reset();
            h.mod("s_ms");
            b0 = h.uc[BR];
            h.ubtn("R");
            h.check("H11-1", (h.uc[BR] == b0 + 1) && (h.dut.U_WTS.w_sw_run_stop == 1), "/btn R", "1 pulse, RUN",
                    $sformatf("%0d pulse, run %b", h.uc[BR] - b0, h.dut.U_WTS.w_sw_run_stop));
            b0 = h.uc[BD];
            h.ubtn("D");
            h.check("H11-2", (h.uc[BD] == b0 + 1) && (h.dut.w_sw_lap == 1), "/btn D", "1 pulse, lap",
                    $sformatf("%0d pulse, lap %b", h.uc[BD] - b0, h.dut.w_sw_lap));
            h.ubtn("R");
            b0 = h.uc[BL];
            h.ubtn("L");
            h.check("H11-3", (h.uc[BL] == b0 + 1) && (h.sw_cnt_cs() == 0) && (h.dut.w_sw_lap == 0), "/btn L (after stop)",
                    "1 pulse, 0, lap off", $sformatf("%0d pulse, %s, lap %b", h.uc[BL] - b0, h.cs2str(h.sw_cnt_cs()), h.dut.w_sw_lap));
            b0 = h.uc[BU];
            k  = $sformatf("%b", h.dut.U_WTS.w_sw_down);
            h.ubtn("U");
            h.check("H11-4", (h.uc[BU] == b0 + 1) && (h.dut.U_WTS.w_sw_down == 1), "/btn U", {"1 pulse, down ", k, " -> 1"},
                    $sformatf("%0d pulse, down %b", h.uc[BU] - b0, h.dut.U_WTS.w_sw_down));
        end

        // ---------------------------------------------------------------- H12
        if (h.run("H12")) begin
            h.begin_sc("H12", "physical and UART button in the same clock", "force physical R right after /btn handshake",
                       "physical first, UART 1 clk later (2 pulses)");
            h.set_sw(7'b000_0000);
            h.do_reset();
            h.mod("s_ms");
            b0 = h.bc[BR];
            fork
                begin
                    @(posedge h.clk iff (h.dut.U_UART.w_handshake === 1'b1));
                    h.pulse_phy_at(BR, $realtime + 10.0);
                end
                h.ubtn("R");
            join
            h.wait_clk(5);
            h.check("H12-1", (h.bc[BR] == b0 + 2) && (h.t_bc[BR] - h.t_bc_prev[BR] == 10.0) && (h.dut.U_WTS.w_sw_run_stop == 0),
                    "physical R + /btn R", "2 R pulses 1 clk apart, SW RUN -> STOP",
                    $sformatf("%0d pulses %0.0f ns apart, run %b", h.bc[BR] - b0, h.t_bc[BR] - h.t_bc_prev[BR],
                              h.dut.U_WTS.w_sw_run_stop));
            b0  = h.bc[BR];
            bl0 = h.bc[BL];
            fork
                begin
                    @(posedge h.clk iff (h.dut.U_UART.w_handshake === 1'b1));
                    h.pulse_phy_at(BR, $realtime + 10.0);
                end
                h.ubtn("L");
            join
            h.wait_clk(5);
            h.check("H12-2", (h.bc[BR] == b0 + 1) && (h.bc[BL] == bl0 + 1) && (h.t_bc[BL] - h.t_bc[BR] == 10.0),
                    "physical R + /btn L", "R then L 1 clk later",
                    $sformatf("R %0d, L %0d, L - R = %0.0f ns", h.bc[BR] - b0, h.bc[BL] - bl0, h.t_bc[BL] - h.t_bc[BR]));
        end

        h.finish_tb();
    end
endmodule
