`timescale 1ns / 1ps
// =============================================================================
// tb_f1_com_skew — F1: FND com/data 위상 차이 → 고스팅 (verification.md §7.1 F1)
//   P0 sw15 = 0 기능 대표 확인 (주입기 bypass = 원본과 동일)
//   P1 TB 모델 sweep: com 지연 N = 0 / 500 / 3,000 / 12,500 clk 를 4 개 모니터로 동시에 측정 (원본 src 에서도 실행)
//      → 자리별 "틀린 숫자가 켜진 시간" 표. N = 0 은 PASS, N > 0 은 DEFECT
//   P2 RTL 주입기 (defect src 만): sw15 = 0 → 참조와 일치 / sw15 = 1 → DEFECT (고스트 시각) / 다시 0 → 회복
// =============================================================================
module tb_f1_com_skew;
`define TB_ID "F1"
`define TB_TIMEOUT_MS 2000
`include "tb_common.svh"

    // TB 쪽 지연 모델 (RTL 주입기 fault_com_skew 와 같은 동작) — 원본 src 의 com 에 붙인다
    wire [3:0] com_raw = dut.FND_CON.o_fnd_com;
    wire [3:0] c_n0, c_n500, c_n3000, c_n12500;
    com_skew_tbmodel #(.N(0))     M0    (.clk(clk), .rst(rst), .i_com(com_raw), .o_com(c_n0));
    com_skew_tbmodel #(.N(500))   M500  (.clk(clk), .rst(rst), .i_com(com_raw), .o_com(c_n500));
    com_skew_tbmodel #(.N(3000))  M3000 (.clk(clk), .rst(rst), .i_com(com_raw), .o_com(c_n3000));
    com_skew_tbmodel #(.N(12500)) M12500(.clk(clk), .rst(rst), .i_com(com_raw), .o_com(c_n12500));

`define SKEW_MON(NAME, COM) \
    fnd_monitor NAME (.com(COM), .font(fnd_font), .sel(dut.FND_CON.w_sel), .disp_mode(dut.w_disp_mode), \
                      .hour(dut.w_hour), .min(dut.w_min), .sec(dut.w_sec), .msec(dut.w_msec), .cursor(dut.w_cursor), \
                      .sw_set(sw_set), .sw_scr(sw_mode | sw_timer));
    `SKEW_MON(mon_n0, c_n0)
    `SKEW_MON(mon_n500, c_n500)
    `SKEW_MON(mon_n3000, c_n3000)
    `SKEW_MON(mon_n12500, c_n12500)

    function automatic string fch(input [7:0] f);
        case (f)
            8'hC0: fch = "0"; 8'hF9: fch = "1"; 8'hA4: fch = "2"; 8'hB0: fch = "3"; 8'h99: fch = "4";
            8'h92: fch = "5"; 8'h82: fch = "6"; 8'hF8: fch = "7"; 8'h80: fch = "8"; 8'h90: fch = "9";
            8'hFF: fch = "_"; 8'h7F: fch = "."; default: fch = "?";
        endcase
    endfunction

    // 자리별 고스트 표 (frames = 측정 프레임 수, 프레임 = 2 ms = 자리마다 숫자 슬롯 1 개)
    task automatic report(input string cid, input integer n, input integer nfr, input realtime tfirst,
                          input realtime g0, input realtime g1, input realtime g2, input realtime g3,
                          input [7:0] f0, input [7:0] f1, input [7:0] f2, input [7:0] f3);
        realtime tot;
        tot = g0 + g1 + g2 + g3;
        info(cid, $sformatf("N=%0d (%0.3f us skew): ghost per frame  AN0 %0.3f us '%s' | AN1 %0.3f us '%s' | AN2 %0.3f us '%s' | AN3 %0.3f us '%s'",
                            n, n * 0.01, g0 / nfr / 1000.0, fch(f0), g1 / nfr / 1000.0, fch(f1),
                            g2 / nfr / 1000.0, fch(f2), g3 / nfr / 1000.0, fch(f3)));
        if (n == 0)
            check(cid, tot == 0, "no skew -> no ghost digit", "0 us", $sformatf("%0.3f us", tot / 1000.0));
        else if (tot > 0)
            defect_at(cid, tfirst, $sformatf("first ghost at %t, N=%0d: AN0 shows '%s'(AN1 digit) for %0.3f us per slot (%0.1f %% duty), AN3 shows '%s'(AN0 digit) %0.3f us",
                                  tfirst, n, fch(f0), g0 / nfr / 1000.0, 100.0 * g0 / nfr / 250000.0, fch(f3), g3 / nfr / 1000.0),
                   "0 us ghost", $sformatf("%0.3f us/frame total", tot / nfr / 1000.0));
        else
            check(cid, 0, $sformatf("N=%0d skew should produce ghost", n), ">0 us", "0 us");
    endtask

    initial begin
        #1;
        // ------------------------------------------------------------------ P0
        if (phase_begin(0, "sw15 = 0: functional smoke (injector bypass == original)")) begin
            sw15 = 0;
            smoke_check();
            phase_end();
        end
        // ------------------------------------------------------------------ P1
        if (phase_begin(1, "TB-model sweep: com delay N = 0 / 500 / 3000 / 12500 clk, screen 12.34, 20 ms")) begin
            do_reset();
            set_sw(0, 0, 0, 1, 0);
            preload_watch(12, 34, 0, 0);
            @(posedge dut.FND_CON.w_sel[2]);  // 프레임 경계(슬롯 4)에서 시작
            mon_n0.clear_stats(); mon_n500.clear_stats(); mon_n3000.clear_stats(); mon_n12500.clear_stats();
            #(20 * MS);
            report("F1.N0", 0, 10, mon_n0.ghost_first_t, mon_n0.ghost_time[0], mon_n0.ghost_time[1], mon_n0.ghost_time[2], mon_n0.ghost_time[3],
                   mon_n0.ghost_font[0], mon_n0.ghost_font[1], mon_n0.ghost_font[2], mon_n0.ghost_font[3]);
            report("F1.N500", 500, 10, mon_n500.ghost_first_t, mon_n500.ghost_time[0], mon_n500.ghost_time[1], mon_n500.ghost_time[2], mon_n500.ghost_time[3],
                   mon_n500.ghost_font[0], mon_n500.ghost_font[1], mon_n500.ghost_font[2], mon_n500.ghost_font[3]);
            report("F1.N3000", 3000, 10, mon_n3000.ghost_first_t, mon_n3000.ghost_time[0], mon_n3000.ghost_time[1], mon_n3000.ghost_time[2], mon_n3000.ghost_time[3],
                   mon_n3000.ghost_font[0], mon_n3000.ghost_font[1], mon_n3000.ghost_font[2], mon_n3000.ghost_font[3]);
            report("F1.N12500", 12500, 10, mon_n12500.ghost_first_t, mon_n12500.ghost_time[0], mon_n12500.ghost_time[1], mon_n12500.ghost_time[2], mon_n12500.ghost_time[3],
                   mon_n12500.ghost_font[0], mon_n12500.ghost_font[1], mon_n12500.ghost_font[2], mon_n12500.ghost_font[3]);
            check("F1.DISP", mon.disp_str == "12.34", "pin FND (no injection) still reads 12.34", "\"12.34\"", {"\"", mon.disp_str, "\""});
            phase_end();
        end
        // ------------------------------------------------------------------ P2
`ifdef HAS_SW_FAULT
        if (phase_begin(2, "RTL injector fault_com_skew (N=12500) via sw15: off -> on -> off, 20 ms each")) begin
            do_reset();
            set_sw(0, 0, 0, 1, 0);
            preload_watch(12, 34, 0, 0);
            sw15 = 0;
            mm_seen = mon.mm_count;
            #(20 * MS);
            check("F1.OFF", mon.mm_count == mm_seen, "sw15=0: pin FND == reference", "0 mismatch",
                  $sformatf("%0d", mon.mm_count - mm_seen));
            @(posedge dut.FND_CON.w_sel[2]);
            @(negedge clk);
            sw15 = 1;
            mm_is_defect = 1;
            info("F1.ON", "sw15 -> 1 : com skew 125 us injected at the pins");
            mon.clear_stats();
            #(20 * MS);
            report("F1.ON", 12500, 10, mon.ghost_first_t, mon.ghost_time[0], mon.ghost_time[1], mon.ghost_time[2], mon.ghost_time[3],
                   mon.ghost_font[0], mon.ghost_font[1], mon.ghost_font[2], mon.ghost_font[3]);
            @(negedge clk);
            sw15 = 0;
            #(300 * US);
            mm_is_defect = 0;
            mm_seen = mon.mm_count;
            #(20 * MS);
            check("F1.OFF2", mon.mm_count == mm_seen, "sw15 back to 0: pin FND == reference again", "0 mismatch",
                  $sformatf("%0d", mon.mm_count - mm_seen));
            phase_end();
        end
`else
        phase_skip(2, "RTL injector via sw15", "original src has no fault_com_skew (run with --src defect_1_fnd_com_skew/src)");
`endif
        tb_finish();
    end
endmodule

// TB 모델: RTL fault_com_skew 와 같은 동작 (sw_fault 항상 1)
module com_skew_tbmodel #(
    parameter N = 0
) (
    input            clk,
    input            rst,
    input      [3:0] i_com,
    output     [3:0] o_com
);
    reg [3:0]  com_d;
    reg [15:0] cnt;
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            com_d <= 4'b1110;
            cnt   <= 16'd0;
        end else if (i_com != com_d) begin
            if (cnt >= N - 1) begin
                com_d <= i_com;
                cnt   <= 16'd0;
            end else cnt <= cnt + 16'd1;
        end else cnt <= 16'd0;
    end
    assign o_com = (N > 0) ? com_d : i_com;
endmodule
