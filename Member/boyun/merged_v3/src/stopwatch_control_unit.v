
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

    parameter STOP = 1'b0, RUN = 1'b1;

    reg c_state, n_state;
    reg mode_reg;

    // State Register
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            c_state <= STOP;
            mode_reg <= 1'b0;
        end else begin
            c_state <= n_state;

            if (btn_mode) begin
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
        clear = btn_clear;
        mode = mode_reg;

        case (c_state)
            STOP: run_stop = 1'b0;
            RUN:  run_stop = 1'b1;
            default: run_stop = 1'b0;
        endcase
    end

endmodule
