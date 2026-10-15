`timescale 1ns / 1ps

// 시계 컨트롤 유닛 (클로드코드 참고 구현)
// sw_set = 0 : NORMAL (버튼 무시)
// sw_set = 1 : SET_HOUR -> SET_MIN -> SET_SEC (R: 오른쪽, L: 왼쪽, 양 끝은 돌아감)
//              U: 지금 칸 +1, D: 지금 칸 -1
module watch_control_unit (
    input            clk,
    input            rst,
    input            btn_left,
    input            btn_right,
    input            btn_up,
    input            btn_down,
    input            sw_set,
    output reg       set_mode,  // 1 = 설정 중 (점멸 · LED 용)
    output reg [1:0] cursor,    // 0 sec, 1 min, 2 hour, 3 없음(NORMAL)
    output reg       o_up,      // 1클럭 펄스
    output reg       o_down     // 1클럭 펄스
);
    parameter NORMAL = 2'b00, SET_HOUR = 2'b01, SET_MIN = 2'b10, SET_SEC = 2'b11;
    parameter CUR_SEC = 2'd0, CUR_MIN = 2'd1, CUR_HOUR = 2'd2, CUR_NONE = 2'd3;

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
                    n_state = SET_HOUR;  // 설정 들어가면 항상 시(hour) 칸부터
                end
            end

            SET_HOUR: begin
                cursor = CUR_HOUR;
                if (sw_set == 1'b0) begin
                    n_state = NORMAL;
                end else if (btn_left == 1'b1) begin
                    n_state = SET_SEC;  // 왼쪽 끝 -> 오른쪽 끝으로 돌아감
                end else if (btn_right == 1'b1) begin
                    n_state = SET_MIN;
                end
            end

            SET_MIN: begin
                cursor = CUR_MIN;
                if (sw_set == 1'b0) begin
                    n_state = NORMAL;
                end else if (btn_left == 1'b1) begin
                    n_state = SET_HOUR;
                end else if (btn_right == 1'b1) begin
                    n_state = SET_SEC;
                end
            end

            SET_SEC: begin
                cursor = CUR_SEC;
                if (sw_set == 1'b0) begin
                    n_state = NORMAL;
                end else if (btn_left == 1'b1) begin
                    n_state = SET_MIN;
                end else if (btn_right == 1'b1) begin
                    n_state = SET_HOUR;  // 오른쪽 끝 -> 왼쪽 끝으로 돌아감
                end
            end
        endcase

        // mealy output: 설정 상태이고 sw_set 이 아직 1 일 때만 +1/-1 펄스
        // U, D 가 같은 클럭에 오면 U 우선
        if ((c_state != NORMAL) && (sw_set == 1'b1)) begin
            o_up   = btn_up;
            o_down = btn_down & ~btn_up;
        end
    end
endmodule
