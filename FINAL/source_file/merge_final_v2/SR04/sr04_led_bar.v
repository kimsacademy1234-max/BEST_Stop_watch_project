`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
//  거리 LED 표시부  (merge : Top_SR04.v 에서 분리, clk / rst → i_clk / i_rst)
//   LD0~7 : 정상 측정값 기준 막대 (가까울수록 많이 켜짐), sw OFF 면 전부 OFF
//           10cm 이하 -> 8개 점멸(250ms), 12cm 초과에서 해제 (히스테리시스)
//   LD8   : 측정 진행 중 (START / WAIT / DIST)
//   LD9   : 마지막 측정 실패 (NO_ECHO / OUT_RANGE / ECHO_STUCK), 다음 정상 측정에서 OFF
//   ※ 갱신은 done 시점에만 -> 측정 중에는 이전 표시 유지
// -----------------------------------------------------------------------------
module sr04_led_bar #(
    parameter BLINK_HALF_CYC = 25_000_000,  // 250ms @100MHz
    parameter WARN_ON_X10    = 100,         // 10.0cm 이하 경고 시작
    parameter WARN_OFF_X10   = 120          // 12.0cm 초과 경고 해제
) (
    input         i_clk,
    input         i_rst,
    input         i_en,
    input         i_done,
    input  [1:0]  i_status,
    input  [11:0] i_dist_x10,
    input         i_measuring,
    output [7:0]  o_bar,
    output        o_meas,
    output        o_err
);

    reg [3:0]  level_reg;     // 켜질 LED 개수 0~8 (0 = 정상값 없음 / 오류)
    reg        warn_reg;      // 근접 경고 (점멸)
    reg        err_reg;
    reg [$clog2(BLINK_HALF_CYC)-1:0] blink_cnt;
    reg        blink_reg;

    // 거리 -> LED 개수 (0.1cm 단위로 비교)
    function [3:0] bar_level(input [11:0] x10);
        begin
            if      (x10 <=  100) bar_level = 4'd8;
            else if (x10 <=  200) bar_level = 4'd7;
            else if (x10 <=  300) bar_level = 4'd6;
            else if (x10 <=  400) bar_level = 4'd5;
            else if (x10 <=  600) bar_level = 4'd4;
            else if (x10 <=  800) bar_level = 4'd3;
            else if (x10 <= 1000) bar_level = 4'd2;
            else                  bar_level = 4'd1;
        end
    endfunction

    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
            level_reg <= 0;
            warn_reg  <= 1'b0;
            err_reg   <= 1'b0;
        end else if (i_done) begin
            if (i_status == 2'b00) begin                 // 정상 측정
                err_reg   <= 1'b0;
                level_reg <= bar_level(i_dist_x10);
                if      (i_dist_x10 <= WARN_ON_X10) warn_reg <= 1'b1;
                else if (i_dist_x10 >  WARN_OFF_X10) warn_reg <= 1'b0;
                // 10.0 ~ 12.0cm : 이전 경고 상태 유지
            end else begin                               // 측정 실패
                err_reg   <= 1'b1;
                level_reg <= 0;
                warn_reg  <= 1'b0;
            end
        end
    end

    // 점멸 250ms ON / 250ms OFF
    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
            blink_cnt <= 0;
            blink_reg <= 1'b0;
        end else if (blink_cnt == BLINK_HALF_CYC - 1) begin
            blink_cnt <= 0;
            blink_reg <= ~blink_reg;
        end else begin
            blink_cnt <= blink_cnt + 1;
        end
    end

    wire [7:0] w_bar_steady = (8'hFF >> (4'd8 - level_reg));   // LD0 부터 level 개
    wire [7:0] w_bar        = warn_reg ? {8{blink_reg}} : ((level_reg == 0) ? 8'h00 : w_bar_steady);

    assign o_bar  = i_en ? w_bar : 8'h00;
    assign o_meas = i_measuring;
    assign o_err  = err_reg;

endmodule
