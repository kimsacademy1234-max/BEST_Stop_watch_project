`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// [Vivado 에서 실행]  (요구사항 · 슬라이드 양식은 같은 폴더 PPT_SCENARIO.md)
//   1) Design Sources     : verification_v2/source_file/*.v, *.sv
//   2) Simulation Sources : 이 파일 하나 → Set as Top
//   3) Run Simulation → 같은 폴더 tb_wt_s1_cursor_fsm_behav.wcfg 열기 → Run All (190 ms 에서 끝)
//   콘솔 : [STEP n] = 아래 표의 순서 n,  [FSM] = c_state 가 바뀐 순간,  [OK]/[FAIL] = 검사
//   파형 : wcfg 마커 1~7 = 표의 순서 1~7 시작 시각
// -----------------------------------------------------------------------------
// =============================================================================
// 3. Watch 시뮬레이션 · 시나리오 1 : 리셋 뒤 커서 FSM (R · L · U · D)
//   프리로드 없음 — 리셋값 12:00:00.00 에서 버튼 · 스위치만으로 진행
//   버튼 1 번 = 5 ms 누름 → 뗌 (디바운서 tick 은 누른 뒤 약 2 ms)
//
//   순서 | 시각(ms)      | 입력/동작                 | 확인 내용              | 예상 결과
//   -----+---------------+---------------------------+------------------------+--------------------------------------
//    1   | 0.001         | rst (1 us)                | 리셋 상태              | NORMAL, cursor 3, 12:00
//    2   | 10 20 30 40   | set_sw2=0, R → L → U → D  | 설정 OFF 버튼 무시     | tick 4 개 발생, NORMAL 유지, 12:00
//    3   | 60            | set_sw2 = 1               | 설정 진입              | NORMAL → SET_MIN_1 (cursor 0)
//    4   | 70 80 90      | L × 3                     | 커서 왼쪽 이동 · 회전  | MIN_1 → MIN_10 → HOUR → MIN_1
//    5   | 110 120 130   | R × 3                     | 커서 오른쪽 이동 · 회전| MIN_1 → HOUR → MIN_10 → MIN_1
//    6   | 150 160       | U → D                     | 상태 유지 (자기 루프)  | SET_MIN_1 유지, 분 00 → 01 → 00
//    7   | 180           | set_sw2 = 0               | 설정 종료              | SET_MIN_1 → NORMAL (cursor 3)
//
//   c_state 인코딩 (watch_control_unit) : NORMAL 00, SET_HOUR 01, SET_MIN_10 10, SET_MIN_1 11
//   o_wt_cursor (= 상태, 무어)          : SET_MIN_1 0, SET_MIN_10 1, SET_HOUR 2, NORMAL 3
// =============================================================================
module tb_wt_s1_cursor_fsm;
    localparam longint MS = 64'd1_000_000;  // 1 ms in ns
    localparam integer BR = 0, BL = 1, BU = 2, BD = 3;
    localparam logic [1:0] S_NORMAL = 2'b00, S_HOUR = 2'b01, S_MIN10 = 2'b10, S_MIN1 = 2'b11;

    // =========================================================================
    // DUT : Top (stopwatch_watch) — 보드 핀 이름 그대로
    // =========================================================================
    reg clk = 1'b0;
    reg rst = 1'b0;
    reg btn_R = 1'b0, btn_L = 1'b0, btn_U = 1'b0, btn_D = 1'b0;
    reg mode_sw0 = 1'b0;           // 0 시계 화면
    reg display_mode_sw1 = 1'b0;
    reg set_sw2 = 1'b0;
    reg hour24_sw3 = 1'b0;
    reg timer_sw4 = 1'b0;
    wire [3:0]  fnd_com;
    wire [7:0]  fnd_font;
    wire [15:0] led;

    always #5 clk = ~clk;   // 100 MHz

    stopwatch_watch dut (
        .clk             (clk),
        .rst             (rst),
        .btn_R           (btn_R),
        .btn_L           (btn_L),
        .btn_U           (btn_U),
        .btn_D           (btn_D),
        .mode_sw0        (mode_sw0),
        .display_mode_sw1(display_mode_sw1),
        .set_sw2         (set_sw2),
        .hour24_sw3      (hour24_sw3),
        .timer_sw4       (timer_sw4),
        .fnd_com         (fnd_com),
        .fnd_font        (fnd_font),
        .led             (led)
    );

    // =========================================================================
    // 관찰 (읽기만)
    // =========================================================================
    wire [1:0] wt_state = dut.U_WATCH_CONTROL_UNIT.c_state;
    wire [3:0] btn_tick = {dut.w_btn_D, dut.w_btn_U, dut.w_btn_L, dut.w_btn_R};  // U_BD_x.o_btn

    integer n_chk = 0, n_fail = 0;
    integer n_tick[0:3];
    integer n_up = 0, n_down = 0;
    bit     started = 0;
    initial begin n_tick[0] = 0; n_tick[1] = 0; n_tick[2] = 0; n_tick[3] = 0; end

    function automatic string st_name(input logic [1:0] s);
        case (s)
            S_NORMAL: st_name = "NORMAL";
            S_HOUR:   st_name = "SET_HOUR";
            S_MIN10:  st_name = "SET_MIN_10";
            S_MIN1:   st_name = "SET_MIN_1";
            default:  st_name = "X";
        endcase
    endfunction

    function automatic string hm_now();
        hm_now = $sformatf("%02d:%02d", dut.w_wt_hour, dut.w_wt_min);
    endfunction

    // 10 ns 펄스는 negedge 에서 센다 (펄스 구간 한가운데)
    always @(negedge clk) begin
        if (btn_tick[0] === 1'b1) n_tick[0] = n_tick[0] + 1;
        if (btn_tick[1] === 1'b1) n_tick[1] = n_tick[1] + 1;
        if (btn_tick[2] === 1'b1) n_tick[2] = n_tick[2] + 1;
        if (btn_tick[3] === 1'b1) n_tick[3] = n_tick[3] + 1;
        if (|btn_tick === 1'b1)
            $display("[%t] [TICK   ] U_BD_{D,U,L,R}.o_btn = %b   (c_state %s, o_wt_up %b, o_wt_down %b)",
                     $realtime, btn_tick, st_name(wt_state), dut.w_wt_up, dut.w_wt_down);
        if (dut.w_wt_up === 1'b1) n_up = n_up + 1;
        if (dut.w_wt_down === 1'b1) n_down = n_down + 1;
    end

    // 상태가 바뀐 순간 (c_state 는 tick 다음 클럭에 바뀜)
    always @(wt_state) begin
        #1;
        if (started) $display("[%t] [FSM    ] c_state -> %-10s  o_wt_cursor = %0d   time %s",
                              $realtime, st_name(wt_state), dut.w_wt_cursor, hm_now());
    end

    // =========================================================================
    // 검사 · 자극
    // =========================================================================
    function automatic void check(input bit ok, input string what, input string exp_s, input string got_s);
        n_chk = n_chk + 1;
        if (ok) $display("[%t] [OK     ] %-34s | exp=%s got=%s", $realtime, what, exp_s, got_s);
        else begin
            n_fail = n_fail + 1;
            $display("[%t] [FAIL   ] %-34s | exp=%s got=%s", $realtime, what, exp_s, got_s);
        end
    endfunction

    function automatic void check_state(input logic [1:0] exp_s, input integer exp_cur);
        check(wt_state === exp_s, "U_WATCH_CONTROL_UNIT.c_state", st_name(exp_s), st_name(wt_state));
        check(dut.w_wt_cursor === exp_cur, "o_wt_cursor", $sformatf("%0d", exp_cur), $sformatf("%0d", dut.w_wt_cursor));
    endfunction

    function automatic void check_hm(input integer h, input integer m);
        check(dut.w_wt_hour === h && dut.w_wt_min === m, "o_wt_hour:o_wt_min",
              $sformatf("%02d:%02d", h, m), hm_now());
    endfunction

    function automatic void step(input integer n, input string what);
        $display("");
        $display("[%t] [STEP %0d ] %s", $realtime, n, what);
    endfunction

    // 절대 시각(ms)까지 대기 — ms 단위 시각은 항상 clk negedge (경쟁 없음)
    task automatic at_ms(input real t);
        realtime target;
        target = t * 1.0e6;
        if (target > $realtime) #(target - $realtime);
    endtask

    task automatic set_btn(input integer b, input bit v);
        case (b)
            BR: btn_R = v;
            BL: btn_L = v;
            BU: btn_U = v;
            default: btn_D = v;
        endcase
    endtask

    // 5 ms 누름 → 뗌 → 4 ms 뒤 리턴 (그때 검사)
    task automatic press(input integer b);
        set_btn(b, 1'b1);
        #(5 * MS);
        set_btn(b, 1'b0);
        #(4 * MS);
    endtask

    // =========================================================================
    // 시나리오
    // =========================================================================
    initial begin
        $timeformat(-3, 3, " ms", 11);
        $display("==========================================================================================");
        $display(" 3. Watch simulation - Scenario 1 : cursor FSM after reset (R / L / U / D), no preload");
        $display("  # | time(ms)     | input                    | expected");
        $display("  1 | 0.001        | rst 1 us                 | NORMAL, cursor 3, 12:00");
        $display("  2 | 10 20 30 40  | set_sw2=0, R L U D       | 4 ticks, NORMAL kept, 12:00");
        $display("  3 | 60           | set_sw2=1                | NORMAL -> SET_MIN_1 (cursor 0)");
        $display("  4 | 70 80 90     | L x 3                    | MIN_1 -> MIN_10 -> HOUR -> MIN_1");
        $display("  5 | 110 120 130  | R x 3                    | MIN_1 -> HOUR -> MIN_10 -> MIN_1");
        $display("  6 | 150 160      | U, D                     | SET_MIN_1 kept, min 00 -> 01 -> 00");
        $display("  7 | 180          | set_sw2=0                | SET_MIN_1 -> NORMAL (cursor 3)");
        $display("==========================================================================================");

        // ---------------------------------------------------------------- 1
        #10 rst = 1'b1;
        #990 rst = 1'b0;     // 1 us 에 해제
        started = 1;
        step(1, "rst 1 us pulse released");
        at_ms(5);
        check_state(S_NORMAL, 3);
        check_hm(12, 0);

        // ---------------------------------------------------------------- 2
        at_ms(10);
        step(2, "set_sw2 = 0 : press R, L, U, D (ignored)");
        press(BR);
        at_ms(20); press(BL);
        at_ms(30); press(BU);
        at_ms(40); press(BD);
        check(n_tick[0] == 1 && n_tick[1] == 1 && n_tick[2] == 1 && n_tick[3] == 1,
              "debouncer ticks R,L,U,D", "1,1,1,1",
              $sformatf("%0d,%0d,%0d,%0d", n_tick[0], n_tick[1], n_tick[2], n_tick[3]));
        check_state(S_NORMAL, 3);
        check(n_up == 0 && n_down == 0, "o_wt_up / o_wt_down pulses", "0 / 0", $sformatf("%0d / %0d", n_up, n_down));
        check_hm(12, 0);

        // ---------------------------------------------------------------- 3
        at_ms(60);
        step(3, "set_sw2 = 1 (enter set mode)");
        set_sw2 = 1'b1;
        at_ms(65);
        check_state(S_MIN1, 0);

        // ---------------------------------------------------------------- 4
        at_ms(70);
        step(4, "L x 3 (cursor left, wrap)");
        press(BL);
        check_state(S_MIN10, 1);
        at_ms(80); press(BL);
        check_state(S_HOUR, 2);
        at_ms(90); press(BL);
        check_state(S_MIN1, 0);

        // ---------------------------------------------------------------- 5
        at_ms(110);
        step(5, "R x 3 (cursor right, wrap)");
        press(BR);
        check_state(S_HOUR, 2);
        at_ms(120); press(BR);
        check_state(S_MIN10, 1);
        at_ms(130); press(BR);
        check_state(S_MIN1, 0);

        // ---------------------------------------------------------------- 6
        at_ms(150);
        step(6, "U then D (state kept, value +1 / -1)");
        press(BU);
        check_state(S_MIN1, 0);
        check(n_up == 1, "o_wt_up pulses", "1", $sformatf("%0d", n_up));
        check_hm(12, 1);
        at_ms(160); press(BD);
        check_state(S_MIN1, 0);
        check(n_down == 1, "o_wt_down pulses", "1", $sformatf("%0d", n_down));
        check_hm(12, 0);

        // ---------------------------------------------------------------- 7
        at_ms(180);
        step(7, "set_sw2 = 0 (leave set mode)");
        set_sw2 = 1'b0;
        at_ms(185);
        check_state(S_NORMAL, 3);
        check_hm(12, 0);

        at_ms(190);
        $display("");
        $display("[%t] [SUMMARY] WT-S1 checks=%0d fail=%0d => %s", $realtime, n_chk, n_fail,
                 (n_fail == 0) ? "PASS" : "FAIL");
        $finish;
    end
endmodule
