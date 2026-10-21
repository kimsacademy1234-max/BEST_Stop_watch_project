`timescale 1ns / 1ps

// 12시간 / 24시간 표시 변환 (조합회로, v2 포트 통일)
// 시계 내부는 항상 24시간(0~23)으로 세고, 화면에 보낼 때만 바꾼다.
// i_hour24_sw3 = 1 : 그대로 (0~23)
// i_hour24_sw3 = 0 : 0 -> 12, 1~12 -> 그대로, 13~23 -> -12   (o_wt_pm = 1 이면 오후)
// (v2) 원본은 Top 에서 ~sw_24h 를 sw_12h 로 넣었음 → 스위치를 그대로 받고 안에서 판단 (동작 동일)
module hour_12_24 #(
    parameter HOUR_BIT_WIDTH = 5
) (
    input      [HOUR_BIT_WIDTH-1:0] i_wt_hour,
    input                           i_hour24_sw3,
    output reg [HOUR_BIT_WIDTH-1:0] o_wt_hour_disp,
    output                          o_wt_pm
);

    assign o_wt_pm = (i_wt_hour >= 12);

    always @(*) begin
        if (i_hour24_sw3 == 1'b1) begin
            o_wt_hour_disp = i_wt_hour;
        end else if (i_wt_hour == 0) begin
            o_wt_hour_disp = 12;              // 자정 00시 -> 오전 12시
        end else if (i_wt_hour > 12) begin
            o_wt_hour_disp = i_wt_hour - 12;  // 13~23시 -> 오후 1~11시
        end else begin
            o_wt_hour_disp = i_wt_hour;       // 1~12시
        end
    end

endmodule
