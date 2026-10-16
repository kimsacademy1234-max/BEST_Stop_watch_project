`timescale 1ns / 1ps
// =============================================================================
// tb_f3_press_timing — F3: 버튼 입력 시점 오차 (verification.md §7.1 F3, RTL 변경 없음 · TB 자극만)
//   100 Hz tick 이 Top 에 하나(공용, 항상 흐름) → RUN 시작 시점이 tick 사이 어디든 될 수 있다
//   또 디바운서 샘플(4 kHz) 과 tick 이 같은 카운터 기준이라 tick 엣지 = 샘플 엣지 (1e6 = 40 x 25,000)
//   P1 스톱워치: RUN 시작 위상 φ = 0..9 ms (tick 기준), RUN 구간 1.005 s (FSM 기준) → count 표
//      이상적 스톱워치(시작 때 tick 0 맞춤)는 항상 100 (1.00 s, 버림). 공용 tick 은 φ 에 따라 100 / 101
//   P2 타이머: 프리로드 00:01.00, 시작 위상 φ = 0..9 ms → run↑ → alarm↑ 간격 ∈ (0.99 s, 1.00 s + 1 clk]
//   P3 짧은 탭 1.5 / 1.8 / 1.9 / 2.0 ms x 샘플 위상 4 개 → 인식/무시 표 (§1.2 회색 구간)
// =============================================================================
module tb_f3_press_timing;
`define TB_ID "F3"
`define TB_TIMEOUT_MS 40000
`include "tb_common.svh"

    realtime t_run_rise = 0, t_run_fall = 0, t_tm_run = 0, t_tm_alarm = 0;
    always @(posedge dut.w_run_stop) t_run_rise = $realtime;
    always @(negedge dut.w_run_stop) t_run_fall = $realtime;
    always @(posedge dut.w_tm_run)   t_tm_run   = $realtime;
    always @(posedge dut.w_tm_alarm) t_tm_alarm = $realtime;

    // 다음 tick 엣지(T) 를 잡고, 디바운서 8 번째 샘플이 T + 20 ms + phi 에 오도록 1.875 ms 앞서 누름
    task automatic press_at_phase(input integer b, input longint phi_us, output realtime e1);
        realtime T;
        @(posedge dut.w_tick_10ms);
        T  = $realtime;               // tick 이 올라간 클럭 엣지 = 샘플 엣지
        e1 = T + 20.0e6 + phi_us * 1000.0;
        #(e1 - 1.875e6 - $realtime);
        press_ns(b, 5 * MS, 5 * MS);
    endtask

    initial begin
        integer phi, i, j, n100, n101, cnt, got, expn, p0;
        realtime e1, win, dt;
        longint tap[0:3];
        longint offs[0:3];
        string row;
        #1;
        // ------------------------------------------------------------------ P1
        if (phase_begin(1, "stopwatch: RUN start phase 0..9 ms vs shared tick, window 1.005 s -> count table")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            n100 = 0;
            n101 = 0;
            for (phi = 0; phi < 10; phi = phi + 1) begin
                press(BL);  // STOP 에서 클리어
                press_at_phase(BR, phi * 1000, e1);
                check("F3.SW.START", (t_run_rise - e1) > 9.999 && (t_run_rise - e1) < 10.001,
                      $sformatf("RUN starts exactly at the targeted sample edge (phi=%0d ms)", phi), "e1+10ns",
                      $sformatf("e1+%0.3fns", t_run_rise - e1));
                // 두 번째 R: 8 번째 샘플 = e1 + 1.005 s
                #(e1 + 1.005e9 - 1.875e6 - $realtime);
                press(BR);
                win = t_run_fall - t_run_rise;
                cnt = sw_count();
                check("F3.SW.WIN", win > 1.005e9 - 0.001 && win < 1.005e9 + 0.001, "RUN window", "1005.000000 ms",
                      $sformatf("%0.6f ms", win / 1.0e6));
                check("F3.SW.CNT", cnt == 100 || cnt == 101, "count for 1.005 s", "100 or 101", $sformatf("%0d", cnt));
                if (cnt == 100) n100 = n100 + 1;
                if (cnt == 101) n101 = n101 + 1;
                limit("F3.SW", $sformatf("phase=%0dms window=1.005s count=%0d (shows %0d.%02d s, ideal 1.00 s, err %0d ms vs true 1.005 s)",
                                         phi, cnt, cnt / 100, cnt % 100, cnt * 10 - 1005));
            end
            limit("F3.SW", $sformatf("same 1.005 s measured 10 times: %0d x 1.00 s, %0d x 1.01 s -> result depends on press phase vs shared tick (+-1 count)",
                                     n100, n101));
            check("F3.SW.DIST", n100 > 0 && n101 > 0, "both 100 and 101 occur across phases (shared-tick effect visible)",
                  "both", $sformatf("100:%0d 101:%0d", n100, n101));
            phase_end();
        end
        // ------------------------------------------------------------------ P2
        if (phase_begin(2, "timer: preload 00:01.00, start phase 0..9 ms -> run->alarm interval table")) begin
            do_reset();
            set_sw(1, 0, 0, 0, 0);
            for (phi = 0; phi < 10; phi = phi + 1) begin
                preload_tm(0, 1, 0);
                press_at_phase(BL, phi * 1000, e1);
                @(posedge dut.w_tm_alarm);
                dt = t_tm_alarm - t_tm_run;
                check("F3.TM", dt > 0.99e9 && dt <= 1.0e9 + 10.001, $sformatf("1.00 s timer duration (phi=%0d ms)", phi),
                      "(990 ms, 1000 ms + 1 clk]", $sformatf("%0.6f ms", dt / 1.0e6));
                limit("F3.TM", $sformatf("phase=%0dms run->alarm = %0.6f ms (err %0.3f ms)", phi, dt / 1.0e6, (dt - 1.0e9) / 1.0e6));
                press(BU);  // 알람 끄기 (더하기 아님 → 0 유지)
            end
            phase_end();
        end
        // ------------------------------------------------------------------ P3
        if (phase_begin(3, "short taps 1.5/1.8/1.9/2.0 ms x sample phase 30/90/160/220 us -> recognized?")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 0);
            tap[0] = 1500; tap[1] = 1800; tap[2] = 1900; tap[3] = 2000;
            offs[0] = 30; offs[1] = 90; offs[2] = 160; offs[3] = 220;
            for (i = 0; i < 4; i = i + 1) begin
                row = "";
                for (j = 0; j < 4; j = j + 1) begin
                    p0 = pc[BU];
                    @(posedge dut.w_clk_4Khz);   // 샘플 시각
                    #(offs[j] * US + 5);
                    btnU = 1;
                    #(tap[i] * US);
                    btnU = 0;
                    #(5 * MS);
                    got  = pc[BU] - p0;
                    expn = (offs[j] + tap[i] >= 2000) ? 1 : 0;  // 8 번째 샘플이 누름 안에 들어오는가
                    check("F3.TAP", got == expn, $sformatf("tap %0d us at phase +%0d us", tap[i], offs[j]),
                          $sformatf("%0d", expn), $sformatf("%0d", got));
                    row = $sformatf("%s  +%0dus:%s", row, offs[j], got ? "HIT " : "miss");
                end
                limit("F3.TAP", $sformatf("tap %0d us ->%s", tap[i], row));
            end
            phase_end();
        end
        tb_finish();
    end
endmodule
