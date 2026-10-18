`timescale 1ns / 1ps

// 시계 컨트롤 유닛 (클로드코드 참고 구현, 10/16 자리 단위 판, v2 포트 통일)
// 팀 합의(정안성 · 정보윤 10/16): 초 설정 대신 분 십의 자리, 시 십의 자리는 설정 안 함
// i_set_sw2 = 0 : NORMAL (버튼 무시)
// i_set_sw2 = 1 : SET_MIN_1 에서 시작 (FND 맨 오른쪽 자리)
//              R: 오른쪽 자리로 (SET_HOUR -> SET_MIN_10 -> SET_MIN_1 -> SET_HOUR 돌아감)
//              L: 왼쪽 자리로   (SET_MIN_1 -> SET_MIN_10 -> SET_HOUR -> SET_MIN_1 돌아감)
//              U: 지금 자리 +1 (SET_MIN_10 은 분 +10), D: -1 (-10), U + D 동시: 무효
// o_wt_cursor = FND 자리 번호(AN0 = 맨 오른쪽)와 같게: 0 분 일, 1 분 십, 2 시 일, 3 없음(NORMAL)
// (v2) 아무 데도 연결되지 않던 set_mode 출력 삭제
module watch_control_unit (
    input            i_clk,
    input            i_rst,
    input            i_wt_btn_R,
    input            i_wt_btn_L,
    input            i_wt_btn_U,
    input            i_wt_btn_D,
    input            i_set_sw2,
    output reg [1:0] o_wt_cursor,  // 0 분 일, 1 분 십, 2 시 일, 3 없음(NORMAL)
    output reg       o_wt_up,      // 1클럭 펄스
    output reg       o_wt_down     // 1클럭 펄스
);
    typedef enum logic [1:0] {NORMAL = 2'b00, SET_HOUR = 2'b01, SET_MIN_10 = 2'b10, SET_MIN_1 = 2'b11} state_t;  // 시뮬레이션 파형에 이름으로 보임
    parameter CUR_MIN_1 = 2'd0, CUR_MIN_10 = 2'd1, CUR_HOUR = 2'd2, CUR_NONE = 2'd3;

    state_t c_state, n_state;

    // 상태 레지스터
    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
            c_state <= NORMAL;
        end else begin
            c_state <= n_state;
        end
    end

    // next state / output CL
    always @(*) begin
        n_state     = c_state;
        o_wt_cursor = CUR_NONE;
        o_wt_up     = 1'b0;
        o_wt_down   = 1'b0;
        case (c_state)
            NORMAL: begin
                // moore output
                o_wt_cursor = CUR_NONE;
                if (i_set_sw2 == 1'b1) begin
                    n_state = SET_MIN_1;  // 설정 들어가면 항상 분 일의 자리(맨 오른쪽)부터
                end
            end

            SET_HOUR: begin
                o_wt_cursor = CUR_HOUR;
                if (i_set_sw2 == 1'b0) begin
                    n_state = NORMAL;
                end else if (i_wt_btn_L == 1'b1) begin
                    n_state = SET_MIN_1;  // 왼쪽 끝 -> 오른쪽 끝으로 돌아감
                end else if (i_wt_btn_R == 1'b1) begin
                    n_state = SET_MIN_10;
                end
            end

            SET_MIN_10: begin
                o_wt_cursor = CUR_MIN_10;
                if (i_set_sw2 == 1'b0) begin
                    n_state = NORMAL;
                end else if (i_wt_btn_L == 1'b1) begin
                    n_state = SET_HOUR;
                end else if (i_wt_btn_R == 1'b1) begin
                    n_state = SET_MIN_1;
                end
            end

            SET_MIN_1: begin
                o_wt_cursor = CUR_MIN_1;
                if (i_set_sw2 == 1'b0) begin
                    n_state = NORMAL;
                end else if (i_wt_btn_L == 1'b1) begin
                    n_state = SET_MIN_10;
                end else if (i_wt_btn_R == 1'b1) begin
                    n_state = SET_HOUR;  // 오른쪽 끝 -> 왼쪽 끝으로 돌아감
                end
            end
        endcase

        // mealy output: 설정 상태이고 i_set_sw2 가 아직 1 일 때만 +/- 펄스
        // U, D 가 같은 클럭에 오면 무효 (둘 다 0)
        if ((c_state != NORMAL) && (i_set_sw2 == 1'b1)) begin
            o_wt_up   = i_wt_btn_U & ~i_wt_btn_D;
            o_wt_down = i_wt_btn_D & ~i_wt_btn_U;
        end
    end
endmodule
