`timescale 1ns / 1ps
// =============================================================================
// tb_B_button — B. 버튼 · 디바운스 (tb_scenario.md B1 ~ B5)
//   B1 정상 누름  B2 채터링  B3 짧은 누름 경계  B4 길게 누름  B5 화면 게이팅
//   버튼은 물리 핀 (btn_*) 으로 누름 → 디바운서 출력 w_phy_btn_* 를 셈 (B5 만 디바운서 출력에 직접 1 clk)
//   디바운서 (4 kHz × 8) 는 시간을 줄이지 않음
// =============================================================================
module tb_B_button;
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
        .TB_ID     ("B_button"),
        .ONLY      (ONLY),
        .TIMEOUT_MS(FAST ? 1_500 : 10_000)
    ) h ();

    localparam integer BR = 0, BL = 1, BU = 2, BD = 3;
    localparam real LONG_PRESS_MS = 500.0;   // B4 (md 는 3 s, 시뮬 시간 때문에 0.5 s — 원리 같음)

    function automatic string bn(input integer b);
        case (b)
            0: return "R";
            1: return "L";
            2: return "U";
            default: return "D";
        endcase
    endfunction

    // B5 : 다섯 모듈 상태 스냅샷
    bit     s_run;
    integer s_cur, s_tm, s_trig, s_dh;
    task automatic snap();
        s_run  = h.dut.U_WTS.w_sw_run_stop;
        s_cur  = h.dut.w_wt_cursor;
        s_tm   = h.tm_cs();
        s_trig = h.trig_cnt;
        s_dh   = h.dh_start_cnt;
    endtask
    function automatic string snap_str();
        return $sformatf("sw_run %b cursor %0d timer %s trig %0d dht_start %0d", h.dut.U_WTS.w_sw_run_stop,
                         h.dut.w_wt_cursor, h.cs2str(h.tm_cs()), h.trig_cnt, h.dh_start_cnt);
    endfunction

    initial begin
        integer  n0, n1;
        realtime t_press, t_last, lat;
        bit      ok;

        // ---------------------------------------------------------------- B1
        if (h.run("B1")) begin
            h.begin_sc("B1", "normal press (R/L/U/D)", "each button 50 ms press, 4 kHz phase varied",
                       "1 pulse of 1 clk, 1.75 ~ 2.00 ms after press");
            h.set_sw(7'b000_0000);     // 시계 (설정 아님) : 버튼이 아무 효과 없음
            h.do_reset();
            for (int b = 0; b < 4; b++) begin
                n0 = h.pc[b];
                n1 = h.pw_long;
                #(37.0 * h.US * (b + 1));   // 4 kHz 위상을 버튼마다 다르게
                t_press = $realtime;
                h.press(b, 50.0);
                h.wait_ms(10);
                lat = h.t_pc[b] - t_press;
                h.check($sformatf("B1-%0d", b + 1), (h.pc[b] == n0 + 1) && (lat >= 1.75 * h.MS) && (lat <= 2.0 * h.MS + 20)
                        && (h.pw_long == n1), {"btn_", bn(b), " -> w_phy_btn pulse"}, "1 pulse, 1.750 ~ 2.000 ms, 1 clk",
                        $sformatf("%0d pulse, %0.4f ms, long %0d", h.pc[b] - n0, lat / 1.0e6, h.pw_long - n1));
            end
        end

        // ---------------------------------------------------------------- B2
        if (h.run("B2")) begin
            h.begin_sc("B2", "chattering on press and release", "10 toggles @100 us -> hold 50 ms -> 10 toggles -> 0",
                       "exactly 1 pulse per press, 0 on release");
            h.set_sw(7'b000_0000);
            h.do_reset();
            n0 = h.pc[BR];
            h.bounce(BR, 10, 100.0, 1'b1, t_last);
            h.wait_ms(50);
            n1 = h.pc[BR];
            lat = h.t_pc[BR] - t_last;
            h.check("B2-1", (n1 == n0 + 1) && (lat >= 1.75 * h.MS) && (lat <= 2.0 * h.MS + 20),
                    "press with bounce", "1 pulse, 1.75 ~ 2.00 ms after last bounce",
                    $sformatf("%0d pulse, %0.4f ms", n1 - n0, lat / 1.0e6));
            h.bounce(BR, 10, 100.0, 1'b0, t_last);
            h.wait_ms(10);
            h.check("B2-2", h.pc[BR] == n1, "release with bounce", "0 pulse", $sformatf("%0d pulse", h.pc[BR] - n1));
        end

        // ---------------------------------------------------------------- B3
        if (h.run("B3")) begin
            h.begin_sc("B3", "short press boundary", "1.5 ms press, 10 ms gap, 2.25 ms press",
                       "0 pulse / 1 pulse (8 samples @ 250 us)");
            h.set_sw(7'b000_0000);
            h.do_reset();
            n0 = h.pc[BR];
            h.press(BR, 1.5);
            h.wait_ms(10);
            h.check("B3-1", h.pc[BR] == n0, "1.5 ms press", "0 pulse", $sformatf("%0d pulse", h.pc[BR] - n0));
            n0 = h.pc[BR];
            h.press(BR, 2.25);
            h.wait_ms(10);
            h.check("B3-2", h.pc[BR] == n0 + 1, "2.25 ms press", "1 pulse", $sformatf("%0d pulse", h.pc[BR] - n0));
        end

        // ---------------------------------------------------------------- B4
        if (h.run("B4")) begin
            h.begin_sc("B4", "long press (no auto repeat)", $sformatf("stopwatch screen, R held %0.0f ms", LONG_PRESS_MS),
                       "1 pulse, stopwatch RUN once");
            h.set_sw(7'b000_0001);
            h.do_reset();
            n0 = h.pc[BR];
            h.press(BR, LONG_PRESS_MS);
            h.wait_ms(5);
            h.check("B4-1", (h.pc[BR] == n0 + 1) && (h.dut.U_WTS.w_sw_run_stop == 1), "long press", "1 pulse, RUN",
                    $sformatf("%0d pulse, run %b", h.pc[BR] - n0, h.dut.U_WTS.w_sw_run_stop));
        end

        // ---------------------------------------------------------------- B5
        if (h.run("B5")) begin
            h.begin_sc("B5", "button goes only to the module on screen", "R on each of 5 screens, compare 5 module states",
                       "only that module reacts");
            h.do_reset();
            h.wait_until(h.t_rel + 1.2 * h.T_BOOT);   // DHT 부팅 대기 끝
            // 1 스톱워치
            h.set_sw(7'b000_0001);
            snap();
            h.pulse_phy(BR);
            h.wait_us(100);
            h.check("B5-1", (h.dut.U_WTS.w_sw_run_stop == 1) && (h.dut.w_wt_cursor == s_cur) && (h.tm_cs() == s_tm)
                            && (h.trig_cnt == s_trig) && (h.dh_start_cnt == s_dh),
                    "stopwatch screen R", "sw RUN, others same", snap_str());
            // 2 시계 설정 (시.분 + set)
            h.set_sw(7'b000_0110);
            h.wait_clk(5);
            snap();
            h.pulse_phy(BR);
            h.wait_us(100);
            h.check("B5-2", (h.dut.w_wt_cursor == 2) && (h.dut.U_WTS.w_sw_run_stop == s_run) && (h.tm_cs() == s_tm)
                            && (h.trig_cnt == s_trig) && (h.dh_start_cnt == s_dh),
                    "watch set screen R", "cursor 0 -> 2, others same", snap_str());
            // 3 타이머
            h.set_sw(7'b001_0000);
            snap();
            h.pulse_phy(BR);
            h.wait_us(100);
            h.check("B5-3", (h.tm_cs() == s_tm + 6000) && (h.dut.U_WTS.w_sw_run_stop == s_run) && (h.dut.w_wt_cursor == s_cur)
                            && (h.trig_cnt == s_trig) && (h.dh_start_cnt == s_dh),
                    "timer screen R", "timer +1 min, others same", snap_str());
            // 4 거리
            h.set_sw(7'b010_0000);
            snap();
            h.pulse_phy(BR);
            h.wait_us(100);
            h.check("B5-4", (h.trig_cnt == s_trig + 1) && (h.dut.U_WTS.w_sw_run_stop == s_run) && (h.tm_cs() == s_tm)
                            && (h.dh_start_cnt == s_dh),
                    "distance screen R", "1 trig, others same", snap_str());
            // 5 온습도
            h.wait_sr_idle(100);
            h.set_sw(7'b100_0000);
            snap();
            h.pulse_phy(BR);
            h.wait_us(100);
            h.check("B5-5", (h.dh_start_cnt == s_dh + 1) && (h.dut.U_WTS.w_sw_run_stop == s_run) && (h.tm_cs() == s_tm)
                            && (h.trig_cnt == s_trig),
                    "temp/humi screen R", "1 DHT START, others same", snap_str());
        end

        h.finish_tb();
    end
endmodule
