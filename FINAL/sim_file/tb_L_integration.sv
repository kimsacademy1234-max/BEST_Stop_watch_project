`timescale 1ns / 1ps
// =============================================================================
// tb_L_integration — L. 통합 · 교차 (tb_scenario.md L1 ~ L6)
//   L1 배경 스톱워치  L2 화면 전환 직후 버튼  L3 전송 중 화면 변경  L4 동시 부하 (soak)
//   L5 랜덤 리셋 x 20  L6 캐리 경계 스냅샷 (⚠)
//   L4 길이 = SOAK_AUTO 박자 (md 는 30 s, FAST 에서는 auto 박자 기준으로 줄임)
// =============================================================================
module tb_L_integration;
    localparam string  ONLY      = "";
    localparam bit     FAST      = 1;    // 1 = 시간 줄임 (tb_scenario.md 3-3), 0 = 실제 시간
    localparam integer SOAK_AUTO = 30;   // L4 : /auto 박자 몇 번 동안 (FAST 5 ms x 30 = 150 ms, 실제 1 s x 30 = 30 s)
    localparam integer N_RESET   = 20;   // L5

    tb_merge_harness #(
        .TICK_F    (FAST ? 1_000 : 1_000_000),
        .AUTO_FRQ  (FAST ? 200 : 1),
        .DHT_BOOT  (FAST ? 300_000 : 100_000_000),
        .DHT_INTV  (FAST ? 500_000 : 200_000_000),
        .BLINK_HALF(FAST ? 25_000 : 25_000_000),
        .BAUD      (FAST ? 115_200 : 9_600),
        .SR_TICK   (FAST ? 10 : 100),
        .DHT_TICK  (FAST ? 10 : 100),
        .TB_ID     ("L_integration"),
        .ONLY      (ONLY),
        .TIMEOUT_MS(FAST ? 800 : 120_000)
    ) h ();

    localparam integer BR = 0, BL = 1, BU = 2, BD = 3;
    real TCS, TA, LINE13;

    initial begin
        string   s, cmd;
        bit      ok;
        integer  v0, v1, n0, b0, e_run, mis0, unexp0, bad0, l0, ndata, nerr, nget, seed;
        realtime t0, t1, tend;
        real     el;

        TCS    = h.T_CS;
        TA     = h.T_AUTO;
        LINE13 = 13 * 10 * h.TX_BIT_NS;
        seed   = 12345;

        // ---------------------------------------------------------------- L1
        if (h.run("L1")) begin
            h.begin_sc("L1", "stopwatch keeps running in the background", "SW RUN -> /mod dist ~300 T_CS -> /mod s_ms",
                       "value grew by the elapsed time (+-1 cs)");
            h.do_reset();
            h.mod("s_ms");
            h.pulse_phy(BR);
            h.wait_until($realtime + 10 * TCS);
            v0 = h.sw_cnt_cs();
            t0 = $realtime;
            h.mod("dist");
            h.wait_until(t0 + 300 * TCS);
            h.mod("s_ms");
            v1 = h.sw_cnt_cs();
            t1 = $realtime;
            el = (t1 - t0) / TCS;
            h.check("L1-1", (v1 - v0 >= 300) && (v1 - v0 >= $rtoi(el) - 1) && (v1 - v0 <= $rtoi(el) + 1) && (h.sw_disp_cs() == v1),
                    "growth while on distance screen", $sformatf("%0.1f cs", el), $sformatf("%0d cs", v1 - v0));
        end

        // ---------------------------------------------------------------- L2
        if (h.run("L2")) begin
            h.begin_sc("L2", "button right at the screen change", "/mod dist with physical R in the handshake clock / one clock later",
                       "same clock -> old screen (stopwatch) ; next clock -> new screen (SR04)");
            h.do_reset();
            h.mod("s_ms");
            n0 = h.trig_cnt;
            fork
                begin
                    forever begin
                        @(posedge h.clk);
                        #1;
                        if (h.dut.U_UART.w_handshake === 1'b1) break;
                    end
                    force h.dut.w_phy_btn_R = 1'b1;      // 다음 엣지 (= ctrl 바뀌는 엣지) 에 보임
                    @(posedge h.clk);
                    #1;
                    release h.dut.w_phy_btn_R;
                end
                h.mod("dist");
            join
            h.wait_us(50);
            h.check("L2-1", (h.dut.U_WTS.w_sw_run_stop == 1) && (h.trig_cnt == n0) && (h.dut.w_disp_sel == 1),
                    "R in the clock ctrl changes", "stopwatch RUN, no trig",
                    $sformatf("sw_run %b, %0d trig, disp_sel %0d", h.dut.U_WTS.w_sw_run_stop, h.trig_cnt - n0, h.dut.w_disp_sel));
            h.do_reset();
            h.mod("s_ms");
            n0 = h.trig_cnt;
            fork
                begin
                    @(posedge h.clk iff (h.dut.U_UART.w_handshake === 1'b1));
                    h.pulse_phy_at(BR, $realtime + 10.0);
                end
                h.mod("dist");
            join
            h.wait_us(50);
            h.check("L2-2", (h.dut.U_WTS.w_sw_run_stop == 0) && (h.trig_cnt == n0 + 1), "R one clock after", "1 trig, stopwatch STOP",
                    $sformatf("sw_run %b, %0d trig", h.dut.U_WTS.w_sw_run_stop, h.trig_cnt - n0));
        end

        // ---------------------------------------------------------------- L3
        if (h.run("L3")) begin
            h.begin_sc("L3", "screen change while a line is sent", "SW 05:00:00.00 -> /get -> /mod dist during the line",
                       "the line stays the stopwatch value");
            h.do_reset();
            h.preload_sw(5, 0, 0, 0);
            h.mod("s_ms");
            h.flush_lines();
            n0 = h.n_tx_bytes;
            h.uget();
            while (h.n_tx_bytes < n0 + 2) #(1 * h.US);
            h.mod("dist");
            h.next_line(s, t0, 3 * LINE13);
            h.check("L3-1", (s == "05:00:00.00") && (h.dut.w_disp_sel == 1), "line", "\"05:00:00.00\", screen distance",
                    $sformatf("\"%s\", disp_sel %0d", s, h.dut.w_disp_sel));
        end

        // ---------------------------------------------------------------- L4
        if (h.run("L4")) begin
            h.begin_sc("L4", "soak : everything at once", $sformatf("/auto all + SR04 auto + DHT auto + timer + random buttons / commands, %0d auto beats", SOAK_AUTO),
                       "no broken / unexpected line, auto lines not lost, FSMs return to IDLE, no x/z");
            h.dh_default();
            h.do_reset();
            mis0   = h.n_line_mis;
            unexp0 = h.n_line_unexp;
            bad0   = h.n_bad_line;
            h.mod("dist");
            h.ubtn("U");
            h.wait_until(h.t_rel + 1.1 * h.T_BOOT);
            h.mod("temp");
            h.ubtn("U");
            h.mod("t_hm");
            h.ubtn("D");
            h.ubtn("L");
            h.flush_lines();
            l0 = h.lines.size();
            h.uart_send("/auto all");
            t0 = h.t_hs;
            tend = t0 + SOAK_AUTO * TA;
            nget = 0;
            while ($realtime < tend - 0.5 * TA) begin
                case ($urandom(seed) % 4)
                    0: h.pulse_phy($urandom(seed) % 4);
                    1: begin
                        case ($urandom(seed) % 6)
                            0: cmd = "/btn U";
                            1: cmd = "/btn R";
                            2: cmd = "/mod s_ms";
                            3: cmd = "/mod dist";
                            4: cmd = "/mod temp";
                            default: cmd = "/x";
                        endcase
                        h.uart_send(cmd);
                    end
                    2: h.sr_w_us = 100 + ($urandom(seed) % 20000);
                    default: begin h.uget(); nget++; end
                endcase
                seed = $urandom(seed);
                h.wait_us(TA / 1000.0 * (0.05 + ($urandom(seed) % 20) / 100.0));
            end
            h.wait_until(tend + 0.5 * TA);
            h.uart_send("/auto off");
            h.wait_tx_quiet(3 * LINE13 / 1.0e6);
            ndata = 0;
            nerr  = 0;
            for (int i = l0; i < h.lines.size(); i++) begin
                if (h.lines[i] == "ERROR") nerr++;
                else ndata++;
            end
            h.wait_sr_idle(100 * h.SR_US / 1000.0 * 2);
            h.check("L4-1", (h.n_line_mis == mis0) && (h.n_line_unexp == unexp0) && (h.n_bad_line == bad0)
                            && (ndata >= SOAK_AUTO - 1) && (ndata <= SOAK_AUTO + 1) && !h.xz_seen
                            && (h.dut.U_UART.U_ASCII_DECODER.c_state == 0) && (h.dut.U_UART.U_ASCII_SENDER.c_state == 0),
                    "soak result", $sformatf("0 broken, %0d +-1 auto lines, decoder / sender IDLE, no x/z", SOAK_AUTO),
                    $sformatf("mismatch %0d, unexpected %0d, no CR %0d, data %0d, ERROR %0d (gets %0d ignored), x/z %b, dec %0d, snd %0d",
                              h.n_line_mis - mis0, h.n_line_unexp - unexp0, h.n_bad_line - bad0, ndata, nerr, nget, h.xz_seen,
                              h.dut.U_UART.U_ASCII_DECODER.c_state, h.dut.U_UART.U_ASCII_SENDER.c_state));
        end

        // ---------------------------------------------------------------- L5
        if (h.run("L5")) begin
            h.begin_sc("L5", "random reset", $sformatf("%0d x : activity -> reset at a random moment", N_RESET),
                       "every time : A1 initial state");
            for (int i = 0; i < N_RESET; i++) begin
                h.set_sw(7'b000_0001);
                h.do_reset();
                h.pulse_phy(BR);
                h.uart_send("/auto all");
                h.set_sw(7'b000_0000);
                h.wait_us(($urandom(seed) % 1000) / 1000.0 * 2 * TA / 1000.0);
                seed = $urandom(seed);
                h.rst_assert();
                h.wait_us($urandom(seed) % 3 + 0.5);
                h.rst_release();
                h.check($sformatf("L5-%0d", i + 1), (h.rst_rel_clk == 2) && (h.sw_cnt_cs() == 0) && (h.dut.U_WTS.w_sw_run_stop == 0)
                        && (h.wt_cs() == h.hms2cs(12, 0, 0, 0)) && (h.dut.w_tm_run == 0) && (h.tx === 1'b1) && (h.trig === 1'b0)
                        && (h.dut.U_DHT11.w_dht_oe == 0) && (h.dut.w_uart_mode == 0) && (h.led == 16'h8009),
                        "state right after reset", "w_rst 2 clk, all initial, LED 8009",
                        $sformatf("rel %0d clk, SW %s run %b, watch %s, tm_run %b, tx %b, trig %b, uart_mode %b, LED %h",
                                  h.rst_rel_clk, h.cs2str(h.sw_cnt_cs()), h.dut.U_WTS.w_sw_run_stop, h.cs2str(h.wt_cs()),
                                  h.dut.w_tm_run, h.tx, h.trig, h.dut.w_uart_mode, h.led));
            end
        end

        // ---------------------------------------------------------------- L6
        if (h.run("L6")) begin
            h.begin_sc("L6", "send snapshot on the carry clock", "SW 00:00:00.95 RUN, force send_go in the clock msec wraps 99 -> 00",
                       "spec : 00:00:01.00 - code may send 00:00:00.00 (issue 8)");
            h.set_sw(7'b000_0001);
            h.do_reset();
            h.preload_sw(0, 0, 0, 95);
            h.pulse_phy(BR);
            h.flush_lines();
            @(posedge h.clk iff ((h.dut.U_WTS.U_STOPWATCH_DATAPATH.U_MSEC_COUNTER.counter_reg == 99)
                                 && (h.dut.U_WTS.U_STOPWATCH_DATAPATH.w_tick_10ms === 1'b1)));
            #6;
            force h.dut.U_UART.U_CONTROL.c_sender_go = 1'b1;   // 다음 엣지에 sender 가 잡음 (sel 0 = 스톱워치)
            @(posedge h.clk);
            #1;
            release h.dut.U_UART.U_CONTROL.c_sender_go;
            h.next_line(s, t0, 3 * LINE13);
            h.spec("L6-1", s == "00:00:01.00", "line sent in the carry clock", "\"00:00:01.00\"", {"\"", s, "\""});
        end

        h.finish_tb();
    end
endmodule
