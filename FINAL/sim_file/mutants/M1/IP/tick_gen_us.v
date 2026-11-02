`timescale 1ns / 1ps

// 1 us tick 생성기 (enable / clear)
// (merge) DHT11 의 tick_gen_1us 와 SR04 의 tick_gen_us 는 주기(1 us) · 동작(clear 우선, enable 일 때만 셈)이
//         같아서 하나로 합침. 포트 이름은 v2 규칙 (i_ / o_)
//   i_clear  = 1 : 0 부터 다시 (FSM 이 IDLE 일 때 → 측정마다 tick 위상 정렬)
//   i_enable = 1 : 셈 / 0 : 멈춤 (o_tick 0)
//   o_tick   : F_COUNT 클럭마다 1 클럭 펄스 (100 MHz, F_COUNT = 100 → 1 us)
module tick_gen_us #(
    parameter F_COUNT = 100
) (
    input  i_clk,
    input  i_rst,
    input  i_enable,
    input  i_clear,
    output o_tick
);

    reg [$clog2(F_COUNT)-1:0] r_cnt;
    reg r_tick;

    assign o_tick = r_tick;

    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
            r_cnt  <= 0;
            r_tick <= 0;
        end else if (i_clear) begin
            r_cnt  <= 0;
            r_tick <= 0;
        end else if (i_enable) begin
            if (r_cnt == F_COUNT - 1) begin
                r_cnt  <= 0;
                r_tick <= 1;
            end else begin
                r_cnt  <= r_cnt + 1;
                r_tick <= 0;
            end
        end else begin
            r_tick <= 1'b0;
        end
    end

endmodule
