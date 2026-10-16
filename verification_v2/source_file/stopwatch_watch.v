`timescale 1ns / 1ps

// 미니프로젝트 Top (클로드코드 참고 구현, v2 포트 통일)
// mode_sw0         : 0 시계, 1 스톱워치
// display_mode_sw1 : 0 초.1/100초, 1 시.분
// set_sw2          : 시계 1 = 시간 설정, 0 = normal
// hour24_sw3       : 시계 표시 0 = 12시간(오전/오후, 기본), 1 = 24시간
// timer_sw4        : 1 = 타이머 화면 · 버튼 (sw0 보다 우선)
// 버튼: 디바운서 4개 -> 화면 선택(w_sel_*) 과 AND 로 한쪽 컨트롤 유닛에만 전달 (버튼 게이팅)
// led[0] 시계, led[1] 스톱워치, led[2] 시.분 표시, led[3] 초.1/100초 표시
// led[5] 타이머 화면, led[6] 타이머 진행 중, led[7] 랩, led[15] 오후 (시계 화면 + 12시간 표시)
// 타이머 알람 중에는 led 16개 전부 0.5초 점멸
//
// v2 이름 규칙
//   모듈 입력 i_*, 출력 o_*, Top 안 와이어 w_*  (o_xxx → w_xxx → i_xxx 같은 몸통 이름)
//   기능 접두어 sw_ 스톱워치 / wt_ 시계 / tm_ 타이머,  스위치는 *_swN,  버튼은 *_btn_R/L/U/D
module stopwatch_watch (
    input         clk,
    input         rst,
    input         btn_R,
    input         btn_L,
    input         btn_U,
    input         btn_D,
    input         mode_sw0,
    input         display_mode_sw1,
    input         set_sw2,
    input         hour24_sw3,
    input         timer_sw4,
    output [ 3:0] fnd_com,
    output [ 7:0] fnd_font,
    output [15:0] led
);

    //parameter
    parameter MSEC_BIT_WIDTH = 7;
    parameter SEC_BIT_WIDTH  = 6;
    parameter MIN_BIT_WIDTH  = 6;
    parameter HOUR_BIT_WIDTH = 5;

    // 클럭 · tick
    wire w_clk_4khz;   // U_CLK_GEN_4KHZ.o_clk_4khz   (250 us 마다 1 클럭 펄스)
    wire w_tick_10ms;  // U_TICK_GEN_100HZ.o_tick_10ms (10 ms 마다 1 클럭 펄스, 스톱워치·시계·타이머 공용)
    // 디바운서 출력
    wire w_btn_R, w_btn_L, w_btn_U, w_btn_D;
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
    wire w_sw_lap;
    // 시계
    wire [1:0] w_wt_cursor;
    wire w_wt_up, w_wt_down;
    wire [MSEC_BIT_WIDTH-1:0] w_wt_msec;
    wire [ SEC_BIT_WIDTH-1:0] w_wt_sec;
    wire [ MIN_BIT_WIDTH-1:0] w_wt_min;
    wire [HOUR_BIT_WIDTH-1:0] w_wt_hour;
    wire [HOUR_BIT_WIDTH-1:0] w_wt_hour_disp;  // 12/24 변환 후
    wire w_wt_pm;
    // 타이머
    wire w_tm_run, w_tm_alarm, w_tm_clear, w_tm_add, w_tm_zero;
    wire [1:0] w_tm_amount;
    wire [MSEC_BIT_WIDTH-1:0] w_tm_msec;
    wire [ SEC_BIT_WIDTH-1:0] w_tm_sec;
    wire [ MIN_BIT_WIDTH-1:0] w_tm_min;
    // 화면 MUX 출력 (FND 로 가는 값)
    wire [MSEC_BIT_WIDTH-1:0] w_disp_msec;
    wire [ SEC_BIT_WIDTH-1:0] w_disp_sec;
    wire [ MIN_BIT_WIDTH-1:0] w_disp_min;
    wire [ MIN_BIT_WIDTH-1:0] w_disp_hour;  // (10/16) 타이머는 이 자리에 분(0~59) → 6비트
    wire w_disp_mode;
    // LED
    wire w_alarm_blink;  // 0.5초 점멸 박자 (시계 msec, 항상 흐름)


    // ---------------------------------------------------------------- 클럭 · tick
    clock_tick_generator #(
        .CLK_FRQ(4000)
    ) U_CLK_GEN_4KHZ (
        .i_clk     (clk),
        .i_rst     (rst),
        .o_clk_4khz(w_clk_4khz)
    );

    // 100hz tick 은 여기서 한 번만 만들어 세 datapath 에 공급 (항상 흐름)
    tick_gen_100hz U_TICK_GEN_100HZ (
        .i_clk      (clk),
        .i_rst      (rst),
        .o_tick_10ms(w_tick_10ms)
    );

    // ---------------------------------------------------------------- 디바운서
    btn_debounce U_BD_R (
        .i_clk     (clk),
        .i_rst     (rst),
        .i_clk_4khz(w_clk_4khz),
        .i_btn     (btn_R),
        .o_btn     (w_btn_R)
    );
    btn_debounce U_BD_L (
        .i_clk     (clk),
        .i_rst     (rst),
        .i_clk_4khz(w_clk_4khz),
        .i_btn     (btn_L),
        .o_btn     (w_btn_L)
    );
    btn_debounce U_BD_U (
        .i_clk     (clk),
        .i_rst     (rst),
        .i_clk_4khz(w_clk_4khz),
        .i_btn     (btn_U),
        .o_btn     (w_btn_U)
    );
    btn_debounce U_BD_D (
        .i_clk     (clk),
        .i_rst     (rst),
        .i_clk_4khz(w_clk_4khz),
        .i_btn     (btn_D),
        .o_btn     (w_btn_D)
    );

    // ---------------------------------------------------------------- 버튼 게이팅 (assign)
    // 화면 선택: timer_sw4 = 1 -> 타이머, 아니면 mode_sw0 = 1 -> 스톱워치, 0 -> 시계
    assign w_sel_tm = timer_sw4;
    assign w_sel_sw = ~timer_sw4 & mode_sw0;
    assign w_sel_wt = ~timer_sw4 & ~mode_sw0;

    assign w_sw_btn_R = w_btn_R & w_sel_sw;  // 시작/정지
    assign w_sw_btn_L = w_btn_L & w_sel_sw;  // 지우기
    assign w_sw_btn_U = w_btn_U & w_sel_sw;  // 업/다운
    assign w_sw_btn_D = w_btn_D & w_sel_sw;  // 랩

    assign w_wt_btn_R = w_btn_R & w_sel_wt;  // 커서 오른쪽
    assign w_wt_btn_L = w_btn_L & w_sel_wt;  // 커서 왼쪽
    assign w_wt_btn_U = w_btn_U & w_sel_wt;  // +
    assign w_wt_btn_D = w_btn_D & w_sel_wt;  // -

    assign w_tm_btn_R = w_btn_R & w_sel_tm;  // +1분
    assign w_tm_btn_L = w_btn_L & w_sel_tm;  // 시작/취소
    assign w_tm_btn_U = w_btn_U & w_sel_tm;  // +10초
    assign w_tm_btn_D = w_btn_D & w_sel_tm;  // +10분

    // ---------------------------------------------------------------- 스톱워치
    stopwatch_control_unit U_STOPWATCH_CONTROL_UNIT (
        .i_clk        (clk),
        .i_rst        (rst),
        .i_sw_btn_R   (w_sw_btn_R),
        .i_sw_btn_L   (w_sw_btn_L),
        .i_sw_btn_U   (w_sw_btn_U),
        .o_sw_run_stop(w_sw_run_stop),
        .o_sw_clear   (w_sw_clear),
        .o_sw_down    (w_sw_down)
    );

    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .i_clk        (clk),
        .i_rst        (rst),
        .i_tick_10ms  (w_tick_10ms),
        .i_sw_run_stop(w_sw_run_stop),
        .i_sw_clear   (w_sw_clear),
        .i_sw_down    (w_sw_down),
        .i_sw_btn_D   (w_sw_btn_D),
        .o_sw_msec    (w_sw_msec),
        .o_sw_sec     (w_sw_sec),
        .o_sw_min     (w_sw_min),
        .o_sw_hour    (w_sw_hour),
        .o_sw_lap     (w_sw_lap)
    );

    // ---------------------------------------------------------------- 시계
    watch_control_unit U_WATCH_CONTROL_UNIT (
        .i_clk      (clk),
        .i_rst      (rst),
        .i_wt_btn_R (w_wt_btn_R),
        .i_wt_btn_L (w_wt_btn_L),
        .i_wt_btn_U (w_wt_btn_U),
        .i_wt_btn_D (w_wt_btn_D),
        .i_set_sw2  (set_sw2),
        .o_wt_cursor(w_wt_cursor),
        .o_wt_up    (w_wt_up),
        .o_wt_down  (w_wt_down)
    );

    watch_datapath U_WATCH_DATAPATH (
        .i_clk      (clk),
        .i_rst      (rst),
        .i_tick_10ms(w_tick_10ms),
        .i_wt_cursor(w_wt_cursor),
        .i_wt_up    (w_wt_up),
        .i_wt_down  (w_wt_down),
        .o_wt_msec  (w_wt_msec),
        .o_wt_sec   (w_wt_sec),
        .o_wt_min   (w_wt_min),
        .o_wt_hour  (w_wt_hour)
    );

    // 12/24 시간 표시 변환 (시계만, 스톱워치 시간은 경과 시간이라 바꾸지 않음)
    hour_12_24 U_HOUR_12_24 (
        .i_wt_hour     (w_wt_hour),
        .i_hour24_sw3  (hour24_sw3),
        .o_wt_hour_disp(w_wt_hour_disp),
        .o_wt_pm       (w_wt_pm)
    );

    // ---------------------------------------------------------------- 타이머
    timer_control_unit U_TIMER_CONTROL_UNIT (
        .i_clk      (clk),
        .i_rst      (rst),
        .i_tm_btn_R (w_tm_btn_R),
        .i_tm_btn_L (w_tm_btn_L),
        .i_tm_btn_U (w_tm_btn_U),
        .i_tm_btn_D (w_tm_btn_D),
        .i_tm_zero  (w_tm_zero),
        .o_tm_run   (w_tm_run),
        .o_tm_alarm (w_tm_alarm),
        .o_tm_clear (w_tm_clear),
        .o_tm_add   (w_tm_add),
        .o_tm_amount(w_tm_amount)
    );

    timer_datapath U_TIMER_DATAPATH (
        .i_clk      (clk),
        .i_rst      (rst),
        .i_tick_10ms(w_tick_10ms),
        .i_tm_run   (w_tm_run),
        .i_tm_clear (w_tm_clear),
        .i_tm_add   (w_tm_add),
        .i_tm_amount(w_tm_amount),
        .o_tm_msec  (w_tm_msec),
        .o_tm_sec   (w_tm_sec),
        .o_tm_min   (w_tm_min),
        .o_tm_zero  (w_tm_zero)
    );

    // ---------------------------------------------------------------- 화면 MUX (assign)
    // timer_sw4 우선, 그다음 mode_sw0
    assign w_disp_msec = (timer_sw4) ? w_tm_msec : ((mode_sw0) ? w_sw_msec : w_wt_msec);
    assign w_disp_sec  = (timer_sw4) ? w_tm_sec  : ((mode_sw0) ? w_sw_sec  : w_wt_sec);
    // (10/16) 타이머는 시.분 칸(왼쪽 2 · 오른쪽 2)에 분 · 초를 넣고 화면을 시.분 칸으로 고정 → "분.초"
    assign w_disp_min  = (timer_sw4) ? w_tm_sec  : ((mode_sw0) ? w_sw_min  : w_wt_min);
    assign w_disp_hour = (timer_sw4) ? w_tm_min  : ((mode_sw0) ? {1'b0, w_sw_hour} : {1'b0, w_wt_hour_disp});
    assign w_disp_mode = timer_sw4 | display_mode_sw1;

    // ---------------------------------------------------------------- FND
    SW2_FND_CONTROLLER #(
        .HOUR_BIT_WIDTH(MIN_BIT_WIDTH)  // (10/16) hour 6비트: 타이머 분
    ) U_FND_CONTROLLER (
        .i_rst      (rst),
        .i_clk_4khz (w_clk_4khz),
        .i_disp_msec(w_disp_msec),
        .i_disp_sec (w_disp_sec),
        .i_disp_min (w_disp_min),
        .i_disp_hour(w_disp_hour),
        .i_disp_mode(w_disp_mode),     // (10/16) 타이머 화면은 분.초 고정
        .i_wt_cursor(w_wt_cursor),
        .i_sel_wt   (w_sel_wt),        // (10/16) 시계 화면에서만 설정 점멸
        .i_set_sw2  (set_sw2),
        .o_fnd_com  (fnd_com),
        .o_fnd_font (fnd_font)
    );

    // ---------------------------------------------------------------- LED (assign)
    assign w_alarm_blink = (w_wt_msec >= 50);
    assign led[0]    = (w_tm_alarm) ? w_alarm_blink : w_sel_wt;                               // 시계
    assign led[1]    = (w_tm_alarm) ? w_alarm_blink : w_sel_sw;                               // 스톱워치
    assign led[2]    = (w_tm_alarm) ? w_alarm_blink : (~timer_sw4 & display_mode_sw1);        // 시.분 표시 중 (타이머 화면은 끔)
    assign led[3]    = (w_tm_alarm) ? w_alarm_blink : (~timer_sw4 & ~display_mode_sw1);       // 초.1/100초 표시 중
    assign led[4]    = (w_tm_alarm) ? w_alarm_blink : 1'b0;                                   // (10/16 오후 표시는 led15 로 옮김)
    assign led[5]    = (w_tm_alarm) ? w_alarm_blink : w_sel_tm;                               // 타이머 화면
    assign led[6]    = (w_tm_alarm) ? w_alarm_blink : w_tm_run;                               // 타이머 진행 중
    assign led[7]    = (w_tm_alarm) ? w_alarm_blink : (w_sel_sw & w_sw_lap);                  // 랩타임 표시 중
    assign led[14:8] = (w_tm_alarm & w_alarm_blink) ? 7'h7f : 7'h00;                          // 알람 때만
    assign led[15]   = (w_tm_alarm) ? w_alarm_blink : (w_sel_wt & ~hour24_sw3 & w_wt_pm);     // 오후 (시계 · 12시간 표시)

endmodule
