`timescale 1ns / 1ps
// =============================================================================
// tb_J_dht11 — J. DHT11 온습도 (tb_scenario.md J1 ~ J14)
//   J1 부팅 대기  J2 시작 신호  J3 정상 측정  J4 비트 경계  J5 체크섬 wrap  J6 체크섬 오류  J7 응답 없음
//   J8 중간 끊김  J9 간격 안 R  J10 측정 중 R  J11 자동 측정  J12 측정 전 표시  J13 화면 밖 동작  J14 습도 >= 100 (⚠)
//   센서 시간 단위 = DHT11 의 1 us tick (D = h.DH_US ns). 부팅 · 간격은 clk 수 (T_BOOT · T_INTV)
// =============================================================================
module tb_J_dht11;
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
        .TB_ID     ("J_dht11"),
        .ONLY      (ONLY),
        .TIMEOUT_MS(FAST ? 300 : 40_000)
    ) h ();

    localparam integer BR = 0, BL = 1, BU = 2, BD = 3;
    localparam [6:0]   SCR_DHT = 7'b100_0000;
    real D, LINE8, TI, TB;

    // R 한 번 → 측정 끝 (간격 안이면 DUT 가 기억했다가 측정)
    task automatic measure(output bit ok);
        h.pulse_phy(BR);
        h.wait_dht_done(3.0 * TI / 1.0e6, ok);
    endtask

    task automatic uget_line(output string s);
        realtime t;
        h.flush_lines();
        h.uget();
        h.next_line(s, t, 3 * LINE8);
    endtask

    function automatic string st();
        return $sformatf("status %0d, valid %b, hum %0d, temp %0d, fnd %0d, dashes %b, LED %b", h.dht_st, h.dut.w_dht_valid,
                         h.dut.w_humidity, h.dut.w_temperature, h.dut.w_dht_fnd_data, h.dut.w_dht_dashes, h.dut.w_dht_led);
    endfunction

    // 부팅 대기 끝난 상태로 시작 (UART 모드, 온습도 화면)
    task automatic start_temp();
        h.dh_default();
        h.do_reset();
        h.mod("temp");
        h.wait_until(h.t_rel + 1.1 * TB);
    endtask

    initial begin
        string   s;
        bit      ok;
        integer  n0, r0;
        realtime d, T, t2, tr;
        real     hi0s[5], hi1s[5];

        D     = h.DH_US;
        LINE8 = 8 * 10 * h.TX_BIT_NS;
        TI    = h.T_INTV;
        TB    = h.T_BOOT;

        // ---------------------------------------------------------------- J1 · J2 · J3 (같은 측정)
        if (h.run("J1") || h.run("J2") || h.run("J3")) begin
            h.begin_sc("J1", "boot wait", "reset -> sw6 -> R at 0.3 boot", "START LOW begins exactly at boot");
            h.dh_default();
            h.set_sw(7'b000_0000);
            h.do_reset();
            h.set_sw(SCR_DHT);
            h.wait_until(h.t_rel + 0.3 * TB);
            n0 = h.dh_start_cnt;
            h.pulse_phy(BR);
            h.wait_dht_done(3.0 * TB / 1.0e6, ok);
            d = h.t_oe_r - h.t_rel;
            h.check("J1-1", (h.dh_start_cnt == n0 + 1) && (d >= TB) && (d <= TB + 100), "START LOW begins",
                    $sformatf("release + %0.3f ms", TB / 1.0e6), $sformatf("release + %0.6f ms", d / 1.0e6));

            h.begin_sc("J2", "start signal", "same measurement", "LOW 18.00 ms then released, FPGA never drives while sensor drives");
            h.check("J2-1", (h.dh_start_w >= 18000 * D) && (h.dh_start_w <= 18000 * D + 2 * D), "START LOW width",
                    $sformatf("%0.4f ms", 18000 * D / 1.0e6), $sformatf("%0.5f ms", h.dh_start_w / 1.0e6));
            h.check("J2-2", !h.dh_contention, "FPGA oe while sensor model drives", "never", h.pick(h.dh_contention, "seen", "never"));

            h.begin_sc("J3", "normal measurement", "55 %, 24 C (checksum 79)",
                       "done ~3.81 ms after START LOW ends, FND 5524, LD2 1, UART 55%24C");
            d = h.t_dht_done - h.t_oe_f;
            h.check("J3-1", ok && (h.dht_st == 0) && (h.dut.w_dht_valid == 1) && (d >= 3700 * D) && (d <= 4000 * D),
                    "done time and status", $sformatf("status 0, %0.3f ~ %0.3f ms", 3700 * D / 1.0e6, 4000 * D / 1.0e6),
                    $sformatf("status %0d, %0.4f ms", h.dht_st, d / 1.0e6));
            h.check("J3-2", (h.dut.w_dht_fnd_data == 5524) && (h.dut.w_dht_dashes == 0) && (h.led[2] == 1) && (h.led[1] == 0),
                    "display data and LED", "5524, LD2 1, LD1 0", st());
            h.mod("temp");
            uget_line(s);
            h.check("J3-3", s == "55%24C", "UART /get", "55%24C", {"\"", s, "\""});
        end

        // ---------------------------------------------------------------- J4
        if (h.run("J4")) begin
            h.begin_sc("J4", "bit HIGH length threshold (40 us)", "0-bit HIGH 26/28/38 us, 1-bit HIGH 43/70 us",
                       "decoded right (55 / 24, checksum OK)");
            start_temp();
            hi0s = '{26, 28, 38, 26, 26};
            hi1s = '{70, 70, 70, 43, 70};
            for (int i = 0; i < 5; i++) begin
                h.dh_hi0 = hi0s[i];
                h.dh_hi1 = hi1s[i];
                measure(ok);
                h.check($sformatf("J4-%0d", i + 1), ok && (h.dht_st == 0) && (h.dut.w_humidity == 55) && (h.dut.w_temperature == 24),
                        $sformatf("0-bit %0.0f us, 1-bit %0.0f us", hi0s[i], hi1s[i]), "status 0, 55 / 24", st());
            end
            h.dh_default();
        end

        // ---------------------------------------------------------------- J5
        if (h.run("J5")) begin
            h.begin_sc("J5", "checksum wraps mod 256", "90 . 99 % / 50 . 99 C, checksum 0x52", "OK, FND 9050");
            start_temp();
            h.dh_data = '{8'd90, 8'd99, 8'd50, 8'd99};
            measure(ok);
            h.check("J5-1", ok && (h.dht_st == 0) && (h.dut.w_dht_fnd_data == 9050), "sum 338 -> 0x52", "status 0, 9050", st());
            h.dh_default();
        end

        // ---------------------------------------------------------------- J6
        if (h.run("J6")) begin
            h.begin_sc("J6", "checksum error keeps last good value", "55/24 OK -> checksum +1 -> 60/25 OK",
                       "Err3 + LD1, UART still 55%24C ; then 6025, LD1 0");
            start_temp();
            measure(ok);
            h.dh_chk_off = 1;
            measure(ok);
            h.check("J6-1", ok && (h.dht_st == 3) && (h.led[1] == 1) && (h.led[2] == 0), "bad checksum", "status 3, LD1 1, LD2 0", st());
            uget_line(s);
            h.check("J6-2", s == "55%24C", "UART during error", "55%24C (last good)", {"\"", s, "\""});
            h.dh_chk_off = 0;
            h.dh_data = '{8'd60, 8'd0, 8'd25, 8'd0};
            measure(ok);
            h.check("J6-3", ok && (h.dht_st == 0) && (h.dut.w_dht_fnd_data == 6025) && (h.led[1] == 0), "next good", "6025, LD1 0", st());
            h.dh_default();
        end

        // ---------------------------------------------------------------- J7
        if (h.run("J7")) begin
            h.begin_sc("J7", "no response", "sensor silent ; data line stuck LOW", "Err1 at START end + 230 us (both)");
            start_temp();
            h.dh_mode = h.DH_NONE;
            measure(ok);
            d = h.t_dht_done - h.t_oe_f;
            h.check("J7-1", ok && (h.dht_st == 1) && (d >= 228 * D) && (d <= 233 * D), "sensor silent",
                    $sformatf("status 1 at %0.1f us", 230 * D / 1000.0), $sformatf("status %0d at %0.1f us", h.dht_st, d / 1000.0));
            h.dh_mode = h.DH_STUCK;
            measure(ok);
            d = h.t_dht_done - h.t_oe_f;
            h.check("J7-2", ok && (h.dht_st == 1) && (d >= 228 * D) && (d <= 233 * D), "line stuck LOW",
                    $sformatf("status 1 at %0.1f us", 230 * D / 1000.0), $sformatf("status %0d at %0.1f us", h.dht_st, d / 1000.0));
            h.dh_default();
        end

        // ---------------------------------------------------------------- J8
        if (h.run("J8")) begin
            h.begin_sc("J8", "stops in the middle", "sensor stops after 20 bits", "Err2 at last rising edge + 200 us");
            start_temp();
            h.dh_nbits = 20;
            measure(ok);
            d = h.t_dht_done - h.t_dh_last_rise;
            h.check("J8-1", ok && (h.dht_st == 2) && (d >= 199 * D) && (d <= 203 * D), "20 bits then silence",
                    $sformatf("status 2 at %0.1f us", 200 * D / 1000.0), $sformatf("status %0d at %0.1f us", h.dht_st, d / 1000.0));
            h.dh_default();
        end

        // ---------------------------------------------------------------- J9
        if (h.run("J9")) begin
            h.begin_sc("J9", "R inside the 2 s interval", "R (start T) -> after done, R x3 inside the interval",
                       "next START exactly T + interval, only once");
            start_temp();
            measure(ok);
            T  = h.t_oe_r;
            tr = T + 0.6 * TI;            // 측정 끝난 뒤 · 간격 안
            h.wait_until(tr);
            n0 = h.dh_start_cnt;
            for (int i = 0; i < 3; i++) begin
                h.pulse_phy(BR);
                h.wait_us(0.02 * TI / 1000.0);
            end
            h.wait_until(T + 2.25 * TI);
            t2 = (h.dh_start_q.size() > 0) ? h.dh_start_q[h.dh_start_q.size() - 1] : 0;
            h.check("J9-1", (t2 - T >= TI) && (t2 - T <= TI + 100), "second START", $sformatf("T + %0.3f ms", TI / 1.0e6),
                    $sformatf("T + %0.6f ms", (t2 - T) / 1.0e6));
            h.check("J9-2", h.dh_start_cnt == n0 + 1, "measurements from 3 R", "1", $sformatf("%0d", h.dh_start_cnt - n0));
        end

        // ---------------------------------------------------------------- J10
        if (h.run("J10")) begin
            h.begin_sc("J10", "R while measuring is ignored", "R (start T) -> R during START LOW", "no START at T + interval");
            start_temp();
            h.pulse_phy(BR);
            while (h.dut.U_DHT11.w_dht_oe !== 1'b1) #(10 * D);
            T  = h.t_oe_r;
            n0 = h.dh_start_cnt;
            h.wait_us(5000 * D / 1000.0);
            h.pulse_phy(BR);
            h.wait_until(T + 1.5 * TI);
            h.check("J10-1", h.dh_start_cnt == n0, "START count after T", "0 more", $sformatf("%0d more", h.dh_start_cnt - n0));
        end

        // ---------------------------------------------------------------- J11
        if (h.run("J11")) begin
            h.begin_sc("J11", "auto measurement", "U (T) -> 3.5 intervals -> U", "START every interval (4), LD3 1, stops after U");
            start_temp();
            h.dh_start_q.delete();
            h.pulse_phy(BU);
            T = h.t_last_pulse;
            h.wait_until(T + 3.4 * TI);
            h.check("J11-2", h.led[3] == 1, "LED while auto", "LD3 1", $sformatf("LD3 %b", h.led[3]));
            h.wait_until(T + 3.5 * TI);
            ok = (h.dh_start_q.size() == 4);
            for (int i = 1; i < h.dh_start_q.size(); i++)
                if ((h.dh_start_q[i] - h.dh_start_q[i - 1] < TI) || (h.dh_start_q[i] - h.dh_start_q[i - 1] > TI + 100)) ok = 0;
            h.check("J11-1", ok && (h.dh_start_q[0] - T <= 100), "START times", $sformatf("4 starts, %0.3f ms apart", TI / 1.0e6),
                    $sformatf("%0d starts, first at +%0.0f ns", h.dh_start_q.size(), h.dh_start_q[0] - T));
            h.pulse_phy(BU);
            h.wait_until(T + 5.0 * TI);
            h.check("J11-3", (h.dh_start_q.size() == 4) && (h.led[3] == 0), "after U", "still 4 starts, LD3 0",
                    $sformatf("%0d starts, LD3 %b", h.dh_start_q.size(), h.led[3]));
        end

        // ---------------------------------------------------------------- J12
        if (h.run("J12")) begin
            h.begin_sc("J12", "before the first measurement", "reset -> /mod temp", "FND ----, UART 00%00C");
            h.dh_default();
            h.do_reset();
            h.mod("temp");
            h.fnd_read(s);
            h.check("J12-1", (s == "----") && (h.dut.w_dht_dashes == 1), "FND", "\"----\"", {"\"", s, "\""});
            uget_line(s);
            h.check("J12-2", s == "00%00C", "UART /get", "00%00C", {"\"", s, "\""});
        end

        // ---------------------------------------------------------------- J13
        if (h.run("J13")) begin
            h.begin_sc("J13", "auto keeps running on another screen", "auto on -> /mod w_ms -> 2.5 intervals ; R on WTS screen",
                       ">= 2 STARTs ; R not delivered to DHT11");
            start_temp();
            h.pulse_phy(BU);
            h.mod("w_ms");
            n0 = h.dh_start_cnt;
            h.wait_until($realtime + 2.5 * TI);
            h.check("J13-1", h.dh_start_cnt - n0 >= 2, "STARTs on WTS screen", ">= 2", $sformatf("%0d", h.dh_start_cnt - n0));
            r0 = h.dh_btnR_cnt;
            h.pulse_phy(BR);
            h.check("J13-2", h.dh_btnR_cnt == r0, "R on WTS screen", "DHT i_btn_R stays 0", $sformatf("%0d pulse", h.dh_btnR_cnt - r0));
        end

        // ---------------------------------------------------------------- J14
        if (h.run("J14")) begin
            h.begin_sc("J14", "humidity >= 100", "100 % / 24 C", "FND 99.24 ; spec: 2-digit UART - code sends ':0%24C' (issue 7)");
            start_temp();
            h.dh_data = '{8'd100, 8'd0, 8'd24, 8'd0};
            measure(ok);
            h.check("J14-1", ok && (h.dht_st == 0) && (h.dut.w_dht_fnd_data == 9924), "FND data", "9924 (99 clamp)", st());
            uget_line(s);
            h.spec("J14-2", h.is_temp(s), "UART /get", "digits only (NN%NNC)", {"\"", s, "\""});
            h.dh_default();
        end

        h.finish_tb();
    end
endmodule
