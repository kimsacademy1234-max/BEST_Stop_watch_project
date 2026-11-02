`timescale 1ns / 1ps
// 원본(이전 실습) 구조 유지 : 분주 → 8bit 쉬프트 → 8입력 AND → 상승 엣지 1 tick
// 고친 점
//  - 분주 출력을 클럭으로 쓰지 않고 1 클럭 tick(enable) 으로 사용 (TIMING-17 경고 제거)
//  - 샘플 간격 1 us → 1 ms (F_COUNT 100 → 100_000) : 8 샘플 = 8 ms 동안 눌려 있어야 인정
//  - 버튼 입력 2단 싱크로나이저 추가
module btn_debounce #(
    parameter F_COUNT = 100_000     // 100 MHz → 1 kHz 샘플 tick
) (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);
    (* ASYNC_REG = "TRUE" *) reg r_btn_sync1, r_btn_sync2;
    reg [$clog2(F_COUNT)-1:0] counter_reg;
    reg       r_sample_tick;
    reg [7:0] q_reg;
    reg       edge_reg;
    wire      debounce;

    // 버튼 싱크로나이저
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_btn_sync1 <= 1'b0;
            r_btn_sync2 <= 1'b0;
        end else begin
            r_btn_sync1 <= i_btn;
            r_btn_sync2 <= r_btn_sync1;
        end
    end

    // 1 ms 마다 1 클럭 tick
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg   <= 0;
            r_sample_tick <= 1'b0;
        end else if (counter_reg == F_COUNT - 1) begin
            counter_reg   <= 0;
            r_sample_tick <= 1'b1;
        end else begin
            counter_reg   <= counter_reg + 1;
            r_sample_tick <= 1'b0;
        end
    end

    // 8bit 쉬프트 레지스터 (tick 때만 이동)
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            q_reg <= 8'h0;
        end else if (r_sample_tick) begin
            q_reg <= {r_btn_sync2, q_reg[7:1]};
        end
    end

    assign debounce = &q_reg;

    // 상승 엣지 → 1 클럭 펄스
    always @(posedge clk, posedge reset) begin
        if (reset) edge_reg <= 1'b0;
        else       edge_reg <= debounce;
    end

    assign o_btn = ~edge_reg & debounce;
endmodule
