`timescale 1ns / 1ps

// 시계 데이터패스
// - tick_gen_100hz 는 스톱워치 것을 그대로 사용 (run_stop = 1, clear = 0 고정 -> 항상 흐름)
// - 카운터는 watch_tick_counter: 리셋값 INIT, 칸 +STEP/-STEP (올림·내림 없이 그 칸만 돌기)
// - 10/16 자리 단위 판: cursor 0 분 +-1, 1 분 +-10, 2 시 +-1, 초는 설정 안 함
module watch_datapath #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input                       clk,
    input                       rst,
    input  [               1:0] cursor,  // 0 분 일, 1 분 십, 2 시 일, 3 없음
    input                       i_up,
    input                       i_down,
    output [MSEC_BIT_WIDTH-1:0] msec,
    output [ SEC_BIT_WIDTH-1:0] sec,
    output [ MIN_BIT_WIDTH-1:0] min,
    output [HOUR_BIT_WIDTH-1:0] hour
);

    wire w_tick_10ms, w_tick_sec, w_tick_min, w_tick_hour;
    wire w_min_up, w_min_down, w_min_step10, w_hour_up, w_hour_down;

    // cursor 가 가리키는 칸에만 +1/-1 펄스 전달
    assign w_min_up     = i_up & ((cursor == 2'd0) | (cursor == 2'd1));
    assign w_min_down   = i_down & ((cursor == 2'd0) | (cursor == 2'd1));
    assign w_min_step10 = (cursor == 2'd1);  // 분 십의 자리: +-10
    assign w_hour_up   = i_up & (cursor == 2'd2);
    assign w_hour_down = i_down & (cursor == 2'd2);

    tick_gen_100hz U_TICK_GEN_100HZ (
        .clk     (clk),
        .rst     (rst),
        .run_stop(1'b1),        // 시계는 항상 흐름
        .clear   (1'b0),
        .o_tick  (w_tick_10ms)  // 100hz tick
    );

    watch_tick_counter #(
        .TIMES(100),
        .BIT_WIDTH(MSEC_BIT_WIDTH),
        .INIT(0)
    ) U_MSEC_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_10ms),
        .i_up      (1'b0),        // msec 는 설정하지 않음
        .i_down    (1'b0),
        .i_step10  (1'b0),
        .time_count(msec),
        .o_tick    (w_tick_sec)
    );

    watch_tick_counter #(
        .TIMES(60),
        .BIT_WIDTH(SEC_BIT_WIDTH),
        .INIT(0)
    ) U_SEC_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_sec),
        .i_up      (1'b0),        // 초는 설정하지 않음 (10/16 팀 합의)
        .i_down    (1'b0),
        .i_step10  (1'b0),
        .time_count(sec),
        .o_tick    (w_tick_min)
    );

    watch_tick_counter #(
        .TIMES(60),
        .BIT_WIDTH(MIN_BIT_WIDTH),
        .INIT(0)
    ) U_MIN_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_min),
        .i_up      (w_min_up),
        .i_down    (w_min_down),
        .i_step10  (w_min_step10),
        .time_count(min),
        .o_tick    (w_tick_hour)
    );

    watch_tick_counter #(
        .TIMES(24),
        .BIT_WIDTH(HOUR_BIT_WIDTH),
        .INIT(12)                   // 시작값 12:00:00:00
    ) U_HOUR_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_hour),
        .i_up      (w_hour_up),
        .i_down    (w_hour_down),
        .i_step10  (1'b0),
        .time_count(hour),
        .o_tick    ()
    );

endmodule


module watch_tick_counter #(
    parameter TIMES = 100,
    BIT_WIDTH = 7,
    INIT = 0
) (
    input                  clk,
    input                  rst,
    input                  i_tick,
    input                  i_up,
    input                  i_down,
    input                  i_step10,  // 1 이면 +-10, 0 이면 +-1
    output [BIT_WIDTH-1:0] time_count,
    output reg             o_tick
);

    reg [$clog2(TIMES)-1:0] counter_reg;
    wire [3:0] w_step;

    assign time_count = counter_reg;
    assign w_step = (i_step10) ? 4'd10 : 4'd1;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= INIT;
            o_tick <= 1'b0;
        end else begin
            if (i_tick) begin
                // tick 우선: 같은 클럭에 버튼이 와도 시각이 틀어지지 않게 tick 만 반영
                if (counter_reg == TIMES - 1) begin
                    counter_reg <= 0;
                    o_tick <= 1'b1;
                end else begin
                    counter_reg <= counter_reg + 1;
                    o_tick <= 1'b0;
                end
            end else begin
                o_tick <= 1'b0;
                // 설정: 그 칸만 돌고 다음 칸으로 올림·내림 없음 (o_tick 안 냄)
                // TIMES 로 돌기: 분 55 +10 -> 05, 05 -10 -> 55 (십의 자리만 0~5 로 도는 것과 같음)
                if (i_up) begin
                    if (counter_reg + w_step >= TIMES) begin
                        counter_reg <= counter_reg + w_step - TIMES;
                    end else begin
                        counter_reg <= counter_reg + w_step;
                    end
                end else if (i_down) begin
                    if (counter_reg < w_step) begin
                        counter_reg <= counter_reg + TIMES - w_step;
                    end else begin
                        counter_reg <= counter_reg - w_step;
                    end
                end
            end
        end
    end

endmodule
