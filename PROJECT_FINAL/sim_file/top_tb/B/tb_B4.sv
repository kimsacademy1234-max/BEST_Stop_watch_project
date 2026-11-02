`timescale 1ns / 1ps
// B4. 길게 누름 — P2 · 1 개   (tb_scenario.md 4 장 B4)
// 스톱워치 화면 (sw0 1) 에서 물리 btn_R 을 3 s 누름 → 디바운서 펄스 1 개 (auto-repeat 없음), 스톱워치 RUN 한 번
module tb_B4;
    `include "tb_env.svh"

    localparam longint T_HOLD = 3 * SEC;      // 누르는 길이
    localparam longint T_GAP  = 20 * MS;      // 뗀 뒤 대기 (뗄 때 펄스 없는지까지)

    initial begin
        env_start("tb_B4", 5 * SEC);
        set_sw(7'b000_0001);                  // 스톱워치 초.1/100
        wait_clk(2);

        press("R", T_HOLD, T_GAP);
        check("B4-01", (cnt_btn_R == 1) && (dut.U_WTS.w_sw_run_stop == 1'b1),
              $sformatf("3 s 누름 기대 펄스 1 개 · 스톱워치 RUN / 실제 펄스 %0d 개 (마지막 %0d ns), run_stop=%0d, sw_time=%h",
                        cnt_btn_R, t_btn_R, dut.U_WTS.w_sw_run_stop, dut.w_sw_time));
        env_finish();
    end
endmodule
