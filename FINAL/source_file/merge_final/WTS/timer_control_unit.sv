`timescale 1ns / 1ps

// 타이머(빠른 알람) 컨트롤 유닛 (v2 포트 통일)
// SET  : U/R/D 로 시간 더하기, L = 시작 (0 이면 시작 안 함)
// RUN  : 줄어듦. L = 취소(0 으로), 0 이 되면 ALARM
// ALARM: LED 점멸. 아무 버튼 = 알람 끄기 → SET
// (10/16 사용자 요청) 더하기: U +10초, R +1분, D +10분 (amount 코드 0 · 1 · 2), sw_alt 없앰
module timer_control_unit (
    input            i_clk,
    input            i_rst,
    input            i_tm_btn_R,
    input            i_tm_btn_L,
    input            i_tm_btn_U,
    input            i_tm_btn_D,
    input            i_tm_zero,     // 남은 시간이 0 인가 (데이터패스)
    output reg       o_tm_run,      // 1 = 줄어드는 중
    output reg       o_tm_alarm,    // 1 = 알람 중
    output reg       o_tm_clear,    // 1클럭: 남은 시간 0 으로
    output reg       o_tm_add,      // 1클럭: amount 만큼 더하기
    output reg [1:0] o_tm_amount    // 0 = +10초, 1 = +1분, 2 = +10분
);
    typedef enum logic [1:0] {SET = 2'b00, RUN = 2'b01, ALARM = 2'b10} state_t;  // 시뮬레이션 파형에 이름으로 보임

    state_t c_state, n_state;

    // 상태 레지스터
    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
            c_state <= SET;
        end else begin
            c_state <= n_state;
        end
    end

    // next state / output CL
    always @(*) begin
        n_state     = c_state;
        o_tm_run    = 1'b0;
        o_tm_alarm  = 1'b0;
        o_tm_clear  = 1'b0;
        o_tm_add    = 1'b0;
        o_tm_amount = 2'd0;
        case (c_state)
            SET: begin
                if (i_tm_btn_L == 1'b1) begin
                    if (i_tm_zero == 1'b0) begin
                        n_state = RUN;          // 0 이 아닐 때만 시작
                    end
                end else if (i_tm_btn_U == 1'b1) begin
                    o_tm_add    = 1'b1;
                    o_tm_amount = 2'd0;  // U: +10초
                end else if (i_tm_btn_R == 1'b1) begin
                    o_tm_add    = 1'b1;
                    o_tm_amount = 2'd1;  // R: +1분
                end else if (i_tm_btn_D == 1'b1) begin
                    o_tm_add    = 1'b1;
                    o_tm_amount = 2'd2;  // D: +10분
                end
            end

            RUN: begin
                o_tm_run = 1'b1;  // moore output
                if (i_tm_btn_L == 1'b1) begin
                    n_state    = SET;
                    o_tm_clear = 1'b1;          // 취소 = 남은 시간 지우기
                end else if (i_tm_zero == 1'b1) begin
                    n_state = ALARM;
                end
            end

            ALARM: begin
                o_tm_alarm = 1'b1;  // moore output
                if (i_tm_btn_L | i_tm_btn_R | i_tm_btn_U | i_tm_btn_D) begin
                    n_state = SET;
                end
            end

            default: begin
                n_state = SET;
            end
        endcase
    end
endmodule
