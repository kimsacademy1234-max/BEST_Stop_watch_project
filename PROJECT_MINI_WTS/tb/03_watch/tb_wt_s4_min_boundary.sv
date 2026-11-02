`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// [Vivado 에서 실행]  (요구사항 · 슬라이드 양식은 같은 폴더 PPT_SCENARIO.md)
//   1) Design Sources     : verification_v2/source_file/*.v, *.sv
//   2) Simulation Sources : 이 파일 하나 → Set as Top
//   3) Run Simulation → 같은 폴더 tb_wt_s4_min_boundary_behav.wcfg 열기 → Run All (50 ms 에서 끝)
//   콘솔 : [STEP n] = 아래 표의 순서 n,  [VALUE] = 시:분 이 바뀐 순간,  [OK]/[FAIL] = 검사
//   파형 : wcfg 마커 1~5 = 표의 순서 1~5 시작 시각
// -----------------------------------------------------------------------------
// =============================================================================
// 3. Watch 시뮬레이션 · 시나리오 4 : 경계값 하나 — 분 00 ↔ 59 (U · D)
//   프리로드 없음 — 리셋값 12:00 에서 분 일의 자리(SET_MIN_1) D 한 번이면 바로 경계
//   설계 : U · D 는 커서 자리만 ±1, 윗자리(시)로 올림 · 내림 없음
//          → 분 00 - 1 = 59 (시 12 그대로), 59 + 1 = 00 (시 12 그대로)
//          U_MIN_COUNTER.o_tick (시 올림 펄스) 는 한 번도 나오면 안 된다
//
//   순서 | 시각(ms) | 입력/동작        | 확인 내용                | 예상 결과
//   -----+----------+------------------+--------------------------+------------------------
//    1   | 0.001, 5 | rst, set_sw2 = 1 | 분 일의 자리 선택        | SET_MIN_1, 12:00
//    2   | 10       | U                | 보통 증가                | 12:01
//    3   | 20       | D                | 보통 감소                | 12:00
//    4   | 30       | D                | 경계 아래로 (내림 없음)  | 12:59 (시 12 그대로)
//    5   | 40       | U                | 경계 위로 (올림 없음)    | 12:00 (시 12 그대로)
// =============================================================================
module tb_wt_s4_min_boundary;
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
    wire [1:0] wt_state  = dut.U_WATCH_CONTROL_UNIT.c_state;
    wire       min_carry = dut.U_WATCH_DATAPATH.U_MIN_COUNTER.o_tick;   // 분 → 시 올림 펄스

    integer n_chk = 0, n_fail = 0;
    integer n_up = 0, n_down = 0, n_carry = 0;
    bit     started = 0;

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

    always @(negedge clk) begin
        if (dut.w_wt_up === 1'b1) n_up = n_up + 1;
        if (dut.w_wt_down === 1'b1) n_down = n_down + 1;
        if (started && min_carry === 1'b1) n_carry = n_carry + 1;
    end

    // 시 · 분이 바뀐 순간
    always @(dut.w_wt_min or dut.w_wt_hour) begin
        #1;
        if (started) $display("[%t] [VALUE  ] o_wt_hour:o_wt_min -> %s   (c_state %s)", $realtime, hm_now(), st_name(wt_state));
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

    function automatic void check_hm(input integer h, input integer m);
        check(dut.w_wt_hour === h && dut.w_wt_min === m, "o_wt_hour:o_wt_min",
              $sformatf("%02d:%02d", h, m), hm_now());
    endfunction

    function automatic void check_no_carry();
        check(n_carry == 0, "U_MIN_COUNTER.o_tick (carry to hour)", "0", $sformatf("%0d", n_carry));
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
        $display(" 3. Watch simulation - Scenario 4 : one boundary, minute 00 <-> 59 with U / D, no preload");
        $display("  # | time(ms) | input            | expected");
        $display("  1 | 0.001, 5 | rst, set_sw2=1   | SET_MIN_1, 12:00");
        $display("  2 | 10       | U                | 12:01");
        $display("  3 | 20       | D                | 12:00");
        $display("  4 | 30       | D                | 12:59  (hour stays 12, no borrow)");
        $display("  5 | 40       | U                | 12:00  (hour stays 12, no carry)");
        $display("==========================================================================================");

        // ---------------------------------------------------------------- 1
        #10 rst = 1'b1;
        #990 rst = 1'b0;     // 1 us 에 해제
        started = 1;
        step(1, "rst 1 us pulse released, set_sw2 = 1 at 5 ms");
        at_ms(5);
        set_sw2 = 1'b1;
        at_ms(9);
        check(wt_state === S_MIN1, "U_WATCH_CONTROL_UNIT.c_state", "SET_MIN_1", st_name(wt_state));
        check_hm(12, 0);

        // ---------------------------------------------------------------- 2
        at_ms(10);
        step(2, "U : 00 -> 01");
        press(BU);
        check(n_up == 1, "o_wt_up pulses", "1", $sformatf("%0d", n_up));
        check_hm(12, 1);

        // ---------------------------------------------------------------- 3
        at_ms(20);
        step(3, "D : 01 -> 00");
        press(BD);
        check(n_down == 1, "o_wt_down pulses", "1", $sformatf("%0d", n_down));
        check_hm(12, 0);

        // ---------------------------------------------------------------- 4
        at_ms(30);
        step(4, "D at boundary : 00 -> 59, hour must stay 12");
        press(BD);
        check(n_down == 2, "o_wt_down pulses", "2", $sformatf("%0d", n_down));
        check_hm(12, 59);
        check_no_carry();

        // ---------------------------------------------------------------- 5
        at_ms(40);
        step(5, "U at boundary : 59 -> 00, hour must stay 12");
        press(BU);
        check(n_up == 2, "o_wt_up pulses", "2", $sformatf("%0d", n_up));
        check_hm(12, 0);
        check_no_carry();

        at_ms(50);
        $display("");
        $display("[%t] [SUMMARY] WT-S4 checks=%0d fail=%0d => %s", $realtime, n_chk, n_fail,
                 (n_fail == 0) ? "PASS" : "FAIL");
        $finish;
    end
endmodule
