`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// [Vivado 에서 실행]  (요구사항 · 슬라이드 양식은 같은 폴더 PPT_SCENARIO.md)
//   1) Design Sources     : verification_v2/source_file/*.v, *.sv
//   2) Simulation Sources : 이 파일 하나 → Set as Top
//   3) Run Simulation → 같은 폴더 tb_wt_s2_btn_simul_behav.wcfg 열기 → Run All (50 ms 에서 끝)
//   콘솔 : [STEP n] = 아래 표의 순서 n,  [TICK] = 디바운서 펄스 (같은 클럭에 온 버튼),  [OK]/[FAIL] = 검사
//   파형 : wcfg 마커 1~5 = 표의 순서 1~5 시작 시각
// -----------------------------------------------------------------------------
// =============================================================================
// 3. Watch 시뮬레이션 · 시나리오 2 : R · L · U · D 동시 입력
//   프리로드 없음 — 리셋값 12:00:00.00 에서 버튼 · 스위치만으로 진행
//   동시 입력 = TB 가 같은 시각에 버튼을 누름 → 디바운서 tick 이 같은 클럭(10 ns)에 나옴
//
//   설계 (watch_control_unit)
//     커서 : set_sw2 = 0 > L > R 우선 (L 과 R 이 같이 오면 L 만)
//     값   : U + D 같은 클럭 = 무효 (o_wt_up · o_wt_down 둘 다 0)
//     이동과 ± 는 같은 클럭에 둘 다 일어남. ± 는 누르기 전 커서 자리에 적용 (o_wt_cursor 는 무어)
//
//   순서 | 시각(ms) | 입력/동작          | 확인 내용              | 예상 결과
//   -----+----------+--------------------+------------------------+------------------------------------
//    1   | 0.001, 5 | rst, set_sw2 = 1   | 설정 진입              | SET_MIN_1, 12:00
//    2   | 10       | L + R 동시         | L 우선                 | SET_MIN_1 → SET_MIN_10
//    3   | 20       | U + D 동시         | ± 무효                 | up · down 0, 12:00 유지, SET_MIN_10 유지
//    4   | 30       | L + U 동시         | 이동 + 증가 같은 클럭  | SET_MIN_10 → SET_HOUR, 분 +10 → 12:10
//    5   | 40       | R + L + U + D 동시 | L 우선 + ± 무효        | SET_HOUR → SET_MIN_1, 12:10 유지
//
//   c_state 인코딩 (watch_control_unit) : NORMAL 00, SET_HOUR 01, SET_MIN_10 10, SET_MIN_1 11
//   o_wt_cursor (= 상태, 무어)          : SET_MIN_1 0, SET_MIN_10 1, SET_HOUR 2, NORMAL 3
// =============================================================================
module tb_wt_s2_btn_simul;
    localparam longint MS = 64'd1_000_000;  // 1 ms in ns
    localparam logic [3:0] MR = 4'b0001, ML = 4'b0010, MU = 4'b0100, MD = 4'b1000;  // {D,U,L,R}
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
    wire [1:0] wt_state  = dut.U_WATCH_CONTROL_UNIT.c_state;
    wire [1:0] wt_nstate = dut.U_WATCH_CONTROL_UNIT.n_state;
    wire [3:0] btn_tick  = {dut.w_btn_D, dut.w_btn_U, dut.w_btn_L, dut.w_btn_R};  // U_BD_x.o_btn

    integer   n_chk = 0, n_fail = 0;
    integer   n_up = 0, n_down = 0;
    logic [3:0] last_tick = 4'b0;   // 마지막 디바운서 펄스 {D,U,L,R} (같은 클럭에 온 것 전부)
    bit       started = 0;

    function automatic string st_name(input logic [1:0] s);
        case (s)
            S_NORMAL: st_name = "NORMAL";
            S_HOUR:   st_name = "SET_HOUR";
            S_MIN10:  st_name = "SET_MIN_10";
            S_MIN1:   st_name = "SET_MIN_1";
            default:  st_name = "X";
        endcase
    endfunction

    function automatic string btn_str(input logic [3:0] m);
        btn_str = "";
        if (m[1]) btn_str = {btn_str, "L "};
        if (m[0]) btn_str = {btn_str, "R "};
        if (m[2]) btn_str = {btn_str, "U "};
        if (m[3]) btn_str = {btn_str, "D "};
        if (btn_str == "") btn_str = "- ";
    endfunction

    function automatic string hm_now();
        hm_now = $sformatf("%02d:%02d", dut.w_wt_hour, dut.w_wt_min);
    endfunction

    // 10 ns 펄스는 negedge 에서 센다 (펄스 구간 한가운데)
    always @(negedge clk) begin
        if (|btn_tick === 1'b1) begin
            last_tick = btn_tick;
            $display("[%t] [TICK   ] same clock : %s  c_state %s -> n_state %s,  o_wt_up %b  o_wt_down %b",
                     $realtime, btn_str(btn_tick), st_name(wt_state), st_name(wt_nstate), dut.w_wt_up, dut.w_wt_down);
        end
        if (dut.w_wt_up === 1'b1) n_up = n_up + 1;
        if (dut.w_wt_down === 1'b1) n_down = n_down + 1;
    end

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

    function automatic void check_updown(input integer up, input integer down);
        check(n_up == up && n_down == down, "o_wt_up / o_wt_down pulses (total)",
              $sformatf("%0d / %0d", up, down), $sformatf("%0d / %0d", n_up, n_down));
    endfunction

    function automatic void check_same_clock(input logic [3:0] m);
        check(last_tick === m, "ticks on the same clock {D,U,L,R}", $sformatf("%b", m), $sformatf("%b", last_tick));
    endfunction

    function automatic void step(input integer n, input string what);
        $display("");
        $display("[%t] [STEP %0d ] %s", $realtime, n, what);
    endfunction

    task automatic at_ms(input real t);
        realtime target;
        target = t * 1.0e6;
        if (target > $realtime) #(target - $realtime);
    endtask

    // mask 의 버튼을 같은 시각에 5 ms 누름 → 뗌 → 4 ms 뒤 리턴 (그때 검사)
    task automatic press_multi(input logic [3:0] m);
        btn_R = m[0]; btn_L = m[1]; btn_U = m[2]; btn_D = m[3];
        #(5 * MS);
        btn_R = 1'b0; btn_L = 1'b0; btn_U = 1'b0; btn_D = 1'b0;
        #(4 * MS);
    endtask

    // =========================================================================
    // 시나리오
    // =========================================================================
    initial begin
        $timeformat(-3, 3, " ms", 11);
        $display("==========================================================================================");
        $display(" 3. Watch simulation - Scenario 2 : simultaneous R / L / U / D, no preload");
        $display("  # | time(ms) | input            | expected");
        $display("  1 | 0.001, 5 | rst, set_sw2=1   | SET_MIN_1, 12:00");
        $display("  2 | 10       | L + R            | L wins : SET_MIN_1 -> SET_MIN_10");
        $display("  3 | 20       | U + D            | invalid : up/down 0, 12:00 kept");
        $display("  4 | 30       | L + U            | move + up same clock : SET_HOUR, min +10 -> 12:10");
        $display("  5 | 40       | R + L + U + D    | L wins, U+D invalid : SET_MIN_1, 12:10 kept");
        $display("==========================================================================================");

        // ---------------------------------------------------------------- 1
        #10 rst = 1'b1;
        #990 rst = 1'b0;     // 1 us 에 해제
        started = 1;
        step(1, "rst 1 us pulse released, set_sw2 = 1 at 5 ms");
        at_ms(5);
        set_sw2 = 1'b1;
        at_ms(9);
        check_state(S_MIN1, 0);
        check_hm(12, 0);

        // ---------------------------------------------------------------- 2
        at_ms(10);
        step(2, "L + R at the same time (L has priority)");
        press_multi(ML | MR);
        check_same_clock(ML | MR);
        check_state(S_MIN10, 1);
        check_updown(0, 0);
        check_hm(12, 0);

        // ---------------------------------------------------------------- 3
        at_ms(20);
        step(3, "U + D at the same time (invalid)");
        press_multi(MU | MD);
        check_same_clock(MU | MD);
        check_state(S_MIN10, 1);
        check_updown(0, 0);
        check_hm(12, 0);

        // ---------------------------------------------------------------- 4
        at_ms(30);
        step(4, "L + U at the same time (cursor move + up on old cursor)");
        press_multi(ML | MU);
        check_same_clock(ML | MU);
        check_state(S_HOUR, 2);
        check_updown(1, 0);
        check_hm(12, 10);

        // ---------------------------------------------------------------- 5
        at_ms(40);
        step(5, "R + L + U + D at the same time");
        press_multi(MR | ML | MU | MD);
        check_same_clock(MR | ML | MU | MD);
        check_state(S_MIN1, 0);
        check_updown(1, 0);
        check_hm(12, 10);

        at_ms(50);
        $display("");
        $display("[%t] [SUMMARY] WT-S2 checks=%0d fail=%0d => %s", $realtime, n_chk, n_fail,
                 (n_fail == 0) ? "PASS" : "FAIL");
        $finish;
    end
endmodule
