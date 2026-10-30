`timescale 1ns / 1ps
// =============================================================================
//  HC-SR04 Ultrasonic Distance Controller
//  - System clock : 100 MHz
//  - Tick         : 1 us (tick_gen_us, FSM이 enable / clear 제어)
//  - echo 입력    : 2-FF synchronizer 통과 (외부 신호 = CDC, 메타스테이블 대비)
//  - 거리 계산    : 나누기(/58) 대신 58us 모듈러 카운터 -> cm 카운터 증가
//                   + 0.1cm 단위: 1us 마다 +10 누적, 58 넘으면 0.1cm +1 (나눗셈 없음)
//  - 출력 distance    : 9bit,  0 ~ 400 cm   (UART / 통합용)
//         distance_x10: 12bit, 0 ~ 4000 (0.1cm 단위, FND "352.7" 표시용)
//  - 측정 주기    : trig 상승 기준 최소 60ms (HC-SR04 제조사 권장)
//  - 자동 연속 측정: auto_en = 1 -> busy 가 풀릴 때마다 자동 시작 (60ms 주기)
//                   (auto_en 은 UART 명령으로 ON, 버튼으로 OFF : sr04_mode_ctrl)
//  - 상태 구분    : status 00 OK / 01 NO_ECHO / 10 OUT_RANGE / 11 ECHO_STUCK
//  - 오류 복귀    : echo 가 계속 1 이면 STOP 에서 50ms 후 강제 IDLE (데드락 방지)
//  - LED 표시     : LD0~7 거리 막대(스위치로 ON/OFF), LD8 측정 중, LD9 측정 오류
//
//  FSM : IDLE -> START(trig 11us) -> WAIT(echo=1) -> DIST(echo=0)
//        -> STOP(echo 하강 후 10ms & 주기 60ms 경과) -> IDLE
// =============================================================================

// -----------------------------------------------------------------------------
//  Top (보드 단독 테스트용, 10/29 수업 구성)
//   btnR -> button_debouncer -> sr04_start -> SR04 -> distance(9bit) -> FND
//   * button_debouncer 는 이전 실습 모듈, FND 는 fnd_controller_dist 사용
//   * 팀 프로젝트 통합 시에는 sr04_start 를 U_CONTROL(버튼 | UART 명령)에서 주고
//     w_distance / w_done / w_busy 를 U_CONTROL / ASCII_SENDER 로 연결
// -----------------------------------------------------------------------------
module top_sr04 (
    input        clk,
    input        rst,       // btnC
    input        btnR,      // 측정 버튼 : 수동 모드 1회 측정 / 자동 모드 해제
    input        btnU,      // 누르고 있는 동안 자동 측정 (떼면 수동 모드)
    input        sw_led,    // SW15 : 거리 막대 LED ON/OFF
    input        echo,      // Pmod JA2
    output       trig,      // Pmod JA1
    output [3:0] fnd_com,
    output [7:0] fnd_font,
    output [9:0] led        // LD0~7 거리 막대 / LD8 측정 중 / LD9 측정 오류
);

    wire        w_btn_tick;      // btnR 1클록 tick
    wire        w_auto_hold;     // btnU 누르고 있는 동안 1 (동기화된 레벨)
    wire        w_auto_cmd_en;   // UART 명령으로 켠 자동 모드 (통합용, 단독 테스트에선 0)
    wire        w_sr04_start;    // 1회 측정 요청
    wire        w_auto_en;       // 자동 측정 모드
    wire [8:0]  w_distance;
    wire [11:0] w_distance_x10;
    wire [1:0]  w_status;
    wire        w_measuring;
    wire        w_led_err;       // 마지막 측정 실패 (LD9 / FND "----")
    wire        w_busy;
    wire        w_done;
    wire [2:0]  w_state;

    button_debouncer U_BTN_DB (
        .i_clk   (clk),
        .i_reset (rst),
        .i_btn   (btnR),
        .o_btn   (w_btn_tick)
    );

    // btnU : 누르고 있는 동안만 자동 측정 -> tick 이 아니라 '레벨' 이 필요
    //   외부 비동기 입력이므로 2-FF 동기화만 사용 (채터링은 자동 모드 ON/OFF 에 영향 없음)
    synchronizer U_BTN_AUTO_SYNC (
        .clk  (clk),
        .rst  (rst),
        .d    (btnU),
        .q    (w_auto_hold)
    );

    // 측정 모드 제어 (통합 시 U_CONTROL 이 같은 역할 : UART 명령 -> auto_cmd)
    //   단독 테스트에서는 UART 가 없으므로 i_auto_cmd = 0
    sr04_mode_ctrl U_MODE (
        .clk        (clk),
        .rst        (rst),
        .i_btn      (w_btn_tick),
        .i_auto_cmd (1'b0),
        .o_auto_en  (w_auto_cmd_en),
        .o_start    (w_sr04_start)
    );

    // 자동 측정 = btnU 누르는 중 | UART 명령으로 켠 자동 모드
    assign w_auto_en = w_auto_hold | w_auto_cmd_en;

    sr04_core U_SR04 (
        .clk          (clk),
        .rst          (rst),
        .sr04_start   (w_sr04_start),
        .auto_en      (w_auto_en),
        .echo         (echo),
        .trig         (trig),
        .distance     (w_distance),
        .distance_x10 (w_distance_x10),
        .status       (w_status),
        .measuring    (w_measuring),
        .busy         (w_busy),
        .done         (w_done),
        .state        (w_state)
    );

    // 거리 LED 표시부 : 스위치는 거리 막대(LD0~7)만 제어, LD8 / LD9 는 항상 동작
    sr04_led_bar U_LED (
        .clk          (clk),
        .rst          (rst),
        .i_en         (sw_led),
        .i_done       (w_done),
        .i_status     (w_status),
        .i_dist_x10   (w_distance_x10),
        .i_measuring  (w_measuring),
        .o_bar        (led[7:0]),
        .o_meas       (led[8]),
        .o_err        (w_led_err)
    );
    assign led[9] = w_led_err;

    // 거리 FND : 0.1cm 단위 + 소수점 -> 352.7 / 측정 오류 시 "----" (LD9 와 동시)
    fnd_controller_dist U_FND_CNTL (
        .i_clk      (clk),
        .i_reset    (rst),
        .i_value    (w_distance_x10),
        .i_dot      (1'b1),
        .i_err      (w_led_err),
        .o_fnd_com  (fnd_com),
        .o_fnd_data (fnd_font)
    );

`ifdef USE_ILA
    // ILA : IP Catalog -> ILA, Native, clk = system clk(100MHz)
    //   probe0[0:0] trig / probe1[0:0] echo / probe2[0:0] sr04_start
    //   probe3[2:0] state / probe4[8:0] distance
    //   ※ 수업처럼 sr04_controller 안에 ILA 를 넣었다면 여기 ILA 는 쓰지 말 것 (둘 중 하나만)
    ila_0 U_ILA (
        .clk    (clk),
        .probe0 (trig),
        .probe1 (echo),
        .probe2 (w_sr04_start),
        .probe3 (w_state),
        .probe4 (w_distance)
    );
`endif

endmodule


// -----------------------------------------------------------------------------
//  측정 모드 제어 (통합 담당 U_CONTROL 참고용)
//   - auto_cmd(UART 명령) -> 자동 측정 ON
//   - 버튼 : 자동 모드이면 해제만 / 수동 모드이면 1회 측정
// -----------------------------------------------------------------------------
module sr04_mode_ctrl (
    input  clk,
    input  rst,
    input  i_btn,        // 버튼 1클록 tick
    input  i_auto_cmd,   // 자동 측정 명령 1클록 tick
    output o_auto_en,
    output o_start
);

    reg auto_reg;

    always @(posedge clk, posedge rst) begin
        if (rst)             auto_reg <= 1'b0;
        else if (i_auto_cmd) auto_reg <= 1'b1;
        else if (i_btn)      auto_reg <= 1'b0;   // 자동 모드에서 누르면 해제만
    end

    assign o_auto_en = auto_reg;
    assign o_start   = i_btn & ~auto_reg;        // 수동 모드에서만 1회 측정

endmodule


// -----------------------------------------------------------------------------
//  거리 LED 표시부
//   LD0~7 : 정상 측정값 기준 막대 (가까울수록 많이 켜짐), sw OFF 면 전부 OFF
//           10cm 이하 -> 8개 점멸(250ms), 12cm 초과에서 해제 (히스테리시스)
//   LD8   : 측정 진행 중 (START / WAIT / DIST)
//   LD9   : 마지막 측정 실패 (NO_ECHO / OUT_RANGE / ECHO_STUCK), 다음 정상 측정에서 OFF
//   ※ 갱신은 done 시점에만 -> 측정 중에는 이전 표시 유지
// -----------------------------------------------------------------------------
module sr04_led_bar #(
    parameter BLINK_HALF_CYC = 25_000_000,  // 250ms @100MHz
    parameter WARN_ON_X10    = 100,         // 10.0cm 이하 경고 시작
    parameter WARN_OFF_X10   = 120          // 12.0cm 초과 경고 해제
) (
    input         clk,
    input         rst,
    input         i_en,
    input         i_done,
    input  [1:0]  i_status,
    input  [11:0] i_dist_x10,
    input         i_measuring,
    output [7:0]  o_bar,
    output        o_meas,
    output        o_err
);

    reg [3:0]  level_reg;     // 켜질 LED 개수 0~8 (0 = 정상값 없음 / 오류)
    reg        warn_reg;      // 근접 경고 (점멸)
    reg        err_reg;
    reg [$clog2(BLINK_HALF_CYC)-1:0] blink_cnt;
    reg        blink_reg;

    // 거리 -> LED 개수 (0.1cm 단위로 비교)
    function [3:0] bar_level(input [11:0] x10);
        begin
            if      (x10 <=  100) bar_level = 4'd8;
            else if (x10 <=  200) bar_level = 4'd7;
            else if (x10 <=  300) bar_level = 4'd6;
            else if (x10 <=  400) bar_level = 4'd5;
            else if (x10 <=  600) bar_level = 4'd4;
            else if (x10 <=  800) bar_level = 4'd3;
            else if (x10 <= 1000) bar_level = 4'd2;
            else                  bar_level = 4'd1;
        end
    endfunction

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            level_reg <= 0;
            warn_reg  <= 1'b0;
            err_reg   <= 1'b0;
        end else if (i_done) begin
            if (i_status == 2'b00) begin                 // 정상 측정
                err_reg   <= 1'b0;
                level_reg <= bar_level(i_dist_x10);
                if      (i_dist_x10 <= WARN_ON_X10) warn_reg <= 1'b1;
                else if (i_dist_x10 >  WARN_OFF_X10) warn_reg <= 1'b0;
                // 10.0 ~ 12.0cm : 이전 경고 상태 유지
            end else begin                               // 측정 실패
                err_reg   <= 1'b1;
                level_reg <= 0;
                warn_reg  <= 1'b0;
            end
        end
    end

    // 점멸 250ms ON / 250ms OFF
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            blink_cnt <= 0;
            blink_reg <= 1'b0;
        end else if (blink_cnt == BLINK_HALF_CYC - 1) begin
            blink_cnt <= 0;
            blink_reg <= ~blink_reg;
        end else begin
            blink_cnt <= blink_cnt + 1;
        end
    end

    wire [7:0] w_bar_steady = (8'hFF >> (4'd8 - level_reg));   // LD0 부터 level 개
    wire [7:0] w_bar        = warn_reg ? {8{blink_reg}} : ((level_reg == 0) ? 8'h00 : w_bar_steady);

    assign o_bar  = i_en ? w_bar : 8'h00;
    assign o_meas = i_measuring;
    assign o_err  = err_reg;

endmodule


// -----------------------------------------------------------------------------
//  SR04 IP : sync + tick_gen + controller (통합 시 이 모듈만 가져다 쓰면 됨)
// -----------------------------------------------------------------------------
module sr04_core (
    input        clk,
    input        rst,
    input        sr04_start,   // 1회 측정 요청 tick
    input        auto_en,      // 1 = 자동 연속 측정 (60ms 주기)
    input        echo,         // HC-SR04 ECHO 핀 (비동기)
    output       trig,         // HC-SR04 TRIG 핀
    output [8:0] distance,     // cm
    output [11:0] distance_x10, // 0.1cm 단위
    output [1:0] status,       // 00 OK / 01 NO_ECHO / 10 OUT_RANGE / 11 ECHO_STUCK
    output       measuring,    // 실제 측정 진행 중 (START / WAIT / DIST)
    output       busy,         // 측정 중 (재측정 대기 포함)
    output       done,         // 측정 완료 1clk 펄스 (SENDER 캡처용)
    output [2:0] state         // 디버그(ILA)용 FSM 상태
);

    wire w_echo_sync;
    wire w_us_tick;
    wire w_tick_en;
    wire w_tick_clr;
    wire w_start = sr04_start | (auto_en & ~busy);   // 자동 모드 : IDLE 되는 즉시 재측정

    synchronizer U_ECHO_SYNC (
        .clk  (clk),
        .rst  (rst),
        .d    (echo),
        .q    (w_echo_sync)
    );

    tick_gen_us U_TICK_GEN_US (
        .clk     (clk),
        .rst     (rst),
        .en      (w_tick_en),
        .clr     (w_tick_clr),
        .us_tick (w_us_tick)
    );

    sr04_controller U_SR04_CNTL (
        .clk        (clk),
        .rst        (rst),
        .sr04_start (w_start),
        .echo       (w_echo_sync),
        .us_tick    (w_us_tick),
        .tick_en    (w_tick_en),
        .tick_clr   (w_tick_clr),
        .trig       (trig),
        .distance   (distance),
        .distance_x10(distance_x10),
        .status     (status),
        .measuring  (measuring),
        .busy       (busy),
        .done       (done),
        .state      (state)
    );

endmodule


// -----------------------------------------------------------------------------
//  Control Unit + Datapath (FSM 안에 tick 카운터 / cm 카운터 포함)
// -----------------------------------------------------------------------------
module sr04_controller #(
    parameter TRIG_US         = 11,       // 데이터시트 min 10us + 마진 10%
    parameter WAIT_TIMEOUT_US = 30_000,   // echo 상승을 이 시간 안에 못 받으면 센서 이상
    parameter MAX_ECHO_US     = 23_200,   // 400cm * 58us
    parameter STOP_US         = 10_000,   // 데이터시트: echo 종료 후 10ms 뒤 다음 trigger
    parameter MEAS_PERIOD_US  = 60_000,   // 제조사 권장 측정 주기 60ms (trig 상승 기준)
    parameter STUCK_US        = 50_000,   // STOP 에서 echo 가 이만큼 계속 1 이면 고착 판정
    parameter US_PER_CM       = 58,
    parameter MAX_CM          = 400
) (
    input            clk,
    input            rst,
    input            sr04_start,
    input            echo,        // synchronized echo
    input            us_tick,
    output           tick_en,
    output           tick_clr,
    output           trig,
    output     [8:0] distance,
    output    [11:0] distance_x10,
    output     [1:0] status,
    output           measuring,
    output           busy,
    output           done,
    output     [2:0] state
);

    localparam IDLE = 3'd0, START = 3'd1, WAIT = 3'd2, DIST = 3'd3, STOP = 3'd4;

    reg [2:0]  c_state, n_state;
    reg [15:0] tick_cnt_reg, tick_cnt_next;   // 최대 65535us (36_000 비교 가능하도록 16bit)
    reg [5:0]  sub_cnt_reg,  sub_cnt_next;    // 0 ~ 57 (58us = 1cm)
    reg [8:0]  cm_cnt_reg,   cm_cnt_next;
    reg [8:0]  distance_reg, distance_next;
    reg        trig_reg,     trig_next;
    reg        done_reg,     done_next;
    reg [15:0] period_cnt_reg, period_cnt_next;  // trig 상승 후 경과 us (측정 주기)
    reg [6:0]  acc_reg,      acc_next;       // 0.1cm 누적기 (1us 마다 +10, 58 이상이면 -58)
    reg [11:0] x10_cnt_reg,  x10_cnt_next;   // 0.1cm 카운터
    reg [11:0] dist_x10_reg, dist_x10_next;

    localparam MAX_X10 = MAX_CM * 10;        // 4000
    localparam ST_OK = 2'b00, ST_NO_ECHO = 2'b01, ST_OUT_RANGE = 2'b10, ST_STUCK = 2'b11;

    reg [1:0]  status_reg,   status_next;
    reg [15:0] stuck_cnt_reg, stuck_cnt_next;   // STOP 에서 echo 연속 high 시간 (us)

    assign status    = status_reg;
    assign measuring = (c_state == START) || (c_state == WAIT) || (c_state == DIST);

    assign trig     = trig_reg;
    assign distance_x10 = dist_x10_reg;
    assign distance = distance_reg;
    assign done     = done_reg;
    assign busy     = (c_state != IDLE);
    assign state    = c_state;

    // tick 생성기는 측정할 때만 동작, IDLE에서 clear -> 매 측정마다 tick 위상 정렬
    assign tick_en  = (c_state != IDLE);
    assign tick_clr = (c_state == IDLE);

    // state register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state      <= IDLE;
            tick_cnt_reg <= 0;
            sub_cnt_reg  <= 0;
            cm_cnt_reg   <= 0;
            distance_reg <= 0;
            trig_reg     <= 1'b0;
            done_reg     <= 1'b0;
            period_cnt_reg <= 0;
            acc_reg      <= 0;
            x10_cnt_reg  <= 0;
            dist_x10_reg <= 0;
            status_reg   <= ST_OK;
            stuck_cnt_reg <= 0;
        end else begin
            c_state      <= n_state;
            tick_cnt_reg <= tick_cnt_next;
            sub_cnt_reg  <= sub_cnt_next;
            cm_cnt_reg   <= cm_cnt_next;
            distance_reg <= distance_next;
            trig_reg     <= trig_next;
            done_reg     <= done_next;
            period_cnt_reg <= period_cnt_next;
            acc_reg      <= acc_next;
            x10_cnt_reg  <= x10_cnt_next;
            dist_x10_reg <= dist_x10_next;
            status_reg   <= status_next;
            stuck_cnt_reg <= stuck_cnt_next;
        end
    end

    // next state / datapath
    always @(*) begin
        n_state       = c_state;
        tick_cnt_next = tick_cnt_reg;
        sub_cnt_next  = sub_cnt_reg;
        cm_cnt_next   = cm_cnt_reg;
        distance_next = distance_reg;   // 이전 측정값 유지 (FND 깜빡임 방지)
        trig_next     = trig_reg;
        done_next     = 1'b0;           // 1clk 펄스
        acc_next      = acc_reg;
        x10_cnt_next  = x10_cnt_reg;
        dist_x10_next = dist_x10_reg;
        status_next   = status_reg;
        stuck_cnt_next = stuck_cnt_reg;

        // 측정 주기 카운터 : 측정 중(IDLE 제외) 1us 마다 증가
        period_cnt_next = period_cnt_reg;
        if ((c_state != IDLE) && us_tick && (period_cnt_reg != 16'hFFFF))
            period_cnt_next = period_cnt_reg + 1;

        case (c_state)
            IDLE: begin
                trig_next = 1'b0;
                if (sr04_start) begin
                    tick_cnt_next = 0;
                    period_cnt_next = 0;
                    stuck_cnt_next  = 0;
                    trig_next     = 1'b1;
                    n_state       = START;
                end
            end

            // trig 11us 유지
            START: begin
                if (us_tick) begin
                    if (tick_cnt_reg == TRIG_US - 1) begin
                        trig_next     = 1'b0;
                        tick_cnt_next = 0;
                        n_state       = WAIT;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end

            // 8-cycle burst 후 echo 상승 대기 (엣지 대신 레벨 확인 -> 엣지 놓칠 위험 없음)
            WAIT: begin
                if (us_tick) begin
                    if (echo) begin
                        // echo high 를 처음 본 이 1us 도 측정 구간에 포함 (off-by-one 방지)
                        tick_cnt_next = 1;
                        sub_cnt_next  = 1;
                        cm_cnt_next   = 0;
                        acc_next      = 10;     // 첫 1us 도 0.1cm 누적에 포함
                        x10_cnt_next  = 0;
                        n_state       = DIST;
                    end else if (tick_cnt_reg >= WAIT_TIMEOUT_US - 1) begin
                        distance_next = 0;      // 응답 없음(센서 미연결/고장) -> 0
                        dist_x10_next = 0;
                        status_next   = ST_NO_ECHO;
                        done_next     = 1'b1;
                        tick_cnt_next = 0;
                        n_state       = STOP;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end

            // echo high 구간 측정 : 58us 마다 cm +1
            DIST: begin
                if (us_tick) begin
                    if (!echo) begin
                        distance_next = cm_cnt_reg;
                        dist_x10_next = x10_cnt_reg;
                        status_next   = ST_OK;
                        done_next     = 1'b1;
                        tick_cnt_next = 0;
                        n_state       = STOP;
                    end else if (tick_cnt_reg >= MAX_ECHO_US - 1) begin
                        distance_next = MAX_CM;  // 범위 초과 / 물체 없음 (echo ~36ms)
                        dist_x10_next = MAX_X10;
                        status_next   = ST_OUT_RANGE;
                        done_next     = 1'b1;
                        tick_cnt_next = 0;
                        n_state       = STOP;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                        if (sub_cnt_reg == US_PER_CM - 1) begin
                            sub_cnt_next = 0;
                            cm_cnt_next  = cm_cnt_reg + 1;
                        end else begin
                            sub_cnt_next = sub_cnt_reg + 1;
                        end
                        // 0.1cm = 5.8us : 1us 마다 10 누적, 58 넘으면 0.1cm +1
                        if (acc_reg + 10 >= US_PER_CM) begin
                            acc_next     = acc_reg + 10 - US_PER_CM;
                            x10_cnt_next = x10_cnt_reg + 1;
                        end else begin
                            acc_next     = acc_reg + 10;
                        end
                    end
                end
            end

            // echo 하강 후 10ms 대기 + trig 상승 후 60ms(측정 주기) 경과 -> IDLE
            STOP: begin
                if (us_tick) begin
                    if (echo) begin
                        tick_cnt_next = 0;   // 물체 없음(echo 36ms)인 경우 echo 끝날 때까지 대기
                        if (stuck_cnt_reg >= STUCK_US - 1) begin
                            // 오류 복귀 : echo 고착 -> 강제 IDLE, 상태 갱신 알림(done)
                            status_next    = ST_STUCK;
                            done_next      = 1'b1;
                            stuck_cnt_next = 0;
                            n_state        = IDLE;
                        end else begin
                            stuck_cnt_next = stuck_cnt_reg + 1;
                        end
                    end else if ((tick_cnt_reg >= STOP_US - 1) &&
                                 (period_cnt_reg >= MEAS_PERIOD_US - 1)) begin
                        stuck_cnt_next = 0;
                        tick_cnt_next = 0;
                        n_state       = IDLE;
                    end else begin
                        tick_cnt_next  = tick_cnt_reg + 1;
                        stuck_cnt_next = 0;          // echo 가 내려가면 고착 카운트 초기화
                    end
                end
            end

            default: n_state = IDLE;
        endcase
    end

endmodule


// -----------------------------------------------------------------------------
//  1us tick generator (enable / clear)
// -----------------------------------------------------------------------------
module tick_gen_us #(
    parameter CLK_FREQ  = 100_000_000,
    parameter TICK_FREQ = 1_000_000
) (
    input      clk,
    input      rst,
    input      en,
    input      clr,
    output reg us_tick
);

    localparam DIV = CLK_FREQ / TICK_FREQ;   // 100
    reg [$clog2(DIV)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            us_tick     <= 1'b0;
        end else if (clr) begin
            counter_reg <= 0;
            us_tick     <= 1'b0;
        end else if (en) begin
            if (counter_reg == DIV - 1) begin
                counter_reg <= 0;
                us_tick     <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1;
                us_tick     <= 1'b0;
            end
        end else begin
            us_tick <= 1'b0;
        end
    end

endmodule


// -----------------------------------------------------------------------------
//  2-FF synchronizer (외부 비동기 입력용)
// -----------------------------------------------------------------------------
module synchronizer (
    input  clk,
    input  rst,
    input  d,
    output q
);

    (* ASYNC_REG = "TRUE" *) reg ff1, ff2;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            ff1 <= 1'b0;
            ff2 <= 1'b0;
        end else begin
            ff1 <= d;
            ff2 <= ff1;
        end
    end

    assign q = ff2;

endmodule
