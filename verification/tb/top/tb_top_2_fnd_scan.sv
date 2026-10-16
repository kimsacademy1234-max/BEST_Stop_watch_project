`timescale 1ns / 1ps
// =============================================================================
// tb_top_2_fnd_scan — 공통: FND 스캔 · 참조 모델 (verification.md §5.2)
//   fnd_monitor 가 전 구간에서 출력 == 참조 를 상시 비교 (불일치 구간마다 FAIL + 시각)
//   P1 com 순서 / 슬롯 폭 250 us · P2 시계 시.분 "12.00" → 프리로드 12:34 "12.34" (+설정 점멸 1 s)
//   P3 초.1/100 화면 DP(AN2) = msec<50 · P4 스톱워치 / 타이머 화면 참조 비교
// =============================================================================
module tb_top_2_fnd_scan;
`define TB_ID "TOP2"
`define TB_TIMEOUT_MS 6000
`include "tb_common.svh"

    integer mm0;
    // 일정 시간 동안 참조 비교 → 불일치 0 이어야 함
    task automatic ref_window(input string cid, input longint dur, input string what);
        integer e0, o0;
        e0 = mon.mm_count;
        o0 = mon.onehot_err;
        #(dur);
        check(cid, mon.mm_count == e0, $sformatf("%s : FND == reference for %0.1f ms", what, dur / 1.0e6), "0 mismatch",
              $sformatf("%0d mismatch", mon.mm_count - e0));
        check(cid, mon.onehot_err == o0, $sformatf("%s : fnd_com one-hot", what), "0", $sformatf("%0d", mon.onehot_err - o0));
    endtask

    initial begin
        integer i, n_bad_order, n_bad_width;
        reg [3:0] prev, nxt;
        realtime tp, w;
        #1;
        // ------------------------------------------------------------------ P1
        if (phase_begin(1, "com order AN0->AN1->AN2->AN3, slot width 250,000 ns (20 ms)")) begin
            do_reset();
            n_bad_order = 0;
            n_bad_width = 0;
            @(fnd_com);
            prev = fnd_com;
            tp = $realtime;
            for (i = 0; i < 80; i = i + 1) begin
                @(fnd_com);
                #0;
                w = $realtime - tp;
                nxt = {prev[2:0], prev[3]};  // 1110 -> 1101 -> 1011 -> 0111 -> 1110
                if (fnd_com !== nxt) begin
                    n_bad_order = n_bad_order + 1;
                    check("ORDER", 0, "com sequence", $sformatf("%b", nxt), $sformatf("%b", fnd_com));
                end
                if (w < 249999.999 || w > 250000.001) begin
                    n_bad_width = n_bad_width + 1;
                    check("WIDTH", 0, $sformatf("slot width of com=%b", prev), "250000.000 ns", $sformatf("%0.3f ns", w));
                end
                prev = fnd_com;
                tp = $realtime;
            end
            check("ORDER", n_bad_order == 0, "80 com changes in rotation order", "0 bad", $sformatf("%0d bad", n_bad_order));
            check("WIDTH", n_bad_width == 0, "80 slots exactly 250 us", "0 bad", $sformatf("%0d bad", n_bad_width));
            phase_end();
        end
        // ------------------------------------------------------------------ P2
        if (phase_begin(2, "watch HH.MM: reset 12.00, preload 12:34 -> 12.34, set-mode blink vs reference 1 s")) begin
            do_reset();
            set_sw(0, 0, 0, 1, 0);
            check_disp("P2.RST", "12.00", "watch HH.MM after reset");
            preload_watch(12, 34, 0, 0);
            check_disp("P2.1234", "12.34", "watch HH.MM after preload 12:34 (all digits differ)");
            ref_window("P2.REF", 20 * MS, "watch HH.MM");
            set_sw(0, 0, 1, 1, 0);  // 설정 모드 → cursor 0 점멸
            ref_window("P2.BLINK", 1000 * MS, "watch HH.MM set-mode blink (cursor 0)");
            set_sw(0, 0, 0, 1, 0);
            phase_end();
        end
        // ------------------------------------------------------------------ P3
        if (phase_begin(3, "watch SS.CC: DP(AN2) on while msec < 50, 1 s")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 0);
            tick_sync();
            mon.clear_stats();
            ref_window("P3.REF", 1000 * MS, "watch SS.CC incl. DP slot");
            check("P3.DP", (mon.dp_frames >= mon.frames / 2 - 3) && (mon.dp_frames <= mon.frames / 2 + 3),
                  "DP on in ~50 % of frames (msec<50)", $sformatf("%0d of %0d", mon.frames / 2, mon.frames),
                  $sformatf("%0d of %0d", mon.dp_frames, mon.frames));
            phase_end();
        end
        // ------------------------------------------------------------------ P4
        if (phase_begin(4, "stopwatch / timer screens vs reference, 20 ms each")) begin
            do_reset();
            set_sw(0, 0, 0, 0, 1);  // 스톱워치 SS.CC
            preload_sw(0, 0, 34, 56);
            check_disp("P4.SW", "34.56", "stopwatch SS.CC preload 00:00:34.56 (STOP)");
            ref_window("P4.SW", 20 * MS, "stopwatch SS.CC");
            set_sw(0, 0, 0, 1, 1);  // 스톱워치 HH.MM
            check_disp("P4.SW", "00.00", "stopwatch HH.MM");
            ref_window("P4.SW", 20 * MS, "stopwatch HH.MM");
            set_sw(1, 0, 0, 0, 0);  // 타이머 (sw1 무관 → 분.초)
            preload_tm(12, 34, 0);
            check_disp("P4.TM", "12.34", "timer MM.SS preload 12:34");
            ref_window("P4.TM", 20 * MS, "timer MM.SS");
            set_sw(1, 0, 1, 1, 1);  // 타이머 + sw2·sw1·sw0 → 점멸 없음, 타이머 우선
            ref_window("P4.TM", 20 * MS, "timer with sw0/sw1/sw2 = 1 (no blink)");
            phase_end();
        end
        tb_finish();
    end
endmodule
