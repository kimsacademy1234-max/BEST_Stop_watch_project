`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// [Vivado 에서 실행]  (요구사항 · 슬라이드 양식은 같은 폴더 PPT_SCENARIO.md)
//   1) Design Sources     : verification_v2/source_file/*.v, *.sv
//   2) Simulation Sources : 이 파일 + 같은 폴더 fnd_monitor.sv → 이 파일을 Set as Top
//   3) Run Simulation → 같은 폴더 tb_wt_s5_fnd_blink_behav.wcfg 열기 → Run All (4 s 에서 끝, 수 분 걸림)
//   콘솔 : [STEP n] = 아래 표의 순서 n,  [BLINK] = U_DOT.o_blink_off 가 바뀐 순간의 FND 화면,  [OK]/[FAIL] = 검사
//   파형 : wcfg 마커 1~4 = 표의 순서 1~4 시작 시각.  clk 는 wcfg 에서 뺐다 (4 초 × 100 MHz 는 파형이 너무 큼)
//          FND 화면은 mon/disp_bcd (Hex, 화면 4 자리 그대로 "1200", 빈칸 자리 = F) 로 읽는다
// -----------------------------------------------------------------------------
// =============================================================================
// 3. Watch 시뮬레이션 · 시나리오 5 : FND 점멸 (설정 중 커서 자리)
//   프리로드 없음 — 리셋값 12:00, 화면 시.분 (display_mode_sw1 = 1), 12 시간 표시
//   설계 : 시계 화면 & set_sw2 = 1 & 시.분 화면 이고 o_wt_msec ≥ 50 (U_DOT.o_blink_off = 1) 이면
//          커서 자리만 빈칸 (U_ANODE_CHOICE_TO_MUX2.o_anX = d). 0.5 s 켜짐 / 0.5 s 꺼짐
//          o_wt_msec ≥ 50 구간 = 매 초 0.500001 s ~ 1.000001 s (rst 해제 1 us 기준)
//
//   순서 | 시각(s)     | 입력/동작                          | 확인 내용     | 예상 결과 (msec < 50 / ≥ 50)
//   -----+-------------+------------------------------------+---------------+------------------------------
//    1   | 0.000001    | rst, display_mode_sw1 = 1,         | 커서 0 점멸   | "12.00" / "12.0_"  (AN0 빈칸)
//        | 0.005       | set_sw2 = 1 (SET_MIN_1)            |               |
//    2   | 1.000       | L (SET_MIN_10)                     | 커서 1 점멸   | "12.00" / "12._0"  (AN1 빈칸)
//    3   | 2.000       | L (SET_HOUR)                       | 커서 2 점멸   | "12.00" / "1_.00"  (AN2 빈칸)
//    4   | 3.005       | set_sw2 = 0 (NORMAL)               | 점멸 해제     | "12.00" / "12.00"  (가운데 점만 점멸)
// =============================================================================
module tb_wt_s5_fnd_blink;
    localparam longint MS = 64'd1_000_000;  // 1 ms in ns
    localparam logic [1:0] S_NORMAL = 2'b00, S_HOUR = 2'b01, S_MIN10 = 2'b10, S_MIN1 = 2'b11;

    // =========================================================================
    // DUT : Top (stopwatch_watch) — 보드 핀 이름 그대로
    // =========================================================================
    reg clk = 1'b0;
    reg rst = 1'b0;
    reg btn_R = 1'b0, btn_L = 1'b0, btn_U = 1'b0, btn_D = 1'b0;
    reg mode_sw0 = 1'b0;           // 0 시계 화면
    reg display_mode_sw1 = 1'b1;   // 1 시.분 (점멸은 시.분 화면에서만)
    reg set_sw2 = 1'b0;
    reg hour24_sw3 = 1'b0;         // 0 12 시간 표시
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

    // FND 해석기 + 참조 모델 (같은 폴더의 fnd_monitor.sv 를 같이 추가할 것)
    //   disp_str = 지금 화면 "12.0_" (빈칸 '_'),  disp_bcd = 화면 4 자리 BCD (파형용, 빈칸 F)
    fnd_monitor mon (
        .i_fnd_com  (fnd_com),
        .i_fnd_font (fnd_font),
        .i_scan_sel (dut.U_FND_CONTROLLER.w_scan_sel),
        .i_disp_mode(dut.w_disp_mode),
        .i_disp_hour(dut.w_disp_hour),
        .i_disp_min (dut.w_disp_min),
        .i_disp_sec (dut.w_disp_sec),
        .i_disp_msec(dut.w_disp_msec),
        .i_wt_cursor(dut.w_wt_cursor),
        .i_set_sw2  (set_sw2),
        .i_sel_wt   (dut.w_sel_wt)
    );

    // =========================================================================
    // 관찰 (읽기만)
    // =========================================================================
    wire [1:0]  wt_state  = dut.U_WATCH_CONTROL_UNIT.c_state;
    wire        blink_off = dut.U_FND_CONTROLLER.w_blink_off;               // U_DOT.o_blink_off
    wire [15:0] an_out    = {dut.U_FND_CONTROLLER.w_mux2_an3, dut.U_FND_CONTROLLER.w_mux2_an2,
                             dut.U_FND_CONTROLLER.w_mux2_an1, dut.U_FND_CONTROLLER.w_mux2_an0};  // U_ANODE_CHOICE_TO_MUX2.o_an3..0

    integer n_chk = 0, n_fail = 0;
    integer mm_base = 0;
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

    // 점멸 박자가 바뀐 순간 (0.5 s 마다) — 3 ms 뒤 (화면 한 바퀴 2 ms 지난 뒤) 화면 문자열
    always @(blink_off) begin
        if (started) begin
            #(3 * MS);
            $display("[%t] [BLINK  ] o_blink_off=%b  c_state %-10s  o_an3..0=%h  FND \"%s\"",
                     $realtime, blink_off, st_name(wt_state), an_out, mon.disp_str);
        end
    end

    always @(wt_state) begin
        #1;
        if (started) $display("[%t] [FSM    ] c_state -> %-10s  o_wt_cursor = %0d", $realtime, st_name(wt_state), dut.w_wt_cursor);
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

    // 한 순간 검사 : 점멸 박자 · 상태 · 화면 4 자리 (o_an3..0, d = 빈칸) · FND 화면 문자열
    function automatic void check_disp(input bit exp_off, input logic [1:0] exp_s, input logic [15:0] exp_an,
                                       input string exp_str);
        check(blink_off === exp_off, "U_DOT.o_blink_off", $sformatf("%b", exp_off), $sformatf("%b", blink_off));
        check(wt_state === exp_s, "U_WATCH_CONTROL_UNIT.c_state", st_name(exp_s), st_name(wt_state));
        check(an_out === exp_an, "U_ANODE_CHOICE_TO_MUX2.o_an3..0", $sformatf("%h", exp_an), $sformatf("%h", an_out));
        check(mon.disp_str == exp_str, "FND screen (fnd_com/fnd_font)", exp_str, mon.disp_str);
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

    // 5 ms 누름 → 뗌
    task automatic press_L();
        btn_L = 1'b1;
        #(5 * MS);
        btn_L = 1'b0;
    endtask

    // =========================================================================
    // 시나리오
    // =========================================================================
    initial begin
        $timeformat(-3, 3, " ms", 12);
        $display("==========================================================================================");
        $display(" 3. Watch simulation - Scenario 5 : FND blink of the cursor digit (HH.MM screen), no preload");
        $display("  # | time(s)       | input                         | expected (msec<50 / msec>=50)");
        $display("  1 | 0.000001/0.005| rst, sw1=1, set_sw2=1         | \"12.00\" / \"12.0_\"  AN0 blank");
        $display("  2 | 1.000         | L (SET_MIN_10)                | \"12.00\" / \"12._0\"  AN1 blank");
        $display("  3 | 2.000         | L (SET_HOUR)                  | \"12.00\" / \"1_.00\"  AN2 blank");
        $display("  4 | 3.005         | set_sw2=0 (NORMAL)            | \"12.00\" / \"12.00\"  no blink");
        $display("==========================================================================================");

        // ---------------------------------------------------------------- 1
        #10 rst = 1'b1;
        #990 rst = 1'b0;     // 1 us 에 해제
        step(1, "rst released (display_mode_sw1 = 1), set_sw2 = 1 at 5 ms -> SET_MIN_1");
        at_ms(5);
        set_sw2 = 1'b1;
        started = 1;
        at_ms(10);
        mm_base = mon.mm_count;   // 리셋 전 X 구간은 빼고 셈
        at_ms(250);
        check_disp(1'b0, S_MIN1, 16'h1200, "12.00");
        at_ms(750);
        check_disp(1'b1, S_MIN1, 16'h120d, "12.0_");

        // ---------------------------------------------------------------- 2
        at_ms(1000);
        step(2, "L -> SET_MIN_10 (cursor 1 blinks)");
        press_L();
        at_ms(1250);
        check_disp(1'b0, S_MIN10, 16'h1200, "12.00");
        at_ms(1750);
        check_disp(1'b1, S_MIN10, 16'h12d0, "12._0");

        // ---------------------------------------------------------------- 3
        at_ms(2000);
        step(3, "L -> SET_HOUR (cursor 2 blinks)");
        press_L();
        at_ms(2250);
        check_disp(1'b0, S_HOUR, 16'h1200, "12.00");
        at_ms(2750);
        check_disp(1'b1, S_HOUR, 16'h1d00, "1_.00");

        // ---------------------------------------------------------------- 4
        at_ms(3005);
        step(4, "set_sw2 = 0 -> NORMAL (no blink)");
        set_sw2 = 1'b0;
        at_ms(3250);
        check_disp(1'b0, S_NORMAL, 16'h1200, "12.00");
        at_ms(3750);
        check_disp(1'b1, S_NORMAL, 16'h1200, "12.00");

        at_ms(4000);
        check(mon.mm_count - mm_base == 0, "FND output = reference model (whole run)", "0 mismatch",
              $sformatf("%0d mismatch", mon.mm_count - mm_base));
        $display("");
        $display("[%t] [SUMMARY] WT-S5 checks=%0d fail=%0d => %s", $realtime, n_chk, n_fail,
                 (n_fail == 0) ? "PASS" : "FAIL");
        $finish;
    end
endmodule
