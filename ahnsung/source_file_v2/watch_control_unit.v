`timescale 1ns / 1ps

// 시계 컨트롤 유닛 (클로드코드 참고 구현, 10/16 자리 단위 판)
// 팀 합의(정안성 · 정보윤 10/16): 초 설정 대신 분 십의 자리, 시 십의 자리는 설정 안 함
// sw_set = 0 : NORMAL (버튼 무시)
// sw_set = 1 : SET_MIN_1 에서 시작 (FND 맨 오른쪽 자리)
//              R: 오른쪽 자리로 (SET_HOUR -> SET_MIN_10 -> SET_MIN_1 -> SET_HOUR 돌아감)
//              L: 왼쪽 자리로   (SET_MIN_1 -> SET_MIN_10 -> SET_HOUR -> SET_MIN_1 돌아감)
//              U: 지금 자리 +1 (SET_MIN_10 은 분 +10), D: -1 (-10)
// cursor = FND 자리 번호(AN0 = 맨 오른쪽)와 같게: 0 분 일, 1 분 십, 2 시 일, 3 없음(NORMAL)
module watch_control_unit (
    input            clk,
    input            rst,
    input            btn_left,
    input            btn_right,
    input            btn_up,
    input            btn_down,
    input            sw_set,
    output reg       set_mode,  // 1 = 설정 중 (점멸 · LED 용)
    output reg [1:0] cursor,    // 0 분 일, 1 분 십, 2 시 일, 3 없음(NORMAL)
    output reg       o_up,      // 1클럭 펄스
    output reg       o_down     // 1클럭 펄스
);
    parameter NORMAL = 2'b00, SET_HOUR = 2'b01, SET_MIN_10 = 2'b10, SET_MIN_1 = 2'b11;
    parameter CUR_MIN_1 = 2'd0, CUR_MIN_10 = 2'd1, CUR_HOUR = 2'd2, CUR_NONE = 2'd3;

    reg [1:0] c_state, n_state;

    // 상태 레지스터
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= NORMAL;
        end else begin
            c_state <= n_state;
        end
    end

    // next state / output CL
    always @(*) begin
        n_state  = c_state;
        set_mode = 1'b1;
        cursor   = CUR_NONE;
        o_up     = 1'b0;
        o_down   = 1'b0;
        case (c_state)
            NORMAL: begin
                // moore output
                set_mode = 1'b0;
                cursor   = CUR_NONE;
                if (sw_set == 1'b1) begin
                    n_state = SET_MIN_1;  // 설정 들어가면 항상 분 일의 자리(맨 오른쪽)부터
                end
            end

            SET_HOUR: begin
                cursor = CUR_HOUR;
                if (sw_set == 1'b0) begin
                    n_state = NORMAL;
                end else if (btn_left == 1'b1) begin
                    n_state = SET_MIN_1;  // 왼쪽 끝 -> 오른쪽 끝으로 돌아감
                end else if (btn_right == 1'b1) begin
                    n_state = SET_MIN_10;
                end
            end

            SET_MIN_10: begin
                cursor = CUR_MIN_10;
                if (sw_set == 1'b0) begin
                    n_state = NORMAL;
                end else if (btn_left == 1'b1) begin
                    n_state = SET_HOUR;
                end else if (btn_right == 1'b1) begin
                    n_state = SET_MIN_1;
                end
            end

            SET_MIN_1: begin
                cursor = CUR_MIN_1;
                if (sw_set == 1'b0) begin
                    n_state = NORMAL;
                end else if (btn_left == 1'b1) begin
                    n_state = SET_MIN_10;
                end else if (btn_right == 1'b1) begin
                    n_state = SET_HOUR;  // 오른쪽 끝 -> 왼쪽 끝으로 돌아감
                end
            end
        endcase

        // mealy output: 설정 상태이고 sw_set 이 아직 1 일 때만 +/- 펄스
        // U, D 가 같은 클럭에 오면 U 우선
        if ((c_state != NORMAL) && (sw_set == 1'b1)) begin
            o_up   = btn_up;
            o_down = btn_down & ~btn_up;
        end
    end
endmodule
