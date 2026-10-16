`timescale 1ns / 1ps
// =============================================================================
// tb_wt_3_display_12h — WATCH (ahnsung): 12/24 표시 · FND · 점멸 · LED (verification.md §2.4)
//   P1 hour 0~23 × sw3 0/1 → dut.w_hour, led15 (48 점) (WB4, WC9)
//   P2 FND 문자열 12:34 / 24h 13:05 / 12h 13:05 · P3 설정 점멸 cursor 0/1/2 (WC8) · P4 LED 표(§1.5)
// =============================================================================
module tb_wt_3_display_12h;
`define TB_ID "WT3"
`define TB_TIMEOUT_MS 8000
`include "tb_common.svh"

    // 점멸: msec 55 근처(빈칸) / 05 근처(숫자) 의 화면 문자열
    task automatic blink_case(input integer cur, input string on_s, input string off_s);
        integer e0;
        e0 = mon.mm_count;
        wait (dut.w_wt_msec == 52);
        #(5 * MS);
        check("WC8", mon.disp_str == off_s, $sformatf("cursor %0d blank while msec>=50", cur), {"\"", off_s, "\""}, {"\"", mon.disp_str, "\""});
        wait (dut.w_wt_msec == 2);
        #(5 * MS);
        check("WC8", mon.disp_str == on_s, $sformatf("cursor %0d digit shown while msec<50", cur), {"\"", on_s, "\""}, {"\"", mon.disp_str, "\""});
        #(1000 * MS - 20 * MS);
        check("WC8", mon.mm_count == e0, $sformatf("cursor %0d: 1 s of blink == reference", cur), "0 mismatch",
              $sformatf("%0d", mon.mm_count - e0));
    endtask

    initial begin
        integer h, h24, exp_h, exp_pm, sw1, nbad;
        reg [15:0] exp_led;
        #1;
        // ------------------------------------------------------------------ P1
        if (phase_begin(1, "hour 0..23 x sw3 0/1 -> displayed hour, led15 (48 points)")) begin
            do_reset();
            nbad = 0;
            info("PRELOAD", "dut.U_WATCH_DATAPATH.U_HOUR_COUNTER.counter_reg = 0..23 sweep (min/sec untouched)");
            for (h24 = 0; h24 < 2; h24 = h24 + 1) begin
                set_sw(0, h24, 0, 1, 0);
                for (h = 0; h < 24; h = h + 1) begin
                    @(negedge clk);
                    dut.U_WATCH_DATAPATH.U_HOUR_COUNTER.counter_reg = h;
                    #(US);
                    if (h24) exp_h = h;
                    else exp_h = (h == 0) ? 12 : (h > 12) ? h - 12 : h;
                    exp_pm = (!h24) && (h >= 12);
                    if (dut.w_hour != exp_h || led[15] != exp_pm) nbad = nbad + 1;
                    check("WB4", dut.w_hour == exp_h, $sformatf("%s hour %0d displayed", h24 ? "24h" : "12h", h),
                          $sformatf("%0d", exp_h), $sformatf("%0d", dut.w_hour));
                    check("WC9", led[15] == exp_pm, $sformatf("%s hour %0d led15(PM)", h24 ? "24h" : "12h", h),
                          $sformatf("%0d", exp_pm), $sformatf("%0d", led[15]));
                end
            end
            info("WB4", $sformatf("48-point 12/24 table: %0d mismatches (0->12 AM, 12->12 PM, 13->1 PM, 23->11 PM)", nbad));
            phase_end();
        end
        // ------------------------------------------------------------------ P2
        if (phase_begin(2, "FND strings: 12:34 -> 12.34, 24h 13:05 -> 13.05, 12h 13:05 -> 01.05")) begin
            do_reset();
            set_sw(0, 0, 0, 1, 0);
            preload_watch(12, 34, 0, 0);
            check_disp("WB4", "12.34", "12h 12:34");
            preload_watch(13, 5, 0, 0);
            set_sw(0, 1, 0, 1, 0);
            check_disp("WB4", "13.05", "24h 13:05");
            set_sw(0, 0, 0, 1, 0);
            check_disp("WB4", "01.05", "12h 13:05 -> 1 PM");
            check("WC9", led[15] == 1, "13:05 12h -> led15 on", "1", $sformatf("%b", led[15]));
            phase_end();
        end
        // ------------------------------------------------------------------ P3
        if (phase_begin(3, "set-mode blink: cursor 0/1/2 blank while msec >= 50, 1 s each (WC8)")) begin
            do_reset();
            set_sw(0, 0, 0, 1, 0);
            preload_watch(12, 34, 0, 0);
            set_sw(0, 0, 1, 1, 0);
            blink_case(0, "12.34", "12.3_");
            press(BL);
            blink_case(1, "12.34", "12._4");
            press(BL);
            blink_case(2, "12.34", "1_.34");
            set_sw(0, 0, 0, 1, 0);
            check_disp("WC8", "12.34", "sw2 off -> no blink");
            phase_end();
        end
        // ------------------------------------------------------------------ P4
        if (phase_begin(4, "LED table, watch screen: sw1 x sw3 x AM/PM")) begin
            do_reset();
            for (sw1 = 0; sw1 < 2; sw1 = sw1 + 1)
                for (h24 = 0; h24 < 2; h24 = h24 + 1)
                    for (h = 9; h <= 21; h = h + 12) begin
                        set_sw(0, h24, 0, sw1, 0);
                        @(negedge clk);
                        dut.U_WATCH_DATAPATH.U_HOUR_COUNTER.counter_reg = h;
                        #(US);
                        exp_led = 16'h0001;
                        exp_led[2] = sw1;
                        exp_led[3] = !sw1;
                        exp_led[15] = (!h24) && (h >= 12);
                        check("LED", led == exp_led, $sformatf("watch screen sw1=%0d sw3=%0d hour=%0d", sw1, h24, h),
                              $sformatf("%h", exp_led), $sformatf("%h", led));
                    end
            phase_end();
        end
        tb_finish();
    end
endmodule
