`timescale 1ns / 1ps

// 타이머 데이터패스
// - tick_gen_100hz 는 스톱워치 것을 그대로 사용 (run 일 때만 10 ms tick)
// - 남은 시간을 1/100초 단위까지 거꾸로 센다. 0 에서는 멈춤
// - 분 더하기: 60 넘으면 시로 올림, 최대 12:00:00.00 (넘으면 12:00 으로)
module timer_datapath #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input                       clk,
    input                       rst,
    input                       run,
    input                       clear,
    input                       add,
    input  [               5:0] amount,
    output [MSEC_BIT_WIDTH-1:0] msec,
    output [ SEC_BIT_WIDTH-1:0] sec,
    output [ MIN_BIT_WIDTH-1:0] min,
    output [HOUR_BIT_WIDTH-1:0] hour,
    output                      zero
);

    wire w_tick_10ms;
    wire w_over;

    reg [MSEC_BIT_WIDTH-1:0] msec_reg;
    reg [ SEC_BIT_WIDTH-1:0] sec_reg;
    reg [ MIN_BIT_WIDTH-1:0] min_reg;
    reg [HOUR_BIT_WIDTH-1:0] hour_reg;

    reg [6:0] min_sum;    // 분 + 더할 분 (최대 59 + 60 = 119 → 7비트)
    reg [MIN_BIT_WIDTH-1:0]  min_next;
    reg [HOUR_BIT_WIDTH-1:0] hour_next;

    assign msec = msec_reg;
    assign sec  = sec_reg;
    assign min  = min_reg;
    assign hour = hour_reg;

    assign zero = (msec_reg == 0) && (sec_reg == 0) && (min_reg == 0) && (hour_reg == 0);

    tick_gen_100hz U_TICK_GEN_100HZ (
        .clk     (clk),
        .rst     (rst),
        .run_stop(run),
        .clear   (clear),
        .o_tick  (w_tick_10ms)
    );

    // 더한 결과 미리 계산 (조합회로)
    always @(*) begin
        min_sum = min_reg + amount;
        if (min_sum >= 60) begin
            min_next  = min_sum - 60;
            hour_next = hour_reg + 1;
        end else begin
            min_next  = min_sum;
            hour_next = hour_reg;
        end
    end

    // 12:00:00.00 을 넘는가
    assign w_over = (hour_next > 12) ||
                    ((hour_next == 12) && ((min_next != 0) || (sec_reg != 0) || (msec_reg != 0)));

    always @(posedge clk, posedge rst) begin
        if (rst | clear) begin
            msec_reg <= 0;
            sec_reg  <= 0;
            min_reg  <= 0;
            hour_reg <= 0;
        end else begin
            if (w_tick_10ms & ~zero) begin
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
            end else if (add) begin
                if (w_over) begin
                    hour_reg <= 12;
                    min_reg  <= 0;
                    sec_reg  <= 0;
                    msec_reg <= 0;
                end else begin
                    hour_reg <= hour_next;
                    min_reg  <= min_next;
                end
            end
        end
    end

endmodule
