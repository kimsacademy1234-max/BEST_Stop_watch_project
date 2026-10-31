`timescale 1ns / 1ps
// E1. 초기값 · 1 초 — P1 · 2 개   (tb_scenario.md 4 장 E1)
// 리셋 직후 시계 = 12:00:00.00 (24 h 값), LD15 1 → 초가 1 이 되는 시각 = w_rst 해제 + 1.000 s (± 5 clk)
module tb_E1;
    `include "tb_env.svh"

    localparam longint T_1S      = 1 * SEC;
    localparam longint TOL_LOGIC = 5 * CLK_NS;
    localparam [23:0]  V_INIT    = {5'd12, 6'd0, 6'd0, 7'd0};   // 12:00:00.00
    localparam [23:0]  V_1S      = {5'd12, 6'd0, 6'd1, 7'd0};   // 12:00:01.00

    time    t_rel = 0, t1;
    longint d;
    bit [23:0] v0, v1;

    always @(negedge dut.w_rst) t_rel = $time;     // 리셋 해제 (w_rst 1 → 0) 시각

    initial begin
        env_start("tb_E1", 2 * SEC);
        v0 = dut.w_wt_time;
        check("E1-01", (v0 == V_INIT) && (led[15] == 1'b1),
              $sformatf("리셋 직후 기대 12:00:00.00 · LD15 1 / 실제 %02d:%02d:%02d.%02d, LD15 %0d (led=%h)",
                        v0[23:19], v0[18:13], v0[12:7], v0[6:0], led[15], led));

        wait (dut.w_wt_time[12:7] == 6'd1);
        t1 = $time;
        v1 = dut.w_wt_time;
        d  = longint'(t1) - longint'(t_rel) - T_1S;
        check("E1-02", (v1 == V_1S) && (d >= -TOL_LOGIC) && (d <= TOL_LOGIC),
              $sformatf("1 초 기대 12:00:01.00 @ 해제 + 1.000 s ± %0d ns / 실제 %02d:%02d:%02d.%02d @ 해제 + %0d ns (오차 %0d ns, 해제 %0d ns)",
                        TOL_LOGIC, v1[23:19], v1[18:13], v1[12:7], v1[6:0], t1 - t_rel, d, t_rel));
        env_finish();
    end
endmodule
