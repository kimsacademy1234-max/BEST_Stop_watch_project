
`timescale 1ns / 1ps

module stopwatch_control_unit (
    input clk,
    input reset,
    input btn_run_stop,
    input btn_clear,
    input btn_mode,
    output reg run_stop,
    output reg clear,
    output reg mode
);

    typedef enum logic {STOP = 1'b0, RUN = 1'b1} state_t;  // 시뮬레이션 파형에 이름으로 보임

    state_t c_state, n_state;
    reg mode_reg;

    // State Register
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            c_state <= STOP;
            mode_reg <= 1'b0;
        end else begin
            c_state <= n_state;

            if (btn_mode && (c_state == STOP)) begin  // (10/16) RUN 중 U 무시
                mode_reg <= ~mode_reg;
            end
        end
    end

    // Next State Logic
    always @(*) begin
        n_state = c_state;

        case (c_state)
            STOP: begin
                if (btn_run_stop)
                    n_state = RUN;
            end

            RUN: begin
                if (btn_run_stop)
                    n_state = STOP;
            end

            default: n_state = STOP;
        endcase
    end

    // Output Logic
    always @(*) begin
        run_stop = 1'b0;
        clear = 1'b0;
        mode = mode_reg;

        case (c_state)
            STOP: begin
                run_stop = 1'b0;
                clear = btn_clear;  // (10/16) L 은 STOP 에서만, RUN 중 L 무시
            end
            RUN:  run_stop = 1'b1;
            default: run_stop = 1'b0;
        endcase
    end

endmodule
