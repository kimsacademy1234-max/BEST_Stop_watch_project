`timescale 1ns / 1ps

// 타이머 데이터패스 (v2 포트 통일)
// - 100hz tick 은 top 에서 받음 (i_tick_10ms), i_tm_run 일 때만 통과
// - 남은 시간을 1/100초 단위까지 거꾸로 센다. 0 에서는 멈춤
// - (10/16) 더하기: +10초 · +1분 · +10분, 최대 59:59 (넘으면 59:59 로). 화면은 분.초 → 시는 늘 0
// - (v2) 아무 데도 연결되지 않던 hour 출력 삭제 (내부 hour_reg 는 그대로)
module timer_datapath #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input                       i_clk,
    input                       i_rst,
    input                       i_tick_10ms,  // top 의 100hz tick
    input                       i_tm_run,
    input                       i_tm_clear,
    input                       i_tm_add,
    input  [               1:0] i_tm_amount,  // 0 +10초, 1 +1분, 2 +10분
    output [MSEC_BIT_WIDTH-1:0] o_tm_msec,
    output [ SEC_BIT_WIDTH-1:0] o_tm_sec,
    output [ MIN_BIT_WIDTH-1:0] o_tm_min,
    output                      o_tm_zero     // 1 = 남은 시간 0
);

    wire w_tick_10ms;
    wire w_over;

    reg [MSEC_BIT_WIDTH-1:0] msec_reg;
    reg [ SEC_BIT_WIDTH-1:0] sec_reg;
    reg [ MIN_BIT_WIDTH-1:0] min_reg;
    reg [HOUR_BIT_WIDTH-1:0] hour_reg;

    reg [6:0] sec_sum;    // 초 + 10 (최대 59 + 10 = 69 → 7비트)
    reg [6:0] min_sum;    // 분 + 더할 분 + 초 올림 (최대 59 + 10 + 1 = 70 → 7비트)
    reg [SEC_BIT_WIDTH-1:0]  sec_next;
    reg [MIN_BIT_WIDTH-1:0]  min_next;
    reg                      carry;

    assign o_tm_msec = msec_reg;
    assign o_tm_sec  = sec_reg;
    assign o_tm_min  = min_reg;

    assign o_tm_zero = (msec_reg == 0) && (sec_reg == 0) && (min_reg == 0) && (hour_reg == 0);

    // 타이머는 run 일 때만 tick 통과
    assign w_tick_10ms = i_tick_10ms & i_tm_run;

    // 더한 결과 미리 계산 (조합회로)
    always @(*) begin
        sec_sum = sec_reg + ((i_tm_amount == 2'd0) ? 7'd10 : 7'd0);
        if (sec_sum >= 60) begin
            sec_next = sec_sum - 60;
            carry    = 1'b1;
        end else begin
            sec_next = sec_sum;
            carry    = 1'b0;
        end
        min_sum = min_reg + ((i_tm_amount == 2'd1) ? 7'd1 : (i_tm_amount == 2'd2) ? 7'd10 : 7'd0) + carry;
        min_next = min_sum;  // 60 이상이면 아래 w_over 로 59:59 고정
    end

    // 분.초 화면(분 두 자리)에 들어가는가: 60분 이상이면 넘침
    assign w_over = (min_sum >= 60);

    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst | i_tm_clear) begin
            msec_reg <= 0;
            sec_reg  <= 0;
            min_reg  <= 0;
            hour_reg <= 0;
        end else begin
            if (w_tick_10ms & ~o_tm_zero) begin
                // 1/100초 줄이기, 0 이면 윗자리에서 빌려 옴
                if (msec_reg != 0) begin
                    msec_reg <= msec_reg - 1;
                end else begin
                    msec_reg <= 99;
                    if (sec_reg != 0) begin
                        sec_reg <= sec_reg - 1;
                    end else begin
                        sec_reg <= 59;
                        if (min_reg != 0) begin
                            min_reg <= min_reg - 1;
                        end else begin
                            min_reg  <= 59;
                            hour_reg <= hour_reg - 1;
                        end
                    end
                end
            end else if (i_tm_add) begin
                if (w_over) begin
                    min_reg  <= 59;   // 최대 59:59
                    sec_reg  <= 59;
                    msec_reg <= 0;
                end else begin
                    min_reg  <= min_next;
                    sec_reg  <= sec_next;
                end
            end
        end
    end

endmodule
