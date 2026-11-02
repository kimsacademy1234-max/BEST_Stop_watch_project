`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
//  측정 모드 제어
//  (merge) DHT11 과 같은 동작으로 변경 (merge.md 5번)
//   - 버튼 U : 누를 때마다 자동 측정 켜기 / 끄기 (원래 : 누르고 있는 동안만 자동)
//   - 버튼 R : 1회 측정 (자동 모드 중이면 sr04_core 가 측정 중이라 무시됨)
//   원래의 i_auto_cmd (UART 명령으로 자동 ON) 는 U_CONTROL 의 /btn U 로 대신함
// -----------------------------------------------------------------------------
module sr04_mode_ctrl (
    input  i_clk,
    input  i_rst,
    input  i_btn_R,      // 1회 측정 버튼 1클록 tick
    input  i_btn_U,      // 자동 측정 켜기/끄기 버튼 1클록 tick
    output o_auto_en,
    output o_start
);

    reg auto_reg;

    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst)        auto_reg <= 1'b0;
        else if (i_btn_U) auto_reg <= ~auto_reg;
    end

    assign o_auto_en = auto_reg;
    assign o_start   = i_btn_R;

endmodule
