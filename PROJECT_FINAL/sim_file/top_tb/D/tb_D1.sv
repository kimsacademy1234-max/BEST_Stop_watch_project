`timescale 1ns / 1ps
// D1. 시작 정확도 — P1 · 2 개   (tb_scenario.md 4 장 D1)
// 스톱워치 화면, pulse_phy(R) = t0 → 1/100 첫 증가 시각 = t0 + 10.000 ms (± 5 clk)
// → t0 + 1.005 s 에 pulse_phy(R) (정지) → 정지값 00:00:01.00, 50 ms 뒤에도 그대로 (FND "01.00")
module tb_D1;
    `include "tb_env.svh"
    string s;

    localparam longint T_TICK    = 10 * MS;       // 1/100 초
    localparam longint TOL_LOGIC = 5 * CLK_NS;    // ± 5 clk
    localparam longint T_STOP    = 1005 * MS;     // 정지 시점 (t0 기준)
    localparam longint T_HOLD    = 50 * MS;       // 정지 뒤 고정 확인
    localparam [23:0]  V_STOP    = {5'd0, 6'd0, 6'd1, 7'd0};   // 00:00:01.00

    time    t0, t1;
    longint d;
    bit [23:0] v_stop, v_hold;

    initial begin
        env_start("tb_D1", 2 * SEC);
        set_sw(7'b000_0001);                  // 스톱워치 초.1/100
        wait_clk(2);

        pulse_phy("R");
        t0 = t_btn_R;
        wait (dut.w_sw_time[6:0] == 7'd1);
        t1 = $time;
        d  = longint'(t1) - longint'(t0) - T_TICK;
        check("D1-01", (d >= -TOL_LOGIC) && (d <= TOL_LOGIC),
              $sformatf("1/100 첫 증가 기대 t0 + 10.000 ms ± %0d ns / 실제 t0 + %0d ns (오차 %0d ns)",
                        TOL_LOGIC, t1 - t0, d));

        #(longint'(t0) + T_STOP - longint'($time));
        pulse_phy("R");
        wait_clk(5);
        v_stop = dut.w_sw_time;
        #(T_HOLD);
        v_hold = dut.w_sw_time;
        fnd_get(s);
        check("D1-02", (v_stop == V_STOP) && (v_hold == V_STOP) && (s == "01.00") && (dut.U_WTS.w_sw_run_stop == 1'b0),
              $sformatf("정지값 기대 00:00:01.00 고정 · FND \"01.00\" / 실제 정지 직후 %02d:%02d:%02d.%02d, 50 ms 뒤 %02d:%02d:%02d.%02d, FND \"%s\", run=%0d (정지 t0 + %0d ns)",
                        v_stop[23:19], v_stop[18:13], v_stop[12:7], v_stop[6:0],
                        v_hold[23:19], v_hold[18:13], v_hold[12:7], v_hold[6:0], s, dut.U_WTS.w_sw_run_stop, t_btn_R - t0));
        env_finish();
    end
endmodule
