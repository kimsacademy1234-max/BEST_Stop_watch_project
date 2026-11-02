`timescale 1ns / 1ps

// 시계 데이터패스 (v2 포트 통일)
// ** 시연용 (source_file_demo) ** 리셋값만 23:59:50.00 (원래 12:00:00.00) — 리셋 10 초 뒤 자정
// - 100hz tick 은 top 에서 받음 (i_tick_10ms), 항상 흐름
// - 카운터는 watch_tick_counter: 리셋값 INIT, 칸 +STEP/-STEP (올림·내림 없이 그 칸만 돌기)
// - 10/16 자리 단위 판: cursor 0 분 +-1, 1 분 +-10, 2 시 +-1, 초는 설정 안 함
module watch_datapath #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input                       i_clk,
    input                       i_rst,
    input                       i_tick_10ms,  // top 의 100hz tick
    input  [               1:0] i_wt_cursor,  // 0 분 일, 1 분 십, 2 시 일, 3 없음
    input                       i_wt_up,
    input                       i_wt_down,
    output [MSEC_BIT_WIDTH-1:0] o_wt_msec,
    output [ SEC_BIT_WIDTH-1:0] o_wt_sec,
    output [ MIN_BIT_WIDTH-1:0] o_wt_min,
    output [HOUR_BIT_WIDTH-1:0] o_wt_hour     // 0~23 (24시간 기준)
);

    wire w_tick_10ms, w_tick_sec, w_tick_min, w_tick_hour;
    wire w_min_up, w_min_down, w_min_step10, w_hour_up, w_hour_down;

    // cursor 가 가리키는 칸에만 +1/-1 펄스 전달
    assign w_min_up     = i_wt_up & ((i_wt_cursor == 2'd0) | (i_wt_cursor == 2'd1));
    assign w_min_down   = i_wt_down & ((i_wt_cursor == 2'd0) | (i_wt_cursor == 2'd1));
    assign w_min_step10 = (i_wt_cursor == 2'd1);  // 분 십의 자리: +-10
    assign w_hour_up    = i_wt_up & (i_wt_cursor == 2'd2);
    assign w_hour_down  = i_wt_down & (i_wt_cursor == 2'd2);

    // 시계는 항상 흐름
    assign w_tick_10ms = i_tick_10ms;

    watch_tick_counter #(
        .TIMES(100),
        .BIT_WIDTH(MSEC_BIT_WIDTH),
        .INIT(0)
    ) U_MSEC_COUNTER (
        .i_clk   (i_clk),
        .i_rst   (i_rst),
        .i_tick  (w_tick_10ms),
        .i_up    (1'b0),        // msec 는 설정하지 않음
        .i_down  (1'b0),
        .i_step10(1'b0),
        .o_count (o_wt_msec),
        .o_tick  (w_tick_sec)
    );

    watch_tick_counter #(
        .TIMES(60),
        .BIT_WIDTH(SEC_BIT_WIDTH),
        .INIT(50)
    ) U_SEC_COUNTER (
        .i_clk   (i_clk),
        .i_rst   (i_rst),
        .i_tick  (w_tick_sec),
        .i_up    (1'b0),        // 초는 설정하지 않음 (10/16 팀 합의)
        .i_down  (1'b0),
        .i_step10(1'b0),
        .o_count (o_wt_sec),
        .o_tick  (w_tick_min)
    );

    watch_tick_counter #(
        .TIMES(60),
        .BIT_WIDTH(MIN_BIT_WIDTH),
        .INIT(59)
    ) U_MIN_COUNTER (
        .i_clk   (i_clk),
        .i_rst   (i_rst),
        .i_tick  (w_tick_min),
        .i_up    (w_min_up),
        .i_down  (w_min_down),
        .i_step10(w_min_step10),
        .o_count (o_wt_min),
        .o_tick  (w_tick_hour)
    );

    watch_tick_counter #(
        .TIMES(24),
        .BIT_WIDTH(HOUR_BIT_WIDTH),
        .INIT(23)                   // (시연용) 시작값 23:59:50.00 — 원래 12:00:00.00
    ) U_HOUR_COUNTER (
        .i_clk   (i_clk),
        .i_rst   (i_rst),
        .i_tick  (w_tick_hour),
        .i_up    (w_hour_up),
        .i_down  (w_hour_down),
        .i_step10(1'b0),
        .o_count (o_wt_hour),
        .o_tick  ()
    );

endmodule


module watch_tick_counter #(
    parameter TIMES = 100,
    BIT_WIDTH = 7,
    INIT = 0
) (
    input                  i_clk,
    input                  i_rst,
    input                  i_tick,
    input                  i_up,
    input                  i_down,
    input                  i_step10,  // 1 이면 +-10, 0 이면 +-1
    output [BIT_WIDTH-1:0] o_count,
    output reg             o_tick
);

    reg [$clog2(TIMES)-1:0] counter_reg;
    wire [3:0] w_step;

    assign o_count = counter_reg;
    assign w_step  = (i_step10) ? 4'd10 : 4'd1;

    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
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
