`timescale 1ns / 1ps
// =============================================================================
// tb_f4_reset_glitch — F4: 리셋 라인 EMI 글리치 (verification.md §7.1 F4)
//   btnC(rst) 는 비동기 리셋, 필터 · 동기화 없음 → 수 ns 글리치에도 전체 초기화
//   P0 sw15 = 0 기능 대표 확인
//   P1 (TB 자극) rst 핀에 클럭과 비정렬 글리치 0.5 / 1 / 5 / 10 ns → 매번 상태(시계 09:41 · 스톱워치 RUN 0.30 · 타이머 RUN 00:50) 소실 = DEFECT
//   P2 (RTL 주입기, defect src 만) sw15 0→1 → 내부 리셋 1 클럭 펄스 → 같은 소실 DEFECT, LED 표시 없음
// =============================================================================
module tb_f4_reset_glitch;
`define TB_ID "F4"
`define TB_TIMEOUT_MS 3000
`include "tb_common.svh"

    // 감시자: 의도된 리셋 시퀀스(do_reset) 밖에서 rst 가 1 이 됨
    realtime t_glitch = -1;
    always @(posedge rst) if (started && !in_reset_seq) t_glitch = $realtime;

    string b_wt, b_sw, b_tm;
    // 시계 09:41 · 스톱워치 RUN 0.30 s · 타이머 RUN 00:50 준비 → 시계 화면
    task automatic prepare();
        do_reset();
        set_sw(0, 0, 0, 1, 0);
        preload_watch(9, 41, 0, 0);
        set_sw(0, 0, 0, 0, 1);
        preload_sw(0, 0, 0, 30);
        press(BR);
        set_sw(1, 0, 0, 0, 0);
        preload_tm(0, 50, 0);
        press(BL);
        set_sw(0, 0, 0, 1, 0);
        check("PREP", dut.w_run_stop == 1 && dut.w_tm_run == 1 && dut.w_wt_hour == 9 && dut.w_wt_min == 41,
              "state prepared: watch 09:41, stopwatch RUN, timer RUN", "09:41 RUN RUN",
              $sformatf("%s sw.run=%b tm.run=%b", wt_now(), dut.w_run_stop, dut.w_tm_run));
        b_wt = wt_now();
        b_sw = sw_raw();
        b_tm = tm_now();
    endtask

    // 글리치 뒤 상태 비교 → 전부 리셋값이면 DEFECT
    task automatic judge(input string cid, input realtime tg, input string how);
        bit lost;
        #(US);
        lost = (dut.w_wt_hour == 12 && dut.w_wt_min == 0) && (sw_count() == 0) && (dut.w_run_stop == 0) &&
               (dut.w_tm_run == 0) && (dut.w_tm_min == 0) && (dut.w_tm_sec == 0);
        if (lost)
            defect_at(cid, tg, $sformatf("unexpected reset glitch %s at %t: watch %s->%s, sw %s->%s (RUN->STOP), timer %s->%s (alarm lost)",
                                         how, tg, b_wt, wt_now(), b_sw, sw_raw(), b_tm, tm_now()),
                      "state kept", "all reset");
        else
            info(cid, $sformatf("glitch %s at %t did NOT reset everything: watch %s sw %s run=%b timer %s run=%b",
                                how, tg, wt_now(), sw_raw(), dut.w_run_stop, tm_now(), dut.w_tm_run));
        check(cid, led == 16'h8005, "LED after glitch = normal watch screen (no fault indication, 12:00 PM)",
              "8005", $sformatf("%h", led));
    endtask

    initial begin
        realtime w[0:3];
        realtime tg;
        integer i;
        #1;
        w[0] = 0.5; w[1] = 1.0; w[2] = 5.0; w[3] = 10.0;
        // ------------------------------------------------------------------ P0
        if (phase_begin(0, "sw15 = 0: functional smoke (injector bypass == original)")) begin
            sw15 = 0;
            smoke_check();
            phase_end();
        end
        // ------------------------------------------------------------------ P1
        if (phase_begin(1, "TB stim: rst pin glitch 0.5 / 1 / 5 / 10 ns, not aligned to clk")) begin
            for (i = 0; i < 4; i = i + 1) begin
                prepare();
                t_glitch = -1;
                @(negedge clk);
                #(2.3);                 // 클럭 엣지와 비정렬
                rst = 1'b1;
                #(w[i]);
                rst = 1'b0;
                tg = t_glitch;
                check("F4.MON", tg >= 0, "glitch monitor saw rst outside do_reset()", "seen", (tg >= 0) ? "seen" : "missed");
                judge($sformatf("F4.W%0d", i), tg, $sformatf("width=%0.1fns", w[i]));
            end
            phase_end();
        end
        // ------------------------------------------------------------------ P2
`ifdef HAS_SW_FAULT
        if (phase_begin(2, "RTL injector fault_rst_glitch: sw15 0->1 -> 1-clk internal reset")) begin
            prepare();
            #(5 * MS);
            check("F4.INJ.OFF", dut.w_wt_hour == 9 && dut.w_run_stop == 1 && dut.w_tm_run == 1,
                  "sw15=0: nothing happens", "kept", $sformatf("%s run=%b tm.run=%b", wt_now(), dut.w_run_stop, dut.w_tm_run));
            b_wt = wt_now(); b_sw = sw_raw(); b_tm = tm_now();
            @(negedge clk);
            sw15 = 1;
            @(posedge dut.w_rst_inj);
            tg = $realtime;
            @(negedge dut.w_rst_inj);
            check("F4.INJ.PW", ($realtime - tg) > 9.999 && ($realtime - tg) < 10.001, "injected internal reset pulse = 1 clk",
                  "10.000 ns", $sformatf("%0.3f ns", $realtime - tg));
            judge("F4.INJ", tg, "(sw15 rising edge, 1 clk)");
            #(50 * MS);
            check("F4.INJ.HOLD", dut.w_wt_msec != 0 || dut.w_wt_sec != 0, "sw15 held at 1: only one pulse, clock runs again",
                  "running", wt_now());
            @(negedge clk);
            sw15 = 0;
            phase_end();
        end
`else
        phase_skip(2, "RTL injector via sw15", "original src has no fault_rst_glitch (run with --src defect_4_reset_glitch/src)");
`endif
        tb_finish();
    end
endmodule
