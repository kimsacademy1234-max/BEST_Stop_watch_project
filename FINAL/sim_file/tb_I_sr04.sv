`timescale 1ns / 1ps
// =============================================================================
// tb_I_sr04 — I. SR04 거리 (tb_scenario.md I1 ~ I11)
//   I1 trig  I2 거리 정확도  I3 범위 초과  I4 echo 없음  I5 echo 고착  I6 측정 중 R  I7 자동 주기
//   I8 LED 막대 · 경고  I9 오류 → 정상  I10 화면 밖 동작  I11 echo 글리치
//   센서 시간 단위 = SR04 의 1 us tick (U = h.SR_US ns). FAST 면 tick 을 10 배 빠르게 (1 us → 100 ns)
//   → echo 폭 · 30 ms · 23.2 ms · 60 ms 등이 전부 같은 비율로 줄고, 거리 계산 결과는 그대로
// =============================================================================
module tb_I_sr04;
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
        .TB_ID     ("I_sr04"),
        .ONLY      (ONLY),
        .TIMEOUT_MS(FAST ? 400 : 5_000)
    ) h ();

    localparam integer BR = 0, BL = 1, BU = 2, BD = 3;
    real U;          // SR04 의 1 us (ns)
    real LINE7;

    // 1 회 측정 : IDLE 기다림 → echo 폭 설정 → R → done
    task automatic measure(input real w_us, output bit ok);
        h.wait_sr_idle(200 * U / 1000.0);
        h.sr_mode = h.SR_NORMAL;
        h.sr_w_us = w_us;
        h.pulse_phy(BR);
        h.wait_dist_done(100 * U / 1000.0, ok);
    endtask

    task automatic uget_line(output string s);
        realtime t;
        h.flush_lines();
        h.uget();
        h.next_line(s, t, 3 * LINE7);
    endtask

    // LED 막대 (LD0~7) 를 1 ms 동안 40 번 샘플
    task automatic sample_bar(output bit s_ff, output bit s_00, output bit s_other, output reg [7:0] other);
        s_ff = 0; s_00 = 0; s_other = 0; other = 0;
        for (int i = 0; i < 40; i++) begin
            #(h.BLINK_HALF * 10.0 * 4 / 40 * 1.03);
            if (h.led[7:0] == 8'hFF) s_ff = 1;
            else if (h.led[7:0] == 8'h00) s_00 = 1;
            else begin s_other = 1; other = h.led[7:0]; end
        end
    endtask

    initial begin
        string   s;
        bit      ok, ff, zz, ot, meas_seen;
        reg [7:0] ov;
        integer  n0, r0, cm, x10, wl[5];
        realtime te, d, iv[$];
        real     w;

        U     = h.SR_US;
        LINE7 = 7 * 10 * h.TX_BIT_NS;

        // ---------------------------------------------------------------- I1
        if (h.run("I1")) begin
            h.begin_sc("I1", "trig pulse", "distance screen R", "trig rises within 1 clk of the button pulse, width 11 us");
            h.do_reset();
            h.mod("dist");
            h.sr_w_us = 1000;
            h.pulse_phy(BR);
            te = h.t_last_pulse;
            h.wait_dist_done(100 * U / 1000.0, ok);
            h.check("I1-1", (h.t_trig_r - te >= 0) && (h.t_trig_r - te <= 15), "trig rise after pulse", "0 ~ 1 clk",
                    $sformatf("%0.1f ns", h.t_trig_r - te));
            h.check("I1-2", (h.trig_w >= 11 * U - 2 * h.CLK) && (h.trig_w <= 11 * U + 2 * h.CLK), "trig width (11 ticks +- 2 clk)",
                    $sformatf("%0.1f ns (11 us)", 11 * U),
                    $sformatf("%0.1f ns", h.trig_w));
        end

        // ---------------------------------------------------------------- I2
        if (h.run("I2")) begin
            h.begin_sc("I2", "distance accuracy", "echo width 61 / 583 / 5803 / 20460 / 23150 us",
                       "x10 = floor(W*10/58), cm = floor(W/58), done <= echo fall + 1.1 us, UART NNNcm");
            h.do_reset();
            h.mod("dist");
            wl = '{61, 583, 5803, 20460, 23150};
            for (int i = 0; i < 5; i++) begin
                measure(wl[i], ok);
                x10 = (wl[i] * 10) / 58;
                cm  = wl[i] / 58;
                d   = h.t_dist_done - h.t_echo_f;
                uget_line(s);
                h.check($sformatf("I2-%0d", i + 1), ok && (h.dut.w_distance_x10 == x10) && (h.dut.w_distance == cm)
                        && (h.dist_st == 0) && (d >= 0) && (d <= 1.1 * U) && (s == $sformatf("%03dcm", cm)),
                        $sformatf("echo %0d us", wl[i]), $sformatf("x10 %0d, %03dcm, done <= %0.0f ns", x10, cm, 1.1 * U),
                        $sformatf("x10 %0d, \"%s\", status %0d, done %0.0f ns", h.dut.w_distance_x10, s, h.dist_st, d));
            end
        end

        // ---------------------------------------------------------------- I3
        if (h.run("I3")) begin
            h.begin_sc("I3", "out of range", "echo 23,250 us", "Err2, 400cm, LD9, done = echo rise + 23.2 ms");
            h.do_reset();
            h.mod("dist");
            measure(23250, ok);
            d = h.t_dist_done - h.t_echo_r;
            uget_line(s);
            h.check("I3-1", ok && (h.dist_st == 2) && (h.dut.w_distance_x10 == 4000) && (s == "400cm") && (h.led[9] == 1)
                    && (d >= 23200 * U - 3 * U) && (d <= 23200 * U + 3 * U),
                    "echo 23,250 us", $sformatf("status 2, 400cm, LD9, %0.3f ms", 23200 * U / 1.0e6),
                    $sformatf("status %0d, \"%s\", LD9 %b, %0.4f ms", h.dist_st, s, h.led[9], d / 1.0e6));
        end

        // ---------------------------------------------------------------- I4
        if (h.run("I4")) begin
            h.begin_sc("I4", "no echo", "sensor gives no echo", "Err1 at trig fall + 30.0 ms, 000cm, LD9");
            h.do_reset();
            h.mod("dist");
            h.sr_mode = h.SR_NONE;
            h.pulse_phy(BR);
            h.wait_dist_done(100 * U / 1000.0, ok);
            d = h.t_dist_done - h.t_trig_f;
            uget_line(s);
            h.check("I4-1", ok && (h.dist_st == 1) && (s == "000cm") && (h.led[9] == 1) && (d >= 30000 * U - 3 * U)
                    && (d <= 30000 * U + 3 * U), "no echo", $sformatf("status 1, 000cm, LD9, %0.3f ms", 30000 * U / 1.0e6),
                    $sformatf("status %0d, \"%s\", LD9 %b, %0.4f ms", h.dist_st, s, h.led[9], d / 1.0e6));
            h.sr_mode = h.SR_NORMAL;
        end

        // ---------------------------------------------------------------- I5
        if (h.run("I5")) begin
            h.begin_sc("I5", "echo stuck high", "echo 1 before trig -> R -> wait -> echo 0 -> R (normal)",
                       "Err2 at 23.2 ms, Err3 at 73.2 ms then IDLE, then normal again");
            h.do_reset();
            h.mod("dist");
            h.sr_mode = h.SR_MANUAL;
            h.echo = 1'b1;
            h.wait_us(100 * U / 1000.0);
            h.pulse_phy(BR);
            h.wait_dist_done(100 * U / 1000.0, ok);
            d = h.t_dist_done - h.t_trig_f;
            h.check("I5-1", ok && (h.dist_st == 2) && (d >= 23200 * U - 3 * U) && (d <= 23200 * U + 3 * U), "first done",
                    $sformatf("Err2 at %0.3f ms", 23200 * U / 1.0e6), $sformatf("status %0d at %0.4f ms", h.dist_st, d / 1.0e6));
            h.wait_dist_done(100 * U / 1000.0, ok);
            d = h.t_dist_done - h.t_trig_f;
            h.wait_clk(5);
            h.check("I5-2", ok && (h.dist_st == 3) && (d >= 73200 * U - 5 * U) && (d <= 73200 * U + 5 * U)
                    && (h.dut.U_SR04.w_busy == 0), "second done",
                    $sformatf("Err3 at %0.3f ms, IDLE", 73200 * U / 1.0e6),
                    $sformatf("status %0d at %0.4f ms, busy %b", h.dist_st, d / 1.0e6, h.dut.U_SR04.w_busy));
            h.echo = 1'b0;
            h.wait_us(1000 * U / 1000.0);
            measure(5803, ok);
            h.check("I5-3", ok && (h.dist_st == 0) && (h.dut.w_distance_x10 == 1000), "echo released, normal echo",
                    "status 0, 100.0 cm", $sformatf("status %0d, x10 %0d", h.dist_st, h.dut.w_distance_x10));
        end

        // ---------------------------------------------------------------- I6
        if (h.run("I6")) begin
            h.begin_sc("I6", "R while measuring", "echo 10 ms, R x3 during DIST", "only 1 trig");
            h.do_reset();
            h.mod("dist");
            n0 = h.trig_cnt;
            h.sr_w_us = 10000;
            h.pulse_phy(BR);
            h.wait_us(3500 * U / 1000.0);
            for (int i = 0; i < 3; i++) begin
                h.pulse_phy(BR);
                h.wait_us(100 * U / 1000.0);
            end
            h.wait_us(70000 * U / 1000.0);
            h.check("I6-1", h.trig_cnt == n0 + 1, "trig count", "1", $sformatf("%0d", h.trig_cnt - n0));
        end

        // ---------------------------------------------------------------- I7
        if (h.run("I7")) begin
            h.begin_sc("I7", "auto period", "U, echo 0.6 ms / 38 ms / 55 ms, then U again",
                       "trig every 60.0 / 60.0 / ~65.5 ms, stops after U");
            h.do_reset();
            h.mod("dist");
            h.sr_mode = h.SR_NORMAL;
            for (int k = 0; k < 3; k++) begin
                case (k)
                    0: w = 600;
                    1: w = 38000;
                    default: w = 55000;
                endcase
                h.sr_w_us = w;
                if (k == 0) h.pulse_phy(BU);
                n0 = h.trig_cnt;
                while (h.trig_cnt < n0 + 2) #(10 * U);      // 바꾼 폭이 적용될 때까지
                h.trig_r_q.delete();
                while (h.trig_r_q.size() < 4) #(10 * U);
                iv.delete();
                for (int i = 1; i < 4; i++) iv.push_back(h.trig_r_q[i] - h.trig_r_q[i - 1]);
                if (k < 2) begin
                    ok = 1;
                    foreach (iv[i]) if ((iv[i] < 60000 * U) || (iv[i] > 60000 * U + 5 * U)) ok = 0;
                    h.check($sformatf("I7-%0d", k + 1), ok && ((k == 0) ? (h.dist_st == 0) : (h.dist_st == 2)),
                            $sformatf("echo %0.0f us", w), $sformatf("3 x %0.3f ms (+0 ~ +5 us)", 60000 * U / 1.0e6),
                            $sformatf("%0.4f / %0.4f / %0.4f ms, status %0d", iv[0] / 1.0e6, iv[1] / 1.0e6, iv[2] / 1.0e6, h.dist_st));
                end else begin
                    ok = 1;
                    foreach (iv[i]) if ((iv[i] < (11 + 500 + 55000 + 10000) * U - 10 * U) || (iv[i] > (11 + 500 + 55000 + 10000) * U + 10 * U)) ok = 0;
                    h.check("I7-3", ok && (h.dist_st == 2), "echo 55,000 us",
                            $sformatf("3 x %0.3f ms (echo fall + 10 ms), Err2 not Err3", 65511 * U / 1.0e6),
                            $sformatf("%0.4f / %0.4f / %0.4f ms, status %0d", iv[0] / 1.0e6, iv[1] / 1.0e6, iv[2] / 1.0e6, h.dist_st));
                end
            end
            h.pulse_phy(BU);
            n0 = h.trig_cnt;
            h.wait_us(150000 * U / 1000.0);
            h.check("I7-4", (h.trig_cnt == n0) && (h.dut.w_dist_auto == 0), "U again", "no more trig",
                    $sformatf("%0d trig, auto %b", h.trig_cnt - n0, h.dut.w_dist_auto));
        end

        // ---------------------------------------------------------------- I8
        if (h.run("I8")) begin
            h.begin_sc("I8", "LED bar and close-range warning", "sw15 1 : 10.0 -> 11.0 -> 12.1 -> 11.0 cm, then sw15 0",
                       "blink -> blink -> steady 7 LED -> steady ; sw15 0 : LD0~7 off, LD8/LD9 still work");
            h.do_reset();
            h.mod("dist");
            h.sw15 = 1'b1;
            wl = '{583, 641, 705, 641, 0};
            for (int i = 0; i < 4; i++) begin
                measure(wl[i], ok);
                sample_bar(ff, zz, ot, ov);
                if (i < 2)
                    h.check($sformatf("I8-%0d", i + 1), ff && zz && !ot, $sformatf("%0d.%0d cm", h.dut.w_distance_x10 / 10,
                            h.dut.w_distance_x10 % 10), "8 LED blinking (FF / 00)", $sformatf("FF %b, 00 %b, other %b", ff, zz, ot));
                else
                    h.check($sformatf("I8-%0d", i + 1), !ff && !zz && ot && (ov == 8'h7F), $sformatf("%0d.%0d cm",
                            h.dut.w_distance_x10 / 10, h.dut.w_distance_x10 % 10), "steady 7F", $sformatf("FF %b, 00 %b, value %h", ff, zz, ov));
            end
            h.sw15 = 1'b0;
            h.wait_sr_idle(200 * U / 1000.0);
            h.sr_mode = h.SR_NONE;
            h.pulse_phy(BR);
            meas_seen = 0;
            ok = 1;
            while (h.dut.U_SR04.w_busy === 1'b1) begin
                #(100 * U);
                if (h.led[8]) meas_seen = 1;
                if (h.led[7:0] != 0) ok = 0;
            end
            h.check("I8-5", ok && meas_seen && (h.led[9] == 1) && (h.led[7:0] == 0), "sw15 0 + measurement (no echo)",
                    "LD0~7 0, LD8 seen, LD9 1", $sformatf("bar %h, LD8 seen %b, LD9 %b", h.led[7:0], meas_seen, h.led[9]));
            h.sr_mode = h.SR_NORMAL;
        end

        // ---------------------------------------------------------------- I9
        if (h.run("I9")) begin
            h.begin_sc("I9", "error then normal", "no echo (Err1) -> echo 5803 us", "100.0 cm, LD9 off");
            h.do_reset();
            h.mod("dist");
            h.sr_mode = h.SR_NONE;
            h.pulse_phy(BR);
            h.wait_dist_done(100 * U / 1000.0, ok);
            h.note($sformatf("first : status %0d, LD9 %b", h.dist_st, h.led[9]));
            measure(5803, ok);
            h.check("I9-1", ok && (h.dist_st == 0) && (h.dut.w_distance_x10 == 1000) && (h.led[9] == 0), "normal after Err1",
                    "status 0, 100.0 cm, LD9 0", $sformatf("status %0d, x10 %0d, LD9 %b", h.dist_st, h.dut.w_distance_x10, h.led[9]));
        end

        // ---------------------------------------------------------------- I10
        if (h.run("I10")) begin
            h.begin_sc("I10", "auto keeps running on another screen", "auto on -> /mod w_ms -> 200 ms ; R on WTS screen",
                       "trig every 60 ms, LED = watch LED ; R not delivered to SR04");
            h.do_reset();
            h.mod("dist");
            h.sr_w_us = 600;
            h.pulse_phy(BU);
            h.mod("w_ms");
            n0 = h.trig_cnt;
            h.wait_us(200000 * U / 1000.0);
            h.check("I10-1", (h.trig_cnt - n0 >= 3) && (h.trig_cnt - n0 <= 4) && (h.led == 16'h8009), "after 200 ms on WTS screen",
                    "3 ~ 4 trig, LED 8009", $sformatf("%0d trig, LED %h", h.trig_cnt - n0, h.led));
            r0 = h.sr_btnR_cnt;
            h.pulse_phy(BR);
            h.check("I10-2", h.sr_btnR_cnt == r0, "R on WTS screen", "SR04 i_btn_R stays 0", $sformatf("%0d pulse", h.sr_btnR_cnt - r0));
        end

        // ---------------------------------------------------------------- I11
        if (h.run("I11")) begin
            h.begin_sc("I11", "echo glitch", "0.5 us echo pulse 200 us after trig", "000.0 (OK) or Err1, back to IDLE within 60 ms");
            h.do_reset();
            h.mod("dist");
            h.sr_mode = h.SR_MANUAL;
            h.pulse_phy(BR);
            te = h.t_trig_r;
            wait (h.trig === 1'b0);
            h.wait_us(200 * U / 1000.0);
            h.echo = 1'b1;
            #(0.5 * U);
            h.echo = 1'b0;
            h.wait_until(te + 60100 * U);
            h.check("I11-1", (h.dut.U_SR04.w_busy == 0) && (((h.dist_st == 0) && (h.dut.w_distance_x10 == 0)) || (h.dist_st == 1)),
                    "after glitch", "IDLE, status 0 (0.0) or 1", $sformatf("busy %b, status %0d, x10 %0d", h.dut.U_SR04.w_busy,
                    h.dist_st, h.dut.w_distance_x10));
            h.sr_mode = h.SR_NORMAL;
        end

        h.finish_tb();
    end
endmodule
