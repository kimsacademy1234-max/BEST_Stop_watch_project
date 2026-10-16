`timescale 1ns / 1ps

// 12시간 / 24시간 표시 변환 (클로드코드 참고 구현, 조합회로)
// 시계 내부는 항상 24시간(0~23)으로 세고, 화면에 보낼 때만 바꾼다.
// sw_12h = 0 : 그대로 (0~23)
// sw_12h = 1 : 0 -> 12, 1~12 -> 그대로, 13~23 -> -12   (pm = 1 이면 오후)
module hour_12_24 #(
    parameter HOUR_BIT_WIDTH = 5
) (
    input                           sw_12h,
    input      [HOUR_BIT_WIDTH-1:0] i_hour,
    output reg [HOUR_BIT_WIDTH-1:0] o_hour,
    output                          pm
);

    assign pm = (i_hour >= 12);

    always @(*) begin
        if (sw_12h == 1'b0) begin
            o_hour = i_hour;
        end else if (i_hour == 0) begin
            o_hour = 12;            // 자정 00시 -> 오전 12시
        end else if (i_hour > 12) begin
            o_hour = i_hour - 12;   // 13~23시 -> 오후 1~11시
        end else begin
            o_hour = i_hour;        // 1~12시
        end
    end

endmodule
