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
//                   (merge) auto_en 은 버튼 U 로 켜기/끄기 (DHT11 과 같은 동작, sr04_mode_ctrl)
//  - 상태 구분    : status 00 OK / 01 NO_ECHO / 10 OUT_RANGE / 11 ECHO_STUCK
//  - 오류 복귀    : echo 가 계속 1 이면 STOP 에서 50ms 후 강제 IDLE (데드락 방지)
//  - LED 표시     : LD0~7 거리 막대(스위치로 ON/OFF), LD8 측정 중, LD9 측정 오류
//
//  FSM : IDLE -> START(trig 11us) -> WAIT(echo=1) -> DIST(echo=0)
//        -> STOP(echo 하강 후 10ms & 주기 60ms 경과) -> IDLE
// =============================================================================

// -----------------------------------------------------------------------------
//  SR04 IP : sync + tick_gen + controller
//  (merge) synchronizer · tick_gen_us 는 IP 폴더의 공용 모듈 사용, 포트 이름 v2 규칙 (i_ / o_)
// -----------------------------------------------------------------------------
module sr04_core (
    input         i_clk,
    input         i_rst,
    input         i_start,          // 1회 측정 요청 tick
    input         i_auto_en,        // 1 = 자동 연속 측정 (60ms 주기)
    input         i_echo,           // HC-SR04 ECHO 핀 (비동기)
    output        o_trig,           // HC-SR04 TRIG 핀
    output [ 8:0] o_distance,       // cm
    output [11:0] o_distance_x10,   // 0.1cm 단위
    output [ 1:0] o_status,         // 00 OK / 01 NO_ECHO / 10 OUT_RANGE / 11 ECHO_STUCK
    output        o_measuring,      // 실제 측정 진행 중 (START / WAIT / DIST)
    output        o_busy,           // 측정 중 (재측정 대기 포함)
    output        o_done,           // 측정 완료 1clk 펄스 (SENDER 캡처용)
    output [ 2:0] o_state           // 디버그(ILA)용 FSM 상태
);

    wire w_echo_sync;
    wire w_us_tick;
    wire w_tick_en;
    wire w_tick_clr;
    wire w_start = i_start | (i_auto_en & ~o_busy);   // 자동 모드 : IDLE 되는 즉시 재측정

    synchronizer U_ECHO_SYNC (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_d  (i_echo),
        .o_q  (w_echo_sync)
    );

    tick_gen_us #(
        .F_COUNT(100)
    ) U_TICK_GEN_US (
        .i_clk   (i_clk),
        .i_rst   (i_rst),
        .i_enable(w_tick_en),
        .i_clear (w_tick_clr),
        .o_tick  (w_us_tick)
    );

    sr04_controller U_SR04_CNTL (
        .i_clk         (i_clk),
        .i_rst         (i_rst),
        .i_start       (w_start),
        .i_echo        (w_echo_sync),
        .i_us_tick     (w_us_tick),
        .o_tick_en     (w_tick_en),
        .o_tick_clr    (w_tick_clr),
        .o_trig        (o_trig),
        .o_distance    (o_distance),
        .o_distance_x10(o_distance_x10),
        .o_status      (o_status),
        .o_measuring   (o_measuring),
        .o_busy        (o_busy),
        .o_done        (o_done),
        .o_state       (o_state)
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
    input            i_clk,
    input            i_rst,
    input            i_start,
    input            i_echo,        // synchronized echo
    input            i_us_tick,
    output           o_tick_en,
    output           o_tick_clr,
    output           o_trig,
    output     [8:0] o_distance,
    output    [11:0] o_distance_x10,
    output     [1:0] o_status,
    output           o_measuring,
    output           o_busy,
    output           o_done,
    output     [2:0] o_state
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

    assign o_status    = status_reg;
    assign o_measuring = (c_state == START) || (c_state == WAIT) || (c_state == DIST);

    assign o_trig     = trig_reg;
    assign o_distance_x10 = dist_x10_reg;
    assign o_distance = distance_reg;
    assign o_done     = done_reg;
    assign o_busy     = (c_state != IDLE);
    assign o_state    = c_state;

    // tick 생성기는 측정할 때만 동작, IDLE에서 clear -> 매 측정마다 tick 위상 정렬
    assign o_tick_en  = (c_state != IDLE);
    assign o_tick_clr = (c_state == IDLE);

    // state register
    always @(posedge i_clk, posedge i_rst) begin
        if (i_rst) begin
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
        if ((c_state != IDLE) && i_us_tick && (period_cnt_reg != 16'hFFFF))
            period_cnt_next = period_cnt_reg + 1;

        case (c_state)
            IDLE: begin
                trig_next = 1'b0;
                if (i_start) begin
                    tick_cnt_next = 0;
                    period_cnt_next = 0;
                    stuck_cnt_next  = 0;
                    trig_next     = 1'b1;
                    n_state       = START;
                end
            end

            // trig 11us 유지
            START: begin
                if (i_us_tick) begin
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
                if (i_us_tick) begin
                    if (i_echo) begin
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
                if (i_us_tick) begin
                    if (!i_echo) begin
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
                if (i_us_tick) begin
                    if (i_echo) begin
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
