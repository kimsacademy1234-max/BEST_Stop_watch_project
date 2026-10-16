`timescale 1ns / 1ps
// =============================================================================
// tb_f2_chatter — F2: 스위치 채터링 / 노이즈 (verification.md §7.1 F2)
//   디바운서 비대칭: 눌림 = 8 샘플 연속 1, 뗌 = 0 샘플 1 개 → 스파이크(a)는 견디고, 누른 중 끊김(b)에는 약하다
//   P0 sw15 = 0 기능 대표 확인
//   P1 (TB 자극) 안 누름 + 스파이크 열 200 ms → 펄스 0 (PASS: 견고)
//   P2 (TB 자극) 바운스 패턴 → 펄스 1 (PASS)
//   P3 (TB 자극) 누름 100 ms + 300 us 끊김 ×4 → 펄스 5 → DEFECT (추가 입력 시각), 시계 분 +5 / 타이머 +50 초
//   P4 (TB 자극) 끊김 폭 50·100·200·250·300 us × 샘플 위상 4 개 → 두 번 입력 되는 경계 표
//   P5 (RTL 주입기, defect src 만) sw15 = 1: 안 누름 200 ms → 0, U 100 ms 누름 → 연타 DEFECT, sw15 = 0 → 1 회
// =============================================================================
module tb_f2_chatter;
`define TB_ID "F2"
`define TB_TIMEOUT_MS 3000
`include "tb_common.svh"

    // 주입기와 같은 스파이크 열: 7 ms 간격, 폭 1 us · 50 us · 500 us · 1.5 ms 순환
    task automatic spike_train(input integer b, input longint dur);
        longint w[0:3];
        longint el;
        integer k;
        w[0] = 1 * US; w[1] = 50 * US; w[2] = 500 * US; w[3] = 1500 * US;
        el = 0;
        k = 0;
        @(negedge clk);
        while (el + 7 * MS <= dur) begin
            set_btn(b, 1); #(w[k]);
            set_btn(b, 0); #(7 * MS - w[k]);
            el = el + 7 * MS;
            k = (k + 1) % 4;
        end
    endtask

    // 누름 total 동안 20 ms 마다 300 us 끊김 (n 회)
    task automatic held_with_dropouts(input integer b, input integer n, input string cid);
        integer p0, i;
        p0 = pc[b];
        @(negedge clk);
        set_btn(b, 1); #(10 * MS);
        for (i = 0; i < n; i = i + 1) begin
            set_btn(b, 0); #(300 * US);
            set_btn(b, 1); #(19700 * US);
            if (pc[b] - p0 > i + 1)
                defect(cid, $sformatf("%s extra pulse #%0d at %t (300 us dropout while held = new press)", bname(b), i + 1, last_pt),
                       "1 pulse per press", $sformatf("%0d pulses", pc[b] - p0));
        end
        set_btn(b, 0); #(5 * MS);
    endtask

    initial begin
        integer p0, m0, i, j, got, expn, s0;
        longint offs[0:3];
        longint wid[0:4];
        string row;
        #1;
        // ------------------------------------------------------------------ P0
        if (phase_begin(0, "sw15 = 0: functional smoke (injector bypass == original)")) begin
            sw15 = 0;
            smoke_check();
            phase_end();
        end
        // ------------------------------------------------------------------ P1
        if (phase_begin(1, "TB stim: spike noise on btnU pin for 200 ms while not pressed -> 0 pulses")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 0);
            p0 = pc[BU];
            m0 = dut.w_wt_min;
            spike_train(BU, 200 * MS);
            check("F2.SPIKE", pc[BU] == p0 && dut.w_wt_min == m0, "spikes 1us/50us/500us/1.5ms (< 1.75 ms) all rejected",
                  "0 pulses", $sformatf("%0d pulses, min %0d->%0d", pc[BU] - p0, m0, dut.w_wt_min));
            phase_end();
        end
        // ------------------------------------------------------------------ P2
        if (phase_begin(2, "TB stim: bounce pattern -> 1 pulse")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 0);
            p0 = pc[BU];
            press_bounce(BU);
            check("F2.BOUNCE", pc[BU] - p0 == 1, "bounce pattern -> exactly 1 pulse", "1", $sformatf("%0d", pc[BU] - p0));
            phase_end();
        end
        // ------------------------------------------------------------------ P3
        if (phase_begin(3, "TB stim: held 100 ms with 4 x 300 us dropouts -> 5 pulses (watch min +5, timer +50 s)")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 0);
            p0 = pc[BU];
            m0 = dut.w_wt_min;
            held_with_dropouts(BU, 4, "F2.WATCH");
            info("F2.WATCH", $sformatf("one long press -> %0d pulses, watch min %0d -> %0d", pc[BU] - p0, m0, dut.w_wt_min));
            check("F2.WATCH", pc[BU] - p0 == 5 && dut.w_wt_min == (m0 + 5) % 60, "expected effect of 4 dropouts",
                  "5 pulses min+5", $sformatf("%0d pulses min+%0d", pc[BU] - p0, (dut.w_wt_min - m0 + 60) % 60));
            set_sw(1, 0, 0, 0, 0);  // 타이머 화면
            p0 = pc[BU];
            held_with_dropouts(BU, 4, "F2.TIMER");
            info("F2.TIMER", $sformatf("one long press of U on timer -> %0d pulses, timer = %s", pc[BU] - p0, tm_now()));
            check("F2.TIMER", tm_now() == "00:50.00", "timer +10 s x5 = 00:50 (user wanted 00:10)", "00:50.00", tm_now());
            phase_end();
        end
        // ------------------------------------------------------------------ P4
        if (phase_begin(4, "TB stim: dropout width x sample phase -> 2nd press boundary table")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 0);
            offs[0] = 30; offs[1] = 90; offs[2] = 160; offs[3] = 220;   // 마지막 샘플 뒤 끊김 시작(us)
            wid[0] = 50; wid[1] = 100; wid[2] = 200; wid[3] = 250; wid[4] = 300;
            for (i = 0; i < 5; i = i + 1) begin
                row = "";
                for (j = 0; j < 4; j = j + 1) begin
                    p0 = pc[BU];
                    @(negedge clk);
                    btnU = 1;
                    #(10 * MS);
                    @(posedge dut.w_clk_4Khz);                // 샘플 시각
                    #(offs[j] * US + 5);
                    btnU = 0;
                    #(wid[i] * US);
                    btnU = 1;
                    #(5 * MS);
                    btnU = 0;
                    #(5 * MS);
                    got  = pc[BU] - p0;
                    expn = (offs[j] + wid[i] > 250) ? 2 : 1;  // 다음 샘플(250 us)이 끊김 안에 들어오면 2
                    check("F2.SWEEP", got == expn, $sformatf("dropout %0d us at phase +%0d us", wid[i], offs[j]),
                          $sformatf("%0d", expn), $sformatf("%0d", got));
                    if (wid[i] >= 250)
                        check("F2.SWEEP", got == 2, $sformatf("dropout >= 250 us always a 2nd press (w=%0d)", wid[i]), "2", $sformatf("%0d", got));
                    row = $sformatf("%s  +%0dus:%0d", row, offs[j], got);
                end
                limit("F2.TABLE", $sformatf("dropout %3d us -> pulses per phase%s", wid[i], row));
            end
            phase_end();
        end
        // ------------------------------------------------------------------ P5
`ifdef HAS_SW_FAULT
        if (phase_begin(5, "RTL injector fault_chatter via sw15")) begin
            do_reset();
            set_sw(0, 0, 1, 1, 0);
            @(negedge clk);
            sw15 = 1;
            info("F2.INJ", "sw15 -> 1 : spikes on idle buttons, 300 us dropouts every 20 ms on held buttons");
            s0 = pc[0] + pc[1] + pc[2] + pc[3];
            m0 = dut.w_wt_min;
            #(200 * MS);
            check("F2.INJ.IDLE", pc[0] + pc[1] + pc[2] + pc[3] == s0 && dut.w_wt_min == m0,
                  "sw15=1, no press for 200 ms: injected spikes rejected", "0 pulses",
                  $sformatf("%0d pulses", pc[0] + pc[1] + pc[2] + pc[3] - s0));
            p0 = pc[BU];
            m0 = dut.w_wt_min;
            got = 1;
            @(negedge clk);
            btnU = 1;
            for (i = 0; i < 10; i = i + 1) begin
                #(10 * MS);
                if (pc[BU] - p0 > 1 && pc[BU] - p0 != got)
                    defect("F2.INJ.HOLD", $sformatf("btnU held once, extra pulse #%0d at %t (injected dropout)", pc[BU] - p0 - 1, last_pt),
                           "1 pulse", $sformatf("%0d pulses", pc[BU] - p0));
                got = pc[BU] - p0;
            end
            btnU = 0;
            #(5 * MS);
            info("F2.INJ.HOLD", $sformatf("sw15=1, U held 100 ms -> %0d pulses, watch min %0d -> %0d (auto-repeat by chatter)",
                                          pc[BU] - p0, m0, dut.w_wt_min));
            check("F2.INJ.HOLD", pc[BU] - p0 >= 2, "injector makes a held button chatter", ">=2", $sformatf("%0d", pc[BU] - p0));
            @(negedge clk);
            sw15 = 0;
            p0 = pc[BU];
            press_ns(BU, 100 * MS, 5 * MS);
            check("F2.INJ.OFF", pc[BU] - p0 == 1, "sw15=0: same 100 ms press -> 1 pulse", "1", $sformatf("%0d", pc[BU] - p0));
            phase_end();
        end
`else
        phase_skip(5, "RTL injector via sw15", "original src has no fault_chatter (run with --src defect_2_switch_chatter/src)");
`endif
        tb_finish();
    end
endmodule
