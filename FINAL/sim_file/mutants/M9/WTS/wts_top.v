`timescale 1ns / 1ps

// WTS (스톱워치 · 시계 · 타이머) 하위 Top (merge)
//  원래 stopwatch_watch 에서 4 kHz 클럭 · 버튼 디바운서 · FND_CONTROLLER · LED 를 뺀 것
//  (디바운서 · 4 kHz · FND · LED 는 Top 에서 DHT11 · SR04 와 같이 쓰는 통합 모듈로)
//  - i_btn_* : Top 의 공용 디바운서 (물리 | UART /btn) 출력, WTS 모드일 때만 들어옴
//  - 스위치 입력 = module_control_bit[4:0] (UART 연결 전 : 보드 스위치, 첫 /mod 뒤 : UART 값)
//  - o_disp_* : 화면 MUX 출력 → Top 의 FND 데이터 MUX
//  - o_*_time : UART 전송용 {hour 5, min 6, sec 6, cs 7} (sender_char_mux 비트 배치)
// 이름 규칙은 v2 그대로 : 모듈 입력 i_*, 출력 o_*, 와이어 w_*
module wts_top (
    input        i_clk,
    input        i_rst,
    input        i_btn_R,
    input        i_btn_L,
    input        i_btn_U,
    input        i_btn_D,
    input        i_mode_sw0,           // 0 시계, 1 스톱워치
    input        i_display_mode_sw1,   // 0 초.1/100초, 1 시.분
    input        i_set_sw2,            // 시계 1 = 시간 설정
    input        i_hour24_sw3,         // 0 = 12시간, 1 = 24시간
    input        i_timer_sw4,          // 1 = 타이머 (sw0 보다 우선)
    // FND 쪽
    output [6:0] o_disp_msec,
    output [5:0] o_disp_sec,
    output [5:0] o_disp_min,
    output [5:0] o_disp_hour,
    output       o_disp_mode,
    output [1:0] o_wt_cursor,
    // LED 쪽
    output       o_sel_sw,
    output       o_sel_wt,
    output       o_sel_tm,
    output       o_sw_lap,
    output [6:0] o_wt_msec,
    output       o_wt_pm,
    output       o_tm_run,
    output       o_tm_alarm,
    // UART 전송 쪽
    output [23:0] o_sw_time,
    output [23:0] o_tm_time,
    output [23:0] o_wt_time
);

    //parameter
    parameter MSEC_BIT_WIDTH = 7;
    parameter SEC_BIT_WIDTH  = 6;
    parameter MIN_BIT_WIDTH  = 6;
    parameter HOUR_BIT_WIDTH = 5;

    // tick
    wire w_tick_10ms;     // 시계 전용 · 항상 흐름
    wire w_sw_tick_10ms;  // 스톱워치 전용, 시작 순간부터 셈
    wire w_tm_tick_10ms;  // 타이머 전용, 시작 순간부터 셈
    wire w_tm_tick_clear; // 취소 또는 알람
    // 화면 선택 (셋 중 하나만 1)
    wire w_sel_sw, w_sel_wt, w_sel_tm;
    // 버튼 게이팅 출력
    wire w_sw_btn_R, w_sw_btn_L, w_sw_btn_U, w_sw_btn_D;
    wire w_wt_btn_R, w_wt_btn_L, w_wt_btn_U, w_wt_btn_D;
    wire w_tm_btn_R, w_tm_btn_L, w_tm_btn_U, w_tm_btn_D;
    // 스톱워치
    wire w_sw_run_stop, w_sw_clear, w_sw_down;
    wire [MSEC_BIT_WIDTH-1:0] w_sw_msec;
    wire [ SEC_BIT_WIDTH-1:0] w_sw_sec;
    wire [ MIN_BIT_WIDTH-1:0] w_sw_min;
    wire [HOUR_BIT_WIDTH-1:0] w_sw_hour;
    // 시계
    wire w_wt_up, w_wt_down;
    wire [ SEC_BIT_WIDTH-1:0] w_wt_sec;
    wire [ MIN_BIT_WIDTH-1:0] w_wt_min;
    wire [HOUR_BIT_WIDTH-1:0] w_wt_hour;
    wire [HOUR_BIT_WIDTH-1:0] w_wt_hour_disp;  // 12/24 변환 후
    // 타이머
    wire w_tm_clear, w_tm_add, w_tm_zero;
    wire [1:0] w_tm_amount;
    wire [MSEC_BIT_WIDTH-1:0] w_tm_msec;
    wire [ SEC_BIT_WIDTH-1:0] w_tm_sec;
    wire [ MIN_BIT_WIDTH-1:0] w_tm_min;


    // ---------------------------------------------------------------- tick
    tick_gen_100hz U_TICK_GEN_100HZ (
        .i_clk      (i_clk),
        .i_rst      (i_rst),
        .o_tick_10ms(w_tick_10ms)
    );

    tick_gen_100hz_run U_TICK_GEN_SW (
        .i_clk      (i_clk),
        .i_rst      (i_rst),
        .i_run_stop (w_sw_run_stop),
        .i_clear    (w_sw_clear),
        .o_tick_10ms(w_sw_tick_10ms)
    );

    assign w_tm_tick_clear = w_tm_clear | o_tm_alarm;

    tick_gen_100hz_run U_TICK_GEN_TM (
        .i_clk      (i_clk),
        .i_rst      (i_rst),
        .i_run_stop (o_tm_run),
        .i_clear    (w_tm_tick_clear),
        .o_tick_10ms(w_tm_tick_10ms)
    );

    // ---------------------------------------------------------------- 버튼 게이팅 (assign)
    // 화면 선택: timer_sw4 = 1 -> 타이머, 아니면 mode_sw0 = 1 -> 스톱워치, 0 -> 시계
    assign w_sel_tm = i_timer_sw4;
    assign w_sel_sw = ~i_timer_sw4 & i_mode_sw0;
    assign w_sel_wt = ~i_timer_sw4 & ~i_mode_sw0;

    assign o_sel_sw = w_sel_sw;
    assign o_sel_wt = w_sel_wt;
    assign o_sel_tm = w_sel_tm;

    assign w_sw_btn_R = i_btn_R & w_sel_sw;  // 시작/정지
    assign w_sw_btn_L = i_btn_L & w_sel_sw;  // 지우기
    assign w_sw_btn_U = i_btn_U & w_sel_sw;  // 업/다운
    assign w_sw_btn_D = i_btn_D & w_sel_sw;  // 랩

    assign w_wt_btn_R = i_btn_R & w_sel_wt;  // 커서 오른쪽
    assign w_wt_btn_L = i_btn_L & w_sel_wt;  // 커서 왼쪽
    assign w_wt_btn_U = i_btn_U & w_sel_wt;  // +
    assign w_wt_btn_D = i_btn_D & w_sel_wt;  // -

    assign w_tm_btn_R = i_btn_R & w_sel_tm;  // +1분
    assign w_tm_btn_L = i_btn_L & w_sel_tm;  // 시작/취소
    assign w_tm_btn_U = i_btn_U & w_sel_tm;  // +10초
    assign w_tm_btn_D = i_btn_D & w_sel_tm;  // +10분

    // ---------------------------------------------------------------- 스톱워치
    stopwatch_control_unit U_STOPWATCH_CONTROL_UNIT (
        .i_clk        (i_clk),
        .i_rst        (i_rst),
        .i_sw_btn_R   (w_sw_btn_R),
        .i_sw_btn_L   (w_sw_btn_L),
        .i_sw_btn_U   (w_sw_btn_U),
        .o_sw_run_stop(w_sw_run_stop),
        .o_sw_clear   (w_sw_clear),
        .o_sw_down    (w_sw_down)
    );

    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .i_clk      (i_clk),
        .i_rst      (i_rst),
        .i_tick_10ms(w_sw_tick_10ms),
        .i_sw_clear (w_sw_clear),
        .i_sw_down  (w_sw_down),
        .i_sw_btn_D (w_sw_btn_D),
        .o_sw_msec  (w_sw_msec),
        .o_sw_sec   (w_sw_sec),
        .o_sw_min   (w_sw_min),
        .o_sw_hour  (w_sw_hour),
        .o_sw_lap   (o_sw_lap)
    );

    // ---------------------------------------------------------------- 시계
    watch_control_unit U_WATCH_CONTROL_UNIT (
        .i_clk      (i_clk),
        .i_rst      (i_rst),
        .i_wt_btn_R (w_wt_btn_R),
        .i_wt_btn_L (w_wt_btn_L),
        .i_wt_btn_U (w_wt_btn_U),
        .i_wt_btn_D (w_wt_btn_D),
        .i_set_sw2  (i_set_sw2),
        .o_wt_cursor(o_wt_cursor),
        .o_wt_up    (w_wt_up),
        .o_wt_down  (w_wt_down)
    );

    watch_datapath U_WATCH_DATAPATH (
        .i_clk      (i_clk),
        .i_rst      (i_rst),
        .i_tick_10ms(w_tick_10ms),
        .i_wt_cursor(o_wt_cursor),
        .i_wt_up    (w_wt_up),
        .i_wt_down  (w_wt_down),
        .o_wt_msec  (o_wt_msec),
        .o_wt_sec   (w_wt_sec),
        .o_wt_min   (w_wt_min),
        .o_wt_hour  (w_wt_hour)
    );

    hour_12_24 U_HOUR_12_24 (
        .i_wt_hour     (w_wt_hour),
        .i_hour24_sw3  (i_hour24_sw3),
        .o_wt_hour_disp(w_wt_hour_disp),
        .o_wt_pm       (o_wt_pm)
    );

    // ---------------------------------------------------------------- 타이머
    timer_control_unit U_TIMER_CONTROL_UNIT (
        .i_clk      (i_clk),
        .i_rst      (i_rst),
        .i_tm_btn_R (w_tm_btn_R),
        .i_tm_btn_L (w_tm_btn_L),
        .i_tm_btn_U (w_tm_btn_U),
        .i_tm_btn_D (w_tm_btn_D),
        .i_tm_zero  (w_tm_zero),
        .o_tm_run   (o_tm_run),
        .o_tm_alarm (o_tm_alarm),
        .o_tm_clear (w_tm_clear),
        .o_tm_add   (w_tm_add),
        .o_tm_amount(w_tm_amount)
    );

    timer_datapath U_TIMER_DATAPATH (
        .i_clk      (i_clk),
        .i_rst      (i_rst),
        .i_tick_10ms(w_tm_tick_10ms),
        .i_tm_run   (o_tm_run),
        .i_tm_clear (w_tm_clear),
        .i_tm_add   (w_tm_add),
        .i_tm_amount(w_tm_amount),
        .o_tm_msec  (w_tm_msec),
        .o_tm_sec   (w_tm_sec),
        .o_tm_min   (w_tm_min),
        .o_tm_zero  (w_tm_zero)
    );

    // ---------------------------------------------------------------- 화면 MUX (assign)
    // timer_sw4 우선, 그다음 mode_sw0. 타이머는 시.분 칸에 분 · 초 → "분.초"
    assign o_disp_msec = (i_timer_sw4) ? w_tm_msec : ((i_mode_sw0) ? w_sw_msec : o_wt_msec);
    assign o_disp_sec  = (i_timer_sw4) ? w_tm_sec  : ((i_mode_sw0) ? w_sw_sec  : w_wt_sec);
    assign o_disp_min  = (i_timer_sw4) ? w_tm_sec  : ((i_mode_sw0) ? w_sw_min  : w_wt_min);
    assign o_disp_hour = (i_timer_sw4) ? w_tm_min  : ((i_mode_sw0) ? {1'b0, w_sw_hour} : {1'b0, w_wt_hour_disp});
    assign o_disp_mode = i_timer_sw4 | i_display_mode_sw1;

    // ---------------------------------------------------------------- UART 전송 데이터
    // {hour 5, min 6, sec 6, cs 7}. 시계는 24시간 값 그대로, 타이머는 hour 자리 0
    assign o_sw_time = {w_sw_hour, w_sw_min, w_sw_sec, w_sw_msec};
    assign o_tm_time = {5'd0, w_tm_min, w_tm_sec, w_tm_msec};
    assign o_wt_time = {w_wt_hour, w_wt_min, w_wt_sec, o_wt_msec};

endmodule
