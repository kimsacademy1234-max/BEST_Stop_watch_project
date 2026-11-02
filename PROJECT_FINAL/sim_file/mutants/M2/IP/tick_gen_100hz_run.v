`timescale 1ns / 1ps

// 100hz(10ms) tick 생성기 — 시작 순간부터 세는 판 (스톱워치 · 타이머 전용)
// (10/17 팀 결정 ④) 스톱워치 · 타이머는 시작한 순간부터 정확히 10 ms 뒤에 첫 tick 이 나와야 한다.
//   공용 tick(U_TICK_GEN_100HZ)을 쓰면 시작 순간이 tick 사이 어디냐에 따라 첫 칸이 최대 10 ms 일찍 바뀜 (10초 타이머 = 9,998 ms)
//   i_run_stop = 1 : 센다 / 0 : 그 자리에서 멈춤 (스톱워치 STOP → 다시 RUN 하면 이어서 셈)
//   i_clear    = 1 : 0 부터 다시 (스톱워치 지우기 · 타이머 취소)
//   코드는 10/14 수업 tick_gen_100hz (run_stop · clear 입력 있는 판) 과 같고 포트 이름만 v2 규칙 (i_ / o_)
// o_tick_10ms : 센 지 100 MHz 클럭 1,000,000 개가 되면 1 클럭(10 ns) 펄스
module tick_gen_100hz_run (
    input      i_clk,
    input      i_rst,
    input      i_run_stop,
    input      i_clear,
    output reg o_tick_10ms
);

    parameter F_COUNT = 100_000_000 / 100;

    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst | i_clear) begin
            counter_reg <= 0;
            o_tick_10ms <= 1'b0;
        end else begin
            if (i_run_stop) begin
                counter_reg <= counter_reg + 1;
                if (counter_reg == F_COUNT - 1) begin
                    counter_reg <= 0;
                    o_tick_10ms <= 1'b1;
                end else begin
                    o_tick_10ms <= 1'b0;
                end
            end else begin
                // 멈춘 동안 o_tick 이 1 로 남지 않게
                o_tick_10ms <= 1'b0;
            end
        end
    end

endmodule
