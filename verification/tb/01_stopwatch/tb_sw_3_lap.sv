`timescale 1ns / 1ps
// =============================================================================
// tb_sw_3_lap — STOPWATCH (jonghyuk): 랩 (verification.md §3.4)
//   P1 RUN 중 D → 표시 고정 + 내부 계속 + led7 · P2 D 다시 → 실시간 · P3 랩 중 RUN 에서 L 무시 → STOP → L → 해제 + 0
//   P4 STOP 상태 랩 · P5 프리로드 00:00:59.98 직후 랩 → 저장 59.98, 내부는 1:00 넘어감 · P6 FND / 점멸 없음 (SC7)
// =============================================================================
module tb_sw_3_lap;
`define TB_ID "SW3"
`define TB_TIMEOUT_MS 3000
`include "tb_common.svh"

    initial begin
        string d1;
        longint c1;
        integer e0;
        #1;
        // ------------------------------------------------------------------ P1
        if (phase_begin(1, "RUN: D -> display frozen, internal keeps counting, led7 (SB4)")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            #(200 * MS);
            press(BD);
            d1 = sw_now();
            c1 = sw_count();
            check("SB4", dut.w_lap_active == 1 && led[7] == 1, "lap active, led7 on", "1 1",
                  $sformatf("%b %b", dut.w_lap_active, led[7]));
            #(100 * MS);
            check("SB4", sw_now() == d1, "display frozen for 100 ms", d1, sw_now());
            check("SB4", sw_count() >= c1 + 9, "internal counter kept running", $sformatf(">=%0d", c1 + 9), $sformatf("%0d", sw_count()));
            phase_end();
        end
        // ------------------------------------------------------------------ P2
        if (phase_begin(2, "D again -> live display (SB4)")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            #(100 * MS);
            press(BD);
            #(50 * MS);
            press(BD);
            check("SB4", dut.w_lap_active == 0 && led[7] == 0, "lap off, led7 off", "0 0", $sformatf("%b %b", dut.w_lap_active, led[7]));
            check("SB4", sw_now() == sw_raw(), "display == internal counter", sw_raw(), sw_now());
            phase_end();
        end
        // ------------------------------------------------------------------ P3
        if (phase_begin(3, "lap during RUN: L ignored (lap kept) -> STOP -> L -> lap off + 0 (SB5, SC4)")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            #(100 * MS);
            press(BD);
            d1 = sw_now();
            press(BL);
            check("SB5", dut.w_lap_active == 1 && led[7] == 1 && sw_now() == d1, "L during RUN: lap kept, display frozen",
                  {"lap ", d1}, $sformatf("lap=%b %s", dut.w_lap_active, sw_now()));
            check("SB5", sw_count() > 0 && dut.w_run_stop == 1, "L during RUN: internal not cleared", ">0 RUN",
                  $sformatf("%0d run=%b", sw_count(), dut.w_run_stop));
            press(BR);
            press(BL);
            check("SC4", dut.w_lap_active == 0 && sw_count() == 0 && sw_now() == "00:00:00.00", "STOP + L -> lap off, 0",
                  "lap=0 00:00:00.00", $sformatf("lap=%b %s", dut.w_lap_active, sw_now()));
            phase_end();
        end
        // ------------------------------------------------------------------ P4
        if (phase_begin(4, "lap in STOP, then RUN: display stays at lap value (SB4)")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            #(120 * MS);
            press(BR);
            d1 = sw_now();
            press(BD);
            check("SB4", dut.w_lap_active == 1 && sw_now() == d1, "lap in STOP holds current value", d1, sw_now());
            press(BR);
            #(100 * MS);
            check("SB4", sw_now() == d1 && sw_raw() != d1, "RUN after lap: display frozen, internal moves", d1,
                  $sformatf("disp %s raw %s", sw_now(), sw_raw()));
            phase_end();
        end
        // ------------------------------------------------------------------ P5
        if (phase_begin(5, "preload 00:00:59.98 while RUN, lap right away -> saved 59.98, internal passes 1:00 (SB4)")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);
            press(BR);
            preload_sw(0, 0, 59, 98);
            press(BD);  // 펄스는 누름 후 ~2 ms → 값이 59.98 인 10 ms 안
            #(50 * MS);
            check("SB4", sw_now() == "00:00:59.98", "lap saved 59.98", "00:00:59.98", sw_now());
            check("SB4", dut.U_STOPWATCH_DATAPATH.w_min == 1, "internal passed 1:00", "00:01:xx", sw_raw());
            phase_end();
        end
        // ------------------------------------------------------------------ P6
        if (phase_begin(6, "FND during lap: SS.CC shows lap value, sw2=1 does not blink on stopwatch screen (SC7)")) begin
            do_reset();
            set_sw(0, 0, 1, 0, 1);  // sw2=1 이어도 스톱워치 화면
            press(BR);
            preload_sw(0, 0, 12, 34);
            press(BD);
            check_disp("SC7", $sformatf("%02d.%02d", dut.w_sw_sec, dut.w_sw_msec), "FND SS.CC = lap value");
            set_sw(0, 0, 1, 1, 1);
            e0 = mon.mm_count;
            #(200 * MS);
            check("SC7", mon.mm_count == e0, "HH.MM with sw2=1 on stopwatch screen == reference (no blink) 200 ms",
                  "0 mismatch", $sformatf("%0d", mon.mm_count - e0));
            check_disp("SC7", "00.00", "HH.MM (00h 00m), no blank digit");
            phase_end();
        end
        tb_finish();
    end
endmodule
