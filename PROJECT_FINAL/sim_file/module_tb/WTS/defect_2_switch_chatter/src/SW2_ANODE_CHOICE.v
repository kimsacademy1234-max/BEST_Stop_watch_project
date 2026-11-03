`timescale 1ns / 1ps

// 설정 점멸 (v2 포트 통일)
// 시계 화면(i_sel_wt) · 설정(i_set_sw2) · 시.분 표시(i_disp_mode) 이고 i_blink_off = 1 이면
// i_wt_cursor 가 가리키는 자리를 4'hd(빈칸)로 바꿈. 그 외에는 그대로 통과.
// i_an0 = 맨 오른쪽 자리(AN0) ... i_an3 = 맨 왼쪽 자리(AN3)
// (v2) 원본 조건 {sw_2, sw_1, sw_0} == 3'b110 (sw_0 = sw_mode | sw_timer)
//      = set & disp_mode & ~(sw_mode | sw_timer) = set & disp_mode & sel_wt (동작 동일)
module SW2_ANODE_CHOICE (
    input        i_set_sw2,
    input        i_disp_mode,
    input        i_sel_wt,
    input  [1:0] i_wt_cursor,
    input        i_blink_off,
    input  [3:0] i_an0,
    input  [3:0] i_an1,
    input  [3:0] i_an2,
    input  [3:0] i_an3,

    output [3:0] o_an0,
    output [3:0] o_an1,
    output [3:0] o_an2,
    output [3:0] o_an3
);

    reg [15:0] r_an;

    always @(*) begin
        if (i_set_sw2 & i_disp_mode & i_sel_wt) begin
            if (!i_blink_off) begin
                r_an = {i_an0, i_an1, i_an2, i_an3};
            end else begin
                case (i_wt_cursor)
                    2'b00: r_an = {4'hd, i_an1, i_an2, i_an3};  // 분 일 (AN0)
                    2'b01: r_an = {i_an0, 4'hd, i_an2, i_an3};  // 분 십 (AN1)
                    2'b10: r_an = {i_an0, i_an1, 4'hd, i_an3};  // 시 일 (AN2)
                    2'b11: r_an = {i_an0, i_an1, i_an2, i_an3};
                endcase
            end
        end else begin
            r_an = {i_an0, i_an1, i_an2, i_an3};
        end
    end

    assign o_an0 = r_an[15:12];
    assign o_an1 = r_an[11:8];
    assign o_an2 = r_an[7:4];
    assign o_an3 = r_an[3:0];

endmodule
