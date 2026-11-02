`timescale 1ns / 1ps

// 미니프로젝트 Top
// sw_mode(sw0)        : 0 시계, 1 스톱워치
// sw_display_mode(sw1): 0 초.1/100초, 1 시.분
// sw_set(sw2)         : 시계 1 = 시간 설정, 0 = normal
// sw_24h(sw3)         : 시계 표시 0 = 12시간(오전/오후, 기본), 1 = 24시간 (10/16 극성 바꿈)
// 버튼: 디바운서 4개 -> sw_mode 와 AND 로 한쪽 컨트롤 유닛에만 전달 (Top Clock 판서)
// led[0] 시계, led[1] 스톱워치, led[2] 시.분 표시, led[3] 초.1/100초 표시
// led[15] 오후(PM) — 시계 화면 + 12시간 표시일 때만 (10/16 led4 → led15)
// sw_timer(sw4)       : 1 = 타이머(빠른 알람) 화면 · 버튼 (sw0 보다 우선)
// 타이머 (10/16): U +10초 · R +1분 · D +10분, 최대 59:59, 화면은 항상 분.초 (sw1 무시), sw5 없앰
// led[5] 타이머 화면, led[6] 타이머 진행 중, 알람 중에는 led 16개 전부 0.5초 점멸
module stopwatch_watch (
    input        clk,
    input        rst,
    input        btnR,
    input        btnL,
    input        btnU,
    input        btnD,
    input        sw_mode,
    input        sw_display_mode,
    input        sw_set,
    input        sw_24h,
    input        sw_timer,
    output [3:0] fnd_com,
    output [7:0] fnd_font,
    output [15:0] led
);

    //parameter
    parameter MSEC_BIT_WIDTH = 7;
    parameter SEC_BIT_WIDTH = 6;
    parameter MIN_BIT_WIDTH = 6;
    parameter HOUR_BIT_WIDTH = 5;

    // 디바운스 출력
    wire w_btnR, w_btnL, w_btnU, w_btnD;
    // 스톱워치 쪽
    wire w_sw_btn_run_stop, w_sw_btn_clear, w_sw_btn_mode;
    wire w_run_stop, w_clear, w_mode;
    wire w_sw_btn_lap, w_lap_active;
    wire [MSEC_BIT_WIDTH-1:0] w_sw_msec;
    wire [ SEC_BIT_WIDTH-1:0] w_sw_sec;
    wire [ MIN_BIT_WIDTH-1:0] w_sw_min;
    wire [HOUR_BIT_WIDTH-1:0] w_sw_hour;
    // 시계 쪽
    wire w_wt_btn_right, w_wt_btn_left, w_wt_btn_up, w_wt_btn_down;
    wire w_set_mode, w_up, w_down;
    wire [1:0] w_cursor;
    wire [MSEC_BIT_WIDTH-1:0] w_wt_msec;
    wire [ SEC_BIT_WIDTH-1:0] w_wt_sec;
    wire [ MIN_BIT_WIDTH-1:0] w_wt_min;
    wire [HOUR_BIT_WIDTH-1:0] w_wt_hour;
    wire [HOUR_BIT_WIDTH-1:0] w_wt_hour_disp;  // 12/24 변환 후
    wire w_pm;
    // 타이머 쪽
    wire w_tm_btn_right, w_tm_btn_left, w_tm_btn_up, w_tm_btn_down;
    wire w_tm_run, w_tm_alarm, w_tm_clear, w_tm_add, w_tm_zero;
    wire [1:0] w_tm_amount;
    wire [MSEC_BIT_WIDTH-1:0] w_tm_msec;
    wire [ SEC_BIT_WIDTH-1:0] w_tm_sec;
    wire [ MIN_BIT_WIDTH-1:0] w_tm_min;
    wire [HOUR_BIT_WIDTH-1:0] w_tm_hour;
    // 지금 버튼 · 화면을 받는 쪽 (셋 중 하나만 1)
    wire w_sel_sw, w_sel_wt, w_sel_tm;
    wire w_blink;  // 0.5초 점멸 박자 (시계 msec, 항상 흐름)
    // 화면으로 가는 값
    wire [MSEC_BIT_WIDTH-1:0] w_msec;
    wire [ SEC_BIT_WIDTH-1:0] w_sec;
    wire [ MIN_BIT_WIDTH-1:0] w_min;
    wire [MIN_BIT_WIDTH-1:0]  w_hour;   // (10/16) 타이머는 이 자리에 분(0~59) → 6비트
    wire w_disp_mode;
    wire w_clk_4Khz;
    wire w_tick_10ms;  // 100hz tick (스톱워치·시계·타이머 공용)


   clock_tick_generator#(
		.CLK_FRQ(4000)
		
   ) U_CLK_GEN_4KHz(
  

            .i_clk(clk),
            .i_reset(rst),
            .o_clk(w_clk_4Khz)

           );




    btn_debounce U_BD_R (
        .clk_remake(w_clk_4Khz),
        .clk  (clk),
        .reset(rst),
        .i_btn(btnR),
        .o_btn(w_btnR)
    );
    btn_debounce U_BD_L (
        .clk_remake(w_clk_4Khz),
        .clk  (clk),
        .reset(rst),
        .i_btn(btnL),
        .o_btn(w_btnL)
    );
    btn_debounce U_BD_U (
        .clk_remake(w_clk_4Khz),
        .clk  (clk),
        .reset(rst),
        .i_btn(btnU),
        .o_btn(w_btnU)
    );
    btn_debounce U_BD_D (
        .clk_remake(w_clk_4Khz),
        .clk  (clk),
        .reset(rst),
        .i_btn(btnD),
        .o_btn(w_btnD)
    );

    // 100hz tick 은 여기서 한 번만 만들어 세 datapath 에 공급 (항상 흐름)
    tick_gen_100hz U_TICK_GEN_100HZ (
        .clk     (clk),
        .rst     (rst),
        .run_stop(1'b1),
        .clear   (1'b0),
        .o_tick  (w_tick_10ms)
    );

    // 버튼 · 화면 선택: sw_timer = 1 -> 타이머, 아니면 sw_mode = 1 -> 스톱워치, 0 -> 시계
    assign w_sel_tm = sw_timer;
    assign w_sel_sw = ~sw_timer & sw_mode;
    assign w_sel_wt = ~sw_timer & ~sw_mode;

    // 버튼 게이팅
    assign w_sw_btn_run_stop = w_btnR & w_sel_sw;
    assign w_sw_btn_clear    = w_btnL & w_sel_sw;
    assign w_sw_btn_mode     = w_btnU & w_sel_sw;
    assign w_sw_btn_lap      = w_btnD & w_sel_sw;

    assign w_wt_btn_right = w_btnR & w_sel_wt;
    assign w_wt_btn_left  = w_btnL & w_sel_wt;
    assign w_wt_btn_up    = w_btnU & w_sel_wt;
    assign w_wt_btn_down  = w_btnD & w_sel_wt;

    assign w_tm_btn_right = w_btnR & w_sel_tm;
    assign w_tm_btn_left  = w_btnL & w_sel_tm;
    assign w_tm_btn_up    = w_btnU & w_sel_tm;
    assign w_tm_btn_down  = w_btnD & w_sel_tm;

    // 스톱워치
    stopwatch_control_unit U_STOPWATCH_CONTROL_UNIT (
        .clk         (clk),
        .reset       (rst),
        .btn_run_stop(w_sw_btn_run_stop),
        .btn_clear   (w_sw_btn_clear),
        .btn_mode    (w_sw_btn_mode),
        .run_stop    (w_run_stop),
        .clear       (w_clear),
        .mode        (w_mode)
    );

    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .clk     (clk),
        .rst     (rst),
        .i_tick_10ms(w_tick_10ms),
        .run_stop(w_run_stop),
        .clear   (w_clear),
        .mode    (w_mode),
        .btn_lap (w_sw_btn_lap),
        .msec    (w_sw_msec),
        .sec     (w_sw_sec),
        .min     (w_sw_min),
        .hour    (w_sw_hour),
        .lap_active(w_lap_active)
    );

    // 시계
    watch_control_unit U_WATCH_CONTROL_UNIT (
        .clk      (clk),
        .rst      (rst),
        .btn_left (w_wt_btn_left),
        .btn_right(w_wt_btn_right),
        .btn_up   (w_wt_btn_up),
        .btn_down (w_wt_btn_down),
        .sw_set   (sw_set),
        .set_mode (w_set_mode),
        .cursor   (w_cursor),
        .o_up     (w_up),
        .o_down   (w_down)
    );

    watch_datapath U_WATCH_DATAPATH (
        .clk   (clk),
        .rst   (rst),
        .i_tick_10ms(w_tick_10ms),
        .cursor(w_cursor),
        .i_up  (w_up),
        .i_down(w_down),
        .msec  (w_wt_msec),
        .sec   (w_wt_sec),
        .min   (w_wt_min),
        .hour  (w_wt_hour)
    );

    // 12/24 시간 표시 변환 (시계만, 스톱워치 시간은 경과 시간이라 바꾸지 않음)
    hour_12_24 U_HOUR_12_24 (
        .sw_12h(~sw_24h),   // sw3 = 0 이면 12시간
        .i_hour(w_wt_hour),
        .o_hour(w_wt_hour_disp),
        .pm    (w_pm)
    );

    // 타이머
    timer_control_unit U_TIMER_CONTROL_UNIT (
        .clk      (clk),
        .rst      (rst),
        .btn_left (w_tm_btn_left),
        .btn_right(w_tm_btn_right),
        .btn_up   (w_tm_btn_up),
        .btn_down (w_tm_btn_down),
        .i_zero   (w_tm_zero),
        .run      (w_tm_run),
        .alarm    (w_tm_alarm),
        .o_clear  (w_tm_clear),
        .o_add    (w_tm_add),
        .amount   (w_tm_amount)
    );

    timer_datapath U_TIMER_DATAPATH (
        .clk   (clk),
        .rst   (rst),
        .i_tick_10ms(w_tick_10ms),
        .run   (w_tm_run),
        .clear (w_tm_clear),
        .add   (w_tm_add),
        .amount(w_tm_amount),
        .msec  (w_tm_msec),
        .sec   (w_tm_sec),
        .min   (w_tm_min),
        .hour  (w_tm_hour),
        .zero  (w_tm_zero)
    );

    // 화면 선택 MUX (sw_timer 우선, 그다음 sw_mode)
    assign w_msec = (sw_timer) ? w_tm_msec : ((sw_mode) ? w_sw_msec : w_wt_msec);
    assign w_sec  = (sw_timer) ? w_tm_sec  : ((sw_mode) ? w_sw_sec  : w_wt_sec);
    // (10/16) 타이머는 시.분 칸(왼쪽 2 · 오른쪽 2)에 분 · 초를 넣고 화면을 시.분 칸으로 고정 → "분.초"
    assign w_min  = (sw_timer) ? w_tm_sec  : ((sw_mode) ? w_sw_min  : w_wt_min);
    assign w_hour = (sw_timer) ? w_tm_min  : ((sw_mode) ? {1'b0, w_sw_hour} : {1'b0, w_wt_hour_disp});
    assign w_disp_mode = sw_timer | sw_display_mode;


SW2_FND_CONTROLLER #(.HOUR_BIT_WIDTH(MIN_BIT_WIDTH)) FND_CON(   // (10/16) hour 6비트: 타이머 분

    .i_cursor(w_cursor),
    .i_clk_remake(w_clk_4Khz),
    .i_clk(clk),
    .i_reset(rst),
	.i_msec(w_msec),
	.i_sec(w_sec),
	.i_min(w_min),
	.i_hour(w_hour),
	.i_sw_display_mode(w_disp_mode),   // (10/16) 타이머 화면은 분.초 고정
	.i_btn_R(w_btnR),
	.i_btn_L(w_btnL),
	.i_sw_0(sw_mode | sw_timer),       // (10/16) 타이머 화면에서는 시계 점멸 안 함
	.i_sw_2(sw_set),

    .o_fnd_com(fnd_com),
    .o_fnd_data(fnd_font)

);




    assign w_blink = (w_wt_msec >= 50);
    assign led[0]  = (w_tm_alarm) ? w_blink : w_sel_wt;                    // 시계
    assign led[1]  = (w_tm_alarm) ? w_blink : w_sel_sw;                    // 스톱워치
    assign led[2]  = (w_tm_alarm) ? w_blink : (~sw_timer & sw_display_mode);   // 시.분 표시 중 (타이머 화면은 끔)
    assign led[3]  = (w_tm_alarm) ? w_blink : (~sw_timer & ~sw_display_mode);  // 초.1/100초 표시 중
    assign led[4]  = (w_tm_alarm) ? w_blink : 1'b0;                        // (10/16 오후 표시는 led15 로 옮김)
    assign led[5]  = (w_tm_alarm) ? w_blink : w_sel_tm;                    // 타이머 화면
    assign led[6]  = (w_tm_alarm) ? w_blink : w_tm_run;                    // 타이머 진행 중
    assign led[7]  = (w_tm_alarm) ? w_blink : (w_sel_sw & w_lap_active);   // 랩타임 표시 중
    assign led[14:8] = (w_tm_alarm & w_blink) ? 7'h7f : 7'h00;             // 알람 때만
    assign led[15]   = (w_tm_alarm) ? w_blink : (w_sel_wt & ~sw_24h & w_pm);  // 오후 (시계 · 12시간 표시)

endmodule
