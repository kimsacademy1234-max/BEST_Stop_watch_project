`timescale 1ns / 1ps

// 스톱워치 컨트롤 유닛 (v2 포트 통일)
// i_sw_btn_R : 시작 ↔ 정지
// i_sw_btn_L : 지우기 (STOP 에서만, RUN 중 무시)
// i_sw_btn_U : 업 ↔ 다운 전환 (STOP 에서만, RUN 중 무시)
// (D = 랩 은 stopwatch_datapath 로 바로 감)
module stopwatch_control_unit (
    input      i_clk,
    input      i_rst,
    input      i_sw_btn_R,
    input      i_sw_btn_L,
    input      i_sw_btn_U,
    output reg o_sw_run_stop,  // 1 = 동작 중
    output reg o_sw_clear,     // 1클럭: 0 으로 지우기
    output reg o_sw_down       // 1 = 다운 카운트 (구 mode)
);

    typedef enum logic {STOP = 1'b0, RUN = 1'b1} state_t;  // 시뮬레이션 파형에 이름으로 보임

    state_t c_state, n_state;
    reg down_reg;

    // State Register
    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            c_state  <= STOP;
            down_reg <= 1'b0;
        end else begin
            c_state <= n_state;

            if (i_sw_btn_U && (c_state == STOP)) begin  // (10/16) RUN 중 U 무시
                down_reg <= ~down_reg;
            end
        end
    end

    // Next State Logic
    always @(*) begin
        n_state = c_state;

        case (c_state)
            STOP: begin
                if (i_sw_btn_R)
                    n_state = RUN;
            end

            RUN: begin
                if (i_sw_btn_R)
                    n_state = STOP;
            end

            default: n_state = STOP;
        endcase
    end

    // Output Logic
    always @(*) begin
        o_sw_run_stop = 1'b0;
        o_sw_clear    = 1'b0;
        o_sw_down     = down_reg;

        case (c_state)
            STOP: begin
                o_sw_run_stop = 1'b0;
                o_sw_clear    = i_sw_btn_L;  // (10/16) L 은 STOP 에서만, RUN 중 L 무시
            end
            RUN:     o_sw_run_stop = 1'b1;
            default: o_sw_run_stop = 1'b0;
        endcase
    end

endmodule
