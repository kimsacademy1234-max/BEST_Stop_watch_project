`timescale 1ns / 1ps

module sr04_controller #(
    parameter TRIG_US = 11,
    CM_US = 58,
    MAX_CM = 400,
    parameter STOP_US = 10000,
    TIMEOUT_US = 30000
) (
    input        clk,
    input        rst,
    input        i_start,
    input        i_us_tick,
    input        i_echo,
    output       o_trig,
    output [8:0] o_distance,
    output       o_done,
    output       o_busy,
    output       o_tick_en,
    output       o_tick_clr
);
    localparam IDLE = 3'd0, START = 3'd1, WAIT = 3'd2, DIST = 3'd3, STOP = 3'd4;

    reg [2:0] c_state, n_state;
    reg [15:0] c_cnt_tick_us, n_cnt_tick_us;
    reg [8:0] c_cnt_cm, n_cnt_cm;
    reg [8:0] c_distance, n_distance;
    reg c_done, n_done;
    reg c_echo_sync1, c_echo_sync2;

    // Integerated Logic Analyzer
    // probing trig, echo, fsm c_state
    ila_0 U_ILA (
        .clk   (clk),
        .probe0(o_trig),
        .probe1(i_echo),
        .probe2(c_echo_sync1),
        .probe3(c_echo_sync2),
        .probe4(c_state)
    );

    assign o_trig     = (c_state == START);
    assign o_busy     = (c_state != IDLE);
    assign o_tick_en  = (c_state != IDLE);
    assign o_tick_clr = (c_state == IDLE);
    assign o_distance = c_distance;
    assign o_done     = c_done;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state       <= IDLE;
            c_cnt_tick_us <= 0;
            c_cnt_cm      <= 0;
            c_distance    <= 0;
            c_done        <= 0;
            c_echo_sync1  <= 0;
            c_echo_sync2  <= 0;
        end else begin
            c_state       <= n_state;
            c_cnt_tick_us <= n_cnt_tick_us;
            c_cnt_cm      <= n_cnt_cm;
            c_distance    <= n_distance;
            c_done        <= n_done;
            c_echo_sync1  <= i_echo;
            c_echo_sync2  <= c_echo_sync1;
        end
    end

    always @(*) begin
        n_state       = c_state;
        n_cnt_tick_us = c_cnt_tick_us;
        n_cnt_cm      = c_cnt_cm;
        n_distance    = c_distance;
        n_done        = 1'b0;  // 펄스는 기본 0

        case (c_state)
            IDLE: begin
                if (i_start) begin
                    n_cnt_tick_us = 0;
                    n_state       = START;
                end
            end
            START: begin
                if (i_us_tick) begin
                    if (c_cnt_tick_us == TRIG_US - 1) begin
                        n_cnt_tick_us = 0;
                        n_state       = WAIT;
                    end else begin
                        n_cnt_tick_us = c_cnt_tick_us + 1;
                    end
                end
            end
            WAIT: begin
                if (c_echo_sync2 == 1) begin
                    n_cnt_tick_us = 0;
                    n_cnt_cm      = 0;
                    n_state       = DIST;
                end else if (i_us_tick) begin
                    if (c_cnt_tick_us == TIMEOUT_US - 1) begin
                        n_distance    = 0;
                        n_done        = 1;
                        n_cnt_tick_us = 0;
                        n_state       = STOP;
                    end else begin
                        n_cnt_tick_us = c_cnt_tick_us + 1;
                    end
                end
            end
            DIST: begin
                if (!c_echo_sync2) begin
                    n_distance    = c_cnt_cm;
                    n_done        = 1;
                    n_cnt_tick_us = 0;
                    n_state       = STOP;
                end else if (c_cnt_cm > MAX_CM) begin
                    n_distance    = 0;  // 범위 밖 = 거리 0
                    n_done        = 1;
                    n_cnt_tick_us = 0;
                    n_state       = STOP;
                end else if (i_us_tick) begin
                    if (c_cnt_tick_us == CM_US - 1) begin
                        n_cnt_tick_us = 0;
                        n_cnt_cm      = c_cnt_cm + 1;
                    end else begin
                        n_cnt_tick_us = c_cnt_tick_us + 1;
                    end
                end
            end
            STOP: begin
                if (c_echo_sync2) begin
                    n_cnt_tick_us = 0;
                end else if (i_us_tick) begin
                    if (c_cnt_tick_us == STOP_US - 1) begin
                        n_state = IDLE;
                    end else begin
                        n_cnt_tick_us = c_cnt_tick_us + 1;
                    end
                end
            end
            default: n_state = IDLE;
        endcase
    end
endmodule
