`timescale 1ns / 1ps

// LED 출력 (merge) — WTS · 거리 · 온습도 LED 를 하나로
//   i_disp_sel = 0 (WTS) : 원래 stopwatch_watch 의 LED 그대로
//       led[0] 시계, led[1] 스톱워치, led[2] 시.분 표시, led[3] 초.1/100초 표시
//       led[5] 타이머 화면, led[6] 타이머 진행 중, led[7] 랩, led[15] 오후 (시계 화면 + 12시간 표시)
//   i_disp_sel = 1 (거리) : SR04 LED   led[7:0] 거리 막대, led[8] 측정 중, led[9] 측정 오류
//   i_disp_sel = 2 (온습도) : DHT11 LED led[0] 측정 중, led[1] 오류, led[2] 정상값, led[3] 자동 측정
//   타이머 알람 중에는 어느 모드든 led 16개 전부 0.5초 점멸 (타이머는 다른 화면에서도 계속 돌기 때문)
module led_output (
    input  [1:0] i_disp_sel,
    // WTS
    input        i_tm_alarm,
    input        i_tm_run,
    input  [6:0] i_wt_msec,
    input        i_wt_pm,
    input        i_sel_wt,
    input        i_sel_sw,
    input        i_sel_tm,
    input        i_sw_lap,
    input        i_display_mode_sw1,
    input        i_timer_sw4,
    input        i_hour24_sw3,
    // 센서
    input  [9:0] i_sr04_led,
    input  [3:0] i_dht_led,

    output [15:0] o_led
);

    wire        w_alarm_blink;   // 0.5초 점멸 박자 (시계 msec, 항상 흐름)
    wire [15:0] w_wts_led;
    wire [15:0] w_mode_led;

    assign w_alarm_blink = (i_wt_msec >= 50);

    assign w_wts_led[0]    = i_sel_wt;                               // 시계
    assign w_wts_led[1]    = i_sel_sw;                               // 스톱워치
    assign w_wts_led[2]    = ~i_timer_sw4 & i_display_mode_sw1;      // 시.분 표시 중 (타이머 화면은 끔)
    assign w_wts_led[3]    = ~i_timer_sw4 & ~i_display_mode_sw1;     // 초.1/100초 표시 중
    assign w_wts_led[4]    = 1'b0;
    assign w_wts_led[5]    = i_sel_tm;                               // 타이머 화면
    assign w_wts_led[6]    = i_tm_run;                               // 타이머 진행 중
    assign w_wts_led[7]    = i_sel_sw & i_sw_lap;                    // 랩타임 표시 중
    assign w_wts_led[14:8] = 7'h00;
    assign w_wts_led[15]   = i_sel_wt & ~i_hour24_sw3 & i_wt_pm;     // 오후 (시계 · 12시간 표시)

    assign w_mode_led = (i_disp_sel == 2'd1) ? {6'd0, i_sr04_led} :
                        (i_disp_sel == 2'd2) ? {12'd0, i_dht_led} : w_wts_led;

    assign o_led = (i_tm_alarm) ? {16{w_alarm_blink}} : w_mode_led;

endmodule
