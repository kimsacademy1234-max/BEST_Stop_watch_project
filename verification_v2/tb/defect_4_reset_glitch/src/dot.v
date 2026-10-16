`timescale 1ns / 1ps

// 0.5 초 점멸 박자 (v2 포트 통일)
// o_blink_off = 1 : 화면 1/100초 ≥ 50 (꺼지는 반 주기) → 커서 자리 빈칸, 가운데 점 꺼짐
// o_blink_off = 0 : 화면 1/100초 < 50  (켜지는 반 주기)
module dot (
    input  [6:0] i_disp_msec,
    output       o_blink_off
);

    assign o_blink_off = (i_disp_msec >= 50) ? 1 : 0;

endmodule
